:- initialization(testall(base2k)).

%% G(?Length, ?Digits, ?Int).
%
%  Wrappers for common chunk sizes, where G is one of `bits`, `crumbs`,
%  `nybbles`, `bytes` or `chomps`.
bits(   Length, Bits,   Int) :- pow2_digits_int( 1, Length, Bits,   Int).
crumbs( Length, Crumbs, Int) :- pow2_digits_int( 2, Length, Crumbs, Int).
nybbles(Length, Nibs,   Int) :- pow2_digits_int( 4, Length, Nibs,   Int).
bytes(  Length, Bytes,  Int) :- pow2_digits_int( 8, Length, Bytes,  Int).
chomps( Length, Chomps, Int) :- pow2_digits_int(16, Length, Chomps, Int).

%% pow2_required_digits(+K, +Integer, -R) is det.
%
% R is a minimal number of digits to represent Integer in base 2^K.
pow2_required_digits(K, Int, Int) :- K =:= 0.
pow2_required_digits(K, Int, R  ) :- K > 0, R is ceiling(log(abs(Int) + 1) / log(2) / K).

%% pow2_digits_int(?K, ?Length, ?Digits, ?Integer).
%
% Similar to pow2_digits_int/5, but uses big-endian.
pow2_digits_int(K, Length, Digits, Int) :-
    pow2_digits_int(big, K, Length, Digits, Int).

%% pow2_digits_int(?Endianness, ?K, ?Length, ?Digits, ?Integer).
%
% Length number of Digits are Endianness representation of unsigned Integer in 2^K-base.
%
% Digits must cover whole Integer, thus first solution is always a list with
% minimal number of digits to represent given Integer.
%
% If Integer is negative does 2's complement.
%
% TODO: I don't consider this predicate particularly good – its exact meaning is
%       somewhat shaky (with K=0 or with Int<0 or with LE mode which is not what
%       most people will think it is). Also it has too many arguments which
%       makes it difficult to test all possible combinations. Something more
%       elegant is needed.
%
%       I've briefly considered cyclic terms, but they aren't well suited to
%       represent padding, because it will work only for little-endian mode and
%       will fail with occurs-check.
%
%       I would like to have length somehow implicit; I have 4 different
%       implementations it would be nice to have single one and that check at the
%       very end isn't great.
pow2_digits_int(Endianness, K, Length, Digits, Int) :-
    (var(Length) -> L = Length; L is Length),
    base2k_integer(K),
    length(Digits, L),
    base2k_endianness_pow2_digits_int(Endianness, K, L, Digits, Int),
    % FIXME: I know its quite bizarre. It can be done more elegantly and using
    %        integer arithmetic only. The idea was to reject lists that don't
    %        contain all meaningful digits. With this rejection it is possible
    %        to distinguish padding from meaningful digits for base 2^0.
    %        It is quite a corner-case. Better semantics are welcome.
    pow2_required_digits(K, Int, R),
    L >= R.

base2k_endianness_pow2_digits_int(big, K, Length, Digits, Int) :-
    nonvar(Int) ->
        foldl(base2k_nonvar_be___(K,Int), Digits, Length-1, _)
    ;   foldl(base2k_var_be___(K), Digits, (0,Length-1), (Expression,_)),
        Int is Expression.
base2k_endianness_pow2_digits_int(little, K, Length, Digits, Int) :-
    nonvar(Int) ->
        foldl(base2k_nonvar_le___(K,Int), Digits, 0, _)
    ;   foldl(base2k_var_le___(K), Digits, (0,0), (Expression,Check)),
        Int is Expression, K*Length =:= Check.

base2k_nonvar_be___(K, Int, Digit, Exp, NextExp) :- Digit is (Int /\ ((2^K-1) << (Exp*K))) >> (Exp*K), NextExp is Exp - 1.
base2k_nonvar_le___(K, Int, Digit, Exp, NextExp) :- Digit is (Int /\ ((2^K-1) <<  Exp   )) >>  Exp   , NextExp is Exp + K.
base2k_var_le___(K, Digit, (A,Exp), (A+(Digit << (Exp*K)),(Exp+K))) :- Max is 2^K-1, between(0, Max, Digit).
base2k_var_be___(K, Digit, (E,L), (E+(Digit << (K*L)),L-1)).

