# ocaml-cheatseet

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
