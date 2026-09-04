%% Peano arithmetic library.
%
% The idea is to use it for simple constraint satisfaction problems on systems
% that lack CLP(ℤ) library.
%
% Currently isn't used.

eq(nat, 0).
eq(nat, s(N)) :- eq(nat, N).
eq(int(N), S) :- suc_number(S, N).

eq(succ, N, s(N)).
eq(pow(2), 0, s(0)).
eq(pow(2), s(N), Z) :-
    eq(pow(2), N, T),
    eq(mul, s(s(0)), T, Z).

eq(cmp(lt), 0, s(_)).
eq(cmp(lt), s(X), s(Y)) :- eq(cmp(lt), X, Y).
eq(cmp(le), 0, _).
eq(cmp(le), s(X), s(Y)) :- eq(cmp(le), X, Y).
eq(cmp(gt), A, B) :- eq(cmp(le), B, A).
eq(cmp(ge), A, B) :- eq(cmp(lt), B, A).
eq(min, X, Y, X) :- eq(cmp(le), X, Y).
eq(min, X, Y, Y) :- eq(cmp(lt), Y, X).
eq(max, X, Y, Y) :- eq(cmp(le), X, Y).
eq(max, X, Y, X) :- eq(cmp(lt), Y, X).

eq(sum, 0, B, B).
eq(sum, s(N), B, s(C)) :- eq(sum, N, B, C).

eq(mul, 0, _, 0).
eq(mul, s(X), Y, Z) :-
    eq(mul, X, Y, T),
    eq(sum, Y, T, Z).

eq(pow, _, 0, s(0)).
eq(pow, Base, s(N), Result) :-
    eq(pow, Base, N, T),
    eq(mul, Base, T, Result).


suc_expr(0, 0).
suc_expr(s(X), N+1) :- suc_var(X, N).
suc_var(S, V) :- suc_expr(S, E), V is E.
suc_int(0, I) :- I =:= 0.
suc_int(s(X), I) :- I > 0, J is I - 1, suc_int(X, J).
suc_number(S, N) :- var(N) -> suc_var(S, N); suc_int(S, N).
