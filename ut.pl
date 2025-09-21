test :- forall(clause(test(N), _), (skip_test(N) -> true; test(N))).
fails(F) :- findall(N, (clause(test(N), _), \+test(N)), F).

:- dynamic(skip_test/1).
skip_test(apdu(1)).

:- dynamic(test/1).
test(lc(1)) :- phrase(lc(Qc), []) -> Qc == absent.
test(lc(2)) :- phrase(lc(Qc), [+0], B) -> Qc == absent, B == [+0].
test(lc(3)) :- phrase(lc(Qc), [+5]) -> Qc == present(short,5).
test(lc(4)) :- phrase(lc(Qc), [+0,+1,+0]) -> Qc == present(extended,256).
test(lc(5)) :- \+ phrase(lc(_), [+0,+0,+0]).
test(lc(6)) :- findall(t, phrase(lc(absent), _), L), length(L, 1).
test(lc(7)) :- findall(t, phrase(lc(present(short,_)), _), L), length(L, 255).
test(lc(8)) :- findall(t, phrase(lc(present(extended,_)), _), L), length(L, 65535).
test(nbytes(1)) :- T = [1|T] -> \+ phrase(nbytes(T, _), _); true.
test(nbytes(2)) :- phrase(nbytes(X,5), Y) -> X = [A,B,C,D,E], Y = [+A,+B,+C,+D,+E].
test(nbytes(3)) :- phrase(nbytes(X,N), [+1,+2,+3]) -> N == 3, X == [1,2,3].
test(nbytes(4)) :- W=[_|W] -> \+ phrase(nbytes(W,_), W); true.
test(nbytes(5)) :- phrase(nbytes([1,2,3], N), W) -> W == [+1,+2,+3], N == 3.
test(nbytes(6)) :- phrase(nbytes(W, 3), W) -> \+ acyclic_term(W), length(W, 3).
test(nbytes(7)) :- catch(phrase(nbytes(_, a), _), error(E,_), true) -> E == type_error(evaluable,a/0).
test(nbytes(8)) :- catch(phrase(nbytes(_, a(_)), _), error(E,_), true) -> (E == instantiation_error; E == type_error(evaluable,a/1)).
test(cm(1)) :- cm(0x00, 0xA4, 0x04, 0x00, Qc, Qe, C) -> Qc = present(_,_), Qe = present(_,_), C == select(aid_prefix,first,fci).
test(cm(2)) :- cm(0x80, 0xA8, 0x00, 0x00, Qc, Qe, C) -> Qc = present(_,_), Qe = present(_,_), C == get_processing_options.
test(cm(3)) :- cm(0x00, 0xB2, 0x01, 0x14, Qc, Qe, C) -> Qc == absent, Qe = present(_,_), C == read_record(2,record_number(exact,1)).
test(cm(4)) :- cm(0x00, 0xB2, 0x02, 0x1C, Qc, Qe, C) -> Qc == absent, Qe = present(_,_), C == read_record(3,record_number(exact,2)).
test(bits(1)) :- bits(8, [1,0,0,0,0,0,0,0], 0x80).
test(bits(2)) :- bits(L, [1,0,0,0,0,0,0,0], 0x80) -> L == 8.
test(bits(3)) :- bits(8, [1,0,0,0,0,0,0,0], N) -> N == 0x80.
test(bits(4)) :- bits(8, Bits, 0x81) -> Bits == [1,0,0,0,0,0,0,1].
test(ber(1)) :-
    Fci = [111-[132-[50,80,65,89,46,83,89,83,46,68,68,70,48,49],165-[48908-[97-
    [79-[160,0,0,1,82,48,16],80-[67,111,110,116,97,99,116,108,101,115,115,68,80,
    65,83],135-[1],40746-[0,6]],97-[79-[160,0,0,3,36,16,16,1],80-[68,105,115,99,
    111,118,101,114],135-[2]]]]]],
    phrase(ber(Fci,L), E),
    maplist(is, Encoded, E) ->
    84 =:= L,
    Encoded == [111,82,132,14,50,80,65,89,46,83,89,83,46,68,68,70,48,49,165,64,
    191,12,61,97,34,79,7,160,0,0,1,82,48,16,80,15,67,111,110,116,97,99,116,108,
    101,115,115,68,80,65,83,135,1,1,159,42,2,0,6,97,23,79,8,160,0,0,3,36,16,16,
    1,80,8,68,105,115,99,111,118,101,114,135,1,2].
test(apdu(1)) :-
    Input = [+0x00,+0xA4,+0x04,+0x00,+0x0E,+0x32,+0x50,+0x41,+0x59,+0x2E,+0x53,
    +0x59,+0x53,+0x2E,+0x44,+0x44,+0x46,+0x30,+0x31,+0x00],
    phrase(command_response_pair, Input, Output) ->
    Output == [-(111),-(82),-(132),-(14),-(50),-(80),-(65),-(89),-(46),-(83),
    -(89),-(83),-(46),-(68),-(68),-(70),-(48),-(49),-(165),-(64),-(191),-(12),
    -(61),-(97),-(34),-(79),-(7),-(160),-(0),-(0),-(1),-(82),-(48),-(16),-(80),
    -(15),-(67),-(111),-(110),-(116),-(97),-(99),-(116),-(108),-(101),-(115),
    -(115),-(68),-(80),-(65),-(83),-(135),-(1),-(1),-(159),-(42),-(2),-(0),-(6),
    -(97),-(23),-(79),-(8),-(160),-(0),-(0),-(3),-(36),-(16),-(16),-(1),-(80),
    -(8),-(68),-(105),-(115),-(99),-(111),-(118),-(101),-(114),-(135),-(1),-(2),
    -(144),-(0)].
