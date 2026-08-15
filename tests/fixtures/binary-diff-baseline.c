#include <windows.h>

__declspec(noinline) static int transform(int value)
{
    return (value * 3) + 1;
}

void mainCRTStartup(void)
{
    volatile int result = transform(7);
    ExitProcess(result == 22 ? 0U : 1U);
}
