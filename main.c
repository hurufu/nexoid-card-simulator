#include <linux_nfc_api.h>
#include <stdbool.h>
#include <unistd.h>
#include <stdlib.h>
#include <fcntl.h>
#include <stdio.h>
#include <poll.h>
#include <errno.h>
#include <err.h>
#include <fcntl.h>

#define LOG_X(Level, Fmt, ...) warnx(Level " %s:%d\t" Fmt, __FILE__, __LINE__, ##__VA_ARGS__)
#define LOGDX(Fmt, ...) LOG_X("D", Fmt, ##__VA_ARGS__)
#define LOGIX(Fmt, ...) LOG_X("I", Fmt, ##__VA_ARGS__)
#define LOGWX(Fmt, ...) LOG_X("W", Fmt, ##__VA_ARGS__)
#define LOGEX(Fmt, ...) LOG_X("E", Fmt, ##__VA_ARGS__)
#define LOGFX(Fmt, ...) errx(EXIT_FAILURE, "F %s:%d\t" Fmt, __FILE__, __LINE__, ##__VA_ARGS__)
#define LOGW(Fmt, ...) warn("W %s:%d\t" Fmt, __FILE__, __LINE__, ##__VA_ARGS__)
#define LOGF(Fmt, ...) err(EXIT_FAILURE, "F %s:%d\t" Fmt, __FILE__, __LINE__, ##__VA_ARGS__)

#define elementsof(Array) (sizeof(Array)/sizeof((Array)[0]))

struct args {
    int timeout;
};

int g_event_pipe[2];

static const char* mode_tostring(const unsigned char mode) {
    switch (mode) {
        case MODE_LISTEN_A: return "A";
        case MODE_LISTEN_B: return "B";
        case MODE_LISTEN_F: return "F";
    }
    return NULL;
}

static void on_host_card_emulation_activated(const unsigned char mode) {
    LOGDX("> Card activated");
    if (write(g_event_pipe[1], &mode, 1) != 1)
        LOGW("> Can't write activation to the event pipe");
}

static void on_data_received(unsigned char* const data, const unsigned int length) {
    if (fwrite(data, 1, length, stdout) != length)
        LOGW("> Can't write received NFC data to stdout");
    else
        LOGDX("> Data was received and forwarded (length %u)", length);
}

static void on_host_card_emulation_deactivated(void) {
    LOGDX("> Card deactivated");
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

static void main_loop(const int timeout_ms) {
    struct pollfd pf[] = {
        { .fd = g_event_pipe[0], .events = POLLRDNORM },
        { .fd = STDIN_FILENO, .events = POLLRDNORM }
    };
    int pf_size = 1;
    int poll_res;
    LOGIX("Waiting for a reader...");
    while ((poll_res = poll(pf, pf_size, timeout_ms)) > 0) {
        if (pf[0].revents & POLLNVAL) {
            LOGEX("Error in the event pipe");
            break;
        }
        if (pf[1].revents & POLLNVAL) {
            LOGEX("Error in the response stream (stdin)");
            break;
        }
        if (pf[0].revents & POLLRDNORM) {
            unsigned char event[1];
            if (read(pf[0].fd, event, sizeof(event)) != sizeof(event))
                LOGF("Can't read an event");
            pf_size = 2;
            LOGDX("Type %s reader detected", mode_tostring(event[0]));
        }
        if (pf[0].revents & POLLHUP) {
            LOGIX("HCE is inactive – no more message will be processed");
            close(pf[0].fd);
            fclose(stdin);
            fclose(stdout);
            break;
        }
        if (pf[1].revents & POLLRDNORM) {
            unsigned char buf[255];
            ssize_t s = read(pf[1].fd, buf, sizeof(buf));
            if (s < 0)
                LOGF("Can't read from fd %d", pf[1].fd);
            const int rs = nfcHce_sendCommand(buf, s);
            if (rs != 0) {
                LOGEX("Can't send NFC command (%#x)", rs);
                break;
            }
            LOGDX("Response was sent to the reader   (length %zd)", s);
        }
        if (pf[1].revents & POLLHUP) {
            LOGWX("Response pipe is closed – no more responses will be served");
            pf_size = 1;
            pf[1].revents = 0;
        }
    }
    switch (poll_res) {
        case 0:
            LOGWX("Timeout reached");
            break;
        case -1:
            LOGEX("Error in polling for events");
            break;
        default:
            break;
    }
}

static struct args parse_args(const int ac, char* av[static const ac]) {
    if (ac > 2)
        LOGFX("Expected 0 or 1 argument");
    return (struct args){
        .timeout = (ac == 2) ? atoi(av[1]) : 5 * 1000
    };
}

int main(int ac, char** av) {
    const struct args ag = parse_args(ac, av);
    {
        FILE* files[] = { stdout, stderr };
        for (size_t i = 0; i < elementsof(files); i++)
            adjust_file_params(files[i]);
    }
    if (pipe2(g_event_pipe, O_NONBLOCK | O_CLOEXEC) != 0)
        LOGF("Can't initiate internal event pipe");

    int nfc_rc;
    if ((nfc_rc = nfcManager_doInitialize()) != 0)
        LOGFX("NFC manager initialization failed: %#x", nfc_rc);
    static nfcHostCardEmulationCallback_t s_cb = {
        .onDataReceived = on_data_received,
        .onHostCardEmulationActivated = on_host_card_emulation_activated,
        .onHostCardEmulationDeactivated = on_host_card_emulation_deactivated
    };
    nfcHce_registerHceCallback(&s_cb);
    nfcManager_enableDiscovery(0x00, 0, 1, 0);

    main_loop(ag.timeout);

    nfcManager_disableDiscovery();
    nfcHce_deregisterHceCallback();
    if ((nfc_rc = nfcManager_doDeinitialize()) != 0)
        LOGFX("Error during NFC deinitialization: %#x", nfc_rc);
    return EXIT_SUCCESS;
}
