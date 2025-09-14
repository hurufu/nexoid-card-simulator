:- initialization(test).

test :- findall(N, clause(test(N),_), Ns), maplist(test, Ns).

:- dynamic(test/1).
test(1) :- phrase(lc(Tc,Nc), []) -> Tc == absent, Nc == 0.
test(2) :- phrase(lc(Tc,Nc), [+0], B) -> Tc == absent, Nc == 0, B == [+0].
test(3) :- phrase(lc(Tc,Nc), [+5]) -> Tc == present(short), Nc == 5.
test(4) :- phrase(lc(Tc,Nc), [+0,+1,+0]) -> Tc == present(extended), Nc == 256.
test(5) :- \+ phrase(lc(_,_), [+0,+0,+0]).
test(6) :- cla_meaning(0x00, Class, ClaMeaning) -> Class == interindustry, ClaMeaning == [default,complete,none].
test(7) :- cm(0x00, 0xA4, 0x04, 0x00, Tc, Te, C) -> Tc = present(_), Te = present(_), C == select(aid_prefix,first,fci).
test(8) :- cm(0x80, 0xA8, 0x00, 0x00, Tc, Te, C) -> Tc = present(_), Te = present(_), C == get_processing_options.
test(rr(1)) :- cm(0x00, 0xB2, 0x01, 0x14, Tc, Te, C) -> Tc == absent, Te = present(_), C == read_record(2,record_number(exact,1)).
test(rr(2)) :- cm(0x00, 0xB2, 0x02, 0x1C, Tc, Te, C) -> Tc == absent, Te = present(_), C == read_record(3,record_number(exact,2)).
test(bits(1)) :- bits(8, [1,0,0,0,0,0,0,0], 0x80).
test(bits(2)) :- bits(L, [1,0,0,0,0,0,0,0], 0x80) -> L == 8.
test(bits(3)) :- bits(8, [1,0,0,0,0,0,0,0], N) -> N == 0x80.
test(bits(4)) :- bits(8, Bits, 0x81) -> Bits == [1,0,0,0,0,0,0,1].
