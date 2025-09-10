:- initialization(test).

test :- phrase(lc(Tc,Nc), []), Tc == absent, Nc = 0.
test :- phrase(lc(Tc,Nc), [0], B), Tc == absent, Nc = 0, B = [0].
test :- phrase(lc(Tc,Nc), [5]), Tc == present(short), Nc = 5.
test :- phrase(lc(Tc,Nc), [0,1,0]), Tc == present(extended), Nc = 256.
test :- \+ phrase(lc(_,_), [0,0,0]).
