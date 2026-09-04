%% Why not

mi_eval([]).
mi_eval([G|Gs]) :- mi_hb(G, Goals, Gs), mi_eval(Goals).

mi_hb(hb(H,Gs0,Gs), T, T) :- mi_hb(H, Gs0, Gs).
mi_hb(not_hb(H,Gs0,Gs), T, T) :- \+ mi_hb(H, Gs0, Gs).

mi_hb(why([], true), T, T).
mi_hb(why([G|Gs], (E/G)), [hb(G,Goals,Gs),why(Goals,E)|T], T).
mi_hb(why([not(G)|Gs], (E/not(G))), [not_hb(G,Goals,Gs),why(Goals,E)|T], T).

mi_hb(interpret([]), T, T).
mi_hb(interpret([G|Gs]), [hb(G,Goals,Gs),interpret(Goals)|T], T).

mi_hb(natnum(0), T, T).
mi_hb(natnum(s(S)), [natnum(S)|T], T).

example(1, X, E) :- mi_eval([why([natnum(X)],E)]).
example(2, X, E) :- mi_eval([why([interpret([natnum(X)])], E)]).
example(3, X, E) :- X = s(s(s(1))), mi_eval([why([not([natnum(X)])],E)]).
