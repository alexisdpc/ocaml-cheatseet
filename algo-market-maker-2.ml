(* =============================================================================
   Oxtrader: HFT Market Making Engine (Maker Strategy)
   Author: Alexis D. Plascencia
   
   WHAT IS MARKET MAKING?
   ----------------------
   A Market Maker provides liquidity by continuously posting BID (buy) and 
   ASK (sell) orders on both sides of the order book. We profit from the 
   SPREAD (difference between our buy and sell prices) while managing 
   INVENTORY RISK (the risk of holding too much of one side).
   
   MAKER vs TAKER:
   - TAKER: Crosses the spread, takes liquidity, pays fees, instant execution
   - MAKER: Posts limit orders, provides liquidity, earns rebates, waits for fills
   
   KEY CONCEPTS:
   1. Fair Value: Our estimate of the "true" price
   2. Inventory Skew: Adjust quotes based on our position to reduce risk
   3. Adverse Selection: Getting filled often means price moved against us
   4. Mean Reversion: Short-term price movements tend to reverse (our edge)
   
   ARCHITECTURE:
   - Zero-allocation hot path (no GC pauses in critical code)
   - Mutable state for performance (avoiding allocation)
   - Fixed-point arithmetic (integers instead of floats for speed)
   
   Author: [Your Name]
   Version: 2.0
   ============================================================================= *)

[@@@warning "-32-27"]  (* Suppress unused value warnings for cleaner output *)

(* =============================================================================
   MODULE 1: CONSTANTS
   
   These parameters control strategy behavior. In production, these would be
   loaded from a config file and potentially adjusted dynamically.
   ============================================================================= *)
module Const = struct
  (* Market microstructure parameters *)
  let tick_size = 1              (* Minimum price increment *)
  let book_depth = 10            (* Levels of book to consider (future use) *)
  
  (* Risk management parameters *)
  let max_pos = 100              (* Maximum absolute position (long or short) *)
  let risk_factor = 5            (* Ticks to skew per 10 units of inventory *)
  let max_drawdown = 1000        (* Stop trading if PnL drops below this *)
  
  (* Quoting parameters *)
  let half_spread = 1            (* Base half-spread in ticks *)
  let min_spread = 1             (* Never quote tighter than this *)
  let max_spread = 5             (* Never quote wider than this *)
  
  (* EMA smoothing factors (in thousandths for fixed-point math) *)
  (* alpha = 50 means 50/1000 = 0.05 = 5% weight to new value *)
  let ema_alpha_fast = 50        (* Fast EMA for mid price *)
  let ema_alpha_slow = 10        (* Slow EMA for volatility *)
  
  (* Fill probability adjustment *)
  let aggressive_threshold = 3   (* Ticks inside touch to expect faster fill *)
end

(* =============================================================================
   MODULE 2: TYPE DEFINITIONS
   
   Using mutable records for zero-allocation updates in the hot path.
   In OCaml, accessing mutable fields is very fast (no boxing).
   ============================================================================= *)

(* Top-of-Book: The best bid and ask prices/quantities *)
type tob = {
  bid_px  : int;    (* Best bid price (highest buy order) *)
  bid_qty : int;    (* Size available at best bid *)
  ask_px  : int;    (* Best ask price (lowest sell order) *)
  ask_qty : int;    (* Size available at best ask *)
  
  (* Extended market data (for future enhancements) *)
  (* last_trade_px : int;    (* Price of last trade *)
     last_trade_side : int;  (* 1=buy, -1=sell, 0=unknown *) *)
}

