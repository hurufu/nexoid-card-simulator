:- meta_predicate(i(0)).
:- meta_predicate(i(1,?)).
:- meta_predicate(i(2,?,?)).

i(_).
i(_, _).
i(_, _, _).

:- meta_predicate(w(0)).
:- meta_predicate(w(1,?)).
:- meta_predicate(w(2,?,?)).

w(G_0) :-
    setup_call_cleanup(write_in(G_0), (call(G_0),write_ok(G_0)), write_fi(G_0)).
w(G_1, A) :-
    setup_call_cleanup(write_in(A^G_1), (call(G_1,A),write_ok(A^G_1)), write_fi(A^G_1)).
w(G_2, A, B) :-
    setup_call_cleanup(write_in(A^B^G_2), (call(G_2,A,B),write_ok(A^B^G_2)), write_fi(A^B^G_2)).

write_in(T) :- write(-T), nl.
write_ok(T) :- write(+T), nl.
write_fi(T) :- write(\T), nl.

format_hex_list(L) :- format_hex_list(user_output, L).
format_hex_list(Stream, L) :- maplist(format_hex_(Stream), L).
format_hex_(Stream, I) :- format(Stream, '~|~`0t~16R~2+', [I]).
