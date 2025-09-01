:- initialization(grun).

grun :- run('in.fifo', 'out.fifo', [buffering(none)]).

%:- meta_predicate(foldl(3,?,?,?)).
foldl(_, [], V0, V0).
foldl(G_3, [Curr|T], Prev, Last) :-
    call(G_3, Curr, Prev, Next),
    foldl(G_3, T, Next, Last).

:- meta_predicate(setup_call_cleanup(0,0,0)).
setup_call_cleanup(S_0, G_0, C_0) :-
    S_0 -> (catch(G_0, E, true), (nonvar(E) -> C_0, throw(E); true); C_0).
