(* Copyright (C) 2012 Eric Schulte, Westly Weimer *)
open Cil

(** Options and usage message *)
let usage = Printf.sprintf
    "Usage: %s [options] file"
    (Filename.basename Sys.argv.(0))

let        ids = ref false
let       list = ref false
let   fulllist = ref false
let      trace = ref false
let        cut = ref false
let     insert = ref false
let       swap = ref false
let      stmt1 = ref (-1)
let      stmt2 = ref (-1)
let       args = ref []
let trace_file = ref "trace"

let speclist = [
  (       "-ids", Arg.Unit   (fun () -> ids := true), "       print the # of statements");
  (      "-list", Arg.Unit   (fun () -> list := true), "      list statements with IDs");
  (  "-fulllist", Arg.Unit   (fun () -> fulllist := true), "  list full statements with IDs");
  (       "-cut", Arg.Unit   (fun () -> cut := true), "       cut stmt1");
  (     "-trace", Arg.Unit   (fun () -> trace := true), "     instrument to trace execution");
  (    "-insert", Arg.Unit   (fun () -> insert := true), "    insert stmt1 before stmt2");
  (      "-swap", Arg.Unit   (fun () -> swap := true), "      swap two stmt1 with stmt2");
  ("-trace-file", Arg.String (fun arg -> trace_file := arg), "file to save trace");
  (     "-stmt1", Arg.Int    (fun arg -> stmt1 := arg), "     first statement");
  (     "-stmt2", Arg.Int    (fun arg -> stmt2 := arg), "     second statement") ]


(** CIL visitors and support *)
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

let counter = ref (-1)
let main_ht = Hashtbl.create 4096