(* Quote Intent: What prices we WANT to quote (before exchange validation) *)
type quote_intent = {
  mutable bid_limit : int;    (* Price we want to buy at *)
  mutable ask_limit : int;    (* Price we want to sell at *)
  mutable bid_size  : int;    (* Size to bid (NEW) *)
  mutable ask_size  : int;    (* Size to offer (NEW) *)
  mutable active    : bool;   (* Are we actively quoting? *)
  mutable reason    : string; (* Why we're quoting this way (debugging) *)
}

(* Strategy State: All the information we track across ticks *)
type state = {
  (* === Market State Memory === *)
  mutable ema_mid      : int;   (* Exponential moving average of mid price *)
  mutable ema_mid_slow : int;   (* Slower EMA for trend detection (NEW) *)
  mutable vol_proxy    : int;   (* Volatility estimate (avg absolute deviation) *)
  mutable last_mid     : int;   (* Previous tick's mid price (NEW) *)
  mutable tick_count   : int;   (* Total ticks processed (NEW) *)
  
  (* === Position & Risk === *)
  mutable position     : int;   (* Current inventory (+ = long, - = short) *)
  mutable peak_pos     : int;   (* Maximum position reached (NEW) *)
  mutable pos_age      : int;   (* Ticks since position changed (NEW) *)
  
  (* === PnL Tracking === *)
  mutable cash         : int;   (* Cumulative cash from trades *)
  mutable realized_pnl : int;   (* PnL from closed positions (NEW) *)
  mutable fees_paid    : int;   (* Exchange fees (NEW) *)
  
  (* === Execution Statistics === *)
  mutable volume       : int;   (* Total contracts traded *)
  mutable fills        : int;   (* Number of individual fills *)
  mutable buy_fills    : int;   (* Fills on bid side (NEW) *)
  mutable sell_fills   : int;   (* Fills on ask side (NEW) *)
  mutable adverse_fills: int;   (* Fills likely due to adverse selection (NEW) *)
}

(* Order side enum for clarity *)
type side = Buy | Sell

(* =============================================================================
   MODULE 3: UTILITY FUNCTIONS (Zero-Allocation Math)
   
   These functions are marked [@inline always] to eliminate function call
   overhead in the hot path. Critical for nanosecond-level performance.
   ============================================================================= *)

(* Exponential Moving Average update using fixed-point arithmetic
   
   Formula: EMA_new = alpha * current + (1 - alpha) * EMA_old
   
   We use thousandths (alpha out of 1000) to avoid floating point:
   - alpha = 50 means 5% weight to new value, 95% to old
   - alpha = 100 means 10% weight to new value, 90% to old
   
   Higher alpha = faster response to changes, more noise
   Lower alpha = slower response, smoother signal
*)
let[@inline always] update_ema current previous alpha =
  if previous = 0 then 
    current  (* Initialize on first tick *)
  else
    ((alpha * current) + ((1000 - alpha) * previous)) / 1000

(* Clamp a value between min and max bounds *)
let[@inline always] clamp value min_val max_val =
  if value < min_val then min_val
  else if value > max_val then max_val
  else value

(* Safe division that returns 0 instead of crashing on divide-by-zero *)
let[@inline always] safe_div numerator denominator default =
  if denominator = 0 then default
  else numerator / denominator

(* Calculate book imbalance as a percentage (-100 to +100)
   Positive = more bids than asks = buy pressure = price likely to rise *)
let[@inline always] calc_imbalance bid_qty ask_qty =
  let total = bid_qty + ask_qty in
  if total = 0 then 0
  else ((bid_qty - ask_qty) * 100) / total

(* Absolute value without branching (for performance) *)
let[@inline always] abs_int x =
  let mask = x asr (Sys.int_size - 1) in  (* All 1s if negative, all 0s if positive *)
  (x + mask) lxor mask

(* =============================================================================
   MODULE 4: THE STRATEGY KERNEL (MAKER)
   
   This is the HOT PATH - called on every market data tick.
   Must be extremely fast with ZERO memory allocation.
   
   The [@zero_alloc] attribute tells the compiler to verify no allocations.
   Any allocation here would trigger garbage collection pauses.
   ============================================================================= *)

let[@zero_alloc] on_tick 
    (t : tob)           (* Incoming market data *)
    (st : state)        (* Mutable strategy state *)
    (q : quote_intent)  (* Output: where to quote *)
  : unit =
  
  (* =========================================================================
     STEP A: UPDATE MARKET STATE ESTIMATES
     
     We maintain EMAs (Exponential Moving Averages) to smooth noisy data
     and detect trends/volatility.
     ========================================================================= *)
  
  (* Calculate current mid price *)
  let mid = (t.bid_px + t.ask_px) / 2 in
  
  (* Update tick counter and save previous mid *)
  st.tick_count <- st.tick_count + 1;
  st.last_mid <- st.ema_mid;
  
  (* Update fast EMA (responds quickly to price changes) *)
  st.ema_mid <- update_ema mid st.ema_mid Const.ema_alpha_fast;
  
  (* Update slow EMA (for trend detection) *)
  st.ema_mid_slow <- update_ema mid st.ema_mid_slow 20;
  
  (* Update volatility proxy: EMA of absolute deviation from mean
     High volatility = widen spreads (more risk)
     Low volatility = tighten spreads (capture more flow) *)
  let deviation = abs_int (mid - st.ema_mid) in
  st.vol_proxy <- update_ema deviation st.vol_proxy Const.ema_alpha_slow;
  
  (* Track position age (how long we've held current position) *)
  if st.position <> 0 then
    st.pos_age <- st.pos_age + 1
  else
    st.pos_age <- 0;
  
  (* =========================================================================
     STEP B: CALCULATE FAIR VALUE
     
     Fair Value is our estimate of the "true" price. We use:
     1. Micro-Price: Mid adjusted for order book imbalance
     2. Trend adjustment: If price is trending, lean into it
     ========================================================================= *)
  
  (* Calculate order book imbalance (-100 to +100) *)
  let book_imb = calc_imbalance t.bid_qty t.ask_qty in
  
  (* Micro-Price adjustment:
     If book_imb = +50 (more bids), fair value is slightly ABOVE mid
     If book_imb = -50 (more asks), fair value is slightly BELOW mid
     
     Intuition: Large bid size suggests buyers are eager, price will rise *)
  let imb_adjustment = (book_imb * Const.tick_size) / 100 in
  
  (* Trend adjustment: If fast EMA > slow EMA, we're in an uptrend
     Add a small adjustment in the trend direction *)
  let trend = st.ema_mid - st.ema_mid_slow in
  let trend_adjustment = clamp (trend / 10) (-2) 2 in
  
  (* Combine into Fair Value *)
  let fair_value = mid + imb_adjustment + trend_adjustment in
  
  (* =========================================================================
     STEP C: INVENTORY SKEW (CRITICAL FOR PNL)
     
     This is the KEY to profitable market making!
     
     Problem: If we accumulate inventory, we have directional risk.
     Solution: Skew our quotes to encourage trades that REDUCE inventory.
     
     If LONG (position > 0):
       - We WANT to sell (reduce longs)
       - Lower BOTH quotes to make selling more likely
       - Our ask becomes more attractive, bid less attractive
       
     If SHORT (position < 0):
       - We WANT to buy (cover shorts)  
       - Raise BOTH quotes to make buying more likely
       - Our bid becomes more attractive, ask less attractive
     ========================================================================= *)
  
  (* Linear skew: 5 ticks per 10 units of inventory *)
  let linear_skew = (st.position * Const.risk_factor) / 10 in
  
  (* Quadratic skew: Increases faster at extreme positions (NEW)
     This makes us VERY aggressive about reducing large positions *)
  let quad_skew = (st.position * st.position * (if st.position > 0 then 1 else -1)) / 500 in
  
  (* Age penalty: If we've held position too long, be more aggressive (NEW) *)
  let age_penalty = if st.pos_age > 100 then st.pos_age / 50 else 0 in
  let age_skew = age_penalty * (if st.position > 0 then 1 else -1) in
  
  (* Combine skews *)
  let total_skew = linear_skew + quad_skew + age_skew in
  
  (* Our "center" price for quoting *)
  let my_center = fair_value - total_skew in
  
  (* =========================================================================
     STEP D: CALCULATE SPREAD WIDTH
     
     Spread = our profit per round-trip, but also affects fill probability.
     
     Tight spread = more fills, less profit per fill, more adverse selection
     Wide spread = fewer fills, more profit per fill, less adverse selection
     
     We adjust spread based on:
     1. Volatility: Higher vol = wider spread (more risk)
     2. Inventory: Extreme position = wider spread (defensive)
     3. Time of day: Could add wider spreads near market close (future)
     ========================================================================= *)
  
  (* Base spread *)
  let base_width = Const.half_spread in
  
  (* Volatility adjustment: +1 tick per 2 units of volatility *)
  let vol_width = st.vol_proxy / 2 in
  
  (* Inventory adjustment: Wider when position is extreme (NEW) *)
  let inv_width = (abs_int st.position) / 30 in
  
  (* Total half-spread, clamped to reasonable bounds *)
  let half_width = clamp (base_width + vol_width + inv_width) 
                         Const.min_spread 
                         Const.max_spread in
  
  (* =========================================================================
     STEP E: GENERATE FINAL QUOTES
     ========================================================================= *)
  
  q.bid_limit <- my_center - half_width;
  q.ask_limit <- my_center + half_width;
  q.bid_size  <- 1;  (* Could vary size based on confidence *)
  q.ask_size  <- 1;
  q.active    <- true;
  q.reason    <- "";  (* Would set this for debugging *)
  
  (* =========================================================================
     STEP F: SAFETY CHECKS
     
     1. Never cross the market (bid >= ask would be instant loss)
     2. Never quote through the current market (aggressive taking)
     3. Disable quoting if position limits breached
     4. Disable quoting if drawdown limit hit
     ========================================================================= *)
  
  (* Don't let our bid cross our ask *)
  if q.bid_limit >= q.ask_limit then begin
    q.bid_limit <- my_center - 1;
    q.ask_limit <- my_center + 1;
  end;
  
  (* Don't bid above current ask (would immediately cross) *)
  if q.bid_limit >= t.ask_px then 
    q.bid_limit <- t.ask_px - 1;
  
  (* Don't offer below current bid (would immediately cross) *)
  if q.ask_limit <= t.bid_px then 
    q.ask_limit <- t.bid_px + 1;
  
  (* Position limit check *)
  if st.position >= Const.max_pos then
    q.bid_limit <- 0;  (* Stop buying *)
  if st.position <= -Const.max_pos then
    q.ask_limit <- 999999;  (* Stop selling *)
  
  ()

(* =============================================================================
   MODULE 5: FILL SIMULATION ENGINE
   
   In live trading, the exchange tells us when we're filled.
   In simulation, we must model when our resting orders would execute.
   
   FILL MODELS:
   1. Simple: Fill if market price touches our limit
   2. Probabilistic: Fill with probability based on queue position
   3. Adverse Selection: More likely to fill when price moves against us
   
   We use a hybrid approach below.
   ============================================================================= *)

let check_fills (t : tob) (st : state) (q : quote_intent) =
  
  (* === BUY FILL CHECK ===
     
     Our BID gets filled when:
     1. Market ASK drops to or below our bid (someone sells to us)
     2. Market BID drops below our bid (we had best price, seller came)
     
     In reality, there's a queue - we'd need to wait our turn.
     Simplified: Fill if market bid touches our level (conservative).
     
     ADVERSE SELECTION WARNING:
     If we get filled, it often means price is DROPPING (bad for our long).
     Track these fills separately for analysis.
  *)
  if q.active && st.position < Const.max_pos && q.bid_limit > 0 then begin
    (* Fill condition: market bid dropped to our level *)
    if t.bid_px <= q.bid_limit then begin
      (* We bought 1 contract at our bid price *)
      st.position <- st.position + 1;
      st.cash     <- st.cash - q.bid_limit;
      st.volume   <- st.volume + 1;
      st.fills    <- st.fills + 1;
      st.buy_fills <- st.buy_fills + 1;
      
      (* Track adverse selection: if ask also dropped, price moving against us *)
      if t.ask_px < q.bid_limit + 2 then
        st.adverse_fills <- st.adverse_fills + 1;
      
      (* Update peak position tracking *)
      if st.position > st.peak_pos then
        st.peak_pos <- st.position;
    end
  end;
  
  (* === SELL FILL CHECK ===
     
     Our ASK gets filled when:
     1. Market BID rises to or above our ask (someone buys from us)
     2. Market ASK rises above our ask (we had best price, buyer came)
  *)
  if q.active && st.position > -Const.max_pos && q.ask_limit < 999999 then begin
    if t.ask_px >= q.ask_limit then begin
      (* We sold 1 contract at our ask price *)
      st.position <- st.position - 1;
      st.cash     <- st.cash + q.ask_limit;
      st.volume   <- st.volume + 1;
      st.fills    <- st.fills + 1;
      st.sell_fills <- st.sell_fills + 1;
      
      (* Track adverse selection *)
      if t.bid_px > q.ask_limit - 2 then
        st.adverse_fills <- st.adverse_fills + 1;
      
      (* Update peak position tracking *)
      if -st.position > st.peak_pos then
        st.peak_pos <- -st.position;
    end
  end

(* =============================================================================
   MODULE 6: MARKET SIMULATION (Ornstein-Uhlenbeck Process)
   
   Real markets exhibit MEAN REVERSION on short time scales:
   - Price deviates from fair value due to noise/order flow
   - Arbitrageurs push it back toward fair value
   - This is the EDGE that market makers exploit!
   
   The Ornstein-Uhlenbeck (OU) process models this:
   
   dX = θ(μ - X)dt + σdW
   
   Where:
   - X = current price
   - μ = long-term mean (true value)
   - θ = mean reversion speed (higher = faster reversion)
   - σ = volatility
   - dW = random noise (Wiener process)
   
   Discretized: X_new = X + θ(μ - X) + noise
   ============================================================================= *)

let simulate_market ~true_value ~theta ~sigma current_price =
  (* Mean reversion component: pulls price toward true value *)
  let mean_reversion = theta *. (true_value -. current_price) in
  
  (* Random noise component *)
  let noise = sigma *. ((Random.float 2.0) -. 1.0) in
  
  (* New price *)
  current_price +. mean_reversion +. noise

(* =============================================================================
   MODULE 7: MAIN SIMULATION RUNNER
   
   This orchestrates the full backtest simulation.
   ============================================================================= *)

let () =
  Random.self_init ();
  
  (* Initialize state with all fields *)
  let st = { 
    (* Market state *)
    ema_mid = 0; 
    ema_mid_slow = 0;
    vol_proxy = 0;
    last_mid = 0;
    tick_count = 0;
    
    (* Position & risk *)
    position = 0;
    peak_pos = 0;
    pos_age = 0;
    
    (* PnL *)
    cash = 0;
    realized_pnl = 0;
    fees_paid = 0;
    
    (* Stats *)
    volume = 0;
    fills = 0;
    buy_fills = 0;
    sell_fills = 0;
    adverse_fills = 0;
  } in
  
  let q = { 
    bid_limit = 0; 
    ask_limit = 0; 
    bid_size = 1;
    ask_size = 1;
    active = false;
    reason = "";
  } in

  (* Market simulation parameters *)
  let true_value = 10_000.0 in     (* Fair value the market reverts to *)
  let theta = 0.01 in              (* Mean reversion speed *)
  let sigma = 1.0 in               (* Volatility of noise *)
  let current_val = ref true_value in
  let ticks = 50_000 in
  let market_spread = 2 in         (* Exchange's displayed spread *)

  (* Tracking for analysis *)
  let pnl_history = Array.make (ticks / 1000 + 1) 0 in
  let pnl_idx = ref 0 in

  Printf.printf "╔══════════════════════════════════════════════════════════════╗\n";
  Printf.printf "║     OXTRADER: HFT Market Making Simulation                   ║\n";
  Printf.printf "╠══════════════════════════════════════════════════════════════╣\n";
  Printf.printf "║ Parameters:                                                  ║\n";
  Printf.printf "║   True Value: %.0f | Theta: %.3f | Sigma: %.1f              ║\n" 
    true_value theta sigma;
  Printf.printf "║   Max Position: %d | Risk Factor: %d | Ticks: %d         ║\n" 
    Const.max_pos Const.risk_factor ticks;
  Printf.printf "╚══════════════════════════════════════════════════════════════╝\n\n";

  Printf.printf "Starting simulation...\n\n";
  Printf.printf "%6s | %4s | %8s | %6s | %6s | %5s | %s\n" 
    "Tick" "Pos" "MtM PnL" "Bid" "Ask" "Mid" "Notes";
  Printf.printf "%s\n" (String.make 65 '-');

  for i = 1 to ticks do
    (* 1. Evolve market price using OU process *)
    current_val := simulate_market ~true_value ~theta ~sigma !current_val;
    
    let mid = int_of_float !current_val in
    
    (* Simulate realistic book with some random variation *)
    let bid_qty = 400 + Random.int 200 in
    let ask_qty = 400 + Random.int 200 in
    
    (* Create market data tick *)
    let t = { 
      bid_px = mid - (market_spread / 2); 
      ask_px = mid + (market_spread / 2);
      bid_qty; 
      ask_qty;
    } in
    
    (* 2. Run strategy to generate quotes *)
    on_tick t st q;
    
    (* 3. Check for fills based on market movement *)
    check_fills t st q;
    
    (* 4. Periodic logging *)
    if i mod 5000 = 0 then begin
      let mtm = st.cash + (st.position * mid) in
      pnl_history.(!pnl_idx) <- mtm;
      incr pnl_idx;
      
      let pos_indicator = 
        if st.position > 20 then "⬆️ LONG"
        else if st.position < -20 then "⬇️ SHORT"
        else "➡️ FLAT" 
      in
      Printf.printf "%6d | %+4d | %+8d | %6d | %6d | %5d | %s\n" 
        i st.position mtm q.bid_limit q.ask_limit mid pos_indicator
    end
  done;

  (* Final results *)
  let final_mid = int_of_float !current_val in
  let total_pnl = st.cash + (st.position * final_mid) in
  let pnl_per_fill = if st.fills > 0 then total_pnl / st.fills else 0 in
  let adverse_pct = if st.fills > 0 then (st.adverse_fills * 100) / st.fills else 0 in
  let fill_imbalance = st.buy_fills - st.sell_fills in

  Printf.printf "\n";
  Printf.printf "╔══════════════════════════════════════════════════════════════╗\n";
  Printf.printf "║                    SIMULATION RESULTS                        ║\n";
  Printf.printf "╠══════════════════════════════════════════════════════════════╣\n";
  Printf.printf "║ PnL METRICS                                                  ║\n";
  Printf.printf "║   Total PnL (Mark-to-Market): %+8d ticks                  ║\n" total_pnl;
  Printf.printf "║   PnL per Fill:               %+8d ticks                  ║\n" pnl_per_fill;
  Printf.printf "╠══════════════════════════════════════════════════════════════╣\n";
  Printf.printf "║ EXECUTION METRICS                                            ║\n";
  Printf.printf "║   Total Volume:     %6d contracts                         ║\n" st.volume;
  Printf.printf "║   Total Fills:      %6d                                   ║\n" st.fills;
  Printf.printf "║   Buy Fills:        %6d                                   ║\n" st.buy_fills;
  Printf.printf "║   Sell Fills:       %6d                                   ║\n" st.sell_fills;
  Printf.printf "║   Fill Imbalance:   %+5d (+=bought more, -=sold more)      ║\n" fill_imbalance;
  Printf.printf "╠══════════════════════════════════════════════════════════════╣\n";
  Printf.printf "║ RISK METRICS                                                 ║\n";
  Printf.printf "║   Final Position:   %+5d                                   ║\n" st.position;
  Printf.printf "║   Peak Position:    %6d                                   ║\n" st.peak_pos;
  Printf.printf "║   Adverse Fills:    %5d%% of total                         ║\n" adverse_pct;
  Printf.printf "╚══════════════════════════════════════════════════════════════╝\n";
  
  (* Strategy assessment *)
  Printf.printf "\n📊 STRATEGY ASSESSMENT:\n";
  if total_pnl > 0 then
    Printf.printf "   ✅ PROFITABLE: Strategy captured spread successfully\n"
  else
    Printf.printf "   ❌ UNPROFITABLE: Review parameters or market model\n";
  
  if adverse_pct > 50 then
    Printf.printf "   ⚠️  HIGH ADVERSE SELECTION: Consider widening spreads\n";
  
  if st.peak_pos > Const.max_pos * 80 / 100 then
    Printf.printf "   ⚠️  POSITION LIMITS HIT: Consider faster inventory skew\n";
  
  Printf.printf "\n"
