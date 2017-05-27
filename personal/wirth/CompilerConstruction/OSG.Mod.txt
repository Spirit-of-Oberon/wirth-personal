MODULE OSG; (* NW 19.12.94 / 20.10.07 / OSGX  9.5.2017*) 
  IMPORT SYSTEM, Files, Texts, Oberon, OSS;

  CONST MemSize = 8192;
    (* class / mode*) Head* = 0;
    Const* = 1; Var* = 2; Par* = 3; Fld* = 4; Typ* = 5;
    SProc* = 6; SFunc* = 7; Proc* = 8; NoTyp* = 9; Reg = 10; RegI = 11; Cond = 12;
    SB = 13; SP = 14; LNK = 15;   (*reserved registers*)
    (* form *) Boolean* = 0; Integer* = 1; Array* = 2; Record* = 3;

  (*frequently used opcodes*)  U = 2000H;
    Mov = 0; Lsl = 1; Asr = 2; Ror= 3; And = 4; Ann = 5; Ior = 6; Xor = 7;
    Add = 8; Sub = 9; Cmp = 9; Mul = 10; Div = 11;
    Ldw = 0; Stw = 2;
    BR = 0; BLR = 1; BC = 2; BL = 3;
    MI = 0; PL = 8; EQ = 1; NE = 9; LT = 5; GE = 13; LE = 6; GT = 14;

  TYPE Object* = POINTER TO ObjDesc;
    Type* = POINTER TO TypeDesc;

    Item* = RECORD
      mode*, lev*: INTEGER;
      type*: Type;
      a*, b, r: LONGINT
    END ;

    ObjDesc*= RECORD
      class*, lev*: INTEGER;
      next*, dsc*: Object;
      type*: Type;
      name*: OSS.Ident;
      val*, nofpar*: LONGINT;
      comd*: BOOLEAN
    END ;

    TypeDesc* = RECORD
      form*: INTEGER;
      dsc*: Object;
      base*: Type;
      size*, len*, nofpar*: LONGINT
    END ;
  
  VAR boolType*, intType*: Type;
    curlev*, pc*: INTEGER;
    curSB: INTEGER;
    entry, fixlist, fixorgD: LONGINT;
    RH: LONGINT;  (*register stack pointer*)
    W: Texts.Writer;
    relmap: ARRAY 6 OF INTEGER;
    code*: ARRAY MemSize OF LONGINT;
    mnemo0, mnemo1: ARRAY 16, 4 OF CHAR;  (*for decoder*)

  PROCEDURE Put0(op, a, b, c: LONGINT);
  BEGIN (*emit format-0 instruction*)
    code[pc] := ((a*10H + b) * 10H + op) * 10000H + c; INC(pc)
  END Put0;

  PROCEDURE Put1(op, a, b, im: LONGINT);
  BEGIN (*emit format-1 instruction*)
    IF im < 0 THEN INC(op, 1000H) END ;  (*set v-bit*)
    code[pc] := (((a+40H) * 10H + b) * 10H + op) * 10000H + (im MOD 10000H); INC(pc)
  END Put1;

  PROCEDURE Put2(op, a, b, off: LONGINT);
  BEGIN (*emit load/store instruction*)
    code[pc] := (((op+8) * 10H + a) * 10H + b) * 100000H + (off MOD 10000H); INC(pc)
  END Put2;

  PROCEDURE Put3(op, cond, off: LONGINT);
  BEGIN (*emit branch instruction*)
    code[pc] := ((op+12) * 10H + cond) * 1000000H + (off MOD 1000000H); INC(pc)
  END Put3;

  PROCEDURE incR;
  BEGIN
    IF RH < SB THEN INC(RH) ELSE OSS.Mark("register stack overflow") END
  END incR;

  PROCEDURE CheckRegs*;
  BEGIN
    IF RH # 0 THEN
    (*  Texts.WriteString(W, "RegStack!"); Texts.WriteInt(W, R, 4);
      Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf) *)
      OSS.Mark("Reg Stack"); RH := 0
    END
  END CheckRegs;

  PROCEDURE SetCC(VAR x: Item; n: LONGINT);
  BEGIN x.mode := Cond; x.a := 0; x.b := 0; x.r := n
  END SetCC;

  PROCEDURE TestRange(x: LONGINT);
  BEGIN (*16-bit entity*)
    IF (x > 0FFFFH) OR (x < -10000H) THEN OSS.Mark("value too large") END
  END TestRange;

  PROCEDURE negated(cond: LONGINT): LONGINT;
  BEGIN
    IF cond < 8 THEN cond := cond+8 ELSE cond := cond-8 END ;
    RETURN cond
  END negated;

  PROCEDURE invalSB;
  BEGIN curSB := 1
  END invalSB;

  PROCEDURE fix(at, with: LONGINT);
  BEGIN code[at] := code[at] DIV 1000000H * 1000000H + (with MOD 1000000H)
  END fix;

  PROCEDURE FixLink*(L: LONGINT);
    VAR L1: LONGINT;
  BEGIN 
    WHILE L # 0 DO
      IF L < MemSize THEN L1 := code[L] MOD 40000H; fix(L, pc-L-1); L := L1 END
    END
  END FixLink;
  
  PROCEDURE GetSB;
  BEGIN
    IF curSB = 1 THEN Put2(Ldw, SB, 0, pc-fixorgD); fixorgD := pc-1; curSB := 0 END
  END GetSB;

  PROCEDURE load(VAR x: Item);
  BEGIN
    IF x.mode # Reg THEN
      IF x.mode = Var THEN
        IF x.r > 0 THEN (*local*) Put2(Ldw, RH, SP, x.a) ELSE GetSB; Put2(Ldw, RH, SB, x.a) END ;
        x.r := RH; incR
      ELSIF x.mode = Par THEN Put2(Ldw, RH, x.r, x.a); Put2(Ldw, RH, RH, 0); x.r := RH; incR
      ELSIF x.mode = Const THEN
        IF (x.a >= 10000H) OR (x.a < -10000H) THEN OSS.Mark("const too large") END ;
        Put1(Mov, RH, 0, x.a); x.r := RH; incR
      ELSIF x.mode = RegI THEN Put2(Ldw, x.r, x.r, x.a)
      ELSIF x.mode = Cond THEN
        Put3(2, negated(x.r), 2);
        FixLink(x.b); Put1(Mov, RH, 0, 1); Put3(2, 7, 1);
        FixLink(x.a); Put1(Mov, RH, 0, 0); x.r := RH; incR
      END ;
      x.mode := Reg
    END
  END load;

  PROCEDURE loadAdr(VAR x: Item);
  BEGIN
    IF x.mode = Var THEN
      IF x.r > 0 THEN (*local*) Put1(Add, RH, SP, x.a); x.r := RH ELSE GetSB; Put1(Add, RH, SB, x.a) END ;
      incR
    ELSIF x.mode = Par THEN Put2(Ldw, RH, SP, x.a); Put1(Add, RH, RH, x.b); x.r := RH; incR
    ELSIF (x.mode = RegI) & (x.a # 0) THEN Put1(Add, x.r, x.r, x.a)
    ELSE OSS.Mark("address error") 
    END ;
    x.mode := Reg
  END loadAdr;

  PROCEDURE loadCond(VAR x: Item);
  BEGIN
    IF x.type.form = Boolean THEN
      IF x.mode = Const THEN x.r := 15 - x.a*8 ELSE load(x); Put1(Cmp, x.r, x.r, 0); x.r := NE; DEC(RH) END ;
      x.mode := Cond; x.a := 0; x.b := 0
    ELSE OSS.Mark("not Boolean")
    END
  END loadCond;

  PROCEDURE merged(L0, L1: LONGINT): LONGINT;
    VAR L2, L3: LONGINT;
  BEGIN 
    IF L0 # 0 THEN
      L3 := L0;
      REPEAT L2 := L3; L3 := code[L2] MOD 40000H UNTIL L3 = 0;
      code[L2] := code[L2] + L1; L1 := L0
    END ;
    RETURN L1
  END merged;

  (*-----------------------------------------------*)

  PROCEDURE IncLevel*(n: INTEGER);
  BEGIN curlev := curlev + n
  END IncLevel;

  PROCEDURE MakeConstItem*(VAR x: Item; typ: Type; val: LONGINT);
  BEGIN x.mode := Const; x.type := typ; x.a := val
  END MakeConstItem;

  PROCEDURE MakeItem*(VAR x: Item; y: Object; curlev: LONGINT);
    VAR r: LONGINT;
  BEGIN x.mode := y.class; x.type := y.type; x.a := y.val; x.r := y.lev;
    IF y.class = Par THEN x.b := 0 END ;
    IF (y.lev > 0) & (y.lev # curlev) & (y.class # Const) THEN OSS.Mark("level error") END
  END MakeItem;

  PROCEDURE Field*(VAR x: Item; y: Object);   (* x := x.y *)
  BEGIN
    IF (x.mode = Var) OR (x.mode = RegI) THEN x.a := x.a + y.val
    ELSIF x.mode = Par THEN Put2(Ldw, RH, x.r, x.a); x.mode := RegI; x.r := RH; x.a := y.val; incR
    END
  END Field;

  PROCEDURE Index*(VAR x, y: Item);   (* x := x[y] *)
    VAR s: LONGINT;
  BEGIN
    IF y.mode = Const THEN
      IF (y.a < 0) OR (y.a >= x.type.len) THEN OSS.Mark("bad index") END ;
      IF x.mode = Par THEN Put2(Ldw, RH, x.r, x.a); x.mode := RegI; x.a := 0 END ;
      x.a := x.a + y.a * x.type.base.size
    ELSE s := x.type.base.size;
      IF y.mode # Reg THEN load(y) END ;
      IF s = 4 THEN Put1(Lsl, y.r, y.r, 2) ELSE Put1(Mul, y.r, y.r, s) END ;
      IF x.mode = Var THEN
        IF x.r > 0 THEN Put0(Add, y.r, SP, y.r) ELSE GetSB; Put0(Add, y.r, SB, y.r) END ;
        x.mode := RegI; x.r := y.r
      ELSIF x.mode = Par THEN
        Put2(Ldw, RH, SP, x.a); Put0(Add, y.r, RH, y.r); x.mode := RegI; x.r := y.r
      ELSIF x.mode = RegI THEN Put0(Add, x.r, x.r, y.r); DEC(RH)
      END
    END
  END Index;
  
  (* Code generation for Boolean operators *)

  PROCEDURE Not*(VAR x: Item);   (* x := ~x *)
    VAR t: LONGINT;
  BEGIN
    IF x.mode # Cond THEN loadCond(x) END ;
    x.r := negated(x.r); t := x.a; x.a := x.b; x.b := t
  END Not;

  PROCEDURE And1*(VAR x: Item);   (* x := x & *)
  BEGIN
    IF x.mode # Cond THEN loadCond(x) END ;
    Put3(BC, negated(x.r), x.a); x.a := pc-1; FixLink(x.b); x.b := 0
  END And1;

  PROCEDURE And2*(VAR x, y: Item);
  BEGIN
    IF y.mode # Cond THEN loadCond(y) END ;
    x.a := merged(y.a, x.a); x.b := y.b; x.r := y.r
  END And2;

  PROCEDURE Or1*(VAR x: Item);   (* x := x OR *)
  BEGIN
    IF x.mode # Cond THEN loadCond(x) END ;
    Put3(BC, x.r, x.b);  x.b := pc-1; FixLink(x.a); x.a := 0
  END Or1;

  PROCEDURE Or2*(VAR x, y: Item);
  BEGIN
    IF y.mode # Cond THEN loadCond(y) END ;
    x.a := y.a; x.b := merged(y.b, x.b); x.r := y.r
  END Or2;

  (* Code generation for arithmetic operators *)

  PROCEDURE Neg*(VAR x: Item);   (* x := -x *)
  BEGIN
    IF x.mode = Const THEN x.a := -x.a
    ELSE load(x); Put1(Mov, RH, 0, 0); Put0(Sub, x.r, RH, x.r)
    END
  END Neg;

  PROCEDURE AddOp*(op: LONGINT; VAR x, y: Item);   (* x := x +- y *)
  BEGIN
    IF op = OSS.plus THEN
      IF (x.mode = Const) & (y.mode = Const) THEN x.a := x.a + y.a
      ELSIF y.mode = Const THEN load(x);
        IF y.a # 0 THEN Put1(Add, x.r, x.r, y.a) END
      ELSE load(x); load(y); Put0(Add, RH-2, x.r, y.r); DEC(RH); x.r := RH-1
      END
    ELSE (*op = OSS.minus*)
      IF (x.mode = Const) & (y.mode = Const) THEN x.a := x.a - y.a
      ELSIF y.mode = Const THEN load(x);
        IF y.a # 0 THEN Put1(Sub, x.r, x.r, y.a) END
      ELSE load(x); load(y); Put0(Sub, RH-2, x.r, y.r); DEC(RH); x.r := RH-1
      END
    END
  END AddOp;

  PROCEDURE MulOp*(VAR x, y: Item);   (* x := x * y *)
  BEGIN
    IF (x.mode = Const) & (y.mode = Const) THEN x.a := x.a * y.a
    ELSIF (y.mode = Const) & (y.a = 2) THEN load(x); Put1(Lsl, x.r, x.r, 1)
    ELSIF y.mode = Const THEN load(x); Put1(Mul, x.r, x.r, y.a)
    ELSIF x.mode = Const THEN load(y); Put1(Mul, y.r, y.r, x.a); x.mode := Reg; x.r := y.r
    ELSE load(x); load(y); Put0(Mul, RH-2, x.r, y.r); DEC(RH); x.r := RH-1
    END
  END MulOp;

  PROCEDURE DivOp*(op: LONGINT; VAR x, y: Item);   (* x := x op y *)
  BEGIN
    IF op = OSS.div THEN
      IF (x.mode = Const) & (y.mode = Const) THEN
        IF y.a > 0 THEN x.a := x.a DIV y.a ELSE OSS.Mark("bad divisor") END
      ELSIF (y.mode = Const) & (y.a = 2) THEN load(x); Put1(Asr, x.r, x.r, 1)
      ELSIF y.mode = Const THEN
        IF y.a > 0 THEN load(x); Put1(Div, x.r, x.r, y.a) ELSE OSS.Mark("bad divisor") END
      ELSE load(y); load(x); Put0(Div, RH-2, x.r, y.r); DEC(RH); x.r := RH-1
      END
    ELSE (*op = OSS.mod*)
      IF (x.mode = Const) & (y.mode = Const) THEN
        IF y.a > 0 THEN x.a := x.a MOD y.a ELSE OSS.Mark("bad modulus") END
      ELSIF (y.mode = Const) & (y.a = 2) THEN load(x); Put1(And, x.r, x.r, 1)
      ELSIF y.mode = Const THEN
        IF y.a > 0 THEN load(x); Put1(Div, x.r, x.r, y.a); Put0(Mov+U, x.r, 0, 0) ELSE OSS.Mark("bad modulus") END
      ELSE load(y); load(x); Put0(Div, RH-2, x.r, y.r); Put0(Mov+U, RH-2, 0, 0); DEC(RH); x.r := RH-1
      END
    END
  END DivOp;

  PROCEDURE Relation*(op: INTEGER; VAR x, y: Item);   (* x := x ? y *)
  BEGIN
    IF y.mode = Const THEN load(x); Put1(Cmp, x.r, x.r, y.a); DEC(RH)
    ELSE load(x); load(y); Put0(Cmp, x.r, x.r, y.r); DEC(RH, 2)
    END ;
    SetCC(x, relmap[op - OSS.eql])
  END Relation;
  
  PROCEDURE Store*(VAR x, y: Item); (* x := y *)
  BEGIN load(y);
    IF x.mode = Var THEN
      IF x.r > 0 THEN (*local*) Put2(Stw, y.r, SP, x.a) ELSE GetSB; Put2(Stw, y.r, SB, x.a) END
    ELSIF x.mode = Par THEN Put2(Ldw, RH, SP, x.a); Put2(Stw, y.r, RH, x.b)
    ELSIF x.mode = RegI THEN Put2(Stw, y.r, x.r, x.a); DEC(RH)
    ELSE OSS.Mark("illegal assignment")
    END ;
    DEC(RH)
  END Store;

  PROCEDURE VarParam*(VAR x: Item; ftype: Type);
    VAR xmd: INTEGER;
  BEGIN xmd := x.mode; loadAdr(x);
    IF (ftype.form = Array) & (ftype.len < 0) THEN (*open array*)
      IF x.type.len >= 0 THEN Put1(Mov, RH, 0, x.type.len) ELSE  Put2(Ldw, RH, SP, x.a+4) END ;
      incR
    ELSIF ftype.form = Record THEN
      IF xmd = Par THEN Put2(Ldw, RH, SP, x.a+4); incR END
    END
  END VarParam;

  PROCEDURE ValueParam*(VAR x: Item);
  BEGIN load(x)
  END ValueParam;

  PROCEDURE OpenArrayParam*(VAR x: Item);
  BEGIN loadAdr(x);
    IF x.type.len >= 0 THEN Put1(Mov, RH, 0, x.type.len) ELSE Put2(Ldw, RH, SP, x.a+4) END ;
    incR
  END OpenArrayParam;

  (*---------------------------------*)
  
  PROCEDURE CFJump*(VAR x: Item);  (*conditional forward jump*)
  BEGIN
    IF x.mode # Cond THEN loadCond(x) END ;
    Put3(2, negated(x.r), x.a); FixLink(x.b); x.a := pc-1
  END CFJump;

  PROCEDURE FJump*(VAR L: LONGINT);  (*unconditional forward jump*)
  BEGIN Put3(2, 7, L); L := pc-1
  END FJump;

  PROCEDURE CBJump*(VAR x: Item; L: LONGINT);  (*conditional backward jump*)
  BEGIN
    IF x.mode # Cond THEN loadCond(x) END ;
    Put3(2, negated(x.r), L-pc-1)
  END CBJump;
  
  PROCEDURE BJump*(L: LONGINT);  (*unconditional backward jump*)
  BEGIN Put3(2, 7, L-pc-1)
  END BJump;

  PROCEDURE Call*(VAR obj: Object);
  BEGIN Put3(3, 7, (obj.val DIV 4) - pc-1); RH := 0
  END Call;

  PROCEDURE Enter*(parblksize, locblksize: LONGINT; comd: BOOLEAN);
    VAR a, r: LONGINT;
  BEGIN a := 4; r := 0; Put1(Sub, SP, SP, locblksize); Put2(Stw, LNK, SP, 0);
    WHILE a < parblksize DO Put2(Stw, r, SP, a); INC(r); INC(a, 4) END ;
  (* IF comd THEN Put2(Ldw, SB, 0, 0) END *)
  END Enter;

  PROCEDURE Return*(size: LONGINT);
  BEGIN Put2(Ldw, LNK, SP, 0); Put1(Add, SP, SP, size); Put3(BR, 7, LNK); RH := 0
  END Return;

  PROCEDURE Ord*(VAR x: Item);
  BEGIN load(x); x.type := intType
  END Ord;

  PROCEDURE OpenInput*;
  BEGIN Put3(3, 7, pc - fixlist + 101000H); fixlist := pc-1; invalSB
  END OpenInput;

  PROCEDURE ReadInt*(VAR x: Item);
  BEGIN loadAdr(x); Put3(3, 7, pc - fixlist + 102000H); fixlist := pc-1; DEC(RH); invalSB
  END ReadInt;

  PROCEDURE eot*(VAR x: Item);
  BEGIN Put3(3, 7, pc - fixlist + 103000H); fixlist := pc-1; Put1(Cmp, 0, 0, Texts.Int); SetCC(x, NE); invalSB
  END eot;

  PROCEDURE WriteChar*(VAR x: Item);
  BEGIN load(x); Put3(3, 7, pc - fixlist + 104000H); fixlist:= pc-1; DEC(RH); invalSB
  END WriteChar;

  PROCEDURE WriteInt*(VAR x, y: Item);
  BEGIN load(x); load(y); Put3(3, 7, pc - fixlist + 105000H); fixlist := pc-1; DEC(RH, 2); invalSB
  END WriteInt;

  PROCEDURE WriteLn*;
  BEGIN Put3(3, 7, pc - fixlist + 106000H); fixlist := pc-1; invalSB
  END WriteLn;

  PROCEDURE Switch*(VAR x: Item);
  BEGIN Put1(Mov, RH, 0, -60); Put2(Ldw, RH, RH, 0);
    x.mode := Reg; x.type := intType; x.r := RH; INC(RH)
  END Switch;

  PROCEDURE LED*(VAR x: Item);
  BEGIN load(x); Put1(Mov, RH, 0, -60); Put2(Stw, x.r, RH, 0); DEC(RH)
  END LED ;

  PROCEDURE Open*;
  BEGIN curlev := 0; pc := 0; RH := 0; fixlist := 0; fixorgD := 0
  END Open;

  PROCEDURE Header*(size: LONGINT);
  BEGIN entry := pc*4; Put1(Sub, SP, SP, 4); Put2(Stw, LNK, SP, 0); invalSB
  END Header;

  PROCEDURE MakeFileName(VAR FName: OSS.Ident; name, ext: ARRAY OF CHAR);
    VAR i, j: INTEGER;
  BEGIN i := 0; j := 0;  (*assume name suffix less than 4 characters*)
    WHILE (i < OSS.IdLen-5) & (name[i] > 0X) DO FName[i] := name[i]; INC(i) END ;
    REPEAT FName[i]:= ext[j]; INC(i); INC(j) UNTIL ext[j] = 0X;
    FName[i] := 0X
  END MakeFileName;

  PROCEDURE Close*(VAR modid: OSS.Ident; key, datasize: LONGINT; topScope: Object);  (*write code file*)
    VAR i, nofent, nofimp, comsize, size: INTEGER;
      obj: Object;
      name: OSS.Ident;
      F: Files.File; R: Files.Rider;
  BEGIN Put2(Ldw, LNK, SP, 0); Put1(Add, SP, SP, 4); Put3(BR, 7, LNK);
    obj := topScope.next; comsize := 4; nofent := 1; nofimp := 1;
    WHILE obj # NIL DO
      IF obj.comd THEN i := 0; (*count entries and commands*)
        WHILE obj.name[i] # 0X DO INC(i) END ;
        i := (i+4) DIV 4 * 4; INC(comsize, i+4); INC(nofent); INC(nofimp)
      END ;
      obj := obj.next
    END ;
    size := datasize + comsize + (pc + nofimp + nofent + 1)*4;
    MakeFileName(name, modid, ".rsc"); (*write code file*)
    F := Files.New(name); Files.Set(R, F, 0);
    Files.WriteString(R, modid); Files.WriteInt(R, key); Files.Write(R, 1X);   (*version*)
    Files.WriteInt(R, size);
    Files.WriteString(R, "IO"); Files.WriteInt(R, 3A8372E2H); Files.Write(R, 0X);  (*import*)
    Files.WriteInt(R, 0);  (*no type descriptors*)
    Files.WriteInt(R, datasize);  (*data*)
    Files.WriteInt(R, 0);   (*no strings*)
    Files.WriteInt(R, pc);  (*code len*)
    FOR i := 0 TO pc-1 DO Files.WriteInt(R, code[i]) END ;  (*program*)
    obj := topScope.next;
    WHILE obj # NIL DO  (*commands*)
      IF obj.comd THEN Files.WriteString(R, obj.name); Files.WriteInt(R, obj.val) END ;
      obj := obj.next
    END ;
    Files.Write(R, 0X);
    Files.WriteInt(R, nofent); Files.WriteInt(R, entry);   (*of program body*)
    obj := topScope.next;
    WHILE obj # NIL DO  (*entries*)
      IF obj.comd THEN Files.WriteInt(R, obj.val) END ;
      obj := obj.next
    END ;
    Files.WriteInt(R, -1);   (*no pointer variables*)
    Files.WriteInt(R, fixlist); Files.WriteInt(R, fixorgD); Files.WriteInt(R, 0); Files.WriteInt(R, entry);
    Files.Write(R, "O"); Files.Register(F)
  END Close;

  (*-------------------- output -----------------------*)

  PROCEDURE WriteReg(r: LONGINT);
  BEGIN Texts.Write(W, " ");
    IF r < 13 THEN Texts.Write(W, "R"); Texts.WriteInt(W, r, 1)
    ELSIF r = 13 THEN Texts.WriteString(W, "SB")
    ELSIF r = 14 THEN Texts.WriteString(W, "SP")
    ELSIF r = 15 THEN Texts.WriteString(W, "LNK")
    END
  END WriteReg;

  PROCEDURE Decode*;
    VAR i, w, a, b, c, op: LONGINT;
  BEGIN Texts.WriteHex(W, code[0]); Texts.WriteHex(W, code[1]); Texts.WriteLn(W);
    i := 0;
    WHILE i < pc DO
      w := code[i];
      a := w DIV 1000000H MOD 10H;
      b := w DIV 100000H MOD 10H;
      Texts.WriteInt(W, i, 4); Texts.WriteHex(W, w); Texts.Write(W, 9X);
      IF ASR(w, 31) = 0 THEN  (*~p:  register instruction*)
        op := w DIV 10000H MOD 10H;
        Texts.WriteString(W, mnemo0[op]); WriteReg(a); WriteReg(b);
        IF ~ODD(w DIV 40000000H) THEN (*~q*) WriteReg(w MOD 10H)
        ELSE c := w MOD 10000H;;
          IF ODD(w DIV 10000000H) THEN (*v*) c := c + 0FFFF0000H END ;
          Texts.WriteInt(W, c, 8)
        END
      ELSIF ~ODD(w DIV 40000000H) THEN  (*load/store*)
        IF ODD(w DIV 20000000H) THEN Texts.WriteString(W, "STW ") ELSE Texts.WriteString(W, "LDW") END ;
        WriteReg(a); WriteReg(b); Texts.WriteInt(W, w MOD 100000H, 8)
      ELSE  (*Branch instr*)
        Texts.Write(W, "B");
        IF ODD(w DIV 10000000H) THEN Texts.Write(W, "L") END ;
        Texts.WriteString(W, mnemo1[a]);
        IF ~ODD(w DIV 20000000H) THEN WriteReg(w MOD 10H) ELSE
          w := w MOD 1000000H;
          IF w >= 800000H THEN w := w - 1000000H END ;
          Texts.WriteInt(W, w, 8)
        END
      END ;
      Texts.WriteLn(W); INC(i)
    END ;
    Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
  END Decode;

  PROCEDURE HexCh(k: LONGINT): CHAR;
  BEGIN
    IF k >= 10 THEN INC(k, 27H) END ; 
    RETURN CHR(k+30H)
  END HexCh;

BEGIN Texts.OpenWriter(W);
  NEW(boolType); boolType.form := Boolean; boolType.size := 4;
  NEW(intType); intType.form := Integer; intType.size := 4;
  relmap[0] := EQ; relmap[1] := NE; relmap[2] := LT; relmap[3] := LE; relmap[4] := GT; relmap[5] := GE;
  mnemo0[Mov] := "MOV";
  mnemo0[Lsl] := "LSL";
  mnemo0[Asr] := "ASR";
  mnemo0[Ror] := "ROR";
  mnemo0[And] := "AND";
  mnemo0[Ann] := "ANN";
  mnemo0[Ior] := "IOR";
  mnemo0[Xor] := "XOR";
  mnemo0[Add] := "ADD";
  mnemo0[Sub] := "SUB";
  mnemo0[Mul] := "MUL";
  mnemo0[Div] := "DIV";
  mnemo1[PL] := "PL ";
  mnemo1[MI] := "MI ";
  mnemo1[EQ] := "EQ ";
  mnemo1[NE] := "NE ";
  mnemo1[LT] := "LT ";
  mnemo1[GE] := "GE ";
  mnemo1[LE] := "LE ";
  mnemo1[GT] := "GT ";
  mnemo1[15] := "NO ";
END OSG.
