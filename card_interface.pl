% Interface to access card personalized data

nesting(Df, Fid) :- pc(Df, Fid), (T = df; T = ddf), type_fid(T, Df).
type_fid(Type, Fid) :- ft(Fid, Type).
type_fid(T, Fid) :- (T = df; T = ddf), (C = mf; C = adf), ft(Fid, C).
abs(Fid, Path) :- phrase(absolute_path(Fid), Path).
absolute_path(16128) --> [16128].
absolute_path(C) --> { nesting(P,C) }, absolute_path(P), [C].
dfname(Fid, A) :- fn(Fid, A).
fid_tag_property(F, 0x84, P) :- fn(F, P).
fid_tag_property(F, T, P) :- pp(F, T, P).