base2k_integer(K) :- length(_, K).

t(base2k, true, ('Integer conforms with bytes (BE)' :-
    forall(base2k_test_bytes(M, I, BE, _), pow2_digits_int(big, 8, M, BE, I))
)).

t(base2k, true, ('Integer conforms with bytes (LE)' :-
    forall(base2k_test_bytes(M, I, _, LE), pow2_digits_int(little, 8, M, LE, I))
)).

t(base2k, true, ('Integer is decomposed into bytes (BE)' :-
    forall(
        base2k_test_bytes(M, I, BE, _),
        (
            pow2_digits_int(big, 8, N, D, I),
            D == BE,
            N == M
        )
    )
)).

t(base2k, true, ('Integer is decomposed into bytes (LE)' :-
    forall(
        base2k_test_bytes(M, I, _, LE),
        (
            pow2_digits_int(little, 8, N, D, I),
            D == LE,
            N == M
        )
    )
)).

t(base2k, true, ('Integer is decomposed into bytes with leading zeros (BE)' :-
    forall(
        base2k_test_bytes(M, I, BE, _),
        (
            pow2_digits_int(big, 8, M+2, D, I),
            D == [0x00,0x00|BE]
        )
    )
)).

t(base2k, true, ('Integer is decomposed into bytes with trailing zeros (LE)' :-
    forall(
        base2k_test_bytes(M, I, _, LE),
        (
            pow2_digits_int(little, 8, M+2, D, I),
            append(LE,[0x00,0x00],D)
        )
    )
)).

t(base2k, true, ('Integer is composed from bytes (BE)' :-
    forall(
        base2k_test_bytes(M, I, BE, _),
        (
            pow2_digits_int(big, 8, N, BE, J),
            J == I,
            N == M
        )
    )
)).

t(base2k, true, ('Integer is composed from bytes bytes with leading zeros (BE)' :-
    forall(
        base2k_test_bytes(M, I, BE, _),
        (
            pow2_digits_int(big, 8, N, [0x00,0x00,0x00|BE], J),
            J == I,
            N =:= M + 3
        )
    )
)).

t(base2k, true, ('Integer is decomposed into 16 bits (BE)' :-
    pow2_digits_int(big, 1, 16, D, 0xABCD),
    D == [1,0,1,0,1,0,1,1, 1,1,0,0,1,1,0,1]
)).

t(base2k, false, ('0xFA is not representable using 2 digits in unary numeral system' :-
    pow2_digits_int(_, 0, 2, _, 0xFA)
)).

t(base2k, true, ('The smallest number of digits to represent any number equals to that number (BE)' :-
    once(pow2_digits_int(big, 0, N, _, 0xFA)),
    N == 0xFA
)).

t(base2k, true, ('The smallest number of digits to represent any number equals to that number (LE)' :-
    once(pow2_digits_int(little, 0, N, _, 0xFA)),
    N == 0xFA
)).

t(base2k, error(domain_error(not_less_than_zero,-1)), ('Only accepts non-negative power of 2' :-
    pow2_digits_int(_, -1, _, _, _)
)).

t(base2k, true, ('It can be decided how many digits are needed in any 2^K base' :-
    forall(
        member(K-R, [
            0-299,
            1-9,
            8-2
        ]),
        (
            once(pow2_required_digits(K, 299, X)),
            X =:= R
        )
    )
)).

base2k_test_bytes(M, I, BE, LE) :-
    member(I-BE, [
        0x00-[],
        0x01-[0x01],
        0xFF-[0xFF],
        0x100-[0x01,0x00],
        0xFAAF-[0xFA,0xAF],
        0xABCDE-[0x0A,0xBC,0xDE],
        0x0123456789ABCDEF-[0x01,0x23,0x45,0x67,0x89,0xAB,0xCD,0xEF]
    ]),
    length(BE, M),
    reverse(BE, LE).
