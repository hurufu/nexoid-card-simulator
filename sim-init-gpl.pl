:- initialization(open('in.fifo',  read,  _, [type(binary),buffering(none),alias(rd),eof_action(eof_code)])).
:- initialization(open('out.fifo', write, _, [type(binary),buffering(none),alias(wr),eof_action(error)])).
