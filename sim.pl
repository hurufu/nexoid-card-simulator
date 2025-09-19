main :- phrase(exchange, []) -> main; true.

exchange --> get_bytes(rd), command_response_pair, put_bytes(wr).

% section 5.1
command_response_pair -->
    hdr(Cmd, Qc, Qe), lc(Qc), cmd(Qc, Dt), le(Qc, Qe), response(Cmd, Dt, Qe).

hdr(Cmd, Qc, Qe) --> [+Cla,+Ins,+P1,+P2], { cm(Cla, Ins, P1, P2, Qc, Qe, Cmd) }.

lc(absent) --> [].
lc(present(short,Nc)) --> singlet(1, Nc).
lc(present(extended,Nc)) --> [+0], doublet(1, Nc).

cmd(absent, []) --> [].
cmd(present(_,Nc), Bytes) --> nbytes(Bytes, Nc).

le(_, absent) --> [].
le(present(short,_), present(short,Ne)) --> singlet(0, Ne).
le(present(extended,_), present(extended,Ne)) --> doublet(0, Ne).
le(absent, present(extended,Ne)) --> [+0], doublet(0, Ne).

response(Cmd, Dt, Qe) --> { response_for(Cmd, Dt, Qe, Response, Sw1, Sw2) }, output([Sw1,Sw2]), output(Response).

singlet(Lowest, A) --> [+A], { between(0, 255, A), A >= Lowest }.
doublet(Lowest, N) --> [+A,+B], { maplist(between(0, 255), [A,B]), N is (A << 8) + B, N >= Lowest }.

nbytes(L, N) --> { ground(N), functor(_, t, N) } -> seqn_int(L, N); { acyclic_term(L) }, seqn_var(L, N).
seqn_int(L, N) --> { N =:= 0 } -> { L = [] }, []; { L = [H|T], M is N - 1 }, [+H], seqn_int(T, M).
seqn_var([], 0) --> [].
seqn_var([H|T], N) --> [+H], seqn_var(T, M), { N is M + 1 }.

put_bytes(Stream) --> [] | [-Byte], { put_byte(Stream, Byte) }, put_bytes(Stream).
get_bytes(Stream, B, A) :-
    get_byte(Stream, Byte), Byte >= 0, A = [+Byte|X], (X = B; get_bytes(Stream, B, X)).

response_for(select(aid_prefix,Occurrence,fci), Dt, Qe, Rs, 0x90, 0x00) :-
    open_list(Dt, L-_),
    select(by_dfname, Occurrence, Fid, L),
    fci(Fid, Fci),
    phrase(ber(Fci,Length), Tmp),
    maplist(is, Rs, Tmp),
    le_ok(Qe, Length).
response_for(get_processing_options, _, Qe, Rs, 0x90, 0x00) :-
    phrase(gpo_(22090), GPO),
    phrase(ber([0x77-GPO], Length), Tmp),
    maplist(is, Rs, Tmp),
    le_ok(Qe, Length).

le_ok(Qe, Length) :- le_max(Qe, Max), Length =< Max.
le_max(present(short,Ne), Max) :- Ne =:= 0 -> Max = 256; Max = Ne.
le_max(present(extended,Ne), Max) :- Ne =:= 0 -> Max = 65535; Max = Ne.

% Describes list difference an it's prefix (regular list)
open_list([], X-X).
open_list([H|D], [H|T]-X) :- open_list(D, T-X).

output([]) --> [].
output([H|T]), [-H] --> output(T).


ber([], 0) --> [].
ber([Tlv|Rest], L0+L1) --> tlv(Tlv, L0), ber(Rest, L1).
tlv(T-V, L0+L1) --> tag(T, spec(S), L0), len(L1, VL), value(S, V, VL).
tag(T, spec(S), 1) --> { tag_property(T, length(1)), tag_property(T, spec(S)) }, [T].
tag(T, spec(S), 2) --> { tag_property(T, length(2)), tag_property(T, spec(S)), number_bytes(T,[B1,B2]) }, [B1,B2].
len(VL+1, VL) --> [VL].
value('t..', V, L) --> ber(V, L).
value('b..16', V, N) --> V,  { once(length(V, N)), N >= 0, N =< 16 }.
value('b..19', V, N) --> V,  { once(length(V, N)), N >= 0, N =< 19 }.
value('b..32', V, N) --> V,  { once(length(V, N)), N >= 0, N =< 32 }.
value('b..64', V, N) --> V,  { once(length(V, N)), N >= 0, N =< 64 }.
value('b5..16', V, N) --> V, { once(length(V, N)), N >= 5, N =< 16 }.
value('b1..16', V, N) --> V, { once(length(V, N)), N >= 1, N =< 16 }.
value('b1..6', V, N) --> V, { once(length(V, N)), N >= 1, N =< 6 }.
value('b1', [V], 1) --> [V].
value('b2', [A,B], 2) --> [A,B].
value('b5', [A,B,C,D,E], 5) --> [A,B,C,D,E].
value('b8', [A,B,C,D,E,F,G,H], 8) --> [A,B,C,D,E,F,G,H].
value('n2', [A], 1) --> [A].

