#include <unistd.h>
#include <err.h>

static inline char hex(const unsigned char n) {
    return n + (n <= 9 ? '0' : ('A' - 10));
}

int main() {
    int rc;
    for (;;) {
        unsigned char c;
        if ((rc = read(0, &c, 1)) != 1)
            break;
        if ((rc = (write(1, (char[]){ hex((c & 0xF0) >> 4), hex(c & 0x0F), ' ' }, 3) != 3)))
            break;
    }
    err(rc, NULL);
}
