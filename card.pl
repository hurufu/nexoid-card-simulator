:- initialization(db_consistent).

% Database ft - fid_type, pc - parent_child, fn - fid_dfname, pp - property,
%          fd - fid_data, fx - fid_data_referencing_method.
ft(16128, mf).
ft(28677, df).
ft(28673, adf).
ft(28674, ef).
ft(28675, ef).
ft(28676, adf).
ft(0x2F00, ef).
ft(0x2F01, ef).
pc(28677, 28673).
pc(28677, 28676).
pc(28676, 28674).
pc(28676, 28675).
pc(16128, 0x2F00).
pc(16128, 0x2F01).
fn(28677, "2PAY.SYS.DDF01", ascii).
fn(28673, "A0000001523010", hex).
fn(28676, "A000000324101001", hex).
fn(0x2F00, "EF.DIR", ascii).
fn(0x2F01, "EF.ATR", ascii).
pp(28673, 0x4F, "A0000001523010", hex).
pp(28676, 0x4F, "A000000324101001", hex).
pp(28673, 0x50, "ContactlessDPAS", ascii).
pp(28676, 0x50, "Discover", ascii).
fd(28674, [0,0,0,0,0,0,0,0,0,0]).
fd(28675, [[0,0,0],[0,1,0],[1,1,3],[0,0,0]]).
fx(28674, transparent).
fx(28674, record).
fx(28674, fixed).
fx(28674, linear).
fx(28676, ber-tlv).

% Interface
nesting(Df, Fid) :- pc(Df, Fid), type(df, Df).
type(Type, Fid) :- ft(Fid, Type).
type(df, Fid) :- ft(Fid, mf).
type(df, Fid) :- ft(Fid, adf).
abs(Fid, Path) :- phrase(absolute_path(Fid), Path).
absolute_path(16128) --> [16128].
absolute_path(C) --> { nesting(P,C) }, absolute_path(P), [C].
dfname(Fid, A) :- fn(Fid, A, _).
property(Fid, 0x50, stratom(A)) :- pp(Fid, 0x50, A, _).
property(Fid, 0x4F, H) :- pp(Fid, 0x4F, H, _).

% Commands (ISO 7816-4 5.3.1.1)
instruction(select, by_dfname, Fid, DfName) :- dfname(Fid, DfName).
instruction(select, by_fid, Fid, Fid) :- ft(Fid, _).
instruction(select, by_path, Fid, Path) :- abs(Fid, Path).

% FCI
fci(Fid, D) :-
    D = [fci-[
            dfname-DfName,
            0xA5-[
                0xBF0C-X61]]],
    dfname(Fid, DfName),
    findall(C, nesting(Fid,C), Children),
    maplist(x61, Children, X61).

x61(Fid, X61) :-
    X61 = 0x61-[aid-Aid,label-Label],
    tag_describe([mnemonic(aid),value(AidT)]),
    tag_describe([mnemonic(label),value(LabelT)]),
    property(Fid, AidT, hex(Aid)),
    property(Fid, LabelT, stratom(Label)).

% Tests
db_consistent :- duplicates, ambiguous_type, ef_hosts_files, ef_has_dfname.
duplicates :- forall(ft(F, _), findall(X, ft(F,X), [_])).
ambiguous_type :- \+((ft(Fid, T1), ft(Fid, T2), T1 \= T2)).
ef_hosts_files :- \+((ft(Ef, ef), pc(Ef, _))).
ef_has_dfname :- forall(fn(F, _, _), type(df, F)).

% Tag knowledge base
tag_describe(P) :-
    between(1, 4, N), % Number of properties
    length(P, N),
    maplist(tag_property(_), P),
    all_different(P).

tag_property(Id, value(V)) :- tag_db(Id, V, _, _) ; tag_db(Id, V, _, _, _).
tag_property(Id, mnemonic(M)) :- tag_db(Id, _, M, _, _).
tag_property(Id, name(N)) :- tag_db(Id, _, N, _) ; tag_db(Id, _, _, N, _).
tag_property(Id, spec(S)) :- tag_db(Id, _, _, S) ; tag_db(Id, _, _, _, S).

tag_db(0x82, 0x82, 'File descriptor', 'b1..6').
tag_db(0x83, 0x83, 'File identifier', 'b2').
tag_db(0xA5, 0xA5, 'File Control Information (FCI) Proprietary Template', '').
tag_db(0xBF0C, 0xBF0C, 'File Control Information (FCI) Issuer Discretionary Data', '').
tag_db(0x61, 0x61, 'Application Template', '').
tag_db(0x4F, 0x4F, aid, 'Application Identifier (AID) – Card', '').
tag_db(0x50, 0x50, label, 'Application Label', '').
tag_db(0x87, 0x87, api, 'Application Priority Indicator', '').
tag_db(0x84, 0x84, dfname, 'Dedicated File (DF) Name', 'b..16').
tag_db(0x6F, 0x6F, fci, 'File Control Information (FCI)', 't..').

% Utils
all_different([]).
all_different([H|T]) :- maplist(\=(H), T), all_different(T).
