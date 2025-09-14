%:- initialization(db_consistent).

%% ft(Fid, Type).
%
ft(16128, mf).
ft(28677, df).
ft(28673, adf).
ft(28674, ef).
ft(28675, ef).
ft(28676, adf).
ft(0x2F00, ef).
ft(0x2F01, ef).

%% pc(Parent, Child).
%
pc(28677, 28673).
pc(28677, 28676).
pc(28676, 28674).
pc(28676, 28675).
pc(16128, 0x2F00).
pc(16128, 0x2F01).

%% fn(Fid, DFName).
%
fn(28677, [50,80,65,89,46,83,89,83,46,68,68,70,48,49]). % 2PAY.SYS.DDF01
fn(28673, [0xA0,0x00,0x00,0x01,0x52,0x30,0x10]).
fn(28676, [0xA0,0x00,0x00,0x00,0x03,0x24,0x10,0x10,0x01]).
fn(0x2F00, [0x45,0x46,0x2e,0x44,0x49,0x52]). % EF.DIR
fn(0x2F01, [0x45,0x46,0x2e,0x41,0x54,0x52]). % EF.ATR

%% pp(Fid, Property, Value).
%
pp(28673, 0x4F, [0xA0,0x00,0x00,0x01,0x52,0x30,0x10]).
pp(28676, 0x4F, [0xA0,0x00,0x00,0x03,0x24,0x10,0x10,0x01]).
pp(28673, 0x50, [0x43,0x6f,0x6e,0x74,0x61,0x63,0x74,0x6c,0x65,0x73,0x73,0x44,0x50,0x41,0x53]). % ContactlessDPAS
pp(28676, 0x50, [0x44,0x69,0x73,0x63,0x6f,0x76,0x65,0x72]). % Discover

%% fd(Fid, Data).
%
fd(28674, [0,0,0,0,0,0,0,0,0,0]).
fd(28675, [[0,0,0],[0,1,0],[1,1,3],[0,0,0]]).

%% fx(Fid, DataReferencingMethod).
%
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
dfname(Fid, A) :- fn(Fid, A).
property(Fid, 0x50, A) :- pp(Fid, 0x50, A).
property(Fid, 0x4F, H) :- pp(Fid, 0x4F, H).

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
    property(Fid, AidT, Aid),
    property(Fid, LabelT, Label).

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

%% cla_meaning(+Cla, -Class, -ClaMeaning) is det.
%
cla_meaning(Cla, Class, ClaMeaning) :-
    bits(8, Bits, Cla),
    once(cla_meaning_(Bits, Class, ClaMeaning)).

cla_meaning_(Bits, proprietary, []) :-
    cla_property(Bits, class(proprietary)).
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
cla_property([1,A,B,C,D,E,F,G], class(proprietary)) :-  member(0, [A,B,C,D,E,F,G]).

:- dynamic(channel_supported/0).

%% cm(+Cla, +Ins, +P1, +P2, -Tc, -Te, -Command).
%
cm(Cla, Ins, P1, P2, Tc, Te, Command) :-
    maplist(bits(8), [ClaBits,P1Bits,P2Bits], [Cla,P1,P2]),
    cm_(ClaBits, Ins, P1Bits, P2Bits, Tc, Te, Command).

%% cm(+ClaBits, +Ins, +P1Bits, +P2Bits, -Tc, -Te, -Command).
%
cm_(Cla, 0x70, [1,0,0,0,0,0,0,0], [0,0,0,0,0,0,0,0], absent, absent,     manage_channel(close(N))) :- cla_meaning_(Cla, _, [channel(N),_,_]).
cm_(_,   0x70, [1,0,0,0,0,0,0,0], [0,0,0,0,0,0,A,B], absent, absent,     manage_channel(close(N))) :- N is A << 1 + B, N > 0.
cm_(_,   0x70, [0,0,0,0,0,0,0,0], [0,0,0,0,0,0,0,0], absent, present(_), manage_channel(open)).
cm_(_,   0x70, [0,0,0,0,0,0,0,0], [0,0,0,0,0,0,A,B], absent, absent,     manage_channel(open(N))) :- N is A << 1 + B, N > 0.
cm_(_,   0xA4, P1Bits,            P2Bits,            Tc,     present(_), select(DataType,Occurrence,Return)) :-
    select_p1(P1Bits, Tc, DataType),
    select_p2(P2Bits, occurrence(Occurrence)),
    select_p2(P2Bits, return(Return)).
% EMV Book 3 table 17
cm_([1,0,0,0,0,0,0,0], 0xA8, [0,0,0,0,0,0,0,0], [0,0,0,0,0,0,0,0], present(_), present(_), get_processing_options).
cm_(_, Ins, P1Bits, [A,B,C,D,E|P2Rest], Tc, Te, Command) :-
    maplist(bits, [8,5,8], [P1Bits,[A,B,C,D,E],InsBits], [P1,Eid,Ins]),
    record(InsBits, P1, Eid, P2Rest, Tc, Te, Command).

