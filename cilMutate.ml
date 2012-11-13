open Cil

(* Options and usage message *)
let usage = Printf.sprintf
    "Usage: %s [options] file"
    (Filename.basename Sys.argv.(0))

let    ids = ref false
let   list = ref false
let delete = ref false
let insert = ref false
let   swap = ref false
let  stmt1 = ref 0
let  stmt2 = ref 0
let   args = ref []

let speclist = [
  (   "-ids", Arg.Unit (fun () ->    ids := true), "print the # of statements");
  (  "-list", Arg.Unit (fun () ->   list := true), "list all statements");
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

let counter = ref 0
let main_ht = Hashtbl.create 4096

(* This makes a deep copy of an arbitrary Ocaml data structure *) 
let copy (x : 'a) = 
  let str = Marshal.to_string x [] in
  (Marshal.from_string str 0 : 'a) 

(* This visitor walks over the C program AST and builds the hashtable that
 * maps integers to statements. *) 
class numVisitor = object
  inherit nopCilVisitor
  method vblock b = 
    ChangeDoChildrenPost(b,(fun b ->
      List.iter (fun b -> 
        if can_trace b.skind then begin
          incr counter;
          b.sid <- !counter ;
          Hashtbl.add main_ht !counter b.skind
        end else begin
          b.sid <- 0; 
        end ;
      ) b.bstmts ; 
      b
    ) )
end 

class delVisitor (file : Cil.file) (to_del : stmt_map) = object
  inherit nopCilVisitor
  method vstmt s = ChangeDoChildrenPost(s, fun s ->
    if Hashtbl.mem to_del s.sid then begin
      let block = { battrs = []; bstmts = []; } in
      { s with skind = Block(block) }
    end else s)
end

class appVisitor (file : Cil.file) (to_app : stmt_map) = object
  (* If (x,y) is in the to_append mapping, we replace x with
   * the block { x; y; } -- that is, we append y after x. *) 
  inherit nopCilVisitor
  method vstmt s = ChangeDoChildrenPost(s, fun s ->
      if Hashtbl.mem to_app s.sid then begin
        let block = {
          battrs = [];
          bstmts = [s; { s with skind = (copy (Hashtbl.find to_app s.sid)); }];
        } in
        { s with skind = Block(block) } 
      end else s) 
end 

class swapVisitor (file : Cil.file) (to_swap : stmt_map) = object
  (* If (x,y) is in the to_swap mapping, we replace statement x 
   * with statement y. Presumably (y,x) is also in the mapping. *) 
  inherit nopCilVisitor
  method vstmt s = ChangeDoChildrenPost(s, fun s ->
      if Hashtbl.mem to_swap s.sid then begin
        { s with skind = (copy (Hashtbl.find to_swap s.sid)) } 
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
  let target_stmts = Hashtbl.create 255 in
  if !stmt1 <> 0 then begin
    if !stmt2 <> 0 then
      Hashtbl.add target_stmts !stmt1 (Hashtbl.find main_ht !stmt2)
    else
      Hashtbl.add target_stmts !stmt1 (Hashtbl.find main_ht !stmt1)
  end;

  (* 3. modify at the CIL level *)
  if !ids then begin
    Printf.printf "%d\n" !counter;

  end else if !list then begin
    for i=1 to !counter do
      let stmt = Hashtbl.find main_ht i in
      let stmt_type = match stmt with
      | Instr _ -> "Instr"
      | Return _ -> "Return"
      | If _ -> "If"
      | Loop _ -> "Loop"
      | _ -> "Error: Other"
      in
      Printf.printf "%d %s\n" i stmt_type;
    done

  end else if !delete then begin
    let del = new delVisitor cil target_stmts in
    visitCilFileSameGlobals del cil;

  end else if !insert then begin
    let app = new appVisitor cil target_stmts in
    visitCilFileSameGlobals app cil;

  end else if !swap then begin
    let swap = new swapVisitor cil target_stmts in
    Hashtbl.add target_stmts !stmt2 (Hashtbl.find main_ht !stmt1);
    visitCilFileSameGlobals swap cil;

  end;

  (* 4. write the results to STDOUT *)
  if not (!ids or !list) then begin
    let printer = new defaultCilPrinterClass in
    iterGlobals cil (dumpGlobal printer stdout)
  end;
end
