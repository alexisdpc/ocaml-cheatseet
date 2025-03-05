let read_lines file =
  In_channel.with_open_text file In_channel.input_all |> Str.(split (regexp "\n"))
;;

let result = read_lines "input.txt"

(* Takes two list as inputs
    e.g. group group ["10";"11";"";"40";"3"] [];;   outputs [43;21] *)
let rec group input result =
  match input with
  | [] -> result
  (* insert a zero at the beginning of the list *)
  | "" :: rest -> group rest (0 :: result)
  (* there are still some calories *)
  | cals :: rest ->
    group
      rest
      (match result with
       | [] -> [int_of_string cals]
       | hd :: tail -> (hd + int_of_string cals) :: tail)
;;

(*  Function that takes two inputs a list and an int e.g.
    max_of_list [1;5;10;2] 1;; returns 10 *)
let rec max_of_list input cur = 
  match input with
  | [] -> cur 
  | hd :: rest -> max_of_list rest (max hd cur)

let () = print_endline (string_of_int (max_of_list ( group result []) 0 ))
