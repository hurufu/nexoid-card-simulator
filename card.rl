#include <string.h>
#include <stdio.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include "log.h"

#define elementsof(Array) (sizeof(Array)/sizeof((Array)[0]))

static enum LogLevel g_log_level = LOG_DEBUG;

%%{
    machine card;

    cla = 0x00;
    cmd_select = 0xa4;
    select = cla cmd_select;
    length_and_aid_ndef = 0x07 0xd2 0x76 0x00 0x00 0x85 0x01 0x01;
    length_aid_capability_container = 0x02 0xe1 0x03;

    select_ndef = select 0x04 0x00 length_and_aid_ndef 0x00 @{ LOGDX("SELECT NDEF"); };
    select_capability_container = select 0x00 0x0c length_aid_capability_container @{ LOGDX("SELECT CC"); };

    main := (select_ndef | select_capability_container)*;
}%%

%% write data;

static void set_fd_flag(const int fd, const int flag) {
    const int fl = fcntl(fd, F_GETFL);
    if ((fl & flag) == flag)
        return;
    fcntl(fd, F_SETFL, fl | flag);
}

int main() {
    {
        const int fd[] = { 0, 1 };
        for (size_t i = 0; i < elementsof(fd); i++)
            set_fd_flag(fd[i], O_CLOEXEC);
    }

    char buf[255];
    ssize_t rc;
    int cs;
    for (;;) {
        if ((rc = read(0, buf, sizeof(buf))) <= 0)
            break;
        char* p = buf, * pe = p + rc;
        %% write init;
        %% write exec;
    }
    if (rc)
        LOGF("");
    LOGDX("Done");
    return 0;
}
