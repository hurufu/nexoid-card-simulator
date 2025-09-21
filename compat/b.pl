:- mode
    maplist(+, ?),
    maplist(+, ?, ?),
    maplist(+, ?, ?, ?),
    foldl(+, ?, +, ?),
    open_pipe(+, +, ?, +).

maplist(_, []).
maplist(G_1, [H|T]) :- call(G_1, H), maplist(G_1, T).

maplist(_, [], []).
maplist(G_1, [H1|T1], [H2|T2]) :- call(G_1, H1, H2), maplist(G_1, T1, T2).

maplist(_, [], [], []).
maplist(G_1, [H1|T1], [H2|T2], [H3|T3]) :- call(G_1, H1, H2, H3), maplist(G_1, T1, T2, T3).

foldl(_, [], V, V).
foldl(G_3, [H1|T1], V0, Vlast) :-
    call(G_3, H1, V0, Vnext),
    foldl(G_3, T1, Vnext, Vlast).

open_pipe(Name, Method, Stream, Options) :-
    open(Name, Method, Stream, Options).
