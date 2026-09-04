?- import reverse/2, between/3, length/2 from basics.
?- import maplist/2, maplist/3, maplist/4, foldl/4 from swi.

open_pipe(Name, Method, Stream, Options) :-
    open(Name, Method, Stream, Options).
