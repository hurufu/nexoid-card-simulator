#include <err.h>
#include <fcntl.h>
#include <fcntl.h>
#include <linux_nfc_api.h>
#include <poll.h>
#include <stdlib.h>
#include <unistd.h>

#define LOG_X(Level, Prefix, Fmt, ...) (Level > g_log_level ? (void)0 : warnx(Prefix " %s:%d\t" Fmt, __FILE__, __LINE__, ##__VA_ARGS__))
#define LOGDX(Fmt, ...) LOG_X(LOG_DEBUG, "D", Fmt, ##__VA_ARGS__)
#define LOGIX(Fmt, ...) LOG_X(LOG_INFO, "I", Fmt, ##__VA_ARGS__)
#define LOGWX(Fmt, ...) LOG_X(LOG_WARNING, "W", Fmt, ##__VA_ARGS__)
#define LOGEX(Fmt, ...) LOG_X(LOG_ERROR, "E", Fmt, ##__VA_ARGS__)
#define LOGFX(Fmt, ...) errx(EXIT_FAILURE, "F %s:%d\t" Fmt, __FILE__, __LINE__, ##__VA_ARGS__)
#define LOGW(Fmt, ...) warn("W %s:%d\t" Fmt, __FILE__, __LINE__, ##__VA_ARGS__)
#define LOGF(Fmt, ...) err(EXIT_FAILURE, "F %s:%d\t" Fmt, __FILE__, __LINE__, ##__VA_ARGS__)

#define elementsof(Array) (sizeof(Array)/sizeof((Array)[0]))

enum LogLevel { LOG_FATAL, LOG_ERROR, LOG_WARNING, LOG_INFO, LOG_DEBUG };

struct args {
    int timeout;
};

static int g_event_pipe[2] = { -1, -1 };
static enum LogLevel g_log_level;

static const char* mode_tostring(const unsigned char mode) {
    switch (mode) {
        case MODE_LISTEN_A: return "A";
        case MODE_LISTEN_B: return "B";
        case MODE_LISTEN_F: return "F";
    }
    return NULL;
}

static void on_host_card_emulation_activated(const unsigned char mode) {
    if (write(g_event_pipe[1], &mode, 1) != 1)
        LOGW("> Can't write activation to the event pipe");
    else
        LOGDX("> Card activated");
}

static void on_data_received(unsigned char* const data, const unsigned int length) {
    if (write(STDOUT_FILENO, data, length) != length)
        LOGW("> Can't write received NFC data to stdout");
    else
        LOGDX("> Data was received and forwarded (length %u)", length);
}

static void on_host_card_emulation_deactivated(void) {
    close(g_event_pipe[1]);
    LOGDX("> Card deactivated");
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

static void main_loop(const int timeout_ms) {
    struct pollfd pf[] = {
        { .fd = g_event_pipe[0], .events = POLLRDNORM },
        { .fd = STDIN_FILENO, .events = POLLRDNORM }
    };
    nfds_t pf_size = 1;
    int poll_res;
    LOGIX("HCE is active – waiting for a reader...");
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
            close(STDIN_FILENO);
            close(STDOUT_FILENO);
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
    if (ac > 3)
        LOGFX("\nUSAGE:\n\t%s <timeout ms> <log level>\n", av[0]);
    const int log_level = (ac == 3) ? atoi(av[2]) : LOG_WARNING;
    if (log_level > LOG_DEBUG)
        LOGFX("Max log level is %d", LOG_DEBUG);
    g_log_level = log_level;
    return (struct args){
        .timeout = (ac >= 2) ? atoi(av[1]) : 5 * 1000
    };
}

int main(int ac, char** av) {
    const struct args ag = parse_args(ac, av);

    {
        if (pipe(g_event_pipe) != 0)
            LOGF("Can't initiate internal event pipe");
        const int fd[] = { STDIN_FILENO, STDOUT_FILENO, STDERR_FILENO, g_event_pipe[0], g_event_pipe[1] };
        for (size_t i = 0; i < elementsof(fd); i++)
            set_fd_flag(fd[i], O_NONBLOCK | O_CLOEXEC);
    }

    if (nfcManager_doInitialize() != 0)
        LOGFX("NFC manager initialization failed");
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
    if (nfcManager_doDeinitialize() != 0)
        LOGFX("Error during NFC deinitialization");
    return EXIT_SUCCESS;
}
