#include <stdio.h>

int main() {
    volatile long long x = 0;

    while (1) {
        x += 1;
    }
}
