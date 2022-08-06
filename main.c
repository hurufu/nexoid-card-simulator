#include <fcntl.h>
#include <fcntl.h>
#include <linux_nfc_api.h>
#include <poll.h>
#include <unistd.h>
#include <string.h>
#include <signal.h>
#include "log.h"
#include "util.h"
#include <stdio.h>

struct args {
    int timeout;
};

enum OutputType {
    OUTPUT_TYPE_RAW,
    OUTPUT_TYPE_HEX
};

static int g_event_pipe[2] = { -1, -1 };
static enum LogLevel g_log_level = LOG_FATAL;
static enum OutputType g_ouptut_type = OUTPUT_TYPE_HEX;

static const char* mode_tostring(const unsigned char mode) {
    switch (mode) {
        case MODE_LISTEN_A: return "A";
        case MODE_LISTEN_B: return "B";
        case MODE_LISTEN_F: return "F";
    }
    return NULL;
}

static inline char hex(const unsigned char n) {
    return n + (n <= 9 ? '0' : ('A' - 10));
}

static void sig_handler(const int sig) {
    (void)sig;
    close(STDOUT_FILENO);
}

static void write_raw_data(const unsigned int length, const unsigned char data[static const length]) {
    if (write(STDOUT_FILENO, data, length) != length)
        LOGW("> Can't write received NFC data to stdout");
    else
        LOGDX("> Data was received and forwarded (length %u)", length);
};

static void write_hex_data(const unsigned int length, const unsigned char data[static const length]) {
    char buf[length + 1][3];
    for (unsigned int i = 0; i < length; i++) {
        buf[i][0] = hex((data[i] & 0xF0) >> 4);
        buf[i][1] = hex(data[i] & 0x0F);
        buf[i][2] = ' ';
    }
    buf[length][0] = '\r';
    buf[length][1] = '\n';
    buf[length][2] = '\0';
    write_raw_data(sizeof(buf), (unsigned char*)buf);
};

static void on_host_card_emulation_activated(const unsigned char mode) {
    if (write(g_event_pipe[1], &mode, 1) != 1)
        LOGW("> Can't write activation to the event pipe");
    else
        LOGDX("> Card activated");
}

static void on_data_received(unsigned char* const data, const unsigned int length) {
    switch (g_ouptut_type) {
        case OUTPUT_TYPE_RAW:
            return write_raw_data(length, data);
        case OUTPUT_TYPE_HEX:
            return write_hex_data(length, data);
    }
}

static void on_host_card_emulation_deactivated(void) {
#   if 1
    // Ugly workaround for the NFC Tools app
    static int count = 0;
    if ((++count % 4) == 0)
        close(g_event_pipe[1]);
#   else
    close(g_event_pipe[1]);
#   endif
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
        { .fd = STDOUT_FILENO, .events = POLLHUP },
        { .fd = STDIN_FILENO, .events = POLLRDNORM }
    };
    nfds_t pf_size = 2;
    int poll_res;
    LOGIX("HCE is active – waiting for a reader...");
    while ((poll_res = poll(pf, pf_size, timeout_ms)) > 0) {
        if (pf[0].revents & POLLNVAL) {
            LOGEX("Error in the event pipe");
            break;
        }
        if (pf[1].revents & POLLNVAL) {
            LOGEX("Error in the command stream (stdout)");
            break;
        }
        if (pf[2].revents & POLLNVAL) {
            LOGEX("Error in the response stream (stdin)");
            break;
        }
        if (pf[0].revents & POLLRDNORM) {
            unsigned char event[1];
            if (read(pf[0].fd, event, sizeof(event)) != sizeof(event))
                LOGF("Can't read an event");
            pf_size = 3;
            LOGDX("Type %s reader detected", mode_tostring(event[0]));
        }
        if (pf[0].revents & POLLHUP) {
            LOGIX("HCE is inactive – no more message will be processed");
            break;
        }
        if (pf[2].revents & POLLRDNORM) {
            unsigned char buf[255];
            ssize_t s = read(pf[2].fd, buf, sizeof(buf));
            if (s < 0)
                LOGF("Can't read from fd %d", pf[2].fd);
            const int rs = nfcHce_sendCommand(buf, s);
            if (rs != 0) {
                LOGEX("Can't send NFC command (%#x)", rs);
                break;
            }
            LOGDX("Response was sent to the reader   (length %zd)", s);
        }
        if (pf[2].revents & POLLHUP) {
            LOGWX("Response pipe is closed – no more responses will be served");
            pf_size = 2;
            pf[2].revents = 0;
        }
    }
    const int fd[] = { STDIN_FILENO, STDOUT_FILENO, g_event_pipe[0], g_event_pipe[1] };
    for (size_t i = 0; i < elementsof(fd); i++)
        close(fd[i]);
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
        LOGFX("USAGE: %s <timeout ms> <log level>", av[0]);
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
        static const struct sigaction act = {
            .sa_handler = sig_handler
        };
        if (sigaction(SIGPIPE, &act, NULL) != 0)
            LOGF("Can't set signal handler");
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
    LOGDX("Done");
    return EXIT_SUCCESS;
}
