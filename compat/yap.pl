:- use_module(library(lists)).

prolog_dialect(yap).

open_pipe(Name, Method, Stream, Options) :-
    open(Name, Method, Stream, [reposition(false)|Options]).
