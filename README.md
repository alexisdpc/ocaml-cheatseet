# OCaml Examples

OCaml is a functional programming language that can be as fast as C. Also, OCaml code is concise and easy to read.
Here I share some examples that can be useful for people learning the language, you can compile online using 
- https://try.ocamlpro.com/
- https://ocsigen.org/js_of_ocaml/latest/manual/files/toplevel/index.html

To check out some algorithms check some solutions to  [Jane Street](https://github.com/alexisdpc/ocaml-cheatseet/blob/main/Jane-Street-Puzzles) puzzles s or the [Advent of Code](https://github.com/alexisdpc/ocaml-cheatseet/tree/main/Advent-Of-Code) programming challenge.

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
  else fibonacci(n - 1) + fibonacci(n - 2)
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

▶ Reverse list
```ocaml
let rec reverse lst acc =
     match lst with 
     | [] -> acc
     | hd :: tl -> reverse tl (hd :: acc)
;;
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

▶ Error handling with exceptions
```ocaml
(* Define a custom exception for division by zero *)
exception Division_by_zero

(* Function that raises an exception on division by zero *)
let safe_divide x y =
  if y = 0 then raise Division_by_zero
  else x / y

(* Handling the exception with a try...with block *)
let () =
  try
    let result = safe_divide 10 0 in
    Printf.printf "Result: %d\n" result
  with
  | Division_by_zero -> Printf.printf "Error: Division by zero encountered.\n"
```

▶ Permutation of an array
```ocaml
let permute array =
  let length = Array.length array in
  for i = 0 to length - 2 do
    (* pick a j to swap with *)
    let j = i + Random.int (length - i) in
    (* Swap i and j *)
    let tmp = array.(i) in
    array.(i) <- array.(j);
    array.(j) <- tmp
  done
;; 
let ar = [|0; 1; 2; 3; 4; 5; 6; 7; 8; 9; 10; 11; 12; 13; 14; 15; 16; 17; 18; 19|];; 
permute ar;;
ar;;
```

▶ Arrays and matrices:
```ocaml
open Arr;;
open Mat;;

(* Adds 1 to every element in the ndarray x,
   then returns a new ndarray y. *)
let y = Arr.map (fun a -> a +.1) x;;

(*  x: 1000x500 matrix that contains 1000 samples each with 500 features
    v: 1x500 bias vector added to each feature 
    u: We must tile v so that it has the same shape as that of x *)
let x = Mat.uniform 1000 500;;
let v = Mat.uniform 1 500;;
let u = Mat.tile v [|1000;1|];;
Mat.(x + u);;

let reverse x =
    Mat.get_slice [ [-1; 0]; [-1; 0] ] x in
    reverse x;;

let rotate90 x =
    Mat.(transpose x |> get_slice [ []; [-1;0] ]) in
    rotate90 x;;    
```

▶ Optional arguments:\
We can make arguments to functions options immediately by prefixing arguments with ?.
```ocaml
let welcome ?greeting_opt name =
     let greeting = 
          match greeting_opt with
          | Some greeting -> greeting
          | None -> "Hi"
     in
     Printf.printf "%s %s\n" greeting name
;;

welcome ~greeting_opt:"Hey" "reader" ;;

welcome ?greeting_opt:None "reader"

welcome "Reader";;
```

▶ Last element of list:
```ocaml
let rec last_element l = 
  match l with
  | [] -> failwith "Empty list" 
  | [x] -> x
  | hd :: tl -> last_element tl 
;;
```

▶ Eliminate consecutive duplicates of list elements:
```ocaml
let rec compress l =
  match l with
  | [] -> []
  | [x] -> [x]
  | x :: (y :: _ as tail) -> if x = y then compress tail else x :: compress tail

let () = assert(compress ["a";"a";"a";"a";"b";"c";"c";"a";"a";"d";"e";"e";"e";"e"] = ["a"; "b"; "c"; "a"; "d"; "e"])
let () = assert(compress ["a";] = ["a";])
let () = assert(compress ["a"; "a";] = ["a";])
```

▶ List operations: append, concat and map.
```ocaml
List.append [1;2;3] [4;5;6];;
(* int list = [1; 2; 3; 4; 5; 6] *)

List.concat [[1;2];[3;4;5];[6];[]];;
(* int list = [1; 2; 3; 4; 5; 6] *)

List.map (fun x -> x * x) [3; 5; 7; 9]
(* int list = [9; 25; 81] *)

```
▶ Length of list:
```ocaml
let rec length_helper l acc =
  match l with
  | [] -> acc
  | _ :: tl -> length_helper tl (acc + 1)
;;
(* val length_helper : 'a  list -> int -> int = <fun> *)

let length l = length_helper l 0 ;;
(* val length : 'a list -> int = <fun> *)

length [1;2;3;4;5;6;7;8;9;10;11;12;13;14;15];;
(* - : int 15 *)
```

▶ Prepend and replicate elemnts in lists
```ocaml
let prepend l x = 
  match l with
  | [] -> []
  | head :: tail -> x :: (head :: tail)
;;

let () = assert( prepend [1;2;3;4] 0  = [0;1;2;3;4]);;

let replicate l n =
  let rec prepend n acc x =
    if n = 0 then acc else prepend (n-1) (x :: acc) x in
  let rec aux acc = function
    | [] -> acc
    | head :: tail -> aux (prepend n acc head) tail in
  aux [] (List.rev l);;

let () = assert(replicate ["a";"b";"c";] 3 = ["a"; "a"; "a"; "b"; "b"; "b"; "c"; "c"; "c"])
```


▶ Exception handlers:
```ocaml
let rec find p = function 
  | [] -> raise Not_found
  | x :: xs -> if p x then x else find p xs
(* val find : ( 'a -> bool) -> 'a list -> 'a = <fun> *)

let x =
  try 
    let x = find (fun i -> i mod 2 = 0) [1;3;5] in 
    Some (x + 2)
  with Not_found -> None
  (* val x : int option = None *)
    
let x =
  match find (fun i -> i mod 2 = 0) [1;3;4] with
  | y -> Some (y + 2)
  | exception Not_found -> None
(* val x : int option = some 6 *)
```

▶ Operations with lists:
```ocaml
let numbers = [1; 2; 3; 4; 5]

(* Double each number *)
let doubled = List.map (fun x -> x * 2) numbers

(* Filter even numbers *)
let evens = List.filter (fun x -> x mod 2 = 0) numbers

(* Combine both operations *)
let doubled_evens = numbers |> List.filter (fun x -> x mod 2 = 0) |> List.map (fun x -> x * 2)

let () =
  List.iter (Printf.printf "%d ") doubled_evens  (* Output: 4 8 *)
```

▶ Operations with Map:
```ocaml
module StringMap = Map.Make(String)

let my_map =
  StringMap.empty
  |> StringMap.add "Alice" 25
  |> StringMap.add "Bob" 30
  |> StringMap.add "Charlie" 22

(* Lookup a key safely *)
let find_age name =
  match StringMap.find_opt name my_map with
  | Some age -> Printf.printf "%s is %d years old\n" name age
  | None -> Printf.printf "%s not found\n" name

let () =
  find_age "Alice";  (* Output: Alice is 25 years old *)
  find_age "Eve"     (* Output: Eve not found *)
```

 ▶ Iterate through a list from left to right
 ```ocaml
(* Define a list of integers *)
let numbers = [1; 2; 3; 4; 5]

(* Define the function to be applied at each step:
   'acc' is the accumulated sum so far.
   'x' is the current element from the list. *)
let sum_function acc x =
  acc + x

(* Use List.fold_left to sum the list *)
(* The initial value for the accumulator ('init') is 0 *)
let total_sum = List.fold_left sum_function 0 numbers

(* Print the result *)
let () = Printf.printf "The list is: [%s]\n" (String.concat "; " (List.map string_of_int numbers))
(* Output: The list is: [1;2;3;4;5] *)

let () = Printf.printf "The sum of the numbers is: %d\n" total_sum
(* Output: The sum of the numbers is: 15 *)
```


