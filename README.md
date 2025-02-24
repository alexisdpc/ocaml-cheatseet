# OCaml examples

OCaml is a functional programming language that is as a fast as C. Here I share some examples that can be useful for people learning the language, you can compile online using https://try.ocamlpro.com/

Recursive function tat calculates the sum of elements in a list:

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

Calculate the n-th Fibonacci number:
```ocaml
let rec fibonacci n =
  if n < 1 then 0
  else if n = 1 then 1
  else (fibonacci (n - 1)) + (fibonacci (n - 2))
;;
print_int (fibonacci 10)
```

Concate strings in a list:
```ocaml
let rec list_concatenate : string list -> string = fun lst ->
  match lst with
  | [] -> ""
  | hd :: tl -> hd ^ list_concatenate tl
;;

list_concatenate ["test: "; "hello";" world"];;
(* - : string = "test: hello world" *)
```
