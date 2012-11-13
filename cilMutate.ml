open Cil

(* usage message *)
let usage = Printf.sprintf
    "Usage: %s [-cut,-insert,-swap] [stmt-ids]"
    (Filename.basename Sys.argv.(0))

let number = ref false
let    cut = ref false
let insert = ref false
let   swap = ref false

let speclist = [
  ("-number", Arg.Unit (fun () -> number := true), "");
  (   "-cut", Arg.Unit (fun () ->    cut := true), "");
  ("-insert", Arg.Unit (fun () -> insert := true), "");
  (  "-swap", Arg.Unit (fun () ->   swap := true), "");
  (     "--", Arg.Rest (fun arg ->  args := !args @ [arg]), "stop parsing opts")
]

let say fmt = Printf.kprintf stdout fmt in
(* main routine: handle cmdline options and args *)
let main () = begin
  (* 1. read and parse arguments *)
  let collect arg = args := !args @ [arg] in
  let _ = Arg.parse speclist collect usage in
  (* 2. load the program into CIL *)
  (* 3. modify at the CIL level *)
  (* 4. write the results to STDOUT *)
  say "boo balls\n"
end ;;

main ()
