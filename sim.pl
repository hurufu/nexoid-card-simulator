:- use_module(library(dif)).

main :- phrase(exchange, []) -> main; true.

exchange --> get_bytes(rd), command_response_pair, put_bytes(wr).

% section 5.1
command_response_pair --> command(Cmd, Dt, Qe), response(Cmd, Dt, Qe).

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

response(Cmd, Dt, Qe) --> { response_for(Cmd, Dt, Qe, Response) }, output(Response).

singlet(Lowest, A) --> rbyte(A), { A >= Lowest }.
doublet(Lowest, N) --> rbyte(A), rbyte(B), { N is (A << 8) + B, N >= Lowest }.

nbytes(L, N) --> foldl_(count_(in_, N), L, 0, N).
in_(E) --> [+E].

rbyte(N) --> [+N], { between(0, 255, N) }.

put_bytes(Stream) --> [] ; [-Byte], { put_byte(Stream, Byte) }, put_bytes(Stream).
get_bytes(Stream, B, A) :-
    get_byte(Stream, Byte), Byte >= 0, A = [+Byte|X], (X = B; get_bytes(Stream, B, X)).

response_for(Cmd, Dt, Qe, Response) :-
    tsv_response_for(Cmd, Dt, Tsv, Status),
    phrase(rapdu(Tsv,Le,Status), Tmp),
    maplist((is), Response, Tmp),
    le_ok(Qe, Le).

tsv_response_for(select(aid_prefix,Occurrence,fci), Dt, Fci, completed(ok)) :-
    append(Dt, _, L),
    select(by_dfname, Occurrence, Fid, L),
    applicable_response(Fid, 0x6F, Fci),
    !.
tsv_response_for(get_processing_options, _, Gpo, completed(ok)) :-
    applicable_response(22090, 0x77, Gpo),
    !.
tsv_response_for(_, _, _, error(state_of_nvram(unchanged,no_info))).

le_ok(Qe, Length) :- le_max(Qe, Max), Length =< Max.
le_max(present(short,Ne), Max) :- Ne =:= 0 -> Max = 256; Max = Ne.
le_max(present(extended,Ne), Max) :- Ne =:= 0 -> Max = 65535; Max = Ne.

output([]) --> [].
output([H|T]), [-H] --> output(T).

rapdu(Tsv, Le, Status) --> ber(Tsv, Le), status(Status).
ber(tsv(T,S,V), TL+LL+L) --> tag(T, TL), len(L, LL), value(S, V, L).
tag(T, L) --> { tag_bytes(T, B, L) }, B.
len(L, 1) --> [L].
value(element(_,C), V, N) --> { value_between(C, N) }, length_(V, N).
value(template, [], 0) --> [].
value(template, [H|T], L1 + L2) --> ber(H, L1), value(template, T, L2).
status(Status) --> { sw_db(Sw1, Sw2, Status) }, [Sw1,Sw2].

tag_bytes(T, B, L) :-
    L is ceiling(log(T + 1) / log(2) / 8),
    length(B, L),
    number_bytes(T, B).

value_between(constraint(byte,L,U), N) :- between(L, U, N).
value_between(constraint(bcd,L,U), N) :- between(L, U, X), N is ceiling(X/2).

in_alphabet(Spec) --> { spec_alphabet_codes(Spec, L) }, in_alphabet_list(L).
in_alphabet_list(_) --> [].
in_alphabet_list(L) --> [C], { memberchk(C, L) }, in_alphabet_list(L).

spec_alphabet_codes(Spec, AlphabetCodes) :-
    spec_alphabet_chars(Spec, AlphabetChars),
    maplist(char_code, AlphabetChars, AlphabetCodes).

spec_alphabet_chars(Spec, AlphabetChars) :-
    spec_alphabet_names(Spec, AlphabetNames),
    maplist(alphabet, AlphabetNames, Y),
    append(Y, AlphabetChars).


spec_alphabet_names(ans, [ascii(space),ascii(punct)|L]) :- spec_alphabet_names(an, L).
spec_alphabet_names(an, [ascii(digit)|A]) :- spec_alphabet_names(a, A).
spec_alphabet_names(a, [ascii(lower),ascii(upper)]).

