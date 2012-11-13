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


(* CIL visitors and support *)
type stmt_id = int (* integers map to 'statements' in C AST. *) 
type stmt_map = (stmt_id, Cil.stmtkind) Hashtbl.t (* map stmt_id to statement. *)

(* CIL statementkinds that we consider as possible-to-be-modified
 * (i.e., nodes in the AST that we may mutate/crossover via GP later). *)
let can_trace sk = match sk with
  | Instr _
  | Return _
  | If _
  | Loop _
  -> true

  | Goto _
  | Break _
  | Continue _
  | Switch _
  | Block _
  | TryFinally _
  | TryExcept _
  -> false

let counter = ref 1 
let get_next_count () = 
  let count = !counter in 
  incr counter ;
  count 

let massive_hash_table = Hashtbl.create 4096

(* This visitor walks over the C program AST and builds the hashtable that
 * maps integers to statements. *) 
class numVisitor = object
  inherit nopCilVisitor
  method vblock b = 
    ChangeDoChildrenPost(b,(fun b ->
      List.iter (fun b -> 
        if can_trace b.skind then begin
          let count = get_next_count () in 
          b.sid <- count ;
          Hashtbl.add massive_hash_table count b.skind
        end else begin
          b.sid <- 0; 
        end ;
      ) b.bstmts ; 
      b
    ) )
end 

class delVisitor (file : Cil.file) (to_del : int) = object
  inherit nopCilVisitor
  method vstmt s = ChangeDoChildrenPost(s, fun s ->
    if to_del = s.sid then begin
      let block = { battrs = []; bstmts = []; } in
      { s with skind = Block(block) }
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

  (* 2. load the program into CIL and collect stmts *)
  initCIL ();
  let cil = (Frontc.parse file ()) in
  visitCilFileSameGlobals (new numVisitor) cil;

  (* 3. modify at the CIL level *)
  if !ids then begin
    Printf.printf "%d\n" !counter;

  end else if !number then begin
    Printf.printf "number\n"

  end else if !delete then begin
    Printf.printf "/* deleting %d */\n" !stmt1;
    let del = new delVisitor cil !stmt1 in
    visitCilFileSameGlobals del cil;

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
