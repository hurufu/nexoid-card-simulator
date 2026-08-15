#include <linux_nfc_api.h>
#include <stdint.h>
#include <assert.h>
#include <stddef.h>
#include <stdlib.h>
#include <stdio.h>
#include <sys/select.h>
#include <sys/param.h>
#include <sysexits.h>
#include <errno.h>
#include <time.h>
#include <stdarg.h>
#include <syslog.h>
#include <unistd.h>

#define xwrite(...) xcall(write, __VA_ARGS__)
#define xread(...) xcall(read, __VA_ARGS__)
#define xpipe(...) xcall(pipe, __VA_ARGS__)
#define xcall(SysCall, ...) if (SysCall(__VA_ARGS__) < 0) exit(EX_IOERR)

union FwVersion {
    int i;
    struct {
        uint8_t minor;
        uint8_t major;
        uint8_t rom;
    };
};

_Static_assert(offsetof(union FwVersion,minor) == 0, "");
_Static_assert(offsetof(union FwVersion,major) == 1, "");
_Static_assert(offsetof(union FwVersion,rom) == 2, "");

static int s_event_pipe[2];
static int s_data_rd = STDIN_FILENO;
static int s_data_wr = STDOUT_FILENO;

static int prprefix(FILE* const s, const uint_fast8_t lvl) {
    static const char s_map[] = {
        [LOG_EMERG] = 'R',
        [LOG_ALERT] = 'A',
        [LOG_CRIT] = 'C',
        [LOG_ERR] = 'E',
        [LOG_WARNING] = 'W',
        [LOG_NOTICE] = 'N',
        [LOG_INFO] = 'I',
        [LOG_DEBUG] = 'D'
    };
    struct timespec ts;
    struct tm tm_info;
    clock_gettime(CLOCK_REALTIME, &ts);
    localtime_r(&ts.tv_sec, &tm_info); // Thread-safe time conversion
    char tmp[24];
    const int sz = strftime(tmp, sizeof tmp, "%Y:%m:%d-%H:%M:%S", &tm_info);
    return fprintf(s, "%*s.%03lu %7s:  %c ", sz, tmp, ts.tv_nsec/1000000, "hce", s_map[lvl]);
}

// Thread-safe logging formatted as in libnfc-nci
#define PR(Level, Fmt, ...) prlog(stderr, Level, Fmt "\n", ##__VA_ARGS__)
static void prlog(FILE* const s, const uint_fast8_t lvl, const char* const fmt, ...) {
    flockfile(s); // Prevent interleaved logs from concurrent callbacks
    prprefix(s, lvl);
    va_list ap;
    va_start(ap, fmt);
    vfprintf(s, fmt, ap);
    va_end(ap);
    funlockfile(s);
}

#define PRBIN(Length, Buf, Prefix, ...) prhexdump(stderr, Length, Buf, Prefix, ##__VA_ARGS__)
static void prhexdump(FILE* const s, const size_t l, const unsigned char b[l], const char* const prefix, ...) {
    flockfile(s);
    prprefix(s, LOG_DEBUG);
    va_list ap;
    va_start(ap, prefix);
    vfprintf(s, prefix, ap);
    va_end(ap);
    for (size_t i = 0; i < l; i++) {
        fprintf(s, "%02x", b[i]);
        if ((i + 1) % 8 == 0) fputc(' ', s);
        if ((i + 1) % (8*4) == 0) fputc(' ', s);
    }
    fputc('\n', s);
    funlockfile(s);
}

static char mode_tostring(const unsigned char mode) {
    switch (mode) {
        case MODE_LISTEN_A: return 'A';
        case MODE_LISTEN_B: return 'B';
        case MODE_LISTEN_F: return 'F';
    }
    return '_';
}

static void on_activated(const unsigned char mode) {
    xwrite(s_event_pipe[1], &mode, 1);
}

static void on_deactivated(void) {
    xwrite(s_event_pipe[1], "D", 1);
}

static void on_data(unsigned char* const data, const unsigned int len) {
    xwrite(s_data_wr, data, len);
    PRBIN(len, data, "< ");
}

