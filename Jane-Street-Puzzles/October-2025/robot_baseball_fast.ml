(* 
   Robot Baseball — Fast Solver (OCaml Implementation)
   ===================================================

   COMPILATION:
   ------------
   ocamlc -o robot_baseball_fast robot_baseball_fast.ml
   ./robot_baseball_fast
   
   PROBLEM OVERVIEW:
   -----------------
   This program solves a game theory problem involving a baseball at-bat between
   a pitcher and a batter, where both players act optimally to maximize their
   expected value.
   
   In baseball, an at-bat has counts tracked as (balls, strikes):
   - 4 balls → walk (batter reaches base, value = 1.0)
   - 3 strikes → strikeout (batter out, value = 0.0)
   - Full count = (3 balls, 2 strikes)
   
   The robots play optimally:
   - The pitcher chooses a "mix" r = probability of throwing a ball
   - The batter chooses whether to swing or wait
   - Parameter p = probability the batter makes contact when swinging at a ball
   
   GOAL: Find p* that maximizes q(p), where q(p) is the probability of reaching
   full count (3-2) before the at-bat ends (walk or strikeout).
   
   SOLUTION APPROACH:
   ------------------
   1. Dynamic Programming: Compute equilibrium values V[b][s] for each count state
   2. Backward Induction: Work from terminal states (walk/strikeout) back to (0,0)
   3. Nash Equilibrium: At each state, find the mixing probability r that makes
      both players indifferent between their pure strategies
   4. Optimization: Use golden-section search to find p* that maximizes q(p)
   
   MATHEMATICAL MODEL:
   -------------------
   At state (b, s) with b balls and s strikes:
   - A = V[b+1][s] = value if ball is thrown/taken
   - B = V[b][s+1] = value if strike occurs
   - Equilibrium mixing: r = p*(4-B) / ((A-B) + p*(4-B))
   - This makes the batter indifferent between swinging and waiting
   - Value at state: V[b][s] = B + (A - B) * r
   
   To run this program:
     ocamlc -o robot_baseball_fast robot_baseball_fast.ml
     ./robot_baseball_fast
   
   Or in OCaml REPL:
     #use "robot_baseball_fast.ml";;
     solve_fast ();;
*)

(* =============================================================================
   PART 1: CORE DYNAMIC PROGRAMMING
   =============================================================================
   
   This section implements the game-theoretic equilibrium computation for the
   robot baseball problem using backward induction.
*)

(* 
   Compute the equilibrium mixing probability r for the pitcher at state (b, s).
   
   PARAMETERS:
   - a: Value V[b+1][s] if a ball is thrown (batter gets closer to walk)
   - b_val: Value V[b][s+1] if a strike occurs (batter gets closer to strikeout)
   - p: Contact probability when batter swings at a ball
   
   FORMULA:
   r = p*(4-B) / ((A-B) + p*(4-B))
   
   INTUITION:
   The pitcher mixes between throwing balls and strikes to make the batter
   indifferent between swinging and waiting. The formula balances:
   - If pitcher throws more balls (high r), batter prefers to wait
   - If pitcher throws more strikes (low r), batter prefers to swing
   - At equilibrium r, batter is indifferent
   
   ROBUSTNESS:
   We guard against division by zero with a tolerance check (1e-18).
*)
let equilibrium_r (a : float) (b_val : float) (p : float) : float =
  let denom = (a -. b_val) +. p *. (4.0 -. b_val) in
  if abs_float denom < 1e-18 then
    0.0
  else
    (p *. (4.0 -. b_val)) /. denom

