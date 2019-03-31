MODULE OSP; (* NW 23.9.93 / 9,5.2017   OSPX*)
  IMPORT Texts, Oberon, OSS, OSG;

  CONST WordSize = 4;
  VAR sym, level: INTEGER;
    topScope, universe, dummy: OSG.Object;
    expression: PROCEDURE (VAR x: OSG.Item);  (*to avoid forward reference*)
    W: Texts.Writer;
  
  PROCEDURE NewObj(VAR obj: OSG.Object; class: INTEGER);
    VAR new, x: OSG.Object;
  BEGIN x := topScope;
    WHILE (x.next # NIL) & (x.next.name # OSS.id) DO x := x.next END ;
    IF x.next = NIL THEN
      NEW(new); new.name := OSS.id; new.class := class; new.next := NIL;
      x.next := new; obj := new
    ELSE obj := x.next; OSS.Mark("mult def")
    END
  END NewObj;
  
  PROCEDURE find(VAR obj: OSG.Object);
    VAR s, x: OSG.Object;
  BEGIN s := topScope;
    REPEAT x := s.next;
      WHILE (x # NIL) & (x.name # OSS.id) DO x := x.next END ;
       s := s.dsc
    UNTIL (x # NIL) OR (s = NIL);
    IF x = NIL THEN x := dummy; OSS.Mark("undef") END ;
    obj := x
  END find;

  PROCEDURE FindField(VAR obj: OSG.Object; list: OSG.Object);
  BEGIN
    WHILE (list # NIL) & (list.name # OSS.id) DO list := list.next END ;
    IF list # NIL THEN obj := list ELSE OSS.Mark("undef"); obj := dummy END
  END FindField;

  PROCEDURE Check(s: INTEGER; msg: ARRAY OF CHAR);
  BEGIN
    IF sym = s THEN OSS.Get(sym) ELSE OSS.Mark(msg) END
  END Check;

  PROCEDURE CheckInt(VAR x: OSG.Item);
  BEGIN
    IF x.type.form # OSG.Integer THEN OSS.Mark("not integer") END
  END CheckInt;

  PROCEDURE CheckBool(VAR x: OSG.Item);
  BEGIN
    IF x.type.form # OSG.Boolean THEN OSS.Mark("not Boolean") END
  END CheckBool;

  PROCEDURE OpenScope;
    VAR s: OSG.Object;
  BEGIN NEW(s); s.class := OSG.Head; s.dsc := topScope; s.next := NIL; topScope := s
  END OpenScope;

  PROCEDURE CloseScope;
  BEGIN topScope := topScope.dsc
  END CloseScope;

  (* -------------------- Parser ---------------------*)

  PROCEDURE selector(VAR x: OSG.Item);
    VAR y: OSG.Item; obj: OSG.Object;
  BEGIN
    WHILE (sym = OSS.lbrak) OR (sym = OSS.period) DO
      IF sym = OSS.lbrak THEN
        OSS.Get(sym); expression(y);
        IF x.type.form = OSG.Array THEN
          CheckInt(y); OSG.Index(x, y); x.type := x.type.base
        ELSE OSS.Mark("not an array")
        END ;
        Check(OSS.rbrak, "no ]")
      ELSE (*period*) OSS.Get(sym);
        IF sym = OSS.ident THEN
          IF x.type.form = OSG.Record THEN
            FindField(obj, x.type.dsc); OSS.Get(sym);
            IF obj # NIL THEN OSG.Field(x, obj); x.type := obj.type END
          ELSE OSS.Mark("not a record")
          END
        ELSE OSS.Mark("ident?")
        END
      END
    END
  END selector;

  PROCEDURE CompTypes(t0, t1: OSG.Type): BOOLEAN;
  BEGIN (*Compatible Types*)
    RETURN (t0 = t1)
      OR (t0.form = OSG.Array) & (t1.form = OSG.Array) & CompTypes(t0.base, t1.base)
  END CompTypes;

  PROCEDURE Parameter(par: OSG.Object);
    VAR x: OSG.Item; varpar: BOOLEAN;
  BEGIN expression(x);
    IF par # NIL THEN
      varpar := par.class = OSG.Par;
      IF CompTypes(par.type, x.type) THEN
        IF ~varpar THEN OSG.ValueParam(x)
        ELSE OSG.VarParam(x, par.type)
        END
      ELSIF (x.type.form = OSG.Array) & (par.type.form = OSG.Array) &
          (x.type.base.form = par.type.base.form) & (par.type.len < 0) THEN
        OSG.OpenArrayParam(x)
      ELSE OSS.Mark("incompatible parameters")
      END
    END
  END Parameter;

  PROCEDURE ParamList(VAR obj: OSG.Object);
    VAR n: INTEGER; par: OSG.Object;
  BEGIN par := obj.dsc; n := 0;
    IF sym # OSS.rparen THEN
      Parameter(par); n := 1;
      WHILE sym <= OSS.comma DO
        Check(sym, "comma?");
        IF par # NIL THEN par := par.next END ;
        INC(n); Parameter(par)
      END ;
      Check(OSS.rparen, ") missing")
    ELSE OSS.Get(sym);
    END ;
    IF n < obj.nofpar THEN OSS.Mark("too few params")
    ELSIF n > obj.nofpar THEN OSS.Mark("too many params")
    END
  END ParamList;

  PROCEDURE StandFunc(VAR x: OSG.Item; fctno: LONGINT);
    VAR y, z: OSG.Item;
  BEGIN
    IF sym = OSS.lparen THEN
      OSS.Get(sym);
      IF fctno = 0 THEN (*ORD*) expression(x); OSG.Ord(x)
      ELSIF fctno = 1 THEN (*eot*) OSG.eot(x)
      ELSE (*fctno = 2*) OSG.Switch(x)
      END ;
      IF sym = OSS.rparen THEN OSS.Get(sym) ELSE OSS.Mark("rparen expected") END
    ELSE OSS.Mark("param missing"); OSG.MakeConstItem(x, OSG.intType, 0)
    END
  END StandFunc;

  PROCEDURE factor(VAR x: OSG.Item);
    VAR obj: OSG.Object;
  BEGIN (*sync*)
    IF (sym < OSS.char) OR (sym > OSS.ident) THEN OSS.Mark("expression expected");
      REPEAT OSS.Get(sym) UNTIL (sym >= OSS.int) & (sym <= OSS.ident)
    END ;
    IF sym = OSS.ident THEN
      find(obj); OSS.Get(sym);
      IF obj.class = OSG.SFunc THEN
        IF obj.type = NIL THEN OSS.Mark("not a function"); obj.type := OSG.intType END ;
        StandFunc(x, obj.val); x.type := obj.type
      ELSE OSG.MakeItem(x, obj, level); selector(x)
      END
    ELSIF sym = OSS.int THEN OSG.MakeConstItem(x, OSG.intType, OSS.val); OSS.Get(sym)
    ELSIF sym = OSS.char THEN OSG.MakeConstItem(x, OSG.intType, OSS.val); OSS.Get(sym)
    ELSIF sym = OSS.lparen THEN
      OSS.Get(sym);
      IF sym # OSS.rparen THEN expression(x) END ;
      Check(OSS.rparen, "no )")
    ELSIF sym = OSS.not THEN OSS.Get(sym); factor(x); CheckBool(x); OSG.Not(x)
    ELSIF sym = OSS.false THEN OSS.Get(sym); OSG.MakeConstItem(x, OSG.boolType, 0)
    ELSIF sym = OSS.true THEN OSS.Get(sym); OSG.MakeConstItem(x, OSG.boolType, 1)
    ELSE OSS.Mark("factor?"); OSG.MakeItem(x, dummy, level)
    END
  END factor;

  PROCEDURE term(VAR x: OSG.Item);
    VAR y: OSG.Item; op: INTEGER;
  BEGIN factor(x);
    WHILE (sym >= OSS.times) & (sym <= OSS.and) DO
      op := sym; OSS.Get(sym);
      IF op = OSS.times THEN CheckInt(x); factor(y); CheckInt(y); OSG.MulOp(x, y)
      ELSIF (op = OSS.div) OR (op = OSS.mod) THEN CheckInt(x); factor(y); CheckInt(y); OSG.DivOp(op, x, y)
      ELSE (*op = and*) CheckBool(x); OSG.And1(x); factor(y); CheckBool(y); OSG.And2(x, y)
      END
    END
  END term;

  PROCEDURE SimpleExpression(VAR x: OSG.Item);
    VAR y: OSG.Item; op: INTEGER;
  BEGIN
    IF sym = OSS.plus THEN OSS.Get(sym); term(x); CheckInt(x)
    ELSIF sym = OSS.minus THEN OSS.Get(sym); term(x); CheckInt(x); OSG.Neg(x)
    ELSE term(x)
    END;
    WHILE (sym >= OSS.plus) & (sym <= OSS.or) DO
      op := sym; OSS.Get(sym);
      IF op = OSS.or THEN OSG.Or1(x); CheckBool(x); term(y); CheckBool(y); OSG.Or2(x, y)
      ELSE CheckInt(x); term(y); CheckInt(y); OSG.AddOp(op, x, y)
      END
    END
  END SimpleExpression;

  PROCEDURE expression0(VAR x: OSG.Item);
    VAR y: OSG.Item; op: INTEGER;
  BEGIN SimpleExpression(x);
    IF (sym >= OSS.eql) & (sym <= OSS.geq) THEN
      op := sym; OSS.Get(sym); SimpleExpression(y);
      IF x.type = y.type THEN OSG.Relation(op, x, y) ELSE OSS.Mark("incompatible types") END ;
      x.type := OSG.boolType
    END
  END expression0;

  PROCEDURE StandProc(pno: LONGINT);
    VAR x, y: OSG.Item;
  BEGIN
    IF pno = 0 THEN  OSG.OpenInput
    ELSIF pno IN {1, 2, 3, 5} THEN
      IF sym = OSS.lparen THEN OSS.Get(sym); expression(x);
        IF pno = 1 THEN OSG.ReadInt(x);
        ELSIF pno = 2 THEN
          IF sym = OSS.comma THEN OSS.Get(sym); expression(y); OSG.WriteInt(x, y) ELSE OSS.Mark("no comma") END
        ELSIF pno = 3 THEN OSG.WriteChar(x)
        ELSIF pno = 5 THEN OSG.LED(x)
            END ;
            IF sym = OSS.rparen THEN OSS.Get(sym) ELSE OSS.Mark("no rparen") END
          ELSE OSS.Mark(" missing lparen")
          END
    ELSIF pno = 4 THEN  OSG.WriteLn
    ELSE OSS.Mark("undef proc")
    END
  END StandProc;

  PROCEDURE StatSequence;
    VAR par, obj: OSG.Object; x, y: OSG.Item; n, L: LONGINT;
  BEGIN (* StatSequence *)
    REPEAT (*sync*) obj := NIL;
      IF ~((sym = OSS.ident) OR (sym >= OSS.if) & (sym <= OSS.repeat) OR (sym >= OSS.semicolon)) THEN
        OSS.Mark("statement expected");
        REPEAT OSS.Get(sym) UNTIL (sym = OSS.ident) OR (sym >= OSS.if)
      END ;
      IF sym = OSS.ident THEN
        find(obj); OSS.Get(sym);
        IF obj.class = OSG.SProc THEN StandProc(obj.val)
        ELSE OSG.MakeItem(x, obj, level); selector(x);
          IF sym = OSS.becomes THEN (*assignment*)
            OSS.Get(sym); expression(y);
            IF (x.type.form IN {OSG.Boolean, OSG.Integer}) & (x.type.form = y.type.form) THEN OSG.Store(x, y)
            ELSE OSS.Mark("incompatible assignment")
            END
          ELSIF sym = OSS.eql THEN OSS.Mark("should be :="); OSS.Get(sym); expression(y)
          ELSIF sym = OSS.lparen THEN (*procedure call*)
            OSS.Get(sym);
            IF (obj.class = OSG.Proc) & (obj.type = NIL) THEN ParamList(obj); OSG.Call(obj);
            ELSE OSS.Mark("not a procedure")
            END
          ELSIF obj.class = OSG.Proc THEN (*procedure call without parameters*)
            IF obj.nofpar > 0 THEN OSS.Mark("missing parameters") END ;
            IF obj.type = NIL THEN OSG.Call(obj) ELSE OSS.Mark("not a procedure") END
          ELSIF (obj.class = OSG.SProc) & (obj.val = 3) THEN OSG.WriteLn
          ELSIF obj.class = OSG.Typ THEN OSS.Mark("illegal assignment")
          ELSE OSS.Mark("not a procedure")
          END
        END
      ELSIF sym = OSS.if THEN
        OSS.Get(sym); expression(x); CheckBool(x); OSG.CFJump(x); Check(OSS.then, "no THEN");
        StatSequence; L := 0;
        WHILE sym = OSS.elsif DO
          OSS.Get(sym); OSG.FJump(L); OSG.FixLink(x.a); expression(x); CheckBool(x); OSG.CFJump(x);
          IF sym = OSS.then THEN OSS.Get(sym) ELSE OSS.Mark("THEN?") END ;
          StatSequence
        END ;
        IF sym = OSS.else THEN
          OSS.Get(sym); OSG.FJump(L); OSG.FixLink(x.a); StatSequence
        ELSE OSG.FixLink(x.a)
        END ;
        OSG.FixLink(L);
        IF sym = OSS.end THEN OSS.Get(sym) ELSE OSS.Mark("END?") END
      ELSIF sym = OSS.while THEN
        OSS.Get(sym); L := OSG.pc; expression(x); CheckBool(x); OSG.CFJump(x);
        Check(OSS.do, "no DO"); StatSequence; OSG.BJump(L); OSG.FixLink(x.a);
        Check(OSS.end, "no END")
      ELSIF sym = OSS.repeat THEN
        OSS.Get(sym); L := OSG.pc; StatSequence;
        IF sym = OSS.until THEN
          OSS.Get(sym); expression(x); CheckBool(x); OSG.CBJump(x, L)
        ELSE OSS.Mark("missing UNTIL"); OSS.Get(sym)
        END        
      END ;
      OSG.CheckRegs;
      IF sym = OSS.semicolon THEN OSS.Get(sym)
      ELSIF sym < OSS.semicolon THEN OSS.Mark("missing semicolon?")
      END
    UNTIL sym > OSS.semicolon
  END StatSequence;
  
  PROCEDURE IdentList(class: INTEGER; VAR first: OSG.Object);
    VAR obj: OSG.Object;
  BEGIN
    IF sym = OSS.ident THEN
      NewObj(first, class); OSS.Get(sym);
      WHILE sym = OSS.comma DO
        OSS.Get(sym);
        IF sym = OSS.ident THEN NewObj(obj, class); OSS.Get(sym)
        ELSE OSS.Mark("ident?")
        END
      END;
      Check(OSS.colon, "no :")
    END
  END IdentList;
  
  PROCEDURE Type(VAR type: OSG.Type);
    VAR obj, first: OSG.Object; x: OSG.Item; tp: OSG.Type;
  BEGIN type := OSG.intType; (*sync*)
    IF (sym # OSS.ident) & (sym < OSS.array) THEN OSS.Mark("type?");
      REPEAT OSS.Get(sym) UNTIL (sym = OSS.ident) OR (sym >= OSS.array)
    END ;
    IF sym = OSS.ident THEN
      find(obj); OSS.Get(sym);
      IF obj.class = OSG.Typ THEN type := obj.type ELSE OSS.Mark("type?") END
    ELSIF sym = OSS.array THEN
      OSS.Get(sym); expression(x);
      IF (x.mode # OSG.Const) OR (x.a < 0) THEN OSS.Mark("bad index") END ;
      IF sym = OSS.of THEN OSS.Get(sym) ELSE OSS.Mark("OF?") END ;
      Type(tp); NEW(type); type.form := OSG.Array; type.base := tp;
      type.len := x.a; type.size := type.len * tp.size
    ELSIF sym = OSS.record THEN
      OSS.Get(sym); NEW(type); type.form := OSG.Record; type.size := 0; OpenScope;
      REPEAT
        IF sym = OSS.ident THEN
          IdentList(OSG.Fld, first); Type(tp); obj := first;
          WHILE obj # NIL DO
            obj.type := tp; obj.val := type.size; type.size := type.size + obj.type.size; obj := obj.next
          END
        END ;
        IF sym = OSS.semicolon THEN OSS.Get(sym)
        ELSIF sym = OSS.ident THEN OSS.Mark("; ?")
        END
      UNTIL sym # OSS.ident;
      type.dsc := topScope.next; CloseScope; Check(OSS.end, "no END")
    ELSE OSS.Mark("ident?")  
    END
  END Type;

  PROCEDURE Declarations(VAR varsize: LONGINT);
    VAR obj, first: OSG.Object;
      x: OSG.Item; tp: OSG.Type; L: LONGINT;
  BEGIN (*sync*)
    IF (sym < OSS.const) & (sym # OSS.end) THEN OSS.Mark("declaration?");
      REPEAT OSS.Get(sym) UNTIL (sym >= OSS.const) OR (sym = OSS.end)
    END ;
    IF sym = OSS.const THEN
      OSS.Get(sym);
      WHILE sym = OSS.ident DO
        NewObj(obj, OSG.Const); OSS.Get(sym);
        IF sym = OSS.eql THEN OSS.Get(sym) ELSE OSS.Mark("=?") END;
        expression(x);
        IF x.mode = OSG.Const THEN obj.val := x.a; obj.type := x.type
        ELSE OSS.Mark("expression not constant")
        END ;
        Check(OSS.semicolon, "; expected")
      END
    END ;
    IF sym = OSS.type THEN
      OSS.Get(sym);
      WHILE sym = OSS.ident DO
        NewObj(obj, OSG.Typ); OSS.Get(sym);
        IF sym = OSS.eql THEN OSS.Get(sym) ELSE OSS.Mark("=?") END ; 
        Type(obj.type); Check(OSS.semicolon, "; expected")
      END
    END ;
    IF sym = OSS.var THEN
      OSS.Get(sym);
      WHILE sym = OSS.ident DO
        IdentList(OSG.Var, first); Type(tp);
        obj := first;
        WHILE obj # NIL DO
          obj.type := tp; obj.lev := level;
          obj.val := varsize; varsize := varsize + obj.type.size; obj := obj.next
        END ;
        Check(OSS.semicolon, "; expected")
      END
    END ;
    IF (sym >= OSS.const) & (sym <= OSS.var) THEN OSS.Mark("declaration in bad order") END
  END Declarations;

  PROCEDURE ProcedureDecl;
    CONST marksize = 4;
    VAR proc, obj: OSG.Object;
      procid: OSS.Ident;
      nofpar: INTEGER;
      locblksize, parblksize: LONGINT;
      
    PROCEDURE FPSection(VAR adr: LONGINT; VAR nofpar: INTEGER);
      VAR obj, first: OSG.Object; tp: OSG.Type; parsize: LONGINT;
    BEGIN
      IF sym = OSS.var THEN OSS.Get(sym); IdentList(OSG.Par, first)
      ELSE IdentList(OSG.Var, first)
      END ;
      IF sym = OSS.ident THEN
        find(obj); OSS.Get(sym);
        IF obj.class = OSG.Typ THEN tp := obj.type ELSE OSS.Mark("type?"); tp := OSG.intType END
      ELSE OSS.Mark("ident?"); tp := OSG.intType
      END ;
      IF first.class = OSG.Var THEN
        parsize := tp.size;
        IF tp.form >= OSG.Array THEN OSS.Mark("no struct params") END ;
      ELSE parsize := WordSize
      END ;
      obj := first;
      WHILE obj # NIL DO
        INC(nofpar); obj.type := tp; obj.lev := level; obj.val := adr; adr := adr + parsize;
        obj := obj.next
      END
    END FPSection;
    
  BEGIN (* ProcedureDecl *) OSS.Get(sym);
    IF sym = OSS.ident THEN
      procid := OSS.id; NewObj(proc, OSG.Proc); OSS.Get(sym); parblksize := marksize; nofpar := 0;
    (* Texts.Write(W, "%"); Texts.WriteInt(W, sym, 4); Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf); *)
      OpenScope;  INC(level); proc.val := -1;
      IF sym = OSS.times THEN proc.comd := TRUE; OSS.Get(sym) ELSE proc.comd := FALSE END ;
      IF sym = OSS.lparen THEN
        OSS.Get(sym);
        IF sym = OSS.rparen THEN OSS.Get(sym)
        ELSE FPSection(parblksize, nofpar);
          WHILE sym = OSS.semicolon DO OSS.Get(sym); FPSection(parblksize, nofpar) END ;
          IF sym = OSS.rparen THEN OSS.Get(sym) ELSE OSS.Mark(")?") END ;
          IF proc.comd THEN OSS.Mark("no params allowed") END
        END
      END ;
      locblksize := parblksize; proc.type := NIL; proc.dsc := topScope.next; proc.nofpar := nofpar;
      Check(OSS.semicolon, "; expected");
      Declarations(locblksize); proc.dsc := topScope.next;
      WHILE sym = OSS.procedure DO
        ProcedureDecl; Check(OSS.semicolon, "; expected")
      END ;
      proc.val := OSG.pc * 4; OSG.Enter(parblksize, locblksize, proc.comd);
      IF sym = OSS.begin THEN OSS.Get(sym); StatSequence END ;
      Check(OSS.end, "no END");
      IF sym = OSS.ident THEN
        IF procid # OSS.id THEN OSS.Mark("no match") END ;
        OSS.Get(sym)
      END ;
      OSG.Return(locblksize); DEC(level); CloseScope
    END
  END ProcedureDecl;

  PROCEDURE Module;
    VAR modid: OSS.Ident; dc: LONGINT;
  BEGIN Texts.WriteString(W, "  compiling ");
    IF sym = OSS.module THEN
      OSS.Get(sym); OSG.Open; OpenScope; dc := 0; level := 0;
      IF sym = OSS.ident THEN
        modid := OSS.id; OSS.Get(sym);
        Texts.WriteString(W, modid); Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
      ELSE OSS.Mark("ident?")
      END ;
      Check(OSS.semicolon, "; expected");
      Declarations(dc);
      WHILE sym = OSS.procedure DO ProcedureDecl; Check(OSS.semicolon, "; expected") END ;
      OSG.Header(dc);
      IF sym = OSS.begin THEN OSS.Get(sym); StatSequence END ;
      Check(OSS.end, "no END");
      IF sym = OSS.ident THEN
        IF modid # OSS.id THEN OSS.Mark("no match") END ;
        OSS.Get(sym)
      ELSE OSS.Mark("ident?")
      END ;
      IF sym # OSS.period THEN OSS.Mark(". ?") END ;
      IF ~OSS.error THEN
        OSG.Close(modid, 1, dc, topScope); Texts.WriteString(W, "code generated "); Texts.WriteString(W, modid);
        Texts.WriteInt(W, OSG.pc, 6); Texts.WriteInt(W, dc, 6); Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
      END ;
      CloseScope
    ELSE OSS.Mark("MODULE?")
    END
  END Module;
  
  PROCEDURE Compile*;
    VAR beg, end, time: LONGINT; T: Texts.Text;
  BEGIN Oberon.GetSelection(T, beg, end, time);
    IF time >= 0 THEN OSS.Init(T, beg); OSS.Get(sym); Module END
  END Compile;

  PROCEDURE enter(name: ARRAY OF CHAR; cl: INTEGER; n: LONGINT;  type: OSG.Type);
    VAR obj: OSG.Object;
  BEGIN NEW(obj);
    obj.class := cl; obj.val := n; obj.name := name; obj.type := type; obj.dsc := NIL;
    obj.next := topScope.next; topScope.next := obj
  END enter; 

BEGIN Texts.OpenWriter(W); Texts.WriteString(W, "Oberon-0 Compiler OSP  9.5.2017");
  Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf);
  NEW(dummy); dummy.class := OSG.Var; dummy.type := OSG.intType; dummy.val := 0;
  expression := expression0;
  topScope := NIL; OpenScope;;
  enter("ORD", OSG.SFunc, 0, OSG.intType);
  enter("eot", OSG.SFunc, 1, OSG.boolType);
  enter("Switch", OSG.SFunc, 2, OSG.intType);
  enter("OpenInput", OSG.SProc, 0, NIL);
  enter("ReadInt", OSG.SProc, 1, NIL);
  enter("WriteInt", OSG.SProc, 2, NIL);
  enter("WriteChar", OSG.SProc, 3, NIL);
  enter("WriteLn", OSG.SProc, 4, NIL);
  enter("LED", OSG.SProc, 5, NIL);
  enter("BOOLEAN", OSG.Typ, 0, OSG.boolType);
  enter("INTEGER", OSG.Typ, 1, OSG.intType);
  universe := topScope
END OSP.
