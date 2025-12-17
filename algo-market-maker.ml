(* Oxtrader: HFT Market Making Engine (Maker Strategy)
   
   Architecture Changes:
   1. Strategy: "Maker" (Posts Limits) instead of "Taker".
   2. Simulation: Checks for passive fills (price moving through our limits).
   3. Market Process: Ornstein-Uhlenbeck (Mean Reverting) to make alpha real.
*)

[@@@warning "-32-27"]

(* --- 1. CONSTANTS --- *)
module Const = struct
  let tick_size = 1
  let max_pos   = 100          (* Tighter position limit *)
  let risk_factor = 5          (* Ticks to skew per 10 units of inventory *)
  let half_spread = 1          (* We try to quote 1 tick inside or at touch *)
end

(* --- 2. TYPES --- *)

type tob =
  { bid_px : int ; bid_qty : int
  ; ask_px : int ; ask_qty : int 
  }

(* Our Output is now a "Quoting Instruction", not a trade *)
type quote_intent =
  { mutable bid_limit : int    (* Price we want to buy at *)
  ; mutable ask_limit : int    (* Price we want to sell at *)
  ; mutable active    : bool   (* Are we quoting? *)
  }

type state =
  { (* Market Memory *)
    mutable ema_mid     : int
  ; mutable vol_proxy   : int  (* Measure of volatility *)
  
  (* Risk & PnL *)
  ; mutable position    : int
  ; mutable cash        : int
  ; mutable volume      : int
  ; mutable fills       : int
  }

(* --- 3. ZERO-ALLOC MATH --- *)

let[@inline always] update_ema cur prev alpha =
  (* Fixed point smoothing *)
  if prev = 0 then cur else
    ((alpha * cur) + ((1000 - alpha) * prev)) / 1000

(* --- 4. THE STRATEGY KERNEL (MAKER) --- *)

let[@zero_alloc] on_tick 
      (t : tob) 
      (st : state) 
      (q : quote_intent) 
  : unit = (* Returns unit, updates 'q' in place *)

  (* A. UPDATE MARKET STATE *)
  let mid = (t.bid_px + t.ask_px) / 2 in
  st.ema_mid <- update_ema mid st.ema_mid 50; (* alpha=0.05 *)
  
  (* Calculate simple volatility proxy (abs diff from mean) *)
  let diff = abs (mid - st.ema_mid) in
  st.vol_proxy <- update_ema diff st.vol_proxy 10;

  (* B. CALCULATE FAIR VALUE *)
  (* Start with the Micro-Price (Weighted Mid) *)
  let book_imb = 
    if (t.bid_qty + t.ask_qty) > 0 then
      ((t.bid_qty - t.ask_qty) * 100) / (t.bid_qty + t.ask_qty)
    else 0 
  in
  (* If imbalance is +50% (Buy pressure), fair value shifts up *)
  let fair_value = mid + (book_imb * Const.tick_size / 100) in

  (* C. INVENTORY SKEW (CRITICAL FOR PNL) *)
  (* If we are Long (Pos > 0), we want to Sell. We lower quotes.
     If we are Short (Pos < 0), we want to Buy. We raise quotes. *)
  let skew = (st.position * Const.risk_factor) / 10 in
  
  (* Our "Center" price is FairValue adjusted by Skew *)
  let my_center = fair_value - skew in

  (* D. GENERATE QUOTES *)
  (* We quote a spread around our center. 
     Widen spread if volatility is high (defensive). *)
  let width = Const.half_spread + (st.vol_proxy / 2) in
  
  q.bid_limit <- my_center - width;
  q.ask_limit <- my_center + width;
  q.active    <- true;

  (* E. SAFETY CLAMP *)
  (* Never cross the market aggressively in a Maker strategy (usually).
     Clamp bid to at most Ask-1, Ask to at least Bid+1 *)
  if q.bid_limit >= t.ask_px then q.bid_limit <- t.ask_px - 1;
  if q.ask_limit <= t.bid_px then q.ask_limit <- t.bid_px + 1;
  ()

(* --- 5. SIMULATION ENGINE (FILL LOGIC) --- *)

(* Checks if the market moved through our limits *)
let check_fills (t : tob) (st : state) (q : quote_intent) =
  (* 1. CHECK BUY FILL *)
  (* If Market Ask drops to or below my Bid Limit, I get filled (Adverse Selection) 
     OR if Market Bid hits my Bid Limit (Passive Fill) -- Simplified here:
     We assume we get filled if Market Low trade <= My Bid *)
     
  (* For sim: We assume if the Ticker Bid drops below my Bid, I caught a seller. *)
  if q.active && st.position < Const.max_pos then begin
    if t.bid_px <= q.bid_limit then begin
      st.position <- st.position + 1;
      st.cash     <- st.cash - q.bid_limit;
      st.volume   <- st.volume + 1;
      st.fills    <- st.fills + 1;
    end
  end;

  (* 2. CHECK SELL FILL *)
  if q.active && st.position > -Const.max_pos then begin
    if t.ask_px >= q.ask_limit then begin
      st.position <- st.position - 1;
      st.cash     <- st.cash + q.ask_limit;
      st.volume   <- st.volume + 1;
      st.fills    <- st.fills + 1;
    end
  end

(* --- 6. RUNNER --- *)

let () =
  Random.self_init ();
  let st = 
    { ema_mid = 0; vol_proxy = 0; position = 0; cash = 0; volume = 0; fills = 0 } 
  in
  let q = { bid_limit=0; ask_limit=0; active=false } in

  (* MARKET GENERATOR: MEAN REVERTING (Ornstein-Uhlenbeck) *)
  (* Real markets mean revert on short scales. This allows MM to profit. *)
  let true_value = 10_000.0 in
  let current_val = ref true_value in
  let ticks = 50_000 in

  Printf.printf "Starting MAKER Simulation (%d ticks)...\n%!" ticks;

  for i = 1 to ticks do
    (* 1. Evolve Market Price *)
    let noise = (Random.float 2.0) -. 1.0 in
    let mean_reversion = 0.01 *. (true_value -. !current_val) in
    current_val := !current_val +. mean_reversion +. noise;
    
    let mid = int_of_float !current_val in
    let spread = 2 in
    
    (* Market Data *)
    let t = 
      { bid_px = mid - (spread/2); ask_px = mid + (spread/2)
      ; bid_qty = 500; ask_qty = 500 } 
    in
    
    (* 2. Run Strategy *)
    on_tick t st q;
    
    (* 3. Simulate Matches *)
    check_fills t st q;
    
    if i mod 5000 = 0 then
      let mtm = st.cash + (st.position * mid) in
      Printf.printf "Tick %5d | Pos: %3d | PnL: %d | Quotes: %d / %d (Mid %d)\n%!" 
        i st.position mtm q.bid_limit q.ask_limit mid
  done;

  let final_mid = int_of_float !current_val in
  let total_pnl = st.cash + (st.position * final_mid) in
  Printf.printf "\n--- FINAL RESULTS ---\n";
  Printf.printf "Total PnL : %d ticks\n" total_pnl;
  Printf.printf "Total Vol : %d\n" st.volume;
  Printf.printf "Fills     : %d\n" st.fills
