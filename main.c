#include <linux_nfc_api.h>
#include <pthread.h>
#include <stdbool.h>
#include <unistd.h>
#include <stdlib.h>
#include <fcntl.h>
#include <stdio.h>
#include <poll.h>
#include <err.h>
#include <fcntl.h>

#define LOG_(Level, Fmt, ...) fprintf(stderr, "main: " Level " %s:%d\t" Fmt "\n", __FILE__, __LINE__, ##__VA_ARGS__)
#define LOGD(Fmt, ...) LOG_("D", Fmt, ##__VA_ARGS__)
#define LOGI(Fmt, ...) LOG_("I", Fmt, ##__VA_ARGS__)
#define LOGW(Fmt, ...) warn("W %s:%d\t" Fmt, __FILE__, __LINE__, ##__VA_ARGS__);
#define LOGX(Fmt, ...) errx(EXIT_FAILURE, "E %s:%d\t" Fmt, __FILE__, __LINE__, ##__VA_ARGS__);
#define LOGF(Fmt, ...) err(EXIT_FAILURE, "E %s:%d\t" Fmt, __FILE__, __LINE__, ##__VA_ARGS__);
#define elementsof(Array) (sizeof(Array)/sizeof((Array)[0]))

int g_event_pipe[2];

static const char* mode_tostring(const unsigned char mode) {
    switch (mode) {
        case MODE_LISTEN_A: return "A";
        case MODE_LISTEN_B: return "B";
        case MODE_LISTEN_F: return "F";
    }
    return NULL;
}

static void on_data_received(unsigned char* const data, const unsigned int length) {
    LOGD("Data received");
    if (fwrite(data, 1, length, stdout) != length)
        LOGW("Can't write received NFC data to stdout");
}

static void on_host_card_emulation_activated(const unsigned char mode) {
    LOGD("Card activated");
    if (write(g_event_pipe[1], &mode, 1) != 1)
        LOGW("Can't write activation to the event pipe");
}

static void on_host_card_emulation_deactivated(void) {
    LOGD("Card deactivated");
    close(g_event_pipe[1]);
}

static void set_fd_flag(const int fd, const int flag) {
    const int fl = fcntl(fd, F_GETFL);
    if ((fl & flag) == flag) {
        if (fl == -1)
            LOGF("fcntl() failed for fd %d", fd);
        return;
    }
    if (fcntl(fd, F_SETFL, fl | flag) != 0)
        LOGF("Can't set fd %d to %X mode", fd, flag);
}

static void adjust_file_params(FILE* const f) {
    const int fd = fileno(f);
    if (fd == -1)
        LOGF("Can't adjust file parameters");
    if (setvbuf(f, NULL, _IONBF, 0) != 0)
        LOGF("Can't make fd %d unbuffered", fd);
    set_fd_flag(fd, O_NONBLOCK);
}

int main() {
    {
        FILE* files[] = { stdin, stdout, stderr };
        for (size_t i = 0; i < elementsof(files); i++)
            adjust_file_params(files[i]);
    }

    if (pipe(g_event_pipe) != 0)
        LOGF("Can't initiate internal event pipe");

    {
        static nfcHostCardEmulationCallback_t s_cb = {
            .onDataReceived = on_data_received,
            .onHostCardEmulationActivated = on_host_card_emulation_activated,
            .onHostCardEmulationDeactivated = on_host_card_emulation_deactivated
        };
        if (nfcManager_doInitialize() != 0)
            LOGX("NFC manager initialization failed");
        nfcHce_registerHceCallback(&s_cb);
        nfcManager_enableDiscovery(0x00, 0, 1, 0);
    }

    struct pollfd pf[] = {
        { .fd = g_event_pipe[0], .events = POLLRDNORM },
        { .fd = STDIN_FILENO, .events = POLLRDNORM }
    };
    while (poll(pf, elementsof(pf), 5 * 1000) > 0) {
        if (pf[0].revents & POLLRDNORM) {
            unsigned char event[1];
            if (read(pf[0].fd, event, sizeof(event)) != sizeof(event))
                LOGF("Can't read event");
            LOGD("Reader type is %s", mode_tostring(event[0]));
        }
        if (pf[0].revents & POLLHUP) {
            LOGD("Event pipe closed");
            close(pf[0].fd);
            break;
        }
        if (pf[0].revents & POLLNVAL) {
            LOGD("Error in event pipe");
            break;
        }
        if (pf[1].revents & POLLRDNORM) {
            LOGD("Read");
            unsigned char buf[255];
            const ssize_t s = read(pf[1].fd, buf, sizeof(buf));
            if (s < 0)
                LOGF("Can't read from fd %d", pf[1].fd);
            const int rs = nfcHce_sendCommand(buf, s);
            if (rs != 0)
                LOGX("Can't send NFC command %d", rs);
        }
        if (pf[1].revents & POLLHUP) {
            LOGD("Close");
            close(pf[1].fd);
            break;
        }
        if (pf[1].revents & POLLNVAL) {
            LOGD("Inval");
            break;
        }
    }

    nfcHce_deregisterHceCallback();
    if (nfcManager_doDeinitialize() != 0)
        LOGX("Error during NFC deinitialization");
    return EXIT_SUCCESS;
}
