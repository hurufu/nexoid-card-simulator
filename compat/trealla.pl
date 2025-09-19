:- use_module(library(dcgs)).

open_pipe(Name, Method, Stream, Options) :-
    open(Name, Method, Stream, Options).