number_bytes(N, [A,B]) :-
    bits(16, [A0,A1,A2,A3,A4,A5,A6,A7,B0,B1,B2,B3,B4,B5,B6,B7], N),
    maplist(bits(8), [[A0,A1,A2,A3,A4,A5,A6,A7],[B0,B1,B2,B3,B4,B5,B6,B7]],[A,B]).

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
select(by_dfname, first, Fid, DfName) :- once(dfname(Fid, DfName)).
select(by_fid, first, Fid, Fid) :- once(ft(Fid, _)).
select(by_path, first, Fid, Path) :- once(abs(Fid, Path)).

% FCI
fci(Fid, D) :-
    D = [0x6F-[
            0x84-DfName,
            0xA5-[
                0xBF0C-X61|A5_Options]]],
    dfname(Fid, DfName),
    phrase(xA5_(Fid), A5_Options),
    findall(C, nesting(Fid,C), Children),
    maplist(x61, [Fid|Children], X61).

x61(Fid, 0x61-V) :- phrase(x61_(Fid), V).

x61_(Fid) -->
    optional_pp(Fid, 0x4F), optional_pp(Fid, 0x50), optional_pp(Fid, 0x87),
    optional_pp(Fid, 0x9F2A), optional_pp(Fid, 0x9F5A).
xA5_(Fid) --> optional_pp(Fid, 0x50), optional_pp(Fid, 0x9F38).

gpo_(Fid) -->
    optional_pp(Fid, 0x57), optional_pp(Fid, 0x82), optional_pp(Fid, 0x5F34),
    optional_pp(Fid, 0x9F10), optional_pp(Fid, 0x9F26), optional_pp(Fid, 0x9F27),
    optional_pp(Fid, 0x9F36), optional_pp(Fid, 0x9F6C).

optional_pp(Fid, Tag) --> { pp(Fid, Tag, Value) } -> [Tag-Value]; [].


% Tests
db_consistent :- duplicates, ambiguous_type, ef_hosts_files.
duplicates :- forall(ft(F, _), findall(X, ft(F,X), [_])).
ambiguous_type :- \+((ft(Fid, T1), ft(Fid, T2), T1 \= T2)).
ef_hosts_files :- \+((ft(Ef, ef), pc(Ef, _))).
%ef_has_dfname :- forall(fn(F, _), type(df, F)).

tag_property(Id, value(Id)) :- tag_db(Id, _, _, _).
tag_property(Id, length(L)) :- tag_db(Id, L, _, _).
tag_property(Id, name(N)) :- tag_db(Id, _, N, _).
tag_property(Id, spec(S)) :- tag_db(Id, _, _, S).

tag_db(0x82, 1, 'File descriptor', 'b1..6').
tag_db(0x83, 1, 'File identifier', 'b2').
tag_db(0xA5, 1, 'FCI Proprietary Template', 't..').
tag_db(0x77, 1, 'Response Message Template Format 2', 't..').
tag_db(0xBF0C, 2, 'File Control Information (FCI) Issuer Discretionary Data', 't..').
tag_db(0x61, 1, 'Application Template', 't..').
tag_db(0x87, 1, 'Application Priority Indicator', 'b1').
tag_db(0x9F2A, 2, 'Unknown', 'b2').
tag_db(0x4F, 1, 'Application Identifier (AID) – Card', 'b5..16').
tag_db(0x50, 1, 'Application Label', 'b1..16').
tag_db(0x87, 1, 'Application Priority Indicator', 'b1').
tag_db(0x84, 1, 'Dedicated File (DF) Name', 'b..16').
tag_db(0x6F, 1, 'File Control Information (FCI)', 't..').
tag_db(0x9F38, 2, 'PDOL', 'b..64').
tag_db(0x9F5A, 2, 'Unknown', 'b5').
tag_db(0x57, 1, 'Track 2 Equivalent Data', 'b..19').
tag_db(0x5F34, 2, 'Application PAN Sequence Number', 'n2').
tag_db(0x9F10, 2, 'Issuer Application Data', 'b..32').
tag_db(0x9F26, 2, 'Application Cryptogram', 'b8').
tag_db(0x9F27, 2, 'Cryptogram Information Data', 'b1').
tag_db(0x9F36, 2, 'ATC', 'b2').
tag_db(0x9F6C, 2, 'Unknown', 'b2').

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

