:- op(950, fy, *).

:- meta_predicate(*(0)).
*(_).

:- meta_predicate(w(0)).
w(G_0) :- writeln(-G_0), call(G_0), writeln(+G_0).
