(* High-Frequency Market Maker Engine (Zero-Alloc Hot Path)
   
   Architecture:
   1. Types: Flat, mutable records with rigorous memory layout.
   2. Math: Fixed-point precision (Q16.16 or scaled integers) to avoid FPU.
   3. Logic: Event-driven "on_tick" loop.
*)

[@@@warning "-32-27"] (* Suppress unused var warnings for the demo *)

(* --- 1. FIXED POINT MATH CONSTANTS --- *)
module Const = struct
  let price_scale = 100          (* 2 decimals *)
  let alpha_scale = 1000         (* Internal precision for signals *)
  let ema_alpha   = 50           (* Smoothing factor 0.05 * 1000 *)
  let max_pos     = 500          (* Max inventory limit *)
  let risk_aversion = 10         (* Price ticks to skew per unit of inventory *)
end

(* --- 2. DATA STRUCTURES --- *)

(* Top of Book: Immediate market state *)
type tob =
  { bid_px : int
  ; bid_qty : int
  ; ask_px : int
  ; ask_qty : int
  }

(* Strategy Internal State:
   Mutable fields for signals, inventory, and PnL.
   Layout is critical for cache locality. 
*)
type state =
  { (* Market Data History *)
    mutable last_mid      : int
  ; mutable ema_mid       : int  (* Exponential Moving Average of Mid *)
  
  (* Signals *)
  ; mutable imbalance     : int  (* Order Book Imbalance *)
  ; mutable fair_value    : int  (* The internal 'true' price *)
  
  (* Risk & Execution *)
  ; mutable position      : int  (* Current net inventory *)
  ; mutable cash          : int  (* Realized + Unrealized cash proxy *)
  ; mutable total_traded  : int
  }

(* Pre-allocated Output Object 
   We write to this instead of returning a new tuple/record 
*)
type order_action =
  { mutable action : int (* 0=NONE, 1=BUY, 2=SELL *)
  ; mutable price  : int
  ; mutable size   : int
  ; mutable reason : int (* Debug code for why we traded *)
  }

(* --- 3. HELPER KERNELS (ALWAYS INLINE) --- *)

let[@inline always] update_ema (current_val : int) (prev_ema : int) : int =
  (* Standard Int-based EMA: 
     New = (Alpha * Price + (1000 - Alpha) * Old) / 1000 *)
  if prev_ema = 0 then current_val
  else
    let num = (Const.ema_alpha * current_val) + ((Const.alpha_scale - Const.ema_alpha) * prev_ema) in
    num / Const.alpha_scale

let[@inline always] clamp x ~lo ~hi =
  if x < lo then lo else if x > hi then hi else x

(* --- 4. THE HOT PATH (ZERO ALLOC) --- *)

(* on_tick:
   Evaluates market data, updates signals, adjusts for inventory risk, 
   and generates an execution decision.
   
   Returns: 1 if trade generated, 0 otherwise (output written to `out`)
*)
let[@zero_alloc] on_tick 
    (t : tob) 
    (st : state) 
    (out : order_action) 
  : int =
  
  (* 1. DERIVE MID PRICE *)
  let mid = (t.bid_px + t.ask_px) / 2 in
  
  (* 2. UPDATE SIGNALS *)
  st.last_mid <- mid;
  st.ema_mid  <- update_ema mid st.ema_mid;

  (* Calculate Imbalance Ratio (scaled): (BidQty - AskQty) / (BidQty + AskQty) 
     We scale by alpha_scale to keep precision. *)
  let total_qty = t.bid_qty + t.ask_qty in
  let imb_raw   = t.bid_qty - t.ask_qty in
  (* Avoid div by zero *)
  st.imbalance <- if total_qty > 0 
                  then (imb_raw * Const.alpha_scale) / total_qty 
                  else 0;

  (* 3. CALCULATE FAIR VALUE (The Alpha)
     FairValue = EMA_Mid + (Imbalance_Signal) 
  *)
  (* Weigh the imbalance impact. e.g., max imbalance moves fair value by 2 ticks *)
  let signal_impact = st.imbalance / 200 in 
  let raw_fair = st.ema_mid + signal_impact in

  (* 4. INVENTORY SKEW (Risk Management)
     If we are long, we lower our fair value to sell.
     If we are short, we raise our fair value to buy.
     Skew = Position * RiskAversionFactor
  *)
  let skew = (st.position * Const.risk_aversion) / 100 in 
  st.fair_value <- raw_fair - skew;

  (* 5. EXECUTION LOGIC (Crossing the spread) 
     In a full MM, we would post limit orders. 
     Here, we simulate "Taking" if the edge is high enough.
     
     Buy Condition:  AskPrice < FairValue - Margin
     Sell Condition: BidPrice > FairValue + Margin
  *)
  
  let required_edge = 5 in (* We need 5 ticks of theoretical profit to pay spread *)
  
  (* Reset output *)
  out.action <- 0;
  out.size   <- 0;
  out.price  <- 0;
  out.reason <- 0;

  let can_buy  = st.position < Const.max_pos in
  let can_sell = st.position > -Const.max_pos in

  (* Check BUY opportunity *)
  if can_buy && (t.ask_px < st.fair_value - required_edge) then begin
    out.action <- 1;
    out.price  <- t.ask_px;
    (* Sizing: Trade larger if imbalance favors us *)
    let base_size = 10 in
    out.size   <- clamp (base_size + (st.imbalance / 100)) ~lo:1 ~hi:50;
    out.reason <- 1; (* Signal Buy *)
    1
  end 
  (* Check SELL opportunity *)
  else if can_sell && (t.bid_px > st.fair_value + required_edge) then begin
    out.action <- 2;
    out.price  <- t.bid_px;
    let base_size = 10 in
    (* Note: Imbalance is negative for sell pressure, so we sub *)
    out.size   <- clamp (base_size - (st.imbalance / 100)) ~lo:1 ~hi:50;
    out.reason <- 2; (* Signal Sell *)
    1
  end 
  else 0

