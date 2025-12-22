#include <stdio.h>

int add(int x, int y) {
    return x + y; // canonical breakpoint: line 5
}

int main(void) {
    int acc = 0;
    for (int i = 0; i < 3; i++) {
        acc = add(acc, i);
    }
    printf("%d\n", acc);
    return 0;
}
