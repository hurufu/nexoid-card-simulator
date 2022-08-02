#include <unistd.h>
#include "log.h"

static enum LogLevel g_log_level = LOG_DEBUG;

%%{
    machine card;

    action Not_Found { write(1, (unsigned char[]){ 0x6a, 0x82 }, 2); }
    action Ok { const unsigned char buf[] = { 0x90, 0x00 }; write(1, buf, sizeof(buf)); }
    action Cc { const unsigned char buf[] = { 0xE1, 0x10, 0x12, 0x00 }; write(1, buf, sizeof(buf)); }
    action Test { const char buf[0x0F] = ""; write(1, buf, sizeof(buf)); }

    cla = 0x00;
    cmd_select = 0xa4;
    cmd_read_binary = 0xb0;
    select = cla cmd_select;
    lc_and_aid_ndef_0 = 0x07 0xd2 0x76 0x00 0x00 0x85 0x01;
    lc_and_aid_ndef_1 = 0x07 0xd2 0x76 0x00 0x00 0x85 0x01 0x01;
    lc_aid_capability_container = 0x02 0xe1 0x03;
    lc_aid_ppse_directory = 0x0e '2PAY.SYS.DDF01';

    select_ndef_1 = select 0x04 0x00 lc_and_aid_ndef_1 0x00 @Not_Found;
    select_ndef_0 = select 0x04 0x00 lc_and_aid_ndef_0 0x00 @Ok;
    select_capability_container = select 0x00 (0x0c | 0x00) lc_aid_capability_container @Cc @Ok;
    select_ppse = select 0x04 0x00 lc_aid_ppse_directory 0x00 @Ok;
    select_ndef = select_ndef_0 | select_ndef_1;
    read_binary = cla cmd_read_binary 0x00 0x00 0x0F @Test @Ok;

    main := (select_ndef | select_capability_container | read_binary)*;
}%%

%% write data noentry;

int main() {
    char buf[255];
    ssize_t rc;
    int cs;
    for (;;) {
        if ((rc = read(0, buf, sizeof(buf))) <= 0)
            break;
        const char* p = buf, * const pe = p + rc;
        %% write init;
        %% write exec;
        if (card_error == cs)
            LOGFX("No valid transition for DFA");
        if (card_first_final == cs)
            LOGFX("DFA accepted its input – no more transitions possibe");
    }
    if (rc)
        LOGF("");
    LOGDX("Done");
    return 0;
}
