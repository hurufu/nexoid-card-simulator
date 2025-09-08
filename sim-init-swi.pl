:- initialization(open('in.fifo',  read,  _, [type(binary),buffer(false),alias(rd),reposition(false),eof_action(eof_code)])).
:- initialization(open('out.fifo', write, _, [type(binary),buffer(false),alias(wr),reposition(false),eof_action(error)])).
