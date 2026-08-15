#include <windows.h>

__declspec(noinline) static int transform(int value)
{
    return (value * 3) + 1;
}

__declspec(noinline) static int normalize(int value)
{
    return value ^ 5;
}

void mainCRTStartup(void)
{
    volatile int result = normalize(transform(7));
    ExitProcess(result == 19 ? 0U : 1U);
}
