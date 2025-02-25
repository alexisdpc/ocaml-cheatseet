# OCaml Examples

OCaml is a functional programming language that can be as fast as C. Also, OCaml code is concise and easy to read.
Here I share some examples that can be useful for people learning the language, you can compile online using https://try.ocamlpro.com/

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
```ocaml
let rec list_max (lst : 'a list) : 'a option = 
  match lst with 
  | h :: t -> begin
      match list_max t with
      | None -> Some h 
      | Some m -> Some (max h m) 
    end
  | [] -> None
```

