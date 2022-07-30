#include <linux_nfc_api.h>
#include <pthread.h>
#include <stdbool.h>
#include <unistd.h>
#include <stdlib.h>
#include <fcntl.h>
#include <stdio.h>
#include <poll.h>
#include <err.h>

#define LOG_(Level, Fmt, ...) fprintf(stderr, "main: " Level " %s:%d\t" Fmt "\n", __FILE__, __LINE__, ##__VA_ARGS__)
#define LOGD(Fmt, ...) LOG_("D", Fmt, ##__VA_ARGS__)
#define LOGI(Fmt, ...) LOG_("I", Fmt, ##__VA_ARGS__)
#define LOGW(Fmt, ...) warn("W %s:%d\t" Fmt, __FILE__, __LINE__, ##__VA_ARGS__);
#define LOGX(Fmt, ...) errx(EXIT_FAILURE, "E %s:%d\t" Fmt, __FILE__, __LINE__, ##__VA_ARGS__);
#define LOGF(Fmt, ...) err(EXIT_FAILURE, "E %s:%d\t" Fmt, __FILE__, __LINE__, ##__VA_ARGS__);
#define elementsof(Array) (sizeof(Array)/sizeof((Array)[0]))

pthread_mutex_t g_mutex = PTHREAD_MUTEX_INITIALIZER;
pthread_cond_t g_card_activated = PTHREAD_COND_INITIALIZER;
pthread_cond_t g_data_received = PTHREAD_COND_INITIALIZER;
pthread_cond_t g_card_deactivated = PTHREAD_COND_INITIALIZER;

static const char* mode_tostring(const unsigned char mode) {
    switch (mode) {
        case MODE_LISTEN_A: return "A";
        case MODE_LISTEN_B: return "B";
        case MODE_LISTEN_F: return "F";
    }
    return NULL;
}

void on_data_received(unsigned char* const data, const unsigned int length) {
    LOGD("Data received");
    if (fwrite(data, 1, length, stdout) != length)
        LOGW("Can't write() received NFC data to stdout");
    pthread_cond_signal(&g_data_received);
}

void on_host_card_emulation_activated(const unsigned char mode) {
    LOGD("Card activated. Remote reader type is %s", mode_tostring(mode));
    pthread_cond_signal(&g_card_activated);
}

void on_host_card_emulation_deactivated(void) {
    LOGD("Card deactivated");
    pthread_cond_signal(&g_card_deactivated);
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
    static nfcHostCardEmulationCallback_t s_cb = {
        .onDataReceived = on_data_received,
        .onHostCardEmulationActivated = on_host_card_emulation_activated,
        .onHostCardEmulationDeactivated = on_host_card_emulation_deactivated
    };

    {
        FILE* files[] = { stdin, stdout, stderr };
        for (size_t i = 0; i < elementsof(files); i++)
            adjust_file_params(files[i]);
    }

    if (nfcManager_doInitialize() != 0)
        LOGX("NFC manager initialization failed");
    nfcHce_registerHceCallback(&s_cb);
    nfcManager_enableDiscovery(0x00, 0, 1, 0);

    LOGI("Waiting for a reader...");
    pthread_cond_wait(&g_card_activated, &g_mutex);
    for (;;) {
        struct pollfd pf[] = {
            { .fd = STDIN_FILENO, .events = POLLRDNORM }
        };
        const int poll_res = poll(pf, elementsof(pf), 5 * 1000);
        if (poll_res == -1)
            LOGF("poll() failed");
        if (poll_res == 0) {
            LOGI("Timeout");
            break;
        }
        for (size_t i = 0; i < elementsof(pf); i++) {
            if (pf[i].revents & POLLRDNORM) {
                LOGD("Read");
                unsigned char buf[255];
                const ssize_t s = read(pf[i].fd, buf, sizeof(buf));
                if (s < 0)
                    LOGF("Can't read from fd %d", pf[i].fd);
                const int rs = nfcHce_sendCommand(buf, s);
                if (rs != 0)
                    LOGX("Can't send NFC command %d", rs);
            }
            if (pf[i].revents & POLLHUP) {
                LOGD("Close");
                close(pf[i].fd);
            }
            if (pf[i].revents & POLLNVAL) {
                LOGD("Inval...");
                pthread_cond_wait(&g_card_deactivated, &g_mutex);
                goto bail;
            }
        }
    }
bail:

    nfcHce_deregisterHceCallback();
    if (nfcManager_doDeinitialize() != 0)
        LOGX("Error during NFC deinitialization");
    return EXIT_SUCCESS;
}
