% Interface to access card personalized data

:- initialization(testall(cardint)).

nesting(Df, Fid) :- pc(Df, Fid), (T = df; T = ddf), type_fid(T, Df).
type_fid(Type, Fid) :- ft(Fid, Type).
type_fid(T, Fid) :- (T = df; T = ddf), (C = mf; C = adf), ft(Fid, C).
abs(Fid, Path) :- phrase(absolute_path(Fid), Path).
absolute_path(16128) --> [16128].
absolute_path(C) --> { nesting(P,C) }, absolute_path(P), [C].
dfname(Fid, A) :- fn(Fid, A).
fid_tag_property(F, 0x84, P) :- fn(F, P).
fid_tag_property(F, T, P) :- fc(F, _, T, P).

t(cardint, true, ('There are no duplicates' :-
    forall(ft(F, _), findall(X, ft(F,X), [_]))
)).
t(cardint, false, ('No file types are ambiguous' :-
    ft(Fid, T1),
    ft(Fid, T2),
    T1 \= T2
)).
t(cardint, false, ('No elementary file is a directory' :-
    ft(Ef, ef),
    pc(Ef, _)
)).
t(cardint, skip, ('Every elementary files has DF Name (not implemented)' :-
    forall(fn(F, _), type(df, F))
)).
