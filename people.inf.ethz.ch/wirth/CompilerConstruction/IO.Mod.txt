MODULE IO;   (*for Oberon0   NW 29.4.2017*)
  IMPORT Texts,Oberon;
  VAR S: Texts.Scanner;  W: Texts.Writer;

  PROCEDURE OpenInput*;
  BEGIN Texts.OpenScanner(S, Oberon.Par.text, Oberon.Par.pos); Texts.Scan(S)
  END OpenInput;

  PROCEDURE ReadInt*(VAR x: LONGINT);
  BEGIN x := S.i;  Texts.Scan(S)
  END ReadInt;

  PROCEDURE Class*(): INTEGER;
  BEGIN RETURN S.class
  END Class;

  PROCEDURE Write*(ch: CHAR);
  BEGIN Texts.Write(W, ch)
  END Write;

  PROCEDURE WriteInt*(x: LONGINT; n: INTEGER);
  BEGIN Texts.WriteInt(W, x, n)
  END WriteInt;

  PROCEDURE WriteLn*;
  BEGIN Texts.WriteLn(W); Texts.Append(Oberon.Log, W.buf)
  END WriteLn;

BEGIN Texts.OpenWriter(W)
END IO.
