:- initialization(test).

test :- findall(N, clause(test(N),_), Ns), maplist(test, Ns).

:- dynamic(test/1).
test(1) :- phrase(lc(Tc,Nc), []) -> Tc == absent, Nc == 0.
test(2) :- phrase(lc(Tc,Nc), [+0], B) -> Tc == absent, Nc == 0, B == [+0].
test(3) :- phrase(lc(Tc,Nc), [+5]) -> Tc == present(short), Nc == 5.
test(4) :- phrase(lc(Tc,Nc), [+0,+1,+0]) -> Tc == present(extended), Nc == 256.
test(5) :- \+ phrase(lc(_,_), [+0,+0,+0]).
test(6) :- cla_meaning(0x00, Class, ClaMeaning) -> Class == interindustry, ClaMeaning == [default,complete,none].
test(7) :- header_meaning(0x00, 0xA4, 0x04, 0x00, Tc, I) ->
    Tc = present(_),
    I = command(cla(interindustry, [default, complete, none]), ins(select, aid_prefix(_), first, fci)).
