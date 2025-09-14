main :- phrase(exchange, []) -> main; true.

exchange --> get_bytes(rd), command_response_pair, put_bytes(wr).

% section 5.1
command_response_pair -->
    hdr(Cmd, Tc, Te), lc(Tc, Nc), cmd(Tc, Nc, Dt), le(Tc, Te, Le), response(Cmd, Dt, Te, Le).

hdr(Cmd, Tc, Te) --> [+Cla,+Ins,+P1,+P2], { cm(Cla, Ins, P1, P2, Tc, Te, Cmd) }.
lc(absent, 0) --> [].
lc(present(Tc), Nc) --> [+L0], ({ L0 > 0 } -> { Tc = short, Nc = L0 }; [+L1,+L2], { Tc = extended, Nc is (L1 << 8) + L2, Nc > 0 }).
cmd(absent, 0, []) --> [].
cmd(present(_), Nc, Bytes) --> length_(L, Nc), { maplist(in_, L, Bytes) }.
in_(+A, A).
le(_, absent, 0) --> [].
le(present(short), present(short), Ne) --> [+Le], { Ne is Le }.
le(present(extended), present(extended), Ne) --> [+L1,+L2], { Ne is (L1 << 8) + L2 }.
le(absent, present(extended), Ne) --> [+ 0,+L1,+L2], { Ne is (L1 << 8) + L2 }.
response(Cmd, Dt, Te, Le) --> { response_for(Cmd, Dt, Te, Le, Response, Sw1, Sw2) }, output([Sw1,Sw2]), output(Response).
length_(L, N) --> { ground(N), functor(_, t, N) } -> seqn_int(L, N); seqn_var(L, N).
seqn_int(L, N) --> { N =:= 0 } -> { L = [] }, []; { L = [H|T], M is N - 1 }, [H], seqn_int(T, M).
seqn_var([], 0) --> [].
seqn_var([H|T], N) --> [H], seqn_var(T, M), { N is M + 1 }.
put_bytes(Stream) --> [] | [-Byte], { put_byte(Stream, Byte) }, put_bytes(Stream).
get_bytes(Stream, B, A) :-
    get_byte(Stream, Byte), Byte >= 0, A = [+Byte|X], (X = B; get_bytes(Stream, B, X)).

response_for(select(aid_prefix,Occurrence,fci), Dt, present(_), Le, Rs, 0x90, 0x00) :-
    open_list(Dt, L-_),
    select(by_dfname, Occurrence, Fid, L),
    fci(Fid, Fci),
    phrase(ber(Fci,Length), Tmp),
    maplist(is, Rs, Tmp),
    (Le = 0, Length < 256; Le > 0, Length =:= Le).

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
value('b5..16', V, N) --> V, { once(length(V, N)), N >= 5, N =< 16 }.
value('b1..16', V, N) --> V, { once(length(V, N)), N >= 1, N =< 16 }.
value('b1', [V], 1) --> [V].
value('b2', [A,B], 2) --> [A,B].

number_bytes(N, [A,B]) :-
    bits(16, [A0,A1,A2,A3,A4,A5,A6,A7,B0,B1,B2,B3,B4,B5,B6,B7], N),
    maplist(bits(8), [[A0,A1,A2,A3,A4,A5,A6,A7],[B0,B1,B2,B3,B4,B5,B6,B7]],[A,B]).

%response_for(0x00, 0xA4, 0x04, 0x00, Dt, present(_), 0x00, Rs, 0x90, 0x00) :- Dt = [50,80,65,89,46,83,89,83,46,68,68,70,48,49], % 2PAY.SYS.DDF01
%    Rs = [111,45,132,14,50,80,65,89,46,83,89,83,46,68,68,70,48,49,165,27,191,12,24,97,22,79,7,160,0,0,0,3,16,16,80,11,86,73,83,65,32,67,82,69,68,73,84].
%response_for(0x00, 0xA4, 0x04, 0x00, Dt, present(_), 0x00, Rs, 0x90, 0x00) :- Dt = [0xA0,0x00,0x00,0x00,0x03,0x10,0x10],
%    Rs = [111,50,132,7,160,0,0,0,3,16,16,165,39,80,11,86,73,83,65,32,67,82,69,68,73,84,159,56,12,159,102,4,159,2,6,95,42,2,159,55,4,191,12,8,159,90,5,0,8,64,8,64].
%response_for(0x00, 0xA4, 0x04, 0x00, Dt, present(_), 0x00, [], 0x90, 0x00) :- Dt = [0xD2,0x76,0x00,0x00,0x85,0x01,0x00].
%response_for(0x00, 0xA4, 0x04, 0x00, Dt, present(_), 0x00, [], 0x6A, 0x82) :- Dt = [0xD2,0x76,0x00,0x00,0x85,0x01,0x01].
%response_for(0x00, 0xA4, 0x04, 0x00, Dt, present(_), 0x00, [], 0x6A, 0x82) :- Dt = [0xE1,0x03].
%response_for(0x80, 0xA8, 0x00, 0x00, Dt, present(_), 0x00, Rs, 0x90, 0x00) :- Dt = [0x83,0x10,0x36,_,0x40,0,0,0,0,0,_,_,_,_,_,_,_,_],
%    Rs = [119,61,87,16,71,97,115,144,1,1,1,25,210,65,34,1,23,88,148,114,130,2,0,0,95,52,1,1,159,16,7,6,1,17,3,160,0,0,159,38,8,19,201,29,101,169,16,201,86,159,39,1,128,159,54,2,0,2,159,108,2,128,0].
%response_for(_, _, _, _, _, present(_), Le, Rs, 0x68, 0x00) :- length(Rs, Le).
