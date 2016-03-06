MODULE OSS; (* NW 19.9.93 / 17.11.94 / 1.11.2013*)
  IMPORT Texts, Oberon;

  CONST IdLen* = 16; KW = 34; maxInt = 2147483647;

    (*lexical symbols of Oberon*)
    null = 0; times* = 1; div* = 3; mod* = 4;
    and* = 5; plus* = 6; minus* = 7; or* = 8; eql* = 9;
    neq* = 10; lss* = 11; leq* = 12; gtr* = 13; geq* = 14;
    period* = 18; char* = 20; int* = 21; false* = 23; true* = 24;
    not* = 27; lparen* = 28; lbrak* = 29;
    ident* = 31; if* = 32; while* = 34;
    repeat* = 35;
    comma* = 40; colon* = 41; becomes* = 42; rparen* = 44;
    rbrak* = 45; then* = 47; of* = 48; do* = 49;
    semicolon* = 52; end* = 53; 
    else* = 55; elsif* = 56; until* = 57; 
    array* = 60; record* = 61; const* = 63; type* = 64;
    var* = 65; procedure* = 66; begin* = 67;  module* = 69;
    eof = 70;

  TYPE Ident* = ARRAY IdLen OF CHAR;

  VAR val*: LONGINT;
    id*: Ident;
    error*: BOOLEAN;

    ch: CHAR;
    nkw: INTEGER;
    errpos: LONGINT;
    R: Texts.Reader;
    W: Texts.Writer;
    keyTab: ARRAY KW OF  (*keywords of Oberon*)
        RECORD sym: INTEGER; id: ARRAY 12 OF CHAR END;

  PROCEDURE Mark*(msg: ARRAY OF CHAR);
    VAR p: LONGINT;
  BEGIN p := Texts.Pos(R) - 1;
    IF p > errpos THEN
      Texts.WriteString(W, "  pos "); Texts.WriteInt(W, p, 1);
      Texts.Write(W, " "); Texts.WriteString(W, msg);
      Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
    END ;
    errpos := p; error := TRUE
  END Mark;

  PROCEDURE Identifier(VAR sym: INTEGER);
    VAR i, k: INTEGER;
  BEGIN i := 0;
    REPEAT
      IF i < IdLen THEN id[i] := ch; INC(i) END ;
      Texts.Read(R, ch)
    UNTIL (ch < "0") OR (ch > "9") & (ch < "A") OR (ch > "Z") & (ch < "a") OR (ch > "z");
    id[i] := 0X; k := 0;
    WHILE (k < nkw) & (id # keyTab[k].id) DO INC(k) END ;
    IF k < nkw THEN sym := keyTab[k].sym ELSE sym := ident END
  END Identifier;

  PROCEDURE Number(VAR sym: INTEGER);
  BEGIN val := 0; sym := int;
    REPEAT
      IF val <= (maxInt - ORD(ch) + ORD("0")) DIV 10 THEN
        val := 10 * val + (ORD(ch) - ORD("0"))
      ELSE Mark("number too large"); val := 0
      END ;
      Texts.Read(R, ch)
    UNTIL (ch < "0") OR (ch > "9")
  END Number;

  PROCEDURE comment;
  BEGIN
    REPEAT
      REPEAT Texts.Read(R, ch);
        WHILE ch = "(" DO Texts.Read(R, ch);
          IF ch = "*" THEN comment END
        END ;
      UNTIL (ch = "*") OR R.eot;
      REPEAT Texts.Read(R, ch) UNTIL (ch # "*") OR R.eot
    UNTIL (ch = ")") OR R.eot;
    IF ~R.eot THEN Texts.Read(R, ch) ELSE Mark("comment not terminated") END
  END comment;

  PROCEDURE Get*(VAR sym: INTEGER);
  BEGIN
    REPEAT
      WHILE ~R.eot & (ch <= " ") DO Texts.Read(R, ch) END;
        IF ch < "A" THEN
        IF ch < "0" THEN
          IF ch = 22X THEN
            Texts.Read(R, ch); val := ORD(ch);
            REPEAT Texts.Read(R, ch) UNTIL (ch = 22X) OR R.eot;
            Texts.Read(R, ch); sym := char
          ELSIF ch = "#" THEN Texts.Read(R, ch); sym := neq
          ELSIF ch = "&" THEN Texts.Read(R, ch); sym := and
          ELSIF ch = "(" THEN Texts.Read(R, ch); 
            IF ch = "*" THEN sym := null; comment ELSE sym := lparen END
          ELSIF ch = ")" THEN Texts.Read(R, ch); sym := rparen
          ELSIF ch = "*" THEN Texts.Read(R, ch); sym := times
          ELSIF ch = "+" THEN Texts.Read(R, ch); sym := plus
          ELSIF ch = "," THEN Texts.Read(R, ch); sym := comma
          ELSIF ch = "-" THEN Texts.Read(R, ch); sym := minus
          ELSIF ch = "." THEN Texts.Read(R, ch); sym := period
          ELSIF ch = "/" THEN Texts.Read(R, ch); sym := null
          ELSE Texts.Read(R, ch); (* ! $ % *) sym := null
          END
        ELSIF ch < ":" THEN Number(sym)
        ELSIF ch = ":" THEN Texts.Read(R, ch);
          IF ch = "=" THEN Texts.Read(R, ch); sym := becomes ELSE sym := colon END 
        ELSIF ch = ";" THEN Texts.Read(R, ch); sym := semicolon
        ELSIF ch = "<" THEN  Texts.Read(R, ch);
          IF ch = "=" THEN Texts.Read(R, ch); sym := leq ELSE sym := lss END
        ELSIF ch = "=" THEN Texts.Read(R, ch); sym := eql
        ELSIF ch = ">" THEN Texts.Read(R, ch);
          IF ch = "=" THEN Texts.Read(R, ch); sym := geq ELSE sym := gtr END
        ELSE (* ? @ *) Texts.Read(R, ch); sym := null
        END
      ELSIF ch < "[" THEN Identifier(sym)
      ELSIF ch < "a" THEN
        IF ch = "[" THEN sym := lbrak
        ELSIF ch = "]" THEN  sym := rbrak
        ELSIF ch = "^" THEN sym := null
        ELSE (* _ ` *) sym := null
        END ;
        Texts.Read(R, ch)
      ELSIF ch < "{" THEN Identifier(sym) ELSE
        IF ch = "{" THEN sym := null
        ELSIF ch = "}" THEN sym := null
        ELSIF ch = "|" THEN sym := null
        ELSIF ch = "~" THEN  sym := not
        ELSE sym := null
        END ;
        Texts.Read(R, ch)
      END
    UNTIL sym # null
  END Get;

  PROCEDURE Init*(T: Texts.Text; pos: LONGINT);
  BEGIN error := FALSE; errpos := pos; Texts.OpenReader(R, T, pos); Texts.Read(R, ch)
  END Init;
  
  PROCEDURE EnterKW(sym: INTEGER; name: ARRAY OF CHAR);
  BEGIN keyTab[nkw].sym := sym; COPY(name, keyTab[nkw].id); INC(nkw)
  END EnterKW;

BEGIN Texts.OpenWriter(W); error := TRUE; nkw := 0;
  EnterKW(array, "ARRAY");
  EnterKW(begin, "BEGIN");
  EnterKW(null, "BY");
  EnterKW(const, "CONST");
  EnterKW(div, "DIV");
  EnterKW(do, "DO");
  EnterKW(else, "ELSE");
  EnterKW(elsif, "ELSIF");
  EnterKW(end, "END");
  EnterKW(false, "FALSE");
  EnterKW(null, "FOR");
  EnterKW(if, "IF");
  EnterKW(null, "IMPORT");
  EnterKW(null, "IN");
  EnterKW(null, "IS");
  EnterKW(mod, "MOD");
  EnterKW(module, "MODULE");
  EnterKW(null, "NIL");
  EnterKW(of, "OF");
  EnterKW(or, "OR");
  EnterKW(null, "POINTER");
  EnterKW(procedure, "PROCEDURE");
  EnterKW(record, "RECORD");
  EnterKW(repeat, "REPEAT");
  EnterKW(null, "RETURN");
  EnterKW(then, "THEN");
  EnterKW(null, "TO");
  EnterKW(true, "TRUE");
  EnterKW(type, "TYPE");
  EnterKW(until, "UNTIL");
  EnterKW(var, "VAR");
  EnterKW(while, "WHILE")
END OSS.
