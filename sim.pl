main :- phrase(exchange, []) -> main; true.

exchange --> get_bytes(rd), command_response_pair, put_bytes(wr).

% section 5.1
command_response_pair -->
    hdr(Hdr, Tc), lc(Tc, Nc), cmd(Tc, Nc, Dt), le(Tc, Te, Le), response(Hdr, Te, Le).

hdr(Hdr, Tc) --> [+Cla,+Ins,+P1,+P2], { header_meaning(Cla, Ins, P1, P2, Hdr, Tc) }.
lc(absent, 0) --> [].
lc(present(Tc), Nc) --> [+L0], ({ L0 > 0 } -> { Tc = short, Nc = L0 }; [+L1,+L2], { Tc = extended, Nc is (L1 << 8) + L2, Nc > 0 }).
cmd(absent, 0, []) --> [].
cmd(present(_), Nc, Bytes) --> length_(L, Nc), { maplist(in_, L, Bytes) }.
in_(+A, A).
le(_, absent, 0) --> [].
le(present(short), present(short), Ne) --> [+Le], { Ne is Le }.
le(present(extended), present(extended), Ne) --> [+L1,+L2], { Ne is (L1 << 8) + L2 }.
le(absent, present(extended), Ne) --> [+ 0,+L1,+L2], { Ne is (L1 << 8) + L2 }.

% logical channel not supported
response(command(cla(interindustry,[channel(_),_,_]),_)), [-(0x68),-(0x81)] --> [].
% secure messaging not supported
response(command(cla(interindustry,[_,_,secm(_)]),_)), [-(0x68),-(0x82)] --> [].
% command chaining not supported
response(command(cla(interindustry,[_,partial,_]),_)), [-(0x68),-(0x83)] --> [].

length_(L, N) --> { ground(N), functor(_, t, N) } -> seqn_int(L, N); seqn_var(L, N).
seqn_int(L, N) --> { N =:= 0 } -> { L = [] }, []; { L = [H|T], M is N - 1 }, [H], seqn_int(T, M).
seqn_var([], 0) --> [].
seqn_var([H|T], N) --> [H], seqn_var(T, M), { N is M + 1 }.

get_bytes(Stream, B, A) :-
    get_byte(Stream, Byte), Byte >= 0, A = [+Byte|X], (X = B; get_bytes(Stream, B, X)).

put_bytes(Stream) --> [] | [-Byte], { put_byte(Stream, Byte) }, put_bytes(Stream).

response_for(0x00, 0xA4, 0x04, 0x00, Dt, present(_), 0x00, Rs, 0x90, 0x00) :- Dt = [50,80,65,89,46,83,89,83,46,68,68,70,48,49], % 2PAY.SYS.DDF01
    Rs = [111,45,132,14,50,80,65,89,46,83,89,83,46,68,68,70,48,49,165,27,191,12,24,97,22,79,7,160,0,0,0,3,16,16,80,11,86,73,83,65,32,67,82,69,68,73,84].
response_for(0x00, 0xA4, 0x04, 0x00, Dt, present(_), 0x00, Rs, 0x90, 0x00) :- Dt = [0xA0,0x00,0x00,0x00,0x03,0x10,0x10],
    Rs = [111,50,132,7,160,0,0,0,3,16,16,165,39,80,11,86,73,83,65,32,67,82,69,68,73,84,159,56,12,159,102,4,159,2,6,95,42,2,159,55,4,191,12,8,159,90,5,0,8,64,8,64].
response_for(0x00, 0xA4, 0x04, 0x00, Dt, present(_), 0x00, [], 0x90, 0x00) :- Dt = [0xD2,0x76,0x00,0x00,0x85,0x01,0x00].
response_for(0x00, 0xA4, 0x04, 0x00, Dt, present(_), 0x00, [], 0x6A, 0x82) :- Dt = [0xD2,0x76,0x00,0x00,0x85,0x01,0x01].
response_for(0x00, 0xA4, 0x04, 0x00, Dt, present(_), 0x00, [], 0x6A, 0x82) :- Dt = [0xE1,0x03].
response_for(0x80, 0xA8, 0x00, 0x00, Dt, present(_), 0x00, Rs, 0x90, 0x00) :- Dt = [0x83,0x10,0x36,_,0x40,0,0,0,0,0,_,_,_,_,_,_,_,_],
    Rs = [119,61,87,16,71,97,115,144,1,1,1,25,210,65,34,1,23,88,148,114,130,2,0,0,95,52,1,1,159,16,7,6,1,17,3,160,0,0,159,38,8,19,201,29,101,169,16,201,86,159,39,1,128,159,54,2,0,2,159,108,2,128,0].
response_for(_, _, _, _, _, present(_), Le, Rs, 0x68, 0x00) :- length(Rs, Le).
