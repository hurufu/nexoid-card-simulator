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

response(Cmd, Dt, Qe) -->
    {
        response_for(Cmd, Dt, Qe, Tv, Response, Sw1, Sw2),
        format_apdu_pair(user_error, Cmd, Dt, Qe, Tv, Sw1, Sw2)
    }, output([Sw1,Sw2]), output(Response).

singlet(Lowest, A) --> rbyte(A), { A >= Lowest }.
doublet(Lowest, N) --> rbyte(A), rbyte(B), { N is (A << 8) + B, N >= Lowest }.

nbytes(L, N) --> foldl_(count_(in_, N), L, 0, N).
in_(E) --> [+E].

rbyte(N) --> [+N], { between(0, 255, N) }.

put_bytes(Stream) --> [] ; [-Byte], { put_byte(Stream, Byte) }, put_bytes(Stream).
get_bytes(Stream, B, A) :-
    get_byte(Stream, Byte), Byte >= 0, A = [+Byte|X], (X = B; get_bytes(Stream, B, X)).

response_for(select(aid_prefix,Occurrence,fci), Dt, Qe, Fci, Rs, 0x90, 0x00) :-
    open_list(Dt, L-_),
    select(by_dfname, Occurrence, Fid, L),
    fci(Fid, Fci),
    phrase(ber(Fci,Length), Tmp),
    maplist((is), Rs, Tmp),
    le_ok(Qe, Length).
response_for(get_processing_options, _, Qe, Tv, Rs, 0x90, 0x00) :-
    Tv = [0x77-GPO],
    phrase(gpo_(22090), GPO),
    phrase(ber(Tv, Length), Tmp),
    maplist((is), Rs, Tmp),
    le_ok(Qe, Length).

le_ok(Qe, Length) :- le_max(Qe, Max), Length =< Max.
le_max(present(short,Ne), Max) :- Ne =:= 0 -> Max = 256; Max = Ne.
le_max(present(extended,Ne), Max) :- Ne =:= 0 -> Max = 65535; Max = Ne.

%% Effectful functions used for debugging %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% {

%% format_apdu_pair(@Stream, +Cmd, +Dt, +Qe, +Tv, +Sw1, +Sw2) is det.
format_apdu_pair(Stream, Cmd, Dt, Qe, Tv, Sw1, Sw2) :-
    format_capdu(Stream, Cmd, Dt, Qe),
    format_rapdu(Stream, Tv, Sw1, Sw2).

%% format_capdu(@Stream, +Cmd, +Dt, +Qe) is det.
format_capdu(Stream, Cmd, Dt, Qe) :-
    format(Stream, '~|~40+< ~w ', [Cmd]),
    format_ascii_or_hex_list(Stream, Dt),
    format(Stream, ' ~w~n', [Qe]).

%% format_capdu(@Stream, +Tv, +Sw1, +Sw2) is det.
format_rapdu(Stream, Tv, Sw1, Sw2) :-
    format(Stream, '~|~40+> [~|~`0t~16R~2+~|~`0t~16R~2+~|]~n', [Sw1,Sw2]),
    format_explain(Tv, ['-'], Stream),
    format(Stream, '~n', []).

format_explain([], Prefix, Stream) :- format(Stream, '~s', [Prefix]).
format_explain([T-V|Rest], Prefix, Stream) :-
    tag_properties_defaults(T, [name(N),spec(S)], [name("Unknown"),spec(false)]),
    format(Stream, '~s 0x~16R ~s (~w): ', [Prefix,T,N,S]),
    format_value(S, V, Prefix, Stream),
    format(Stream, '~n', []),
    format_explain(Rest, Prefix, Stream).

format_value(t, Value, Prefix, Stream) :-
    format(Stream, '~n', []),
    format_explain(Value, ['+'|Prefix], Stream).
format_value(b(_,_), Value, _, Stream) :- format_ascii_or_hex_list(Stream, Value).
format_value(an(_,_), Value, _, Stream) :- format_printable_list(Stream, Value).
format_value(ans(_,_), Value, _, Stream) :- format_printable_list(Stream, Value).
format_value(n(_), Value, _, Stream) :- format_printable_list(Stream, Value).
format_value(cn(_,_), Value, _, Stream) :- format_hex_list(Stream, Value).

format_hex_list(Stream, List) :- format_list(List, Stream, '~|~`0t~16R~2+').
format_printable_list(Stream, List) :- format(Stream, '"~s"', [List]).

format_ascii_or_hex_list(Stream, List) :-
    phrase(in_alphabet(ansp), List) ->
        format_printable_list(Stream, List)
    ;   format_hex_list(Stream, List).

format_list([], _, _).
format_list([H|T], Stream, Format) :-
    format(Stream, Format, [H]),
    format_list(T, Stream, Format).
%% }
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Describes list difference an it's prefix (regular list)
open_list([], X-X).
open_list([H|D], [H|T]-X) :- open_list(D, T-X).

