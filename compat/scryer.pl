:- use_module(library(lists)).
:- use_module(library(dcgs)).
:- use_module(library(between)).
:- use_module(library(iso_ext)).
:- use_module(library(when)).

prolog_dialect(scryer).

open_pipe(Name, Method, Stream, Options) :-
    open(Name, Method, Stream, Options).
