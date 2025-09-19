open_pipe(Name, Method, Stream, Options) :-
    open(Name, Method, Stream, [type(binary),buffering(none)|Options]).

foldl(_, [], _, _).
foldl(G_3, [H1|T1], V0, Vlast) :-
    call(G_3, H1, V0, Vnext),
    foldl(G_3, T1, Vnext, Vlast).
