:- use_module(library(dcgs)).

prolog_dialect(trealla).

open_pipe(Name, Method, Stream, Options) :-
    open(Name, Method, Stream, [bom(false),reposition(false)|Options]).
