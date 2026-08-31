% EMV-flavor of BER parser/serializer
%

:- initialization(testall(eber)).

ber(K, tsv(T,S,V), TL+LL+VL) --> tag(S, K, T, TL), len(VL, LL), value(S, K, V, VL).
tag(S, K, T, TL) --> { between(1, 4, TL) }, length__(Bs, TL), { bytes(TL, Bs, T), once(tag_spec_db(T, K, S, _)) }.
len(VL, 1) --> [X], { when((nonvar(X);nonvar(VL)), (nonvar(X) -> VL is X; X is VL)) }.
value(element(_,C), _K, V, VL) --> { value_between(C, VL) }, length__(V, VL).
value(template, K, V, VL) --> value_template(V, VL, K).
value_template([], 0, _) --> [].
value_template([H|T], VL, K) --> ber(K, H, HL), value_template(T, TL, K), { var(VL) -> VL = HL + TL; VL =:= HL + TL }.

value_between(constraint(byte,L,U), VL) :- between(L, U, VL).
value_between(constraint(bcd,L,U), VL) :- between(L, U, X), VL is ceiling(X/2).

spec_alphabet(ans, N) :- spec_alphabet(an, N); alphabet(ascii(other), N).
spec_alphabet(an,  N) :- spec_alphabet(a, N); alphabet(ascii(digit), N).
spec_alphabet(a,   N) :- alphabet(ascii(lower), N); alphabet(ascii(upper), N).

alphabet(ascii(digit), N) :- between(0x30, 0x39, N).
alphabet(ascii(upper), N) :- between(0x41, 0x5A, N).
alphabet(ascii(lower), N) :- between(0x61, 0x7A, N).
alphabet(ascii(other), N) :-
    between(0x20, 0x2F, N)
;   between(0x3A, 0x40, N)
;   between(0x5B, 0x60, N)
;   between(0x7B, 0x7E, N).


t(eber, true, ('There exist only single BER serialization' :-
    findall(0, ber_test(_,_,_), [_])
)).

ber_test(S, L1, R1) :-
    R1 = [
        0x77,0x3d,0x57,0x10,0x47,0x61,0x73,0x90,
        0x01,0x01,0x01,0x19,0xd2,0x41,0x22,0x01,
        0x17,0x58,0x94,0x72,0x82,0x02,0x00,0x00,
        0x5f,0x34,0x01,0x01,0x9f,0x10,0x07,0x06,
        0x01,0x11,0x03,0xa0,0x00,0x00,0x9f,0x26,
        0x08,0x13,0xc9,0x1d,0x65,0xa9,0x10,0xc9,
        0x56,0x9f,0x27,0x01,0x80,0x9f,0x36,0x02,
        0x00,0x02,0x9f,0x6c,0x02,0x80,0x00
    ],
    phrase(ber(3,S,L1), R1),
    phrase(ber(3,S,L2), R2),
    L1 =:= L2,
    R1 == R2.
