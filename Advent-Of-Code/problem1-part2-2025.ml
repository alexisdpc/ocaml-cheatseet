(* Helper for Euclidean modulo (Python-style %) *)
(* Ensures results are always positive: -5 %! 100 = 95 *)
let ( %! ) a b = ((a mod b) + b) mod b

(* Helper for Floor Division (Python-style //) *)
(* Ensures negative division floors down: -6 /! 100 = -1 *)
let ( /! ) a b = 
  if a >= 0 || a mod b = 0 then a / b 
  else (a / b) - 1

let count_clicks instructions start_pos =
  (* Inner function to process a single step *)
  let process_step (current_pos, total_zeros) instruction =
    let direction = String.get instruction 0 in
    let amount_str = String.sub instruction 1 (String.length instruction - 1) in
    let amount = int_of_string amount_str in

    match direction with
    | 'R' ->
        (* Moving clockwise (increasing numbers) *)
        (* Python logic: (current + amount) // 100 - current // 100 *)
        let zeros_crossed = ((current_pos + amount) /! 100) - (current_pos /! 100) in
        let next_pos = (current_pos + amount) %! 100 in
        (next_pos, total_zeros + zeros_crossed)
        
    | 'L' ->
        (* Moving counter-clockwise (decreasing numbers) *)
        (* Python logic: (current - 1) // 100 - (current - amount - 1) // 100 *)
        let zeros_crossed = ((current_pos - 1) /! 100) - ((current_pos - amount - 1) /! 100) in
        let next_pos = (current_pos - amount) %! 100 in
        (next_pos, total_zeros + zeros_crossed)
        
    | _ -> (current_pos, total_zeros) (* Should not happen with valid input *)
  in

  (* Fold over the list of instructions, accumulating state (pos, count) *)
  let _, result = List.fold_left process_step (start_pos, 0) instructions in
  result

(* --- Test with the Example from the Prompt --- *)
let () =
  let example_input = ["L68"; "L30"; "R48"; "L5"; "R60"; "L55"; "L1"; "L99"; "R14"; "L82"] in
  let result = count_clicks example_input 50 in
  
  Printf.printf "--- Verification ---\n";
  Printf.printf "Example Input: [%s]\n" (String.concat "; " example_input);
  Printf.printf "Calculated Password: %d\n" result;
  Printf.printf "Expected Password: 6\n";
  
  if result = 6 then
    print_endline "SUCCESS: Logic matches the example."
  else
    print_endline "FAILURE: Logic does not match example."

(* --- Placeholder for your Actual Input --- *)
(* let real_input = ["L123"; "R456"; ...]
   let () = Printf.printf "Real Password: %d\n" (count_clicks real_input 50)
*)
