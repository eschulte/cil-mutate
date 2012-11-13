open Printf
open Cil

(* usage message *)
let usage = Printf.sprintf
    "Usage: %s [-cut,-insert,-swap] [stmt-ids]"
    (Filename.basename Sys.argv.(0))

let    ids = ref false
let number = ref false
let delete = ref false
let insert = ref false
let   swap = ref false
let   args = ref []

let speclist = [
  (   "-ids", Arg.Unit (fun () ->    ids := true), "");
  ("-number", Arg.Unit (fun () -> number := true), "");
  ("-delete", Arg.Unit (fun () -> delete := true), "");
  ("-insert", Arg.Unit (fun () -> insert := true), "");
  (  "-swap", Arg.Unit (fun () ->   swap := true), "");
  (     "--", Arg.Rest (fun arg ->  args := !args @ [arg]), "stop parsing opts")
]

(* main routine: handle cmdline options and args *)
let () = begin
  (* 1. read and parse arguments *)
  let collect arg = args := !args @ [arg] in
  let _ = Arg.parse speclist collect usage in
  if (List.length !args) < 1 then begin
    Printf.printf "You need to specify a program.\n";
    exit 1
  end;
  let file = (List.nth !args 0) in
  (* 2. load the program into CIL *)
  (* 3. modify at the CIL level *)
  (* 4. write the results to STDOUT *)
  Printf.printf "ids=%b number=%b file=%s\n" !ids !number file
end
