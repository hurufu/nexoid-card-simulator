open_pipe(Name, Method, Stream, Options) :-
    open(Name, Method, Stream, [buffer(false),reposition(false)|Options]).