% B2; B3
record([1,0,1,1,0,0,1,X], P1, Eid, [0|T],   Tc, present(_), read_record(Eid,record_identifier(O,P1))) :- occurrence(T, O), read_record_tc(X, Tc).
record([1,0,1,1,0,0,1,X], P1, Eid, [1,0,0], Tc, present(_), read_record(Eid,record_number(exact,P1))) :- read_record_tc(X, Tc).
record([1,0,1,1,0,0,1,X], P1, Eid, [1,0,1], Tc, present(_), read_record(Eid,record_number(starting_from,P1))) :- read_record_tc(X, Tc).
record([1,0,1,1,0,0,1,X], P1, Eid, [1,1,0], Tc, present(_), read_record(Eid,record_number(from_last_up_to,P1))) :- read_record_tc(X, Tc).
% D2
record([1,1,0,1,0,0,0,0], P1, Eid, [0|T],   _, _, write_record(Eid,record_identifier(O,P1))) :- occurrence(T, O).
record([1,1,0,1,0,0,0,0], P1, Eid, [1,0,0], _, _, write_record(Eid,record_number(exact,P1))).
% DC; DD
record([1,1,0,1,1,1,0,1], P1, Eid, [1,0,0], _, _, update_record(replace,Eid,record_number(exact,P1))).
record([1,1,0,1,1,1,0,1], P1, Eid, [1,0,1], _, _, update_record(and,Eid,record_number(exact,P1))).
record([1,1,0,1,1,1,0,1], P1, Eid, [1,1,0], _, _, update_record(or,Eid,record_number(exact,P1))).
record([1,1,0,1,1,1,0,1], P1, Eid, [1,1,1], _, _, update_record(xor,Eid,record_number(exact,P1))).

read_record_tc(0, absent).
read_record_tc(1, present(_)).

occurrence([0,0], first).
occurrence([0,1], last).
occurrence([1,0], next).
occurrence([1,1], previous).

binary_data_handling(Ins, P1, P2, Tc, Te, File, Offset) :-
    bits(8, InsBits, Ins),
    bdh_(InsBits, P1, P2, Tc, Te, File, Offset).

bdh_([_,_,_,_,_,_,_,0], [1,_,_,A,B,C,D,E], P2Bits, absent, absent, eid(Eid), Offset) :-
    bits(5,[A,B,C,D,E], Eid),
    bits(8, P2Bits, Offset).
bdh_([_,_,_,_,_,_,_,0], [0,A,B,C,D,E,F,G], P2Bits, absent, absent, current, Offset) :-
    bits(15, [A,B,C,D,E,F,G|P2Bits], Offset).
bdh_([_,_,_,_,_,_,_,1], _, _, _, _, _, _) :- throw(error(not_implemented(bdh_/7),_)).

% table 39
select_p1([0,0,0,0,0,0,0,0], present(_), fid). % file (MF, DF, EF) identifier
select_p1([0,0,0,0,0,0,0,0], absent,     absent).
select_p1([0,0,0,0,0,0,0,1], present(_), did). % DF identifier
select_p1([0,0,0,0,0,0,1,0], present(_), eid). % EF identifier
select_p1([0,0,0,0,0,0,1,1], absent,     absent).
select_p1([0,0,0,0,0,1,0,0], present(_), aid_prefix).
select_p1([0,0,0,0,1,0,0,0], present(_), path_mf). % Path without the MF identifier
select_p1([0,0,0,0,1,0,0,1], present(_), path_df). % Path without the current DF identifier

% table 40
select_p2([0,0,0,0,_,_| P2], occurrence(O)) :- occurrence(P2, O).
select_p2([0,0,0,0,0,0,_,_], return(fci)). % Return FCI template
select_p2([0,0,0,0,0,1,_,_], return(fcp)).
select_p2([0,0,0,0,1,0,_,_], return(fmd)).
select_p2([0,0,0,0,1,1,_,_], return(absent)).
select_p2([0,0,0,0,1,1,_,_], return(proprietary)).

%% bits(-Exponent, -Bits, +Number) is multi.
%% bits(+Exponent, -Bits, +Number) is semidet.
%% bits(+Exponent, +Bits, -Number) is semidet.
%
bits(Exp, RBits, N) :-
    length(Bits, Exp),
    reverse(Bits, RBits),
    (ground(N) ->
        foldl(bb(N), Bits, 0, Exp), 1 << Exp > N
    ;   foldl(bv, Bits, 0:0, Expression:Check), N is Expression, Exp =:= Check).

bb(Byte, Bit, Exp, NextExp) :- Bit is (Byte /\ 1 << Exp) >> Exp, NextExp is Exp + 1.
bv(Bit, A:Exp, A + (Bit << Exp):(Exp + 1)).
