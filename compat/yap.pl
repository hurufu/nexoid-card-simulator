:- use_module(library(lists)).

open_pipe(Name, Method, Stream, Options) :-
    open(Name, Method, Stream, [reposition(false)|Options]).
