:- initialization(open('in.fifo',  read,  _, [type(binary),buffering(none),alias(rd),eof_action(eof_code)])).
:- initialization(open('out.fifo', write, _, [type(binary),buffering(none),alias(wr),eof_action(error)])).

foldl(_, [], _, _).
foldl(G_3, [H1|T1], V0, Vlast) :-
    call(G_3, H1, V0, Vnext),
    foldl(G_3, T1, Vnext, Vlast).
