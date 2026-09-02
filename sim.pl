main :- main([]).

main(FsPrev) :- phrase(exchange(FsPrev, FsNext), []) -> main(FsNext); true.

exchange(FsPrev, FsNext) --> get_bytes(rd), command_response_pair(FsPrev, FsNext), put_bytes(wr).

put_bytes(Stream) --> [] ; [-Byte], { put_byte(Stream, Byte) }, put_bytes(Stream).
get_bytes(Stream, B, A) :-
    get_byte(Stream, Byte), Byte >= 0, A = [+Byte|X], (X = B; get_bytes(Stream, B, X)).

% section 5.1
command_response_pair(FsPrev, FsNext) --> command(Cmd, Dt, Qe), response(Cmd, Dt, Qe, FsPrev, FsNext).

command(Cmd, Dt, Qe) --> hdr(Cmd, Qc, Qe), lc(Qc), cmd(Qc, Dt), le(Qc, Qe).

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

response(Cmd, Dt, Qe, FsPrev, FsNext) --> { response_for(Cmd, Dt, Qe, Response, FsPrev, FsNext) }, output(Response).

singlet(Lowest, A) --> rbyte(A), { A >= Lowest }.
doublet(Lowest, N) --> rbyte(A), rbyte(B), { N is (A << 8) + B, N >= Lowest }.

nbytes(L, N) --> foldl__(count__(in__, N), L, 0, N).
in__(E) --> [+E].

rbyte(N) --> [+N], { between(0, 255, N) }.

rapdu(Kernel, Tsv, Le, Status) --> value_template(Tsv, Le, Kernel), status(Status).
status(Status) --> { sw_db(Sw1, Sw2, Status) }, [Sw1,Sw2].

response_for(Cmd, Dt, Qe, Response, FsPrev, FsNext) :-
    tsv_response_for(Cmd, Dt, Tsv, Status, FsPrev, FsNext),
    phrase(rapdu(3,Tsv,Le,Status), Tmp),
    maplist((is), Response, Tmp),
    le_ok(Qe, Le).

le_ok(Qe, Length) :- le_max(Qe, Max), Length =< Max.
le_max(present(short,Ne), Max) :- Ne =:= 0 -> Max = 256; Max = Ne.
le_max(present(extended,Ne), Max) :- Ne =:= 0 -> Max = 65535; Max = Ne.

% Commands (ISO 7816-4 5.3.1.1)
select(by_dfname, first, Fid, DfName) :- once(dfname(Fid, DfName)).
select(by_fid, first, Fid, Fid) :- once(ft(Fid, _)).
select(by_path, first, Fid, Path) :- once(abs(Fid, Path)).

output([]) --> [].
output([H|T]), [-H] --> output(T).

tsv_response_for(select(aid_prefix,Occurrence,fci), Dt, Fci, completed(ok), Fs, [Fid|Fs]) :-
    append(Dt, _, L),
    select(by_dfname, Occurrence, Fid, L),
    applicable_response(Fid, 0x6F, Fci),
    !.
tsv_response_for(get_processing_options, _, Gpo, completed(ok), [Fid|Fs], [Fid|Fs]) :-
    applicable_response(Fid, 0x77, Gpo),
    !.
tsv_response_for(_, _, [], error(state_of_nvram(unchanged,no_info)), Fs, Fs).

applicable_response(Fid, Root, X) :-
    all_applicable_nested_non_templates(Fid, Root, [C|Cs]),
    maplist(trul(X), [C|Cs]).

all_applicable_nested_non_templates(Fid, Root, Chains) :-
    tag_db_kernel(K),
    findall(C, applicable_nested_non_templates(K,Fid,Root,_,C), Chains).

applicable_nested_non_templates(Kernel, Fid, P, C, [tsv(P,template,[tsv(C,element(X,Y),V)|_])|_]) :-
    nesting_applicability(P, C),
    tag_spec_db(C, Kernel, element(X,Y), _),
    tag_spec_db(P, Kernel, template, _),
    fid_tag_property(Fid, C, V).
applicable_nested_non_templates(Kernel, Fid, P, C, [tsv(P,template,Y)|_]) :-
    tag_spec_db(P, Kernel, template, _),
    nesting_applicability(P, X),
    applicable_nested_non_templates(Kernel, Fid, X, C, Y).


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

channel_supported :- false.

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
