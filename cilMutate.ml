(* Options and usage message *)
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


(* visitors *)
(* class delVisitor (to_del : int) = object *)
(*   inherit nopCilVisitor *)
(*   method vstmt s = ChangeDoChildrenPost(s, fun s -> *)
(*     if to_del = s.sid then begin  *)
(*       let block = { battrs = []; bstmts = []; } in *)
(*       { s with skind = Block(block); } *)
(*     end else s) *)
(* end  *)

let write_cil (cil : Cil.file) =
  let printer = new Cil.defaultCilPrinterClass in
  Cil.iterGlobals cil (Cil.dumpGlobal printer stdout)


(* main routine: handle cmdline options and args *)
let () = begin
  (* 1. read and parse arguments *)
  let collect arg = args := !args @ [arg] in
  let _ = Arg.parse speclist collect usage in
  if (List.length !args) < 1 then begin
    Printf.printf "You must specify a program.\n";
    exit 1
  end;
  let file = (List.nth !args 0) in
  (* 2. load the program into CIL *)
  Cil.initCIL ();
  let cil = (Frontc.parse file) in
  (* 3. modify at the CIL level *)
  (* 4. write the results to STDOUT *)
  Printf.printf "ids=%b number=%b file=%s\n" !ids !number file
end
