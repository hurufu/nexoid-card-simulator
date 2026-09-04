% Main entry into card simulator.

main :- main([]).

main(FsPrev) :- phrase(exchange(FsPrev, FsNext), []) -> main(FsNext); true.

exchange(FsPrev, FsNext) --> get_bytes(rd), command_response_pair(FsPrev, FsNext), put_bytes(wr).

put_bytes(Stream) --> [] ; [-Byte], { put_byte(Stream, Byte) }, put_bytes(Stream).
get_bytes(Stream, B, A) :-
    get_byte(Stream, Byte), Byte >= 0, A = [+Byte|X], (X = B; get_bytes(Stream, B, X)).

% section 5.1
command_response_pair(FsPrev, FsNext) --> command(Cmd, Dt, Qe), response(Cmd, Dt, Qe, FsPrev, FsNext).

response(Cmd, Dt, Qe, FsPrev, FsNext) --> { response_for(Cmd, Dt, Qe, Response, FsPrev, FsNext) }, output(Response).

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
