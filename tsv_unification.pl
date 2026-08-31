%% tru(A, B).
%
% Special unification of tag-spec-value terms. It ignores leaf order with the
% same prefix. It has a special provisions for open lists, so it can be
% used to merge terms if they are open.
tru(tsv(A,element(B,C),V), tsv(A,element(B,C),V)).
tru(tsv(A,template,VL), tsv(A,template,VR)) :- trul(VL, VR).

%% trul(A, B).
%
% Special unification of a (possibly open) list of tag-spec-value terms.
trul(L, R) :- var(L), var(R) -> true; L = R, L = [].
trul([HL|TL], [HR|TR]) :- tru(HL, HR), trul(TL, TR).
trul([HL|TL], [HR|TR]) :- \+ tru(HL, HR), trux(TR, HL), trux(TL, HR).

%% trux(List, Element).
%
% Element membership using special unification within open List of t-s-v terms.
trux([H|_], X) :- tru(H, X).
trux([H|T], X) :- \+ tru(H, X), trux(T, X).


test_tru :- findall(N, test_tru(N), P), maplist(writeln, P).

test_tru(test_reflexivity(N)) :-
    nth1(N, [
        _,
        tsv(111,template,[]),
        tsv(111,element(_,_),[])
    ], X),
    (tru(X, X) -> true).
test_tru(test_symmetry(N)) :-
    nth1(N, [
        [
            tsv(0,template,[]),
            tsv(0,template,[])
        ]
    ], [L,R]),
    (tru(L, R) -> tru(R, L)).
test_tru(test_transitivity(N)) :-
    nth1(N, [
        [
            tsv(0,template,[]),
            tsv(0,template,[]),
            tsv(0,template,[])
        ]
    ], [A,B,C]),
    (tru(A, B), tru(B, C) -> tru(A, C)).
test_tru( 4) :- E = tsv(33,element(_,_),[]), tru(X, E), X == E.
test_tru(-4) :- E = tsv(33,element(_,_),[]), tru(E, X), X == E.
test_tru( 5) :- \+ tru(tsv(1,element(_,_),_), tsv(2,_,_)).
test_tru(-5) :- \+ tru(tsv(2,_,_), tsv(1,element(_,_),_)).
test_tru( 6) :-
    A = tsv(1,template,_),
    B = tsv(1,template,[tsv(33,element(_,_),_)]),
    tru(A, B),
    A == B.
test_tru( 7) :-
    L = tsv(1,template,[tsv(34,element(BL,CL),VL)|RL]),
    R = tsv(1,template,[tsv(33,element(BR,CR),VR)|RR]),
    tru(L, R),
    RL = [tsv(33,element(BR,CR),VR)|RRL],
    RR = [tsv(34,element(BL,CL),VL)|RRR],
    var(RRL),
    var(RRR),
    RRL \== RRR.
test_tru( 8) :-
    EL = tsv(99,element(_,_),_),
    ER = tsv(98,element(_,_),_),
    L = tsv(1,template,[tsv(2,template,[EL|_R1L])|_R2L]),
    R = tsv(1,template,[tsv(2,template,[ER|_R1R])|_R2R]),
    once(tru(L, R)).