static void sig_handler(const int sig) {
    char sigbyte;
    switch (sig) {
        case SIGPIPE:
            sigbyte = 'P';
        default:
            return;
    }
    if (write(s_event_pipe[1], &sigbyte, 1) < 0)
        _exit(EX_IOERR);
}

int main() {
    setlinebuf(stderr);
    setenv("LC_ALL", "C", 1); ///< For %m messages
    static const struct sigaction act = {
        .sa_handler = sig_handler
    };
    sigaction(SIGPIPE, &act, NULL);
    if (nfcManager_doInitialize() != 0)
        exit(EX_UNAVAILABLE);
    xpipe(s_event_pipe);
    const union FwVersion v = { nfcManager_getFwVersion() };
    PR(LOG_DEBUG, "NCI device detected. ROM %#04x FW %d.%d", v.rom, v.major, v.minor);
    static nfcHostCardEmulationCallback_t s_cb = {
        .onDataReceived = on_data,
        .onHostCardEmulationActivated = on_activated,
        .onHostCardEmulationDeactivated = on_deactivated
    };
    nfcHce_registerHceCallback(&s_cb);
    nfcManager_enableDiscovery(NFA_TECHNOLOGY_MASK_A, 0, 1, 0);
    int ret = EXIT_SUCCESS;
    fd_set rd;
    FD_ZERO(&rd);
    FD_SET(s_event_pipe[0], &rd);
    struct timeval timeout = { .tv_sec = 60 };
    if (select(s_event_pipe[0] + 1, &rd, NULL, NULL, &timeout) < 0) {
        PR(LOG_ERR, "select: %m");
        ret = EX_IOERR;
        goto end;
    }
    if (!FD_ISSET(s_event_pipe[0], &rd)) {
        PR(LOG_ERR, "No reader");
        ret = EX_NOHOST;
        goto end;
    }
    unsigned char mode = 0;
    xread(s_event_pipe[0], &mode, 1);
    PR(LOG_DEBUG, "Card type %c detected", mode_tostring(mode));
    unsigned char buf[1024];
    while (1) {
        FD_ZERO(&rd);
        FD_SET(s_data_rd, &rd);
        FD_SET(s_event_pipe[0], &rd);
        timeout = (struct timeval){ .tv_sec = 1 };
        const int sr = select(MAX(s_data_rd, s_event_pipe[0]) + 1, &rd, NULL, NULL, &timeout);
        if (sr < 0) {
            if (errno == EINTR) continue;
            PR(LOG_ERR, "select: %m");
            ret = EX_IOERR;
            break;
        }
        if (sr == 0) {
            PR(LOG_WARNING, "select: Timeout");
            ret = EX_PROTOCOL;
            break;
        }
        if (FD_ISSET(s_event_pipe[0], &rd)) {
            unsigned char status = 0;
            xread(s_event_pipe[0], &status, 1);
            assert(status == 'D' || status == 'P');
            PR(LOG_DEBUG, "Card deactivated %c", status);
            break;
        }
        if (FD_ISSET(s_data_rd, &rd)) {
            usleep(10 * 1000);
            const ssize_t l = read(s_data_rd, buf, sizeof buf);
            if (l < 0) {
                PR(LOG_ERR, "Can't read from fd %d: %m", s_data_rd);
                ret = EX_IOERR;
                break;
            }
            if (l == 0) {
                PR(LOG_ERR, "Input fd %d closed", s_data_rd);
                ret = EX_IOERR;
                break;
            }
            const int r = nfcHce_sendCommand(buf, l);
            if (r != 0) {
                PR(LOG_ERR, "Can't send NFC command (%#04x)", r);
                ret = EX_SOFTWARE;
                break;
            }
            PRBIN(l, buf, "> ");
        }
    }
end:
    // Graceful shutdown locks inside libnfc-nci on surprise removal of USB NFC
    // dongle. SIGALRM should terminate the process in such case.
    alarm(10);
    nfcManager_disableDiscovery();
    nfcHce_deregisterHceCallback();
    nfcManager_doDeinitialize();
    return ret;
}