%% cm(+Cla, +Ins, +P1, +P2, -Qc, -Qe, -Command).
%
cm(Cla, Ins, P1, P2, Qc, Qe, Command) :-
    maplist(bits(8), [ClaBits,P1Bits,P2Bits], [Cla,P1,P2]),
    cm_(ClaBits, Ins, P1Bits, P2Bits, Qc, Qe, Command).

%% cm(+ClaBits, +Ins, +P1Bits, +P2Bits, -Qc, -Qe, -Command).
%
cm_(Cla, 0x70, [1,0,0,0,0,0,0,0], [0,0,0,0,0,0,0,0], absent, absent,     manage_channel(close(N))) :- cla_meaning_(Cla, _, [channel(N),_,_]).
cm_(_,   0x70, [1,0,0,0,0,0,0,0], [0,0,0,0,0,0,A,B], absent, absent,     manage_channel(close(N))) :- N is A << 1 + B, N > 0.
cm_(_,   0x70, [0,0,0,0,0,0,0,0], [0,0,0,0,0,0,0,0], absent, present(_,_), manage_channel(open)).
cm_(_,   0x70, [0,0,0,0,0,0,0,0], [0,0,0,0,0,0,A,B], absent, absent,     manage_channel(open(N))) :- N is A << 1 + B, N > 0.
cm_(_,   0xA4, P1Bits,            P2Bits,            Qc,     present(_,_), select(DataType,Occurrence,Return)) :-
    select_p1(P1Bits, Qc, DataType),
    select_p2(P2Bits, occurrence(Occurrence)),
    select_p2(P2Bits, return(Return)).
% EMV Book 3 table 17
cm_([1,0,0,0,0,0,0,0], 0xA8, [0,0,0,0,0,0,0,0], [0,0,0,0,0,0,0,0], present(_,_), present(_,_), get_processing_options).
cm_(_, Ins, P1Bits, [A,B,C,D,E|P2Rest], Qc, Qe, Command) :-
    maplist(bits, [8,5,8], [P1Bits,[A,B,C,D,E],InsBits], [P1,Eid,Ins]),
    record(InsBits, P1, Eid, P2Rest, Qc, Qe, Command).

% B2; B3
record([1,0,1,1,0,0,1,X], P1, Eid, [0|T],   Tc, present(_,_), read_record(Eid,record_identifier(O,P1))) :- occurrence(T, O), read_record_tc(X, Tc).
record([1,0,1,1,0,0,1,X], P1, Eid, [1,0,0], Tc, present(_,_), read_record(Eid,record_number(exact,P1))) :- read_record_tc(X, Tc).
record([1,0,1,1,0,0,1,X], P1, Eid, [1,0,1], Tc, present(_,_), read_record(Eid,record_number(starting_from,P1))) :- read_record_tc(X, Tc).
record([1,0,1,1,0,0,1,X], P1, Eid, [1,1,0], Tc, present(_,_), read_record(Eid,record_number(from_last_up_to,P1))) :- read_record_tc(X, Tc).
% D2
record([1,1,0,1,0,0,0,0], P1, Eid, [0|T],   _, _, write_record(Eid,record_identifier(O,P1))) :- occurrence(T, O).
record([1,1,0,1,0,0,0,0], P1, Eid, [1,0,0], _, _, write_record(Eid,record_number(exact,P1))).
% DC; DD
record([1,1,0,1,1,1,0,1], P1, Eid, [1,0,0], _, _, update_record(replace,Eid,record_number(exact,P1))).
record([1,1,0,1,1,1,0,1], P1, Eid, [1,0,1], _, _, update_record(and,Eid,record_number(exact,P1))).
record([1,1,0,1,1,1,0,1], P1, Eid, [1,1,0], _, _, update_record(or,Eid,record_number(exact,P1))).
record([1,1,0,1,1,1,0,1], P1, Eid, [1,1,1], _, _, update_record(xor,Eid,record_number(exact,P1))).

read_record_tc(0, absent).
read_record_tc(1, present(_,_)).

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
select_p1([0,0,0,0,0,0,0,0], present(_,_), fid). % file (MF, DF, EF) identifier
select_p1([0,0,0,0,0,0,0,0], absent,     absent).
select_p1([0,0,0,0,0,0,0,1], present(_,_), did). % DF identifier
select_p1([0,0,0,0,0,0,1,0], present(_,_), eid). % EF identifier
select_p1([0,0,0,0,0,0,1,1], absent,     absent).
select_p1([0,0,0,0,0,1,0,0], present(_,_), aid_prefix).
select_p1([0,0,0,0,1,0,0,0], present(_,_), path_mf). % Path without the MF identifier
select_p1([0,0,0,0,1,0,0,1], present(_,_), path_df). % Path without the current DF identifier

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
