% Main entry into card simulator.

main :- main([]).

% Uses FsPrev, FsNext variable as a crude way to pass selected FID between
% command/response pairs. Head of that list always contains currently selected
% file.
main(FsPrev) :- phrase(exchange(FsPrev, FsNext), []) -> main(FsNext); true.

exchange(FsPrev, FsNext) --> get_bytes(rd), command_response_pair(FsPrev, FsNext), put_bytes(wr).

put_bytes(Stream) --> [] ; [-Byte], { put_byte(Stream, Byte) }, put_bytes(Stream).
get_bytes(Stream, B, A) :-
    get_byte(Stream, Byte), Byte >= 0, A = [+Byte|X], (X = B; get_bytes(Stream, B, X)).

% section 5.1
command_response_pair(FsPrev, FsNext) --> command(Cmd, Dt, Qe), response(Cmd, Dt, Qe, FsPrev, FsNext).

response(Cmd, Dt, Qe, FsPrev, FsNext) --> { response_for(Cmd, Dt, Qe, Response, FsPrev, FsNext) }, output(Response).

output([]) --> [].
output([H|T]), [-H] --> output(T).
