OSP.Compile @
TestOberon0.Permutations 2 3 4~
TestOberon0.MagicSquares  3~.
TestOberon0.PrimeNumbers 12
TestOberon0.Fractions 16
TestOberon0.Powers 16

MODULE TestOberon0;
  VAR n: INTEGER;
    a: ARRAY 10 OF INTEGER;

  PROCEDURE perm(k: INTEGER);
    VAR i, x: INTEGER;
  BEGIN
    IF k = 0 THEN i := 0;
      WHILE i < n DO WriteInt(a[i], 5); i := i+1 END ;
      WriteLn;
    ELSE perm(k-1); i := 0;
      WHILE i < k-1 DO
        x := a[i]; a[i] := a[k-1]; a[k-1] := x;
        perm(k-1);
        x := a[i]; a[i] := a[k-1]; a[k-1] := x;
        i := i+1
      END
    END
  END perm;

  PROCEDURE Permutations*;
  BEGIN OpenInput; n := 0;
    WHILE ~eot() DO ReadInt(a[n]); n := n+1 END ;
    perm(n)
  END Permutations;

  PROCEDURE MagicSquares*;  (*magic square of order 3, 5, 7, ... *)
    VAR i, j, x, nx, nsq, n: INTEGER;
      M: ARRAY 13 OF ARRAY 13 OF INTEGER;
  BEGIN OpenInput;
    IF ~eot() THEN
      ReadInt(n); nsq := n*n; x := 0;
      i := n DIV 2; j := n-1;
      WHILE x < nsq DO
        nx := n + x; j := (j-1) MOD n; x := x+1; M[i][j] := x;
        WHILE x < nx DO
          i := (i+1) MOD n; j := (j+1) MOD n;
          x := x+1; M[i][j] := x
        END
      END ;
      i := 0;
      WHILE i < n DO
        j := 0;
        WHILE j < n DO WriteInt(M[i][j], 6); j := j+1 END ;
        i := i+1; WriteLn
      END
    END
  END MagicSquares;

  PROCEDURE PrimeNumbers*;
    VAR i, k, m, x, inc, lim, sqr: INTEGER; prim: BOOLEAN;
      p: ARRAY 400 OF INTEGER;
      v: ARRAY 20 OF INTEGER;
  BEGIN OpenInput; ReadInt(n);
    x := 1; inc := 4; lim := 1; sqr := 4; m := 0; i := 3;
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
      p[i] := x; WriteInt(x, 5); i := i+1;
      IF m = 10 THEN WriteLn; m := 0 ELSE m := m+1 END
    END ;
    IF m > 0 THEN WriteLn END
  END PrimeNumbers;

  PROCEDURE Fractions*;  (* Tabulate fractions 1/n*)
    CONST Base = 10; N = 32;
    VAR i, j, m, r, n: INTEGER;
      d: ARRAY N OF INTEGER;  (*digits*)
      x: ARRAY N OF INTEGER;  (*index*)
  BEGIN OpenInput;
    IF ~eot() THEN
      ReadInt(n); i := 2;
      WHILE i <= n DO j := 0;
        WHILE j < i DO x[j] := 0; j := j+1 END ;
        m := 0; r := 1;
        WHILE x[r] = 0 DO
          x[r] := m; r := Base*r; d[m] := r DIV i; r := r MOD i; m := m+1
        END ;
        WriteInt(i, 5); WriteChar(9); WriteChar(46); j := 0;
        WHILE j < x[r] DO WriteChar(d[j] + 48); j := j+1 END ;
        WriteChar(32);  (*blank*)
        WHILE j < m DO WriteChar(d[j] + 48); j := j+1 END ;
        WriteLn; i := i+1
      END
    END
  END Fractions;

  PROCEDURE Powers*;
    CONST N = 32; M = 11;  (*M ~ N*log2*)
    VAR i, k, n, exp: INTEGER;
      c, r, t: INTEGER;
      d: ARRAY M OF INTEGER;
      f: ARRAY N OF INTEGER;
  BEGIN OpenInput;
    IF ~eot() THEN
      ReadInt(n); d[0] := 1; k := 1; exp := 1;
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
        WHILE i > k DO i := i-1; WriteChar(32) (*blank*) END ;
        WHILE i > 0 DO i := i-1; WriteChar(d[i] + 48) END ;
        WriteInt(exp, M);
        (*compute  f = 2^-exp*)
        WriteChar(9);; WriteChar(46); r := 0; i := 1;
        WHILE i < exp DO
          r := 10*r + f[i]; f[i] := r DIV 2; r := r MOD 2;
          WriteChar(f[i] + 48); i := i+1
        END ;
        f[exp] := 5; WriteChar(53); (*5*) WriteLn; exp := exp + 1
      END
    END
  END Powers;

END TestOberon0.