(*
   Compute q(p) = probability of reaching full count (3-2) under optimal play.
   
   ALGORITHM:
   ----------
   1. Initialize 5x4 grids for:
      - V[b][s]: Expected value at state (b balls, s strikes)
      - r[b][s]: Equilibrium mixing probability (Prob of ball)
      - F[b][s]: Probability of reaching (3,2) from state (b,s)
   
   2. Set terminal states:
      - V[4][s] = 1.0 for all s (4 balls = walk, batter wins)
      - V[b][3] = 0.0 for all b (3 strikes = out, batter loses)
      - F[3][2] = 1.0 (already at full count)
      - F[4][s] = 0.0 and F[b][3] = 0.0 (absorbed, didn't reach 3-2)
   
   3. Backward induction for V and r (strikes from 2 down to 0):
      For each state (b,s):
      - A = V[b+1][s] (value after ball)
      - B = V[b][s+1] (value after strike)
      - r = equilibrium mixing probability
      - V[b][s] = B + (A - B) * r (convex combination)
   
   4. Backward induction for F (probability of reaching 3-2):
      For each state (b,s):
      - With probability r*r: ball is thrown and taken → go to (b+1,s)
      - With probability (1-r)*(1-r)*p: strike thrown, batter swings at ball 
        and makes contact → go to (b,s+1)
      - Otherwise: reach (b,s+1)
      - F[b][s] is weighted sum of reaching 3-2 from successor states
   
   5. Return F[0][0] = probability of reaching 3-2 from initial state
   
   PARAMETER:
   - p: Contact probability (parameter we're optimizing over)
   
   RETURNS:
   - q(p): Probability of reaching full count for this value of p
*)
let q_of_p (p : float) : float =
  (* Initialize value grid V[b][s] where b=0..4 (balls), s=0..3 (strikes) *)
  let v = Array.make_matrix 5 4 0.0 in
  
  (* Initialize mixing probability grid r[b][s] *)
  let r = Array.make_matrix 5 4 0.0 in
  
  (* Set terminal states for value function:
     - 4 balls = walk (value 1.0 for batter)
     - 3 strikes = strikeout (value 0.0 for batter) *)
  for s = 0 to 3 do
    v.(4).(s) <- 1.0  (* Walk *)
  done;
  for b = 0 to 4 do
    v.(b).(3) <- 0.0  (* Strikeout *)
  done;
  
  (* Backward induction: compute equilibrium values and mixing probabilities
     Work backwards from s=2 down to s=0 (fewer strikes to more strikes possible) *)
  for s = 2 downto 0 do
    for b = 3 downto 0 do
      let a = v.(b + 1).(s) in      (* Value if ball (b+1, s) *)
      let b_val = v.(b).(s + 1) in  (* Value if strike (b, s+1) *)
      let rr = equilibrium_r a b_val p in
      r.(b).(s) <- rr;
      (* Value is convex combination: strike value + (ball-strike diff) * mix prob *)
      v.(b).(s) <- b_val +. (a -. b_val) *. rr
    done
  done;
  
  (* Initialize hitting probability grid F[b][s]
     F[b][s] = probability of reaching (3,2) starting from (b,s) *)
  let f = Array.make_matrix 5 4 0.0 in
  
  (* Terminal state: already at full count *)
  f.(3).(2) <- 1.0;
  (* F[4][*] and F[*][3] remain 0.0 (absorbed before reaching 3-2) *)
  
  (* Backward induction for hitting probability:
     Compute probability of reaching (3,2) from each state *)
  for s = 2 downto 0 do
    for b = 3 downto 0 do
      (* Skip (3,2) as it's already set to 1.0 *)
      if not (b = 3 && s = 2) then begin
        let rr = r.(b).(s) in
        (* 
           Transition probabilities:
           - r*r: ball thrown and taken (both choose "ball") → (b+1, s)
           - (1-r)*(1-r)*p: strike thrown, batter swings at ball, makes contact → (b, s+1)
           - Otherwise: goes to (b, s+1)
           
           F[b][s] = r² * F[b+1][s] + (1 - r² - (1-r)²*p) * F[b][s+1]
        *)
        f.(b).(s) <- (rr *. rr) *. f.(b + 1).(s) +.
                     (1.0 -. rr *. rr -. (1.0 -. rr) *. (1.0 -. rr) *. p) *. f.(b).(s + 1)
      end
    done
  done;
  
  (* Return probability of reaching (3,2) from initial state (0,0) *)
  f.(0).(0)

(* =============================================================================
   PART 2: OPTIMIZATION - GOLDEN SECTION SEARCH
   =============================================================================
   
   We need to find p* that maximizes q(p). Since q(p) is a smooth, unimodal
   function on [0,1], we use golden-section search for efficient optimization.
*)

(*
   Golden-section search to find the maximum of a unimodal function on [a, b].
   
   ALGORITHM:
   ----------
   Golden-section search is an efficient method for finding the extremum of
   a unimodal function without using derivatives.
   
   The golden ratio φ = (√5 - 1)/2 ≈ 0.618 has the special property that
   (1 - φ) = φ², which allows us to reuse function evaluations.
   
   STEPS:
   1. Start with interval [a, b]
   2. Evaluate at two interior points: c and d
      - c = b - φ*(b-a)
      - d = a + φ*(b-a)
   3. Compare f(c) vs f(d):
      - If f(c) < f(d): maximum is in [c, b], so update a = c
      - Otherwise: maximum is in [a, d], so update b = d
   4. Repeat until interval is smaller than tolerance
   
   PARAMETERS:
   - f: Function to maximize
   - a: Left endpoint of search interval
   - b: Right endpoint of search interval
   - tol: Convergence tolerance (default 1e-13)
   - max_iter: Maximum iterations (default 200)
   
   RETURNS:
   - (x, f(x)): Location and value of maximum
   
   COMPLEXITY:
   Each iteration reduces the interval by factor φ ≈ 0.618, giving logarithmic
   convergence. Achieves ~12 decimal digits accuracy in ~50 iterations.
*)
let golden_max (f : float -> float) (a : float) (b : float) 
               ?(tol : float = 1e-13) ?(max_iter : int = 200) : float * float =
  (* Golden ratio: φ = (√5 - 1)/2 *)
  let gr = (sqrt 5.0 -. 1.0) /. 2.0 in
  
  (* Initialize interior points *)
  let rec search a b c d fc fd iter =
    (* Check convergence *)
    if (b -. a) <= tol || iter >= max_iter then
      let x = 0.5 *. (a +. b) in
      (x, f x)
    else
      (* Compare function values and narrow the interval *)
      if fc < fd then
        (* Maximum is in [c, b], shift left boundary *)
        let new_a = c in
        let new_c = d in
        let new_fc = fd in
        let new_d = new_a +. gr *. (b -. new_a) in
        let new_fd = f new_d in
        search new_a b new_c new_d new_fc new_fd (iter + 1)
      else
        (* Maximum is in [a, d], shift right boundary *)
        let new_b = d in
        let new_d = c in
        let new_fd = fc in
        let new_c = new_b -. gr *. (new_b -. a) in
        let new_fc = f new_c in
        search a new_b new_c new_d new_fc new_fd (iter + 1)
  in
  
  (* Initial interior points *)
  let c = b -. gr *. (b -. a) in
  let d = a +. gr *. (b -. a) in
  let fc = f c in
  let fd = f d in
  
  search a b c d fc fd 0

(* =============================================================================
   PART 3: MAIN SOLVER
   =============================================================================
   
   Combines coarse grid search with golden-section refinement to find the
   optimal p* that maximizes q(p).
*)

(**
   Fast solver for robot baseball problem.
   
   STRATEGY:
   ---------
   1. COARSE SCAN: Evaluate q(p) on a grid of 2049 points in [0,1]
      - This gives ~0.0005 resolution
      - Quickly identifies approximate location of maximum
      - Cheap because each q(p) call is fast (5x4 grid DP)
   
   2. NARROW BRACKETING: Create interval [best_p - 0.05, best_p + 0.05]
      - Focuses search near the coarse maximum
      - Ensures we have a good starting bracket for refinement
   
   3. GOLDEN-SECTION REFINEMENT: Precise optimization on narrow interval
      - Achieves ~12 decimal digit accuracy
      - Converges in ~50 iterations
      - Total time: milliseconds
   
   RETURNS:
   - p*, q*: Optimal contact probability and maximum full-count probability
   
   PERFORMANCE:
   - Coarse scan: 2049 evaluations of q(p)
   - Golden search: ~50 evaluations
   - Total: ~2100 function evaluations
   - Each evaluation: microseconds (5x4 grid DP)
   - Overall: milliseconds on modern hardware
*)

let solve_fast () : float * float =
  let f = q_of_p in
  
  (* PHASE 1: Coarse grid search to bracket the maximum
     We use 2049 samples to cover [0,1] with ~5e-4 resolution *)
  let n = 2049 in
  let step = 1.0 /. float_of_int (n - 1) in
  
  (* Find the best p in the coarse grid *)
  let rec coarse_search i best_p best_q =
    if i >= n then
      (best_p, best_q)
    else
      let p = float_of_int i *. step in
      let qv = f p in
      if qv > best_q then
        coarse_search (i + 1) p qv
      else
        coarse_search (i + 1) best_p best_q
  in
  
  let (best_p, best_q) = coarse_search 0 0.0 (f 0.0) in
  
  (* PHASE 2: Create narrow bracket around the coarse maximum *)
  let left = max 0.0 (best_p -. 0.05) in
  let right = min 1.0 (best_p +. 0.05) in
  
  (* PHASE 3: Golden-section refinement for high precision *)
  golden_max f left right ~tol:1e-14 ~max_iter:250

(* =============================================================================
   PART 4: MAIN PROGRAM
   =============================================================================
*)

(**
   Main entry point: solve the problem and display results.
   
   OUTPUT FORMAT:
   Displays p* and q* with 12 decimal places for verification against
   the Python implementation and mathematical analysis.
*)
let () =
  Printf.printf "\nRobot Baseball - Fast Solver (OCaml)\n";
  Printf.printf "====================================\n\n";
  
  let (p_star, q_star) = solve_fast () in
  
  Printf.printf "Results:\n";
  Printf.printf "--------\n";
  Printf.printf "p* = %.12f  (optimal contact probability)\n" p_star;
  Printf.printf "q* = %.12f  (maximum full-count probability)\n\n" q_star;
  
  Printf.printf "Interpretation:\n";
  Printf.printf "---------------\n";
  Printf.printf "When the batter's contact probability is p* = %.4f,\n" p_star;
  Printf.printf "the probability of reaching full count (3-2) is maximized at q* = %.4f\n" q_star;
  Printf.printf "under optimal game-theoretic play by both pitcher and batter.\n\n"

(*
   NOTES ON OCAML VS PYTHON DIFFERENCES:
   ======================================
   
   1. SYNTAX:
      - OCaml: let x = ... (immutable by default)
      - Python: x = ... (mutable by default)
      - OCaml: function parameters use spaces, no commas
      - OCaml: types are inferred (optional annotations)
   
   2. ARRAYS:
      - OCaml: Array.make_matrix for 2D arrays
      - Python: list comprehensions [[0.0]*4 for _ in range(5)]
      - OCaml: arrays are 0-indexed like Python
      - OCaml: a.(i).(j) syntax for 2D array access
   
   3. LOOPS:
      - OCaml: for i = a to b do ... done (inclusive both ends)
      - OCaml: for i = a downto b do ... done (decreasing)
      - Python: for i in range(a, b) (exclusive end)
   
   4. RECURSION:
      - OCaml favors recursion with tail-call optimization
      - Python has recursion limits, favors iteration
      - OCaml: recursive functions use 'let rec'
   
   5. COMPILATION:
      - OCaml: compiled to native code (fast) or bytecode
      - Python: interpreted with optional compilation to bytecode
      - OCaml type checking at compile time catches many errors
   
   6. FUNCTIONAL STYLE:
      - OCaml encourages immutability and pure functions
      - Pattern matching is idiomatic in OCaml
      - Python is multi-paradigm (imperative/OO/functional)
   
   PERFORMANCE:
   The OCaml version should be significantly faster than Python due to:
   - Native compilation
   - No interpreter overhead
   - Static typing allows better optimization
   - Efficient memory layout
*)
