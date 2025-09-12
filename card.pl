%:- initialization(db_consistent).

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

header_meaning(Cla, Ins, P1, P2, Tc, command(cla(Class,ClaMeaning),InsMeaning)) :-
    cla_meaning(Cla, Class, ClaMeaning),
    ins_meaning(Class, Ins, P1, P2, Tc, InsMeaning).

ins_meaning(Class, Ins, P1, P2, Tc, ins(I,D,O,R)) :-
    ins(Class, Ins, I),
    bits(P1Bits, P1, 8),
    bits(P2Bits, P2, 8),
    p1(I, P1Bits, Tc, D),
    p2(I, P2Bits, occurrence(O)),
    p2(I, P2Bits, _, return(R)).

%% cla_meaning(+Cla, -Class, -ClaMeaning) is det.
%
cla_meaning(Cla, Class, ClaMeaning) :-
    bits(Bits, Cla, 8),
    once(cla_meaning_(Bits, Class, ClaMeaning)).

cla_meaning_(Bits, proprietary(T), []) :-
    cla_property(Bits, class(proprietary(T))).
cla_meaning_(Bits, interindustry, [Channel,Chaining,Secure]) :-
    cla_property(Bits, class(interindustry)),
    cla_property(Bits, logical_channel(Channel)),
    cla_property(Bits, chaining_control(Chaining)),
    cla_property(Bits, secure_messaging(Secure)).

%% cla_property(?Bits, ?Property).
%
% @see ISO 7816-4 table 2 and 3
%
cla_property([0,0,0,_,_,_,A,B], logical_channel(channel(N))) :- channel_supported, N is A << 1 + B.
cla_property([0,0,0,_,_,_,0,0], logical_channel(default)) :- \+ channel_supported.
cla_property([0,0,0,_,0,0,_,_], secure_messaging(none)).
cla_property([0,0,0,_,0,1,_,_], secure_messaging(secm(proprietary))).
cla_property([0,0,0,_,1,0,_,_], secure_messaging(secm(not_processed))).
cla_property([0,0,0,_,1,1,_,_], secure_messaging(secm(authenticated))).
cla_property([0,0,0,0,_,_,_,_], chaining_control(complete)).
cla_property([0,0,0,1,_,_,_,_], chaining_control(partial)).
cla_property([0,1,0,_,_,_,_,_], secure_messaging(none)).
cla_property([0,1,1,_,_,_,_,_], secure_messaging(secm(not_processed))).
cla_property([0,1,_,_,A,B,C,D], logical_channel(channel(N))) :- channel_supported, N is A << 3 + B << 2 + C << 1 + D.
cla_property([0,1,_,_,0,0,0,0], logical_channel(default)) :- \+ channel_supported.
cla_property([0,1,_,0,_,_,_,_], chaining_control(complete)).
cla_property([0,1,_,1,_,_,_,_], chaining_control(partial)).
cla_property([0,_,_,_,_,_,_,_], class(interindustry)).
cla_property([1,A,B,C,D,E,F,G], class(proprietary(emv))) :-  member(0, [A,B,C,D,E,F,G]).

:- dynamic(channel_supported/0).

