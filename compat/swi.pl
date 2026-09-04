:- use_module(library(dcg/basics)).
:- use_module(library(apply)).
:- set_prolog_flag(double_quotes, chars).

prolog_dialect(swi).

open_pipe(Name, Method, Stream, Options) :-
    open(Name, Method, Stream, [buffer(false),reposition(false)|Options]).