output([]) --> [].
output([H|T]), [-H] --> output(T).


ber([], 0) --> [].
ber([Tlv|Rest], L0+L1) --> tlv(Tlv, L0), ber(Rest, L1).
tlv(T-V, L0+L1) --> tag(T, spec(S), L0), len(L1, VL), value(S, V, VL).
tag(T, spec(S), 1) --> { tag_properties(T, [length(1),spec(S)]) }, [T].
tag(T, spec(S), 2) --> { tag_properties(T, [length(2),spec(S)]), number_bytes(T,[B1,B2]) }, [B1,B2].
len(VL+1, VL) --> [VL].
value(t, V, L) --> ber(V, L).
value(b(L,U), V, N) --> { between(L, U, N) }, length_(V, N).
value(ans(L,U), V, N) --> { between(L, U, N) }, length_(V, N).
value(an(L,U), V, N) --> { between(L, U, N) }, length_(V, N).
value(n(I), V, N) --> { N is ceiling(I / 2) }, length_(V, N).
value(cn(L,U), V, N) --> { between(L, U, X), N is ceiling(X/2) }, length_(V, N).

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


spec_alphabet_names(ansp, [ascii(punct)|L]) :- spec_alphabet_names(ans, L).
spec_alphabet_names(ans, [ascii(space)|L]) :- spec_alphabet_names(an, L).
spec_alphabet_names(an, [N|A]) :- spec_alphabet_names(n, [N]), spec_alphabet_names(a, A).
spec_alphabet_names(a, [ascii(digit),ascii(upper)]).
spec_alphabet_names(n, [ascii(lower)]).

alphabet(ascii(digit), ['0','1','2','3','4','5','6','7','8','9']).
alphabet(ascii(upper), ['A','B','C','D','E','F','G','H','I','J','K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y','Z']).
alphabet(ascii(lower), ['a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z']).
alphabet(ascii(space), [' ']).
alphabet(ascii(punct), ['.',',',';','!','?']).

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
    optional_pp(Fid, 0x9F2A), optional_pp(Fid, 0x9F5A), optional_pp(Fid, 0x9F28).
xA5_(Fid) --> optional_pp(Fid, 0x50), optional_pp(Fid, 0x9F38).

gpo_(Fid) -->
    optional_pp(Fid, 0x57), optional_pp(Fid, 0x82), optional_pp(Fid, 0x5F34),
    optional_pp(Fid, 0x9F10), optional_pp(Fid, 0x9F26), optional_pp(Fid, 0x9F27),
    optional_pp(Fid, 0x9F36), optional_pp(Fid, 0x9F6C).

optional_pp(Fid, Tag) --> { pp(Fid, Tag, Value) } -> [Tag-Value]; [].


