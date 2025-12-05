(* OCaml version *)

(* Parse a rotation string like "L68" or "R48" *)
let parse_rotation s =
  let direction = String.get s 0 in
  let degrees = int_of_string (String.sub s 1 (String.length s - 1)) in
  (direction, degrees)

(* Apply a rotation to current position *)
let apply_rotation pos (direction, degrees) =
  match direction with
  | 'R' -> (pos + degrees) mod 100
  | 'L' -> (pos - degrees) mod 100
  | _ -> failwith "Invalid direction"

(* Count how many times dial points at 0 *)
let solve_puzzle rotations =
  let rec process pos count = function
    | [] -> count
    | rot :: rest ->
        let new_pos = apply_rotation pos (parse_rotation rot) in
        let new_count = if new_pos = 0 then count + 1 else count in
        process new_pos new_count rest
  in
  process 50 0 rotations

(* Main *)
let () =
  let rotations = ["L68"; "L30"; "R48"; "L5"; "R60"; "L55"; "L1"; "L99"; "R14"; "L82"] in
  let password = solve_puzzle rotations in
  Printf.printf "Password (times dial points at 0): %d\n" password
