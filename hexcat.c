#include <unistd.h>
#include <stdio.h>
#include <err.h>

int main() {
    ssize_t rc;
    unsigned char c;
    setvbuf(stdout, NULL, _IONBF, 0);
    while ((rc = read(0, &c, 1)) == 1)
        printf("%02X ", c);
    putchar('\n');
    err(-rc, NULL);
}