(* This makes a deep copy of an arbitrary Ocaml data structure *)
let copy (x : 'a) =
  let str = Marshal.to_string x [] in
  (Marshal.from_string str 0 : 'a)

(* This visitor walks over the C program AST and builds the hashtable that
 * maps integers to statements. *)
class numVisitor = object
  inherit nopCilVisitor
  method! vblock b =
    ChangeDoChildrenPost(b,(fun b ->
      List.iter (fun b ->
        if can_trace b.skind then begin
          incr counter;
          b.sid <- !counter ;
          Hashtbl.add main_ht !counter b
        end else begin
          b.sid <- 0;
        end ;
      ) b.bstmts ;
      b
    ) )
end

(* from covVisitor in genprog *)
let stderr_va = makeVarinfo true "_coverage_fout" (TPtr(TVoid [], []))
class traceVisitor = object
  inherit nopCilVisitor

  val fopen = Lval((Var (makeVarinfo true "fopen" (TVoid []))), NoOffset)

  method! vblock b =
    ChangeDoChildrenPost(b,(fun b ->
      let result = List.map (fun stmt ->
        if stmt.sid > 0 then begin
          let str = Printf.sprintf "%d\n" stmt.sid in 
          
          let stderr = Lval((Var stderr_va), NoOffset) in
          
          let fprintf = Lval(Var (makeVarinfo true "fprintf" (TVoid [])), NoOffset) in
          let fflush = Lval(Var (makeVarinfo true "fflush" (TVoid [])), NoOffset) in
          [(mkStmt
              (Instr([(Call(None, fprintf, [stderr; Const(CStr(str))], !currentLoc));
                      (Call(None, fflush, [stderr], !currentLoc))]))); stmt]
        end else [stmt]
      ) b.bstmts in
      let block = { b with bstmts = List.flatten result } in block ) )

  method! vfunc f =
    let outfile = Var(stderr_va), NoOffset in
    let fout_args = [Const(CStr(!trace_file)); Const(CStr("wb"))] in
    let make_fout = Call((Some(outfile)), fopen, fout_args, !currentLoc) in
    let new_stmt = mkStmt (Instr([make_fout])) in
    let ifknd = If(BinOp(Eq,Lval(outfile), Cil.zero, Cil.intType),
                   { battrs = []; bstmts = [new_stmt] }, 
                   { battrs = []; bstmts = [] }, !currentLoc) in
    let ifstmt = Cil.mkStmt(ifknd) in
    ChangeDoChildrenPost(f, (fun f ->
      f.sbody.bstmts <- ifstmt :: f.sbody.bstmts; f))

end

class delVisitor (file : Cil.file) (to_del : stmt_map) = object
  inherit nopCilVisitor
  method! vstmt s = ChangeDoChildrenPost(s, fun s ->
    if Hashtbl.mem to_del s.sid then begin
      let block = { battrs = []; bstmts = []; } in
      { s with skind = Block(block) }
    end else s)
end

class appVisitor (file : Cil.file) (to_app : stmt_map) = object
  (* If (x,y) is in the to_append mapping, we replace x with
   * the block { x; y; } -- that is, we append y after x. *)
  inherit nopCilVisitor
  method! vstmt s = ChangeDoChildrenPost(s, fun s ->
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
  method! vstmt s = ChangeDoChildrenPost(s, fun s ->
      if Hashtbl.mem to_swap s.sid then begin
        { s with skind = (copy (Hashtbl.find to_swap s.sid)) }
      end else s)
end

class noLineCilPrinterClass = object
  inherit defaultCilPrinterClass as super
  method! pGlobal () (g:global) : Pretty.doc =
    match g with
    | GVarDecl(vi,l) when
        (not !printCilAsIs && Hashtbl.mem Cil.builtinFunctions vi.vname) ->
          (* This prevents the printing of all of those 'compiler built-in'
           * commented-out function declarations that always appear at the
           * top of a normal CIL printout file. *)
          Pretty.nil
    | _ -> super#pGlobal () g

  method! pLineDirective ?(forcefile=false) l =
    Pretty.nil
end


(** main routine: handle cmdline options and args *)
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
  if !stmt1 >= 0 then begin
    if !stmt2 >= 0 then
      Hashtbl.add target_stmts !stmt1 (Hashtbl.find main_ht !stmt2).skind
    else
      Hashtbl.add target_stmts !stmt1 (Hashtbl.find main_ht !stmt1).skind
  end;

  (* 3. modify at the CIL level *)
  if !ids then begin
    Printf.printf "%d\n" (1 + !counter);

  end else if !list then begin
    for i=0 to !counter do
      let stmt = Hashtbl.find main_ht i in
      let stmt_type = match stmt.skind with
      | Instr _ -> "Instr"
      | Return _ -> "Return"
      | If _ -> "If"
      | Loop _ -> "Loop"
      | _ -> "Error: Other"
      in
      Printf.printf "%d %s\n" i stmt_type;
    done

  end else if !fulllist then begin
    let print_stmt s = Cil.d_stmt () s in
    for i=0 to !counter do
      let stmt = Hashtbl.find main_ht i in
      Printf.printf "%d\n%s\n\n" i (Pretty.sprint max_int (print_stmt stmt));
    done

  end else if !trace then begin
    let trace = new traceVisitor in
    visitCilFileSameGlobals trace cil;
    cil.globals <- [GVarDecl(stderr_va,!currentLoc)] @ cil.globals;

  end else if !cut then begin
    if !stmt1 < 0 then begin
      Printf.printf "Delete requires a statment.  Use -stmt1.\n";
      exit 1
    end;
    let del = new delVisitor cil target_stmts in
    visitCilFileSameGlobals del cil;

  end else if !insert then begin
    if !stmt1 < 0 or !stmt2 < 0 then begin
      Printf.printf "Insert requires statments.  Use -stmt1 and -stmt2.\n";
      exit 1
    end;
    let app = new appVisitor cil target_stmts in
    visitCilFileSameGlobals app cil;

  end else if !swap then begin
    if !stmt1 < 0 or !stmt2 < 0 then begin
      Printf.printf "Swap requires statments.  Use -stmt1 and -stmt2.\n";
      exit 1
    end;
    let swap = new swapVisitor cil target_stmts in
    Hashtbl.add target_stmts !stmt2 (Hashtbl.find main_ht !stmt1).skind;
    visitCilFileSameGlobals swap cil;

  end;

  (* 4. write the results to STDOUT *)
  if not (!ids or !list or !fulllist) then begin
    let printer = new noLineCilPrinterClass in
    iterGlobals cil (dumpGlobal printer stdout)
  end;
end
