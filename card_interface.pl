% Interface to access card personalized data

nesting(Df, Fid) :- pc(Df, Fid), (T = df; T = ddf), type_fid(T, Df).
type_fid(Type, Fid) :- ft(Fid, Type).
type_fid(T, Fid) :- (T = df; T = ddf), (C = mf; C = adf), ft(Fid, C).
abs(Fid, Path) :- phrase(absolute_path(Fid), Path).
absolute_path(16128) --> [16128].
absolute_path(C) --> { nesting(P,C) }, absolute_path(P), [C].
dfname(Fid, A) :- fn(Fid, A).
fid_tag_property(F, 0x84, P) :- fn(F, P).
fid_tag_property(F, T, P) :- fc(F, _, T, P).

db_consistent :- duplicates, ambiguous_type, ef_hosts_files.
duplicates :- forall(ft(F, _), findall(X, ft(F,X), [_])).
ambiguous_type :- \+((ft(Fid, T1), ft(Fid, T2), T1 \= T2)).
ef_hosts_files :- \+((ft(Ef, ef), pc(Ef, _))).
%ef_has_dfname :- forall(fn(F, _), type(df, F)).
%