alphabet(ascii(digit), ['0','1','2','3','4','5','6','7','8','9']).
alphabet(ascii(upper), ['A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z']).
alphabet(ascii(lower), ['a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z']).
alphabet(ascii(space), [' ']).
alphabet(ascii(punct), [!,#,$,&,'\'','(',')',*,+,-,'.','/',':',';','<','=','>','?',@,'[',\,']','^','_','`','{','|','}','~','%','"']).%'


number_bytes(N, [A]) :-
    bits(8, [A0,A1,A2,A3,A4,A5,A6,A7], N),
    maplist(bits(8), [[A0,A1,A2,A3,A4,A5,A6,A7]],[A]).
number_bytes(N, [A,B]) :-
    bits(16, [A0,A1,A2,A3,A4,A5,A6,A7,B0,B1,B2,B3,B4,B5,B6,B7], N),
    maplist(bits(8), [[A0,A1,A2,A3,A4,A5,A6,A7],[B0,B1,B2,B3,B4,B5,B6,B7]],[A,B]).

% Interface
nesting(Df, Fid) :- pc(Df, Fid), (T = df; T = ddf), type_fid(T, Df).
type_fid(Type, Fid) :- ft(Fid, Type).
type_fid(T, Fid) :- (T = df; T = ddf), (C = mf; C = adf), ft(Fid, C).
abs(Fid, Path) :- phrase(absolute_path(Fid), Path).
absolute_path(16128) --> [16128].
absolute_path(C) --> { nesting(P,C) }, absolute_path(P), [C].
dfname(Fid, A) :- fn(Fid, A).
fid_tag_property(F, 0x84, P) :- fn(F, P).
fid_tag_property(F, T, P) :- pp(F, T, P).

% Commands (ISO 7816-4 5.3.1.1)
select(by_dfname, first, Fid, DfName) :- once(dfname(Fid, DfName)).
select(by_fid, first, Fid, Fid) :- once(ft(Fid, _)).
select(by_path, first, Fid, Path) :- once(abs(Fid, Path)).

%% tru(A, B).
%
% Special unification of tag-spec-value terms. It ignores leaf order with the
% same prefix. It has a special provisions for open lists, so it can be
% used to merge terms if they are open.
tru(tsv(A,element(B,C),V), tsv(A,element(B,C),V)).
tru(tsv(A,template,VL), tsv(A,template,VR)) :- trul(VL, VR).

%% trul(A, B).
%
% Special unification of a (possibly open) list of tag-spec-value terms.
trul(L, R) :- var(L), var(R) -> true; L = R, L = [].
trul([HL|TL], [HR|TR]) :- tru(HL, HR), trul(TL, TR).
trul([HL|TL], [HR|TR]) :- \+ tru(HL, HR), trux(TR, HL), trux(TL, HR).

%% trux(List, Element).
%
% Element membership using special unification within open List of t-s-v terms.
trux([H|_], X) :- tru(H, X).
trux([H|T], X) :- \+ tru(H, X), trux(T, X).


test_tru :- findall(N, test_tru(N), P), maplist(writeln, P).

test_tru(test_reflexivity(N)) :-
    nth1(N, [
        _,
        tsv(111,template,[]),
        tsv(111,element(_,_),[])
    ], X),
    (tru(X, X) -> true).
test_tru(test_symmetry(N)) :-
    nth1(N, [
        [
            tsv(0,template,[]),
            tsv(0,template,[])
        ]
    ], [L,R]),
    (tru(L, R) -> tru(R, L)).
test_tru(test_transitivity(N)) :-
    nth1(N, [
        [
            tsv(0,template,[]),
            tsv(0,template,[]),
            tsv(0,template,[])
        ]
    ], [A,B,C]),
    (tru(A, B), tru(B, C) -> tru(A, C)).
test_tru( 4) :- E = tsv(33,element(_,_),[]), tru(X, E), X == E.
test_tru(-4) :- E = tsv(33,element(_,_),[]), tru(E, X), X == E.
test_tru( 5) :- \+ tru(tsv(1,element(_,_),_), tsv(2,_,_)).
test_tru(-5) :- \+ tru(tsv(2,_,_), tsv(1,element(_,_),_)).
test_tru( 6) :-
    A = tsv(1,template,_),
    B = tsv(1,template,[tsv(33,element(_,_),_)]),
    tru(A, B),
    A == B.
test_tru( 7) :-
    L = tsv(1,template,[tsv(34,element(BL,CL),VL)|RL]),
    R = tsv(1,template,[tsv(33,element(BR,CR),VR)|RR]),
    tru(L, R),
    RL = [tsv(33,element(BR,CR),VR)|RRL],
    RR = [tsv(34,element(BL,CL),VL)|RRR],
    var(RRL),
    var(RRR),
    RRL \== RRR.
test_tru( 8) :-
    EL = tsv(99,element(_,_),_),
    ER = tsv(98,element(_,_),_),
    L = tsv(1,template,[tsv(2,template,[EL|_R1L])|_R2L]),
    R = tsv(1,template,[tsv(2,template,[ER|_R1R])|_R2R]),
    once(tru(L, R)).

applicable_response(Fid, Root, X) :-
    all_applicable_nested_non_templates(Fid, Root, Chains),
    maplist(trul([X]), Chains).

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

%% EMV tag database %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% {

tag_properties_defaults(Id, Kernel, L, D) :- maplist(tag_property_default(Id,Kernel), L, D).
tag_properties(Id, Kernel, L) :- maplist(tag_property(Id,Kernel), L).

tag_property_default(Id, Kernel, Property, Default) :-
    ground(Default),
    (
        \+ tag_property(Id, Kernel, Property) ->
            Property = Default
        ;   tag_property(Id, Kernel, Property)
    ).

tag_property(Id, Kernel, value(Id)) :- tag_db(Id, _, Kernel, _).
tag_property(Id, Kernel, length(L)) :- tag_db(Id, _, Kernel, _), L is ceiling(log(Id + 1) / log(2) / 8).
tag_property(Id, Kernel, name(N)) :- tag_db(Id, _, Kernel, N).
tag_property(Id, Kernel, spec(S)) :- tag_db(Id, S, Kernel, _).

%% fmt(FormatSpecification)// is multi.
%
% Data element specification format.
fmt(false) --> fmt_false.
fmt(template) --> fmt_template.
fmt(element(F,constraint(C,L,U))) --> fmt_format(F), { fmt_constraint(F, C), fmt_max_unspec(M, Y) }, fmt_lower_upper(M, Y, L, U).
fmt_template --> [t].
fmt_false --> [-].
fmt_format(b) --> [b].
fmt_format(n) --> [n].
fmt_format(cn) --> [c,n].
fmt_format(a) --> [a].
fmt_format(an) --> [a,n].
fmt_format(ans) --> [a,n,s].
fmt_format(var) --> [v,a,r].
fmt_range --> [.,.].
fmt_any --> [.,.,.].
fmt_unspec --> [v,a,r].
fmt_spc --> [' '].
fmt_lower_upper(_, Y, 0, Y) --> fmt_any, fmt_unspec.
fmt_lower_upper(M, _, 0, U) --> fmt_any, between__(1, M, U).
fmt_lower_upper(M, Y, L, Y) --> { between(1, M, L) }, fmt_spc, fmt_unspec.
fmt_lower_upper(M, _, L, L) --> between__(1, M, L).
fmt_lower_upper(M, Y, L, Y) --> between__(1, M, L), fmt_range, fmt_unspec.
fmt_lower_upper(M, _, L, U) --> between__(1, M, L), fmt_range, between__(1, M, U), { L < U }.
fmt_constraint(cn,  bcd ).
fmt_constraint(n,   bcd ).
fmt_constraint(b,   byte).
fmt_constraint(a,   byte).
fmt_constraint(an,  byte).
fmt_constraint(ans, byte).
fmt_max_unspec(252, 253).
%fmt_max_unspec(252, 16).
%fmt_max_unspec(252, _).

tag_spec_db(T, K, S, N) :-
    tag_db(T, K, Atom, N),
    atom_chars(Atom, Codes),
    phrase(fmt(S), Codes).

%% tag_db(EmvTag, Spec, ApplicableKernel, Name) is fact.
%
tag_db(0x4F,   _, 'b5..16', "Application Identifier (AID) – Card").
tag_db(0x50,   _, 'b1..16', "Application Label").
tag_db(0x57,   _, 'b...19', "Track 2 Equivalent Data").
tag_db(0x5A,   _, 'cn...19', "Application Primary Account Number (PAN)").
tag_db(0x5F20, _, 'ans2..26', "Cardholder Name").
tag_db(0x5F24, _, 'n6', "Application Expiration Date").
tag_db(0x5F25, _, 'n6', "Application Effective Date").
tag_db(0x5F2A, _, 'n3', "Transaction Currency Code").
tag_db(0x5F30, _, 'n3..4', "Service Code").
tag_db(0x5F34, _, 'n2', "Application PAN Sequence Number").
tag_db(0x61,   _, 't', "Application Template").
tag_db(0x6F,   _, 't', "File Control Information (FCI)").
tag_db(0x77,   _, 't', "Response Message Template Format 2").
tag_db(0x82,   _, 'b1..6', "File descriptor").
tag_db(0x83,   _, 'b2', "File identifier").
tag_db(0x84,   _, 'b...16', "Dedicated File (DF) Name").
tag_db(0x87,   _, 'b1', "Application Priority Indicator").
tag_db(0x87,   _, 'b1', "Application Priority Indicator").
tag_db(0x8A,   _, 'an2', "Authorisation Response Code").
tag_db(0x8C,   _, 'b...252', "Card Risk Management DOL 1").
tag_db(0x8D,   _, 'b...252', "Card Risk Management DOL 2").
tag_db(0x8E,   _, 'b...252', "Cardholder Verification Method (CVM) List").
tag_db(0x95,   _, 'b5', "Terminal Verification Results (TVR)").
tag_db(0x9A,   _, 'n6', "Transaction Date").
tag_db(0x9C,   _, 'n2', "Transaction Type").
tag_db(0x9F02, _, 'n12', "Amount, Authorised (numeric)").
tag_db(0x9F03, _, 'n12', "Amount, Other (numeric)").
tag_db(0x9F07, _, 'b2', "Application Usage Control (AUC)").
tag_db(0x9F08, _, 'b2', "Application Version").
tag_db(0x9F0D, _, 'b5', "Issuer Action Code (IAC) - Default").
tag_db(0x9F0E, _, 'b5', "Issuer Action Code (IAC) - Denial").
tag_db(0x9F0F, _, 'b5', "Issuer Action Code (IAC) - Online").
tag_db(0x9F10, _, 'b...32', "Issuer Application Data").
tag_db(0x9F1A, _, 'n3', "Terminal Country Code").
tag_db(0x9F26, _, 'b8', "Application Cryptogram").
tag_db(0x9F27, _, 'b1', "Cryptogram Information Data").
tag_db(0x9F28, _, 'b2', "Contactless Application Capabilities Type").
tag_db(0x9F2A, _, 'b2', "Kernel Identifier").
tag_db(0x9F35, _, 'n2', "Terminal Type").
tag_db(0x9F36, _, 'b2', "Application Transaction Counter (ATC)").
tag_db(0x9F37, _, 'b4', "Unpredictable Number (UN)").
tag_db(0x9F38, _, 'b...64', "Processing Options DOL (PDOL)").
tag_db(0x9F42, _, 'n3', "Application Currency Code").
tag_db(0x9F5A, 4, 'b1..4', "Membership Product Identifier").
tag_db(0x9F5A, 3, 'b1..16', "Application Program Identifier").
tag_db(0x9F5B, 2, 'b...252', "Data Storage DOL (DSDOL)"). %      ''
tag_db(0x9F5B, 3, 'b...252', "Issuer Script Results").    % Max size is var.
tag_db(0x9F5B, 4, '-', "Product Membership Number").
tag_db(0x9F63, 2, 'b6', "Positions of UN and ATC in Track 1 (PUNATC) ").
tag_db(0x9F64, 2, 'b1', "Number of ATC digits (NATC) in Track 1").
tag_db(0x9F65, 2, 'b2', "Positions of CVC3 (PCVC3) in Track 2").
tag_db(0x9F66, 3, 'b4', "Terminal Transaction Qualifiers (TTQ)").
tag_db(0x9F6C, _, 'b2', "Card Transaction Qualifiers (CTQ)").
tag_db(0xA5,   _, 't', "FCI Proprietary Template").
tag_db(0xBF0C, _, 't', "FCI Issuer Discretionary Data").

nesting_applicability(0x6F, 0x84).
nesting_applicability(0x6F, 0xA5).
nesting_applicability(0xA5, 0x50).
nesting_applicability(0xA5, 0x9F38).
nesting_applicability(0xA5, 0xBF0C).
nesting_applicability(0xBF0C, 0x61).
nesting_applicability(0x61, 0x4F).
nesting_applicability(0x61, 0x50).
nesting_applicability(0x61, 0x87).
nesting_applicability(0x61, 0x9F5A).
nesting_applicability(0x77, 0x57).
nesting_applicability(0x77, 0x82).
nesting_applicability(0x77, 0x5F34).
nesting_applicability(0x77, 0x9F10).
nesting_applicability(0x77, 0x9F26).
nesting_applicability(0x77, 0x9F27).
nesting_applicability(0x77, 0x9F36).
nesting_applicability(0x77, 0x9F6C).

sw_db_extended(Sw1, Sw2, Status) :- sw_db(Sw1, Sw2, Status).
sw_db_extended(Sw1, Sw2, Status) :- sw_db_rfu(Sw1, Sw2, Status).

sw_db_rfu(0x6A, Sw2, error(wrong_parameters(rfu))) :-
    between(0, 255, Sw2), \+ sw_db(0x6A, Sw2, _).

sw_db(0x62, 0x00, warning(state_of_nvram(unchanged,no_info))).
sw_db(0x63, 0x00, warning(state_of_nvram(changed,no_info))).
sw_db(0x64, 0x00, error(state_of_nvram(unchanged,no_info))).
sw_db(0x64, 0x01, error(state_of_nvram(unchanged,command_timeout))).
sw_db(0x65, 0x00, error(state_of_nvram(changed,no_info))).
sw_db(0x66, 0x00, error(command_not_allowed(no_info))).
sw_db(0x6A, 0x00, error(wrong_parameters(no_info))).
sw_db(0x6A, 0x80, error(wrong_parameters(bad_data))).
sw_db(0x6A, 0x81, error(wrong_parameters(function_not_supported))).
sw_db(0x6A, 0x82, error(wrong_parameters(file_not_found))).
sw_db(0x6A, 0x83, error(wrong_parameters(record_not_found))).
sw_db(0x6A, 0x84, error(wrong_parameters(insufficient_space))).
sw_db(0x6A, 0x85, error(wrong_parameters(lc_inconsistent_with_tlv_structure))).
sw_db(0x6A, 0x86, error(wrong_parameters(incorrect_p1_or_p2))).
sw_db(0x6A, 0x87, error(wrong_parameters(lc_inconsistent_with_p1_or_p2))).
sw_db(0x6A, 0x88, error(wrong_parameters(referenced_data_not_found))).
sw_db(0x6A, 0x89, error(wrong_parameters(file_already_exists))).
sw_db(0x6A, 0x8A, error(wrong_parameters(df_name_already_exists))).
sw_db(0x6A, 0xF0, error(wrong_parameters(wrong_value))).
sw_db(0x6F, 0x00, error(internal(aborted))).
sw_db(0x6F, 0xFF, error(internal(dead))).
sw_db(0x90, 0x00, completed(ok)).
sw_db(0x90, 0x01, warning(pin_not_verified_3_or_more_tries_left)).
sw_db(0x9F, N   , completed(response_size(N))) :- between(0, 255, N).

% Tests
db_consistent :- duplicates, ambiguous_type, ef_hosts_files, db_rules_consistent.
db_rules_consistent :- forall(clause(db_check(run,R),_), db_check(_,R)).
duplicates :- forall(ft(F, _), findall(X, ft(F,X), [_])).
ambiguous_type :- \+((ft(Fid, T1), ft(Fid, T2), T1 \= T2)).
ef_hosts_files :- \+((ft(Ef, ef), pc(Ef, _))).
%ef_has_dfname :- forall(fn(F, _), type(df, F)).
%

:- dynamic(db_check/2).

db_check(run, all_constructed_tags_are_templates) :-
    forall((tag_spec_db(T,_,S,_),bits(8,[_,_,1|_],T)), S == template).
db_check(run, all_primitive_tags_are_data_elements) :-
    forall((tag_spec_db(T,_,S,_),bits(8,[_,_,0|_],T)), S = element(_,_)).
db_check(run, all_templates_are_constructed) :-
    forall(tag_spec_db(T,_,template,_), ((E=8;E=16),bits(E,[_,_,1|_],T))).
db_check(run, all_data_elements_are_primitive) :-
    forall(tag_spec_db(T,_,element(_,_),_), ((E=8;E=16),bits(E,[_,_,0|_],T))).
db_check(run, every_tag_spec_is_parseable) :-
    forall(tag_db(T, K, _, N), (tag_spec_db(T, K, _, N) -> true; throw(error(tag(T),_)))).
db_check(run, only_templates_can_nest_other_elements) :-
    tag_db_kernel(K),
    forall(nesting_applicability(T,_), tag_spec_db(T,K,template,_)).
db_check(run, every_template_defines_nesting) :-
    tag_db_kernel(K),
    forall(tag_spec_db(T,K,template,_), nesting_applicability(T,_)).
db_check(run, none_of_the_non_templates_can_nest_other_elements) :-
    forall(tag_spec_db(T,_,element(_,_),_), ((\+nesting_applicability(T,_)) -> true; throw(error(tag(T),_)))).
db_check(skip, every_non_template_is_nested_somewhere) :-
    forall(tag_spec_db(T,_,element(_,_),_), nesting_applicability(_,T)).
db_check(run, sw_db_extended_terminates_on_the_most_generic_query) :-
    sw_db_extended(_,_,_), fail; true.

%% }
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

dol([]) --> [].
dol([H|T]) -->
    {   tag_db_kernel(K),
        tag_db(H, Type, K, _),
        tag_property(H, _, length(1)),
        phrase(value(Type, _, N), _) }, [H,N], dol(T).
dol([H|T]) -->
    {   tag_db_kernel(K),
        tag_db(H, Type, K, _),
        tag_property(H, _, length(2)),
        number_bytes(H, [A,B]),
        phrase(value(Type, _, N), _) }, [A,B,N], dol(T).

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

%% bits(-Exponent, -Bits, +Number) is multi.
%% bits(+Exponent, -Bits, +Number) is semidet.
%% bits(+Exponent, +Bits, -Number) is semidet.
%
bits(Exp, RBits, N) :-
    length(Bits, Exp),
    reverse(Bits, RBits),
    (ground(N) ->
        foldl(bb(N), Bits, 0, Exp), 1 << Exp > N
    ;   foldl(bv, Bits, (0,0), (Expression,Check)), N is Expression, Exp =:= Check).

bb(Byte, Bit, Exp, NextExp) :- Bit is (Byte /\ 1 << Exp) >> Exp, NextExp is Exp + 1.
bv(Bit, (A,Exp), (A + (Bit << Exp),(Exp + 1))).

% EMV Book 3 table CCD 3
cryptogram_information_data([0,0,0,0,0,0,0,0], aac).
cryptogram_information_data([0,1,0,0,0,0,0,0], tc).
cryptogram_information_data([1,0,0,0,0,0,0,0], arqc).

% EMV Book C-3 pp 91-92
ctq(Qualifiers, Bytes) :-
    Q1 = [online_pin_required,signature_required,go_online_if_oda_fails_and_reader_is_online_capable,
          switch_interface_if_oda_fails,go_online_if_application_expired,
          switch_interface_for_cash,switch_interface_for_cashback,false],
    Q2 = [cdcvm_performed,card_supports_issuer_update_processing_at_the_pos,
          false, false,false,false,false,false],
    maplist(qual(Qualifiers), Q1, B1),
    maplist(qual(Qualifiers), Q2, B2),
    maplist(bits(8), [B1,B2], Bytes).

qual(Qualifiers, Name, Bit) :- Name \= false, member(Name, Qualifiers) -> Bit = 1; Bit = 0.

% https://sdk.supply/comparison-of-emv-compatible-applications
% 9F10
visa_discretionary_data([B1,B2,0x11,0x03,B5,0x00,0x00]) :-
    cryptogram_version_number(B1),
    derivation_key_indicator(B2),
    cvr(A, B, C, D, E, F),
    phrase(cvr_1(A, B, C, D, E, F), Bits),
    bits(8, Bits, B5).

% https://sdk.supply/the-standard-of-emv-entry-point-specification/
% 9F28
contactless_application_capabilities(EmvApplicationPresent, NativeApplicationPresent, ProcessingPreferenceIndicator, TerminalApplication, [B1,B2]) :-
    phrase(contactless_application_capabilities_1(EmvApplicationPresent, NativeApplicationPresent, ProcessingPreferenceIndicator), Bits1),
    phrase(contactless_application_capabilities_2(TerminalApplication), Bits2),
    maplist(bits(8), [Bits1,Bits2], [B1,B2]).
contactless_application_capabilities_1(EmvApplicationPresent, NativeApplicationPresent, ProcessingPreferenceIndicator) -->
    bit(EmvApplicationPresent), bit(NativeApplicationPresent), bit(ProcessingPreferenceIndicator), [0,0,0,0,0].
% Name of the terminal application associated with this application
contactless_application_capabilities_2(native_jcb) --> [0,0,0,0,0,0,0,1].
contactless_application_capabilities_2(mastercard_paypass) --> [0,0,0,0,0,0,1,0].
contactless_application_capabilities_2(visa_contactless) --> [0,0,0,0,0,0,1,1].
contactless_application_capabilities_2(numeric(N)) --> [A,B,C,D,E,F,G,H], { bits(8, [A,B,C,D,E,F,G,H], N), N > 3, N < 255 }.

%% cvr_1(A, B, C, D, E, F).
%
% @source https://paymentcardtools.com/emv-tag-decoders/iad
% C = 1 when Issuer Authentication performed and failed
% D = 1 when Offline PIN verification performed
% E = 1 when Offline PIN verification failed
% F = 1 when Unable to go online
%
% All of them must be 0 otherwise
%
% @source EMB Book 3 section C7.3
%
cvr_1(A,B,C,D,E,F) --> cvr_second_generate_ac(A), cvr_first_generate_ac(B), bit(C), bit(D), { D = 0 -> E = 0; D = 1 }, bit(E), bit(F).

% Application Cryptogram Type Returned in 2nd GENERATE AC
cvr_second_generate_ac(aac) --> [0,0].
cvr_second_generate_ac(tc) --> [0,1].
% 2nd GENERATE AC not requested
cvr_second_generate_ac(not_requested) --> [1,0].

% Application Cryptogram Type returned in 1st GENERATE AC
cvr_first_generate_ac(aac) --> [0,0].
cvr_first_generate_ac(tc) --> [0,1].
cvr_first_generate_ac(arqc) --> [1,0].

bit(1) --> [1].
bit(0) --> [0].


:- meta_predicate(foldl_(5,?,?,?,?,?)).
%% foldl_(G__3, L1, V0, Vlast)//
%
foldl_(_, [], V, V) --> [].
foldl_(G__3, [H1|T1], V0, Vlast) --> { acyclic_term(T1) }, call(G__3, H1, V0, Vnext), foldl_(G__3, T1, Vnext, Vlast).


%% length_(L, N)//
%
length_(L, N) --> { acyclic_term(L) }, foldl_(count_(noop_, N), L, 0, N).

:- meta_predicate(count_(3,?,?,?,?,?,?)).
count_(T_1, N, E, V0, Vn) --> { \+var(N), V0 =:= N -> false; Vn is V0 + 1 }, call(T_1, E).
noop_(E) --> [E].

between__(L, U, N) --> { between(L, U, N) }, number__(N).
number__(N) --> { prolog_dialect(swi), number_chars(N, Cs) }, Cs.