%% instruction(Disposition, Ins, Name).
%
ins(interindustry, 0x04, deactivate_file).
ins(interindustry, 0x0C, erase_record).
ins(interindustry, X,    erase_binary) :- X = 0x0E; X = 0x0F.
ins(interindustry, 0x10, perform_scql_operation).
ins(interindustry, 0x12, perform_transaction_operation).
ins(interindustry, 0x14, perform_user_operation).
ins(interindustry, X,    verify) :- X = 0x20; X = 0x21.
ins(interindustry, 0x22, manage_security_environment).
ins(interindustry, 0x24, change_reference_data).
ins(interindustry, 0x26, enable_verification_requirement).
ins(interindustry, 0x28, disable_verification_requirement).
ins(interindustry, 0x2A, perform_security_operation).
ins(interindustry, 0x2C, reset_retry_counter).
ins(interindustry, 0x44, activate_file).
ins(interindustry, 0x46, generate_asymmetric_key_pair).
ins(interindustry, 0x70, manage_channel).
ins(interindustry, 0x82, external_authenticate). % Also mutual_authenticate
ins(interindustry, 0x84, get_challenge).
ins(interindustry, X,    general_authenticate) :- X = 0x86; X = 0x87.
ins(interindustry, 0x88, intenral_authenticate).
ins(interindustry, X,    search_binary) :- X = 0xA0; X = 0xA1.
ins(interindustry, 0xA2, search_record).
ins(interindustry, 0xA4, select).
ins(interindustry, X,    read_binary) :- X = 0xB0; X = 0xB1.
ins(interindustry, X,    read_record) :- X = 0xB2; X = 0xB3.
ins(interindustry, 0xC0, get_response).
ins(interindustry, X,    envelope) :- X = 0xC2; X = 0xC3.
ins(interindustry, X,    get_data) :- X = 0xCA; X = 0xCB.
ins(interindustry, X,    write_binary) :- X = 0xD0; X = 0xD1.
ins(interindustry, 0xD2, write_record).
ins(interindustry, X,    update/binary) :- X = 0xD6; X = 0xD7.
ins(interindustry, X,    put_data) :- X = 0xDA; X = 0xDB.
ins(interindustry, X,    update_record) :- X = 0xDC; X = 0xDD.
ins(interindustry, 0xE0, create_file).
ins(interindustry, 0xE2, append_record).
ins(interindustry, 0xE4, delete_file).
ins(interindustry, 0xE6, terminate_df).
ins(interindustry, 0xE8, terminate_ef).
ins(interindustry, 0xFE, terminate_card_usage).
%ins(interindustry, X,    invalid_command) :- X /\ 0x60 + X /\ 0x90 =\= 0.
ins(proprietary(emv), 0xA8, get_processing_options).


% table 39
p1(select, [0,0,0,0,0,0,0,0], present(_), fid(_)). % file (MF, DF, EF) identifier
p1(select, [0,0,0,0,0,0,0,0], absent,     absent).
p1(select, [0,0,0,0,0,0,0,1], present(_), did(_)). % DF identifier
p1(select, [0,0,0,0,0,0,1,0], present(_), eid(_)). % EF identifier
p1(select, [0,0,0,0,0,0,1,1], absent,     absent).
p1(select, [0,0,0,0,0,1,0,0], present(_), aid_prefix(_)).
p1(select, [0,0,0,0,1,0,0,0], present(_), path(mf, _)). % Path without the MF identifier
p1(select, [0,0,0,0,1,0,0,1], present(_), path(df, _)). % Path without the current DF identifier

% table 40
p2(select, [0,0,0,0,_,_,0,0], occurrence(first)).
p2(select, [0,0,0,0,_,_,0,1], occurrence(last)).
p2(select, [0,0,0,0,_,_,1,0], occurrence(next)).
p2(select, [0,0,0,0,_,_,1,1], occurrence(previous)).
p2(select, [0,0,0,0,0,0,_,_], _,          return(fci)). % Return FCI template
p2(select, [0,0,0,0,0,1,_,_], present(_), return(fcp)).
p2(select, [0,0,0,0,1,0,_,_], present(_), return(fmd)).
p2(select, [0,0,0,0,1,1,_,_], absent,     return(absent)).
p2(select, [0,0,0,0,1,1,_,_], present,    return(proprietary)).


%% bits(Bits, Number, Exponent) is multi.
%
bits(RBits, N, Exp) :-
    length(Bits, Exp),
    reverse(Bits, RBits),
    foldl(bb(N), Bits, 0, Exp), 1 << Exp > N.

bb(Byte, Bit, Exp, NextExp) :- Bit is (Byte /\ 1 << Exp) >> Exp, NextExp is Exp + 1.
