run :- run("card.bin", "card2.bin", []).
run(Read, Write, Options) :-
    main(Read, Write, X-[], Options),
    maplist(format_hex, X), nl.

format_hex(E) :- format("~16R", [E]).

main(Read, Write, X, Options) :-
    foldl(nesting, [
        open_call_close(write, Write, [type(binary),alias(wr)|Options]),
        open_call_close(read, Read, [type(binary),alias(rd)|Options])],
        fixpoint(exchange,X), S),
    S.

nesting(E_1, E_0, call(E_1, E_0)).

exchange(R-WCont) :-
    phrase(command(Cla,Ins,P1,P2,Dt,Le), R, RCont),
    once((
        response_for(Cla, Ins, P1, P2, Dt, Le, Rs, Sw1, Sw2)
    ;   throw(error(no_response_for(R,_))))),
    phrase(response(Rs,Sw1,Sw2), RCont, WCont).

fixpoint(G_2, A-Az) :- call(G_2, A-Ac) -> fixpoint(G_2, Ac-Az); A = Az.

command(Cla,Ins,P1,P2,Dt,Le) -->
    dt([Cla,Ins,P1,P2,Lc]), { length(Dt, Lc) }, dt(Dt), dt([Le]).
response(Dt,Sw1,Sw2) --> dd(Dt), dd([Sw1,Sw2]).

dt(Codes) --> { maplist(good_io(get_byte(rd)), Codes) }, Codes.
dd(Codes) --> { maplist(good_io(put_byte(wr)), Codes) }, Codes.

:- meta_predicate(good_io(1,?)).
good_io(G_1, Code) :- call(G_1, Code), Code >= 0.

response_for(0x00, 0xA4, 0x04, 0x00, Dt, 0x00, Rs, 0x90, 0x00) :-
    Dt = [50,80,65,89,46,83,89,83,46,68,68,70,48,49], % 2PAY.SYS.DDF01
    Rs = [111,45,132,14,50,80,65,89,46,83,89,83,46,68,68,70,48,49,165,27,191,12,24,97,22,79,7,160,0,0,0,3,16,16,80,11,86,73,83,65,32,67,82,69,68,73,84].
response_for(0x00, 0xA4, 0x04, 0x00, Dt, 0x00, Rs, 0x90, 0x00) :-
    Dt = [160,0,0,0,3,16,16], % A0000000031010
    Rs = [111,50,132,7,160,0,0,0,3,16,16,165,39,80,11,86,73,83,65,32,67,82,69,68,73,84,159,56,12,159,102,4,159,2,6,95,42,2,159,55,4,191,12,8,159,90,5,0,8,64,8,64].
response_for(0x80, 0xA8, 0x00, 0x00, Dt, 0x00, Rs, 0x90, 0x00) :-
    Dt = [131,16,54,_,64,0,0,0,0,0,_,_,_,_,_,_,_,_],
    Rs = [119,61,87,16,71,97,115,144,1,1,1,25,210,65,34,1,23,88,148,114,130,2,0,0,95,52,1,1,159,16,7,6,1,17,3,160,0,0,159,38,8,19,201,29,101,169,16,201,86,159,39,1,128,159,54,2,0,2,159,108,2,128,0].

:- meta_predicate(open_call_close(?,?,?,0)).
open_call_close(Method, File, Options, G_0) :-
    setup_call_cleanup(open(File, Method, Stream, Options), G_0, close(Stream)).
