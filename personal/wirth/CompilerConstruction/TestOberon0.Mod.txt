OSP.Compile @  OSG.Decode
OSG.Execute 3 7 11~

MODULE Permutations;  (*NW 22.1.2013 for Oberon-0*)
  VAR m, n: INTEGER;
    a: ARRAY 10 OF INTEGER;

  PROCEDURE perm(k: INTEGER);
    VAR i, x: INTEGER;
  BEGIN
    IF k = 0 THEN i := 0;
      WHILE i < n DO WriteInt(a[i]); i := i+1 END ;
      WriteLn
    ELSE perm(k-1); i := 0;
      WHILE i < k-1 DO
        x := a[i]; a[i] := a[k-1]; a[k-1] := x;
        perm(k-1);
        x := a[i]; a[i] := a[k-1]; a[k-1] := x;
        i := i+1
      END
    END
  END perm;

BEGIN n := 0; ReadInt(m);
  WHILE ~eot() DO a[n] := m; n := n+1; ReadInt(m) END ;
  perm(n)
END Permutations.

OSP.Compile @  OSG.Decode
OSG.Execute 3

MODULE MagicSquares;   (*for Oberon-0 NW 25.1.2013*)

  PROCEDURE Generate;  (*magic square of order 3, 5, 7, ... *)
    VAR i, j, x, nx, nsq, n: INTEGER;
      M: ARRAY 13 OF ARRAY 13 OF INTEGER;
  BEGIN ReadInt(n);
      nsq := n*n; x := 0;
      i := n DIV 2; j := n-1;
      WHILE x < nsq DO
        nx := n + x; j := (j-1) MOD n; x := x+1; M[i][j] := x;
        WHILE x < nx DO
          i := (i+1) MOD n; j := (j+1) MOD n;
          x := x+1; M[i][j] := x
        END
      END ;
    i := 0;
    REPEAT j := 0;
      REPEAT WriteInt(M[i][j]); j := j+1 UNTIL j = n;
      WriteLn; i := i+1
    UNTIL i = n
  END Generate;

BEGIN Generate
END MagicSquares.

OSP.Compile @  OSG.Decode
OSG.Execute 20

MODULE PrimeNumbers;  (*NW 6.9.07; Tabulate prime numbers; for Oberon-07  NW 25.1.2013*)
  
  VAR n: INTEGER;
    p: ARRAY 400 OF INTEGER;
    v: ARRAY 20 OF INTEGER;

  PROCEDURE Primes(n: INTEGER);
    VAR i, k, m, x, inc, lim, sqr: INTEGER; prim: BOOLEAN;
  BEGIN x := 1; inc := 4; lim := 1; sqr := 4; m := 0; i := 3;
    WHILE i <= n DO
      REPEAT x := x + inc; inc := 6 - inc;
        IF sqr <= x THEN  (*sqr = p[lim]^2*)
          v[lim] := sqr; lim := lim + 1; sqr := p[lim]*p[lim]
        END ;
        k := 2; prim := TRUE;
        WHILE prim & (k < lim) DO
          k := k+1;
          IF v[k] < x THEN v[k] := v[k] + p[k] END ;
          prim := x # v[k]
        END
      UNTIL prim;
      p[i] := x; WriteInt(x);
      IF m = 10 THEN WriteLn; m := 0 ELSE m := m+1 END ;
      i := i+1
    END ;
    IF m > 0 THEN WriteLn END
  END Primes;

BEGIN ReadInt(n); WriteInt(n); WriteLn; Primes(n)
END PrimeNumbers.

OSP.Compile @  OSG.Decode
OSG.Execute 20

MODULE Fractions;  (*NW  10.10.07;  Tabulate fractions 1/n*)
  CONST Base = 10; N = 32;
  
  PROCEDURE Go;
    VAR i, j, m, n, r: INTEGER;
      d: ARRAY N OF INTEGER;  (*digits*)
      x: ARRAY N OF INTEGER;  (*index*)
  BEGIN ReadInt(n); i := 2;
      WHILE i <= n DO j := 0;
        WHILE j < i DO x[j] := 0; j := j+1 END ;
        m := 0; r := 1;
        WHILE x[r] = 0 DO
          x[r] := m; r := Base*r; d[m] := r DIV i; r := r MOD i; m := m+1
        END ;
        WriteInt(i); WriteChar(9); WriteChar("."); j := 0;
        WHILE j < x[r] DO WriteChar(d[j] + 48); j := j+1 END ;
        WriteChar("'");
        WHILE j < m DO WriteChar(d[j] + 48); j := j+1 END ;
        WriteLn; i := i+1
      END
  END Go;

BEGIN Go
END Fractions.

OSP.Compile @  OSG.Decode
OSG.Execute 32

MODULE Powers;  (*NW  25.1.2013 fo Oberon-07; Tabulate positive and negative powers of 2*)
  CONST N = 32; M = 11;  (*M ~ N*log2*)
  
  PROCEDURE Go;
    VAR i, k, n, exp: INTEGER;
      c, r, t: INTEGER;
      d: ARRAY M OF INTEGER;
      f: ARRAY N OF INTEGER;
  BEGIN ReadInt(n); d[0] := 1; k := 1; exp := 1;
      WHILE exp < n DO
        (*compute d = 2^exp*)
        c := 0;  (*carry*) i := 0;
        WHILE i < k DO
          t := 2*d[i] + c;
          IF t < 10 THEN d[i] := t; c := 0 ELSE d[i] := t - 10; c := 1 END ;
          i := i+1
        END ;
        IF c = 1 THEN d[k] := 1; k := k+1 END ;
        (*write d*) i := M;
        WHILE i > k DO i := i-1; WriteChar(" ") END ;
        WHILE i > 0 DO i := i-1; WriteChar(d[i] + 48) END ;
        WriteInt(exp);
        (*compute  f = 2^-exp*)
        WriteChar(9); WriteChar("0"); WriteChar(".");
        r := 0; i := 1;
        WHILE i < exp DO
          r := 10*r + f[i]; f[i] := r DIV 2; r := r MOD 2;
          WriteChar(f[i] + 48); i := i+1
        END ;
        f[exp] := 5; WriteChar("5"); WriteLn; exp := exp + 1
      END
  END Go;

BEGIN Go
END Powers.
