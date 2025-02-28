let read_lines file =
  In_channel.with_open_text file In_channel.input_all |> Str.(split (regexp "\n"))
;;

let result = read_lines "input.txt"

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

let rec max_of_list input cur = 
  match input with
  | [] -> cur 
  | hd :: rest -> max_of_list rest (max hd cur)

let () = print_endline (string_of_int (max_of_list ( group result []) 0 ))
