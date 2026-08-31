:- initialization(testall(misc)).

%% G(?Length, ?Digits, ?Int).
%
%  Wrappers for common chunk sizes, where G is one of `bits`, `crumbs`,
%  `nybbles`, `bytes` or `chomps`.
bits(   Length, Bits,   Int) :- int_base2k( 1, Length, Bits,   Int).
crumbs( Length, Crumbs, Int) :- int_base2k( 2, Length, Crumbs, Int).
nybbles(Length, Nibs,   Int) :- int_base2k( 4, Length, Nibs,   Int).
bytes(  Length, Bytes,  Int) :- int_base2k( 8, Length, Bytes,  Int).
chomps( Length, Chomps, Int) :- int_base2k(16, Length, Chomps, Int).

%% int_base2k(?K, ?Length, ?Digits, ?Integer).
%
% Similar to int_base2k/5, but uses big-endian.
int_base2k(K, Length, Digits, Int) :-
    int_base2k(big, K, Length, Digits, Int).

%% int_base2k(?Endianness, ?K, ?Length, ?Digits, ?Integer).
%
% Length number of Digits are Endianness representation of unsigned Integer in 2^K-base.
int_base2k(Endianness, K, Length, Digits, Int) :-
    (var(Length) -> L = Length; L is Length),
    between(1, 16, K),
    length(Digits, L),
    misc_endianness_base2k_int_len_digits(Endianness, K, L, Digits, Int).

misc_endianness_base2k_int_len_digits(big, K, Length, Digits, Int) :-
    nonvar(Int) ->
        foldl(misc_nonvar_be___(K,Int), Digits, Length-1, _)
    ;   foldl(misc_var_be___(K), Digits, (0,Length-1), (Expression,_)),
        Int is Expression.
misc_endianness_base2k_int_len_digits(little, K, Length, Digits, Int) :-
    nonvar(Int) ->
        foldl(misc_nonvar_le___(K,Int), Digits, 0, _)
    ;   foldl(misc_var_le___(K), Digits, (0,0), (Expression,Check)),
        Int is Expression, K*Length =:= Check.

misc_nonvar_be___(K, Int, Digit, Exp, NextExp) :- Digit is (Int /\ ((2^K-1) << (Exp*K))) >> (Exp*K), NextExp is Exp - 1.
misc_nonvar_le___(K, Int, Digit, Exp, NextExp) :- Digit is (Int /\ ((2^K-1) <<  Exp   )) >>  Exp   , NextExp is Exp + K.
misc_var_le___(K, Digit, (A,Exp), (A+(Digit << (Exp*K)),(Exp+K))) :- Max is 2^K-1, between(0, Max, Digit).
misc_var_be___(K, Digit, (E,L), (E+(Digit << (K*L)),L-1)).


t(misc, true, ('Integer conforms with bytes (BE)' :-
    forall(misc_test_bytes(M, I, BE, _), int_base2k(big, 8, M, BE, I))
)).

t(misc, true, ('Integer conforms with bytes (LE)' :-
    forall(misc_test_bytes(M, I, _, LE), int_base2k(little, 8, M, LE, I))
)).

t(misc, true, ('Integer is decomposed into bytes (BE)' :-
    forall(
        misc_test_bytes(M, I, BE, _),
        (
            int_base2k(big, 8, N, D, I),
            D == BE,
            N == M
        )
    )
)).

t(misc, true, ('Integer is decomposed into bytes (LE)' :-
    forall(
        misc_test_bytes(M, I, _, LE),
        (
            int_base2k(little, 8, N, D, I),
            D == LE,
            N == M
        )
    )
)).

t(misc, true, ('Integer is decomposed into bytes with leading zeros (BE)' :-
    forall(
        misc_test_bytes(M, I, BE, _),
        (
            int_base2k(big, 8, M+2, D, I),
            D == [0x00,0x00|BE]
        )
    )
)).

t(misc, true, ('Integer is decomposed into bytes with trailing zeros (LE)' :-
    forall(
        misc_test_bytes(M, I, _, LE),
        (
            int_base2k(little, 8, M+2, D, I),
            append(LE,[0x00,0x00],D)
        )
    )
)).

t(misc, true, ('Integer is composed from bytes (BE)' :-
    forall(
        misc_test_bytes(M, I, BE, _),
        (
            int_base2k(big, 8, N, BE, J),
            J == I,
            N == M
        )
    )
)).

t(misc, true, ('Integer is composed from bytes bytes with leading zeros (BE)' :-
    forall(
        misc_test_bytes(M, I, BE, _),
        (
            int_base2k(big, 8, N, [0x00,0x00,0x00|BE], J),
            J == I,
            N =:= M + 3
        )
    )
)).

t(misc, true, ('Integer is decomposed into 16 bits (BE)' :-
    int_base2k(big, 1, 16, D, 0xABCD),
    D == [1,0,1,0,1,0,1,1, 1,1,0,0,1,1,0,1]
)).

misc_test_bytes(M, I, BE, LE) :-
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
