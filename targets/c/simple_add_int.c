#include <stdio.h>
#include <unistd.h>

int foo(int x) {
    return x + 1;
}

int main(void) {
    int n = 41;
    int m = foo(n);
    printf("m = %d ... will now sleep for 1000 secs\n", m);
    sleep(1000);
    return 0;
}
