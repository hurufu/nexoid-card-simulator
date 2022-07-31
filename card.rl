#include <string.h>
#include <stdio.h>
#include <fcntl.h>

#define elementsof(Array) (sizeof(Array)/sizeof((Array)[0]))

%%{
    machine card;

    select = 0x00 0xA4 0x00 0x00 @{ printf("Select\n"); };
    main := select;
}%%

%% write data;

static void set_fd_flag(const int fd, const int flag) {
    const int fl = fcntl(fd, F_GETFL);
    if ((fl & flag) == flag)
        return;
    fcntl(fd, F_SETFL, fl | flag);
}

static void adjust_file_params(FILE* const f) {
    setvbuf(f, NULL, _IONBF, 0);
    set_fd_flag(fileno(f), O_NONBLOCK);
}

int main() {
    {
        FILE* files[] = { stdout, stderr };
        for (size_t i = 0; i < elementsof(files); i++)
            adjust_file_params(files[i]);
    }
    char buf[255];
    const int size = fread(buf, 1, sizeof(buf), stdin);
    printf("read %d bytes\n", size);
    int cs;
    char *p = buf;
    char *pe = p + size;
    %% write init;
    %% write exec;
    printf("Done.\n");
    return 0;
}
