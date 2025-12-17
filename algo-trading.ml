(* Illustrative only; some module names may differ across releases. *)

type side = Buy | Sell

(* Keep the live book compact. You might store prices as ticks (int64#),
   and sizes as int32# or float32# depending on your model. *)
type level = {
  px   : float32#;   (* unboxed small number *)
  qty  : float32#;   (* unboxed small number *)
}

type top_of_book = {
  bid : level;
  ask : level;
}

(* Per-symbol feature vector stored as packed float32# array *)
type features = float32# array

type decision =
  | Hold
  | Make of { side : side; px : float32#; qty : float32# }


(* A minimal ring buffer for a rolling window, reused to avoid allocation. *)
type window = {
  mutable idx : int;
  data : float32# array;  (* packed *)
}

let window_push (w : window) (x : float32#) : unit =
  (* No allocation: in-place update *)
  w.data.(w.idx) <- x;
  w.idx <- (w.idx + 1) mod Array.length w.data

(* Example feature: microprice (toy) *)
let microprice (tob : top_of_book) : float32# =
  let open Stdlib_stable.Float32_u in
  let bidp = tob.bid.px and askp = tob.ask.px in
  (* (bid+ask)/2 *)
  div (add bidp askp) (#2.0s)

(* Hot-path kernel: should not allocate on normal paths. *)
let[@zero_alloc] on_tick
    (tob   @ local : top_of_book)
    (w_mid @ local : window)
    (feat  @ local : features)
  : decision
  =
  [%probe "tick_enter" ()];

  let mid = microprice tob in
  window_push w_mid mid;

  (* Fill a feature vector (toy example) *)
  feat.(0) <- mid;

  (* Use stack allocation for ephemeral structs if you build any *)
  let _tmp = stack_ { px = tob.bid.px; qty = tob.bid.qty } in
  ignore _tmp;

  (* Toy rule: cross the spread if imbalance is huge (placeholder) *)
  let open Stdlib_stable.Float32_u in
  let imbalance = sub tob.bid.qty tob.ask.qty in
  if gt imbalance (#1000.0s) then
    Make { side = Buy; px = tob.ask.px; qty = (#1.0s) }
  else if lt imbalance (#-1000.0s) then
    Make { side = Sell; px = tob.bid.px; qty = (#1.0s) }
  else
    Hold

module F32x4 = Ocaml_simd_sse.Float32x4

(* Compute 4 mid-prices in parallel: (bid+ask)/2 for 4 symbols. *)
let mids_4 (bid : float32x4#) (ask : float32x4#) : float32x4# =
  let sum = F32x4.add bid ask in
  let two = F32x4.set 2.0 2.0 2.0 2.0 in
  F32x4.div sum two

(* In practice you’d load from float32# arrays, run kernels, then store. *)



let run_shard (shard_id : int) : decision list =
  (* Own shard-local mutable state here (books, windows, etc.) *)
  []

let run_all_shards parallel ~n_shards =
  (* Toy: fork/join two halves; you can generalize to N. *)
  let #(a, b) =
    Parallel.fork_join2 parallel
      (fun _ -> run_shard 0)
      (fun _ -> run_shard 1)
  in
  a @ b