(* --- 5. EXECUTION HANDLER (POST-TRADE BOOKKEEPING) --- *)

let update_position (st : state) (side : int) (qty : int) (px : int) =
  (* This is usually not in the hot-path decision loop, but immediately after *)
  match side with
  | 1 -> (* BUY *)
     st.position <- st.position + qty;
     st.cash     <- st.cash - (qty * px);
     st.total_traded <- st.total_traded + qty
  | 2 -> (* SELL *)
     st.position <- st.position - qty;
     st.cash     <- st.cash + (qty * px);
     st.total_traded <- st.total_traded + qty
  | _ -> ()

(* --- 6. SIMULATION HARNESS --- *)

let pp_tob t =
  Printf.sprintf "BID %4d @ %6d | ASK %4d @ %6d" t.bid_qty t.bid_px t.ask_qty t.ask_px

let () =
  Random.self_init ();
  
  (* Initial State *)
  let st = 
    { last_mid = 10000; ema_mid = 0; imbalance = 0
    ; fair_value = 10000; position = 0; cash = 0; total_traded = 0 
    } 
  in
  let out = { action = 0; price = 0; size = 0; reason = 0 } in
  
  (* Simulation Parameters *)
  let price = ref 10_000 in
  let ticks = 100_000 in
  
  Printf.printf "Starting HFT Simulation (%d ticks)...\n" ticks;
  Printf.printf "Parameters: MaxPos=%d, RiskAversion=%d\n%!" Const.max_pos Const.risk_aversion;

  let start_t = Sys.time() in

  for i = 1 to ticks do
    (* 1. Simulate Random Walk Market Data *)
    let move = (Random.int 3) - 1 in (* -1, 0, or +1 *)
    price := !price + move;
    
    (* Create Spread and Liquidity *)
    let spread = 2 + (Random.int 3) in
    let b_px = !price - (spread / 2) in
    let a_px = b_px + spread in
    
    (* Randomize liquidity (noisy) *)
    let b_qty = 100 + Random.int 400 in
    let a_qty = 100 + Random.int 400 in
    
    let market_data = { bid_px = b_px; bid_qty = b_qty; ask_px = a_px; ask_qty = a_qty } in
    
    (* 2. CALL THE HOT KERNEL *)
    let res = on_tick market_data st out in
    
    (* 3. SIMULATED MATCHING ENGINE *)
    if res <> 0 then begin
       update_position st out.action out.size out.price;
       
       (* Debug Output for interesting events (sparsely) *)
       if i mod 100 = 0 then
         Printf.printf "[TICK %d] %s | FV:%d Pos:%d -> ACT: %s %d@%d\n%!" 
           i (pp_tob market_data) st.fair_value st.position 
           (if out.action=1 then "BUY" else "SELL") out.size out.price
    end
  done;

  let end_t = Sys.time() in
  
  (* Mark to Market PnL calculation *)
  let final_mid = !price in
  let position_value = st.position * final_mid in
  let total_pnl = st.cash + position_value in
  
  Printf.printf "\n--- Simulation Results ---\n";
  Printf.printf "Total Ticks  : %d\n" ticks;
  Printf.printf "Elapsed Time : %.4fs\n" (end_t -. start_t);
  Printf.printf "Total Volume : %d contracts\n" st.total_traded;
  Printf.printf "Final Pos    : %d\n" st.position;
  Printf.printf "Ending PnL   : %d (Ticks)\n" total_pnl;
