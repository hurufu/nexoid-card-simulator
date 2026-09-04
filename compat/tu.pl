%% forall(Generate, Test).
%
% For all bindings possible by Generate, Test must be true.
%
% In this example, it checks that all numbers are even:
%
% ```
% ?- Ns = [2,4,6], forall(member(N, Ns), 0 is N mod 2).
%    Ns = [2,4,6].
% ```
:- meta_predicate(forall(0,0)).
forall(Generate, Test) :-
    \+ (Generate, \+ Test).

:- meta_predicate(call_cleanup(0,0)).
call_cleanup(G_0, C_0) :- catch(call_cleanup_aux(G_0,C_0), E, call_throw(C_0,E)).

:- meta_predicate(call_cleanup_aux(0,0)).
call_cleanup_aux(G_0, _) :- call(G_0).
call_cleanup_aux(_, C_0) :- call(C_0).

:- meta_predicate(call_throw(0,?)).
call_throw(C_0, E) :- call(C_0), !, throw(E).
call_throw(_, E) :- throw(E).

length(List, N) :- length(List, 0, N).
length([_|T], C, N) :-
    C < N,
    C1 is C + 1,
    length(T, C1, N).
length([], N, N).

:- meta_predicate(phrase(2,?)).
phrase(G__0, L) :- phrase(G__0, L, []).

:- meta_predicate(phrase(2,?,?)).
phrase(G__0, _, _) :-
    throw(error(dcgs_arent_supported(G__0),_)).

:- meta_predicate(maplist(1,?)).
:- meta_predicate(maplist(2,?,?)).
:- meta_predicate(maplist(3,?,?,?)).
maplist(_, []).
maplist(G_1, [H|T]) :- call(G_1, H), maplist(G_1, T).

maplist(_, [], []).
maplist(G_1, [H1|T1], [H2|T2]) :- call(G_1, H1, H2), maplist(G_1, T1, T2).

maplist(_, [], [], []).
maplist(G_1, [H1|T1], [H2|T2], [H3|T3]) :- call(G_1, H1, H2, H3), maplist(G_1, T1, T2, T3).

:- meta_predicate(foldl(3,?,?,?)).
foldl(_, [], V, V).
foldl(G_3, [H1|T1], V0, Vlast) :-
    call(G_3, H1, V0, Vnext),
    foldl(G_3, T1, Vnext, Vlast).

:- meta_predicate(call_list(0,?)).
call_list(G_N, As) :-
    G_N =.. [F|Rest],
    append(Rest, As, Args),
    G_0 =.. [F|Args],
    call(G_0).

:- meta_predicate(call(1,?)).
:- meta_predicate(call(2,?,?)).
:- meta_predicate(call(3,?,?,?)).
:- meta_predicate(call(4,?,?,?,?)).
:- meta_predicate(call(5,?,?,?,?,?)).
call(G_1, A1) :- call_list(G_1, [A1]).
call(G_2, A1, A2) :- call_list(G_2, [A1,A2]).
call(G_3, A1, A2, A3) :- call_list(G_3, [A1,A2,A3]).
call(G_4, A1, A2, A3, A4) :- call_list(G_4, [A1,A2,A3,A4]).
call(G_5, A1, A2, A3, A4, A5) :- call_list(G_5, [A1,A2,A3,A4,A5]).

:- meta_predicate(setup_call_cleanup(0,0,0)).
setup_call_cleanup(S_0, G_0, C_0) :- S_0 -> call_cleanup(G_0, C_0).
