:- initialization(testall(capdu)).

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
    tag_property(C, Kernel, spec(element(X,Y))),
    tag_property(P, Kernel, spec(template)),
    fid_tag_property(Fid, C, V).
applicable_nested_non_templates(Kernel, Fid, P, C, [tsv(P,template,Y)|_]) :-
    tag_property(P, Kernel, spec(template)),
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

t(capdu, true, ('lc 1' :-
    phrase(lc(Qc), []) -> Qc == absent
)).
t(capdu, true, ('lc 2' :-
    phrase(lc(Qc), [+0], B) -> Qc == absent, B == [+0]
)).
t(capdu, true, ('lc 3' :-
    phrase(lc(Qc), [+5]) -> Qc == present(short,5)
)).
t(capdu, true, ('lc 4' :-
    phrase(lc(Qc), [+0,+1,+0]) -> Qc == present(extended,256)
)).
t(capdu, false, ('lc 5' :-
    phrase(lc(_), [+0,+0,+0])
)).
t(capdu, true, ('lc 6' :-
    findall(t, phrase(lc(absent), _), L), length(L, 1)
)).
t(capdu, true, ('lc 7' :-
    findall(t, phrase(lc(present(short,_)), _), L), length(L, 255)
)).
t(capdu, true, ('lc 8' :-
    findall(t, phrase(lc(present(extended,_)), _), L), length(L, 65535)
)).
t(capdu, false, ('nbytes/2 terminates on cyclic list with ground elements' :-
    T = [1|T] -> phrase(nbytes(T, _), _)
)).
t(capdu, true, ('nbytes 2' :-
    phrase(nbytes(X,5), Y) ->
        X = [A,B,C,D,E],
        Y = [+A,+B,+C,+D,+E]
)).
t(capdu, true, ('nbytes 3' :-
    phrase(nbytes(X,N), [+1,+2,+3]) ->
        N == 3,
        X == [1,2,3]
)).
t(capdu, fail, ('nbytes/2 terminates on cyclic list with free elements' :-
    W=[_|W] -> phrase(nbytes(W,_), W)
)).
t(capdu, true, ('nbytes 5' :-
    phrase(nbytes([1,2,3], N), W) ->
        W == [+1,+2,+3],
        N == 3
)).
t(capdu, true, ('nbytes 6' :-
    phrase(nbytes(W, 3), W) ->
        (acyclic_term(W) -> write(xsb_bug); true),
        length(W, 3)
)).
t(capdu, true, ('nbytes 7' :-
    catch(phrase(nbytes(_, a), _), error(E,_), true) ->
        (
            E == type_error(evaluable,a/0)
        ;   E == type_error(evaluable,a)
        )
)).
t(capdu, true, ('nbytes 8' :-
    catch(phrase(nbytes(_, a(_)), _), error(E,_), true) ->
        (
            E == instantiation_error
        ;   E == type_error(evaluable,a/1)
        ;   E = type_error(evaluable,a(_))
        )
)).
t(capdu, true, ('cm 1' :-
    cm(0x00, 0xA4, 0x04, 0x00, Qc, Qe, C) ->
        Qc = present(_,_),
        Qe = present(_,_),
        C == select(aid_prefix,first,fci)
)).
t(capdu, true, ('cm 2' :-
    cm(0x80, 0xA8, 0x00, 0x00, Qc, Qe, C) ->
        Qc = present(_,_),
        Qe = present(_,_),
        C == get_processing_options
)).
t(capdu, true, ('cm 3' :-
    cm(0x00, 0xB2, 0x01, 0x14, Qc, Qe, C) ->
        Qc == absent,
        Qe = present(_,_),
        C == read_record(2,record_number(exact,1))
)).
t(capdu, true, ('cm 4' :-
    cm(0x00, 0xB2, 0x02, 0x1C, Qc, Qe, C) ->
        Qc == absent,
        Qe = present(_,_),
        C == read_record(3,record_number(exact,2))
)).
t(capdu, true, ('bits 1' :-
    bits(8, [1,0,0,0,0,0,0,0], 0x80)
)).
t(capdu, true, ('bits 2' :-
    bits(L, [1,0,0,0,0,0,0,0], 0x80) -> L == 8
)).
t(capdu, true, ('bits 3' :-
    bits(8, [1,0,0,0,0,0,0,0], N) -> N == 0x80
)).
t(capdu, true, ('bits 4' :-
    bits(8, Bits, 0x81) -> Bits == [1,0,0,0,0,0,0,1]
)).
t(capdu, skip, ('ber 1' :-
    Fci = [111-[132-[50,80,65,89,46,83,89,83,46,68,68,70,48,49],165-[48908-[97-
    [79-[160,0,0,1,82,48,16],80-[67,111,110,116,97,99,116,108,101,115,115,68,80,
    65,83],135-[1],40746-[0,6]],97-[79-[160,0,0,3,36,16,16,1],80-[68,105,115,99,
    111,118,101,114],135-[2]]]]]],
    phrase(ber(Fci,L), E),
    maplist((is), Encoded, E) ->
    84 =:= L,
    Encoded == [111,82,132,14,50,80,65,89,46,83,89,83,46,68,68,70,48,49,165,64,
    191,12,61,97,34,79,7,160,0,0,1,82,48,16,80,15,67,111,110,116,97,99,116,108,
    101,115,115,68,80,65,83,135,1,1,159,42,2,0,6,97,23,79,8,160,0,0,3,36,16,16,
    1,80,8,68,105,115,99,111,118,101,114,135,1,2]
)).
test(capdu, skip, ('apdu 1' :-
    Input = [+0x00,+0xA4,+0x04,+0x00,+0x0E,+0x32,+0x50,+0x41,+0x59,+0x2E,+0x53,
    +0x59,+0x53,+0x2E,+0x44,+0x44,+0x46,+0x30,+0x31,+0x00],
    phrase(command_response_pair, Input, Output) ->
    Output == [-(111),-(82),-(132),-(14),-(50),-(80),-(65),-(89),-(46),-(83),
    -(89),-(83),-(46),-(68),-(68),-(70),-(48),-(49),-(165),-(64),-(191),-(12),
    -(61),-(97),-(34),-(79),-(7),-(160),-(0),-(0),-(1),-(82),-(48),-(16),-(80),
    -(15),-(67),-(111),-(110),-(116),-(97),-(99),-(116),-(108),-(101),-(115),
    -(115),-(68),-(80),-(65),-(83),-(135),-(1),-(1),-(159),-(42),-(2),-(0),-(6),
    -(97),-(23),-(79),-(8),-(160),-(0),-(0),-(3),-(36),-(16),-(16),-(1),-(80),
    -(8),-(68),-(105),-(115),-(99),-(111),-(118),-(101),-(114),-(135),-(1),-(2),
    -(144),-(0)]
)).
