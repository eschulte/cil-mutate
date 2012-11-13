open Cil

(* Options and usage message *)
let usage = Printf.sprintf
    "Usage: %s [options] file"
    (Filename.basename Sys.argv.(0))

let    ids = ref false
let number = ref false
let delete = ref false
let insert = ref false
let   swap = ref false
let  stmt1 = ref 0
let  stmt2 = ref 0
let   args = ref []

let speclist = [
  (   "-ids", Arg.Unit (fun () ->    ids := true), "print the # of statements");
  ("-number", Arg.Unit (fun () -> number := true), "number all statements");
  ("-delete", Arg.Unit (fun () -> delete := true), "delete stmt1");
  ("-insert", Arg.Unit (fun () -> insert := true), "insert stmt1 before stmt2");
  (  "-swap", Arg.Unit (fun () ->   swap := true), "swap two stmt1 with stmt2");
  ( "-stmt1", Arg.Int  (fun arg -> stmt1 := arg),  "first statement");
  ( "-stmt2", Arg.Int  (fun arg -> stmt2 := arg),  "second statement");
  (     "--", Arg.Rest (fun arg ->  args := !args @ [arg]), "stop parsing opts")
]


(* visitors *)
class delVisitor (to_del : int) = object
  inherit nopCilVisitor
  method vstmt s = ChangeDoChildrenPost(s, fun s ->
    if to_del = s.sid then begin
      let block = { battrs = []; bstmts = []; } in
      { s with skind = Block(block); }
    end else s)
end


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
  if not (Sys.file_exists file) then begin
    Printf.printf "File '%s' does not exist\n" file;
    exit 1
  end;
  (* 2. load the program into CIL *)
  initCIL ();
  let cil = (Frontc.parse file ()) in
  (* 3. modify at the CIL level *)
  if !ids then begin
    Printf.printf "ids\n"
  end else if !number then begin
    Printf.printf "number\n"
  end else if !delete then begin
    let del = new delVisitor in
    visitCilFileSameGlobals (del !stmt1) cil;
  end else if !insert then begin
    Printf.printf "insert\n"
  end else if !swap then begin
    Printf.printf "swap\n"
  end;
  (* 4. write the results to STDOUT *)
  if not (!ids or !number) then begin
    let printer = new defaultCilPrinterClass in
    iterGlobals cil (dumpGlobal printer stdout)
  end;
end
