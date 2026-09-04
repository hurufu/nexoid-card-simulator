% Actual connection to HCI via pipes.

% WARNING: Blocks when evaluated
:- initialization(open_pipe('in.fifo', read, _, [type(binary),alias(rd),eof_action(eof_code)])).
:- initialization(open_pipe('out.fifo', write, _, [type(binary),alias(wr),eof_action(error)])).
