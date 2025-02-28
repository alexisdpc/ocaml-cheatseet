# OCaml Examples

OCaml is a functional programming language that can be as fast as C. Also, OCaml code is concise and easy to read.
Here I share some examples that can be useful for people learning the language, you can compile online using https://try.ocamlpro.com/

To check out some algorithms check the [solutions](https://github.com/alexisdpc/ocaml-cheatseet/tree/main/Advent-Of-Code) to the Advent of Code programming challenge.

▶ Recursive function tat calculates the sum of elements in a list:

```ocaml
let rec sum l =
  match l with
  | [] -> 0
  | hd :: tl -> hd + sum tl
;;
(*val sum : int list -> int = <fun> *)

sum [1;2;3];;
(* - : int = 6 *)

```

▶ Calculate the n-th Fibonacci number:
```ocaml
let rec fibonacci n =
  if n < 1 then 0
  else if n = 1 then 1
  else (fibonacci (n - 1)) + (fibonacci (n - 2))
;;
print_int (fibonacci 10)
```

▶ Concatenate strings in a list:
```ocaml
let rec list_concatenate : string list -> string = fun lst ->
  match lst with
  | [] -> ""
  | hd :: tl -> hd ^ list_concatenate tl
;;

list_concatenate ["test: "; "hello";" world"];;
(* - : string = "test: hello world" *)
```

▶ Check if number is prime:
```ocaml
let prime n =
  let rec checkZero x d = match d with
    | 1 -> true    
    | _ -> (x mod d <> 0) && checkZero x (d-1)
  in match n with
  | 0 | 1 -> false
  | _ -> checkZero n (n-1) ;;
```

▶ Return the largest element from a list
```ocaml
let rec list_max xs =
  match xs with
  | [] -> failwith "list_max called on empty list"
  | [x] -> x
  | x :: remainder -> max x (list_max remainder);;
```

▶ Greatest common divisor with system input
```ocaml
let rec gcd a b =
  if b = 0 then a
  else gcd b (a mod b);;

let main () =
  let a = int_of_string Sys.argv.(1) in
  let b = int_of_string Sys.argv.(2) in
  Printf.printf "%d\n" (gcd a b);
  exit 0;;

main ();;
```

▶ Sum elements of a list
```ocaml
let rec sum list = 
  match list with
  | [] -> 0 
  | first :: rest -> first + sum rest
;;

let y  = sum [1;4;5];;
(*val y : int = 10 *)
```