%% EMV tag database %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% {

tag_properties_defaults(Id, L, D) :- maplist(tag_property_default(Id), L, D).
tag_properties(Id, L) :- maplist(tag_property(Id), L).

tag_property_default(Id, Property, Default) :-
    ground(Default),
    (
        \+ tag_property(Id, Property) ->
            Property = Default
        ;   tag_property(Id, Property)
    ).

tag_property(Id, value(Id)) :- tag_db(Id, _, _).
tag_property(Id, length(L)) :- tag_db(Id, _, _), L is ceiling(log(Id + 1) / log(2) / 8).
tag_property(Id, name(N)) :- tag_db(Id, _, N).
tag_property(Id, spec(S)) :- tag_db(Id, S, _).

tag_db(0x82,   b(1,6),    "File descriptor").
tag_db(0x83,   b(2,2),    "File identifier").
tag_db(0xA5,   t,         "FCI Proprietary Template").
tag_db(0x77,   t,         "Response Message Template Format 2").
tag_db(0xBF0C, t,         "FCI Issuer Discretionary Data").
tag_db(0x61,   t,         "Application Template").
tag_db(0x87,   b(1,1),    "Application Priority Indicator").
tag_db(0x9F2A, b(2,2),    "Kernel Identifier").
tag_db(0x4F,   b(5,16),   "Application Identifier (AID) – Card").
tag_db(0x50,   b(1,16),   "Application Label").
tag_db(0x87,   b(1,1),    "Application Priority Indicator").
tag_db(0x84,   b(0,16),   "Dedicated File (DF) Name").
tag_db(0x6F,   t,         "File Control Information (FCI)").
tag_db(0x9F38, b(0,64),   "Processing Options DOL (PDOL)").
tag_db(0x9F5A, b(1,16),   "Application Program Identifier (Kernel 3)").
tag_db(0x9F5A, b(1),      "Membership Product Identifier (Kernel 4)").
tag_db(0x57,   b(0,19),   "Track 2 Equivalent Data").
tag_db(0x5F34, n(2),      "Application PAN Sequence Number").
tag_db(0x9F10, b(0,32),   "Issuer Application Data").
tag_db(0x9F26, b(8,8),    "Application Cryptogram").
tag_db(0x9F27, b(1,1),    "Cryptogram Information Data").
tag_db(0x9F36, b(2,2),    "Application Transaction Counter (ATC)").
tag_db(0x9F6C, b(2,2),    "Card Transaction Qualifiers (CTQ)").
tag_db(0x9F66, b(4,4),    "Terminal Transaction Qualifiers (TTQ) (Kernel 3)").
tag_db(0x9F63, b(6,6),    "Positions of UN and ATC (PUNATC) (Kernel 2) (Track 1)").
tag_db(0x9F64, b(1,1),    "Number of ATC digits (NATC) (Kernel 2) (Track 1)").
tag_db(0x9F65, b(2,2),    "Positions of CVC3 (PCVC3) (Kernel 2) (Track 2)").
tag_db(0x9F02, n(12),     "Amount, Authorised (numeric)").
tag_db(0x9F03, n(12),     "Amount, Other (numeric)").
tag_db(0x5F2A, n(3),      "Transaction Currency Code").
tag_db(0x9F37, b(4,4),    "Unpredictable Number (UN)").
tag_db(0x9F5B, b(0,252),  "Issuer Script Results (Kernel 3)").    % Max size is var.
tag_db(0x9F5B, b(0,252),  "Data Storage DOL (DSDOL) (Kernel 2)"). %      ''
tag_db(0x9F5B, false,     "Product Membership Number (Kernel 4)").
tag_db(0x9F28, b(2,2),    "Contactless Application Capabilities Type").
tag_db(0x9F35, n(2),      "Terminal Type").
tag_db(0x5F20, ans(2,26), "Cardholder Name").
tag_db(0x8C,   b(0,252),  "Card Risk Management DOL 1").
tag_db(0x8D,   b(0,252),  "Card Risk Management DOL 2").
tag_db(0x9F1A, n(3),      "Terminal Country Code").
tag_db(0x95,   b(5,5),    "Terminal Verification Results (TVR)").
tag_db(0x9A,   n(6),      "Transaction Date").
tag_db(0x9C,   n(2),      "Transaction Type").
tag_db(0x8A,   an(2),     "Authorisation Response Code").
tag_db(0x9F08, b(2,2),    "Application Version").
tag_db(0x9F07, b(2,2),    "Application Usage Control (AUC)").
tag_db(0x9F42, n(3),      "Application Currency Code").
tag_db(0x5F30, n(3),      "Service Code").
tag_db(0x5F25, n(6),      "Application Effective Date").
tag_db(0x5F24, n(6),      "Application Expiration Date").
tag_db(0x5A,   cn(0,19),  "Application Primary Account Number (PAN)").
tag_db(0x9F0D, b(5,5),    "Issuer Action Code (IAC) - Default").
tag_db(0x9F0E, b(5,5),    "Issuer Action Code (IAC) - Denial").
tag_db(0x9F0F, b(5,5),    "Issuer Action Code (IAC) - Online").
tag_db(0x8E,   b(0,252),  "Cardholder Verification Method (CVM) List").

% Tests
db_consistent :- duplicates, ambiguous_type, ef_hosts_files.
duplicates :- forall(ft(F, _), findall(X, ft(F,X), [_])).
ambiguous_type :- \+((ft(Fid, T1), ft(Fid, T2), T1 \= T2)).
ef_hosts_files :- \+((ft(Ef, ef), pc(Ef, _))).
%ef_has_dfname :- forall(fn(F, _), type(df, F)).

%% }
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

dol([]) --> [].
dol([H|T]) -->
    {   tag_db(H, Type, _),
        tag_property(H, length(1)),
        phrase(value(Type, _, N), _) }, [H,N], dol(T).
dol([H|T]) -->
    {   tag_db(H, Type, _),
        tag_property(H, length(2)),
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
