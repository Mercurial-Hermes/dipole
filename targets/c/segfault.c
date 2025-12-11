#include <stdio.h>

int main(void) {
    int *p = NULL;
    *p = 1; // deliberate crash
    return 0;
}
