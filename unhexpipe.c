#include <unistd.h>
#include <err.h>

static inline unsigned char unhex1(const char h) {
    switch (h) {
        case 'A' ... 'F': return h - 'A' + 10;
        case 'a' ... 'f': return h - 'a' + 10;
        case '0' ... '9': return h - '0';
    }
    errx(1, "Unexpected character %#.2x (%c)", h, h);
}

static inline unsigned char unhex(const char h[static const 2]) {
    return (unhex1(h[0]) << 4) | unhex1(h[1]);
}

int main() {
    int rc;
    for (;;) {
        char h[2];
        if ((rc = read(0, h, 2)) != 2)
            break;
        if ((rc = (write(1, (unsigned char[]){ unhex(h) }, 1) != 1)))
            break;
    }
    err(rc, NULL);
}
