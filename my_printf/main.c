#include <stdio.h>
#define RESET   "\033[0m"
#define GREEN   "\033[0;32m"


extern void my_printf(const char *format, ...);

int main() {
    // 1. Тест строк и простых чисел
    my_printf("1. Basic test: %s, %d, %%\n", "Hello World", 12345);
    // printf(GREEN "1. Basic test: %s, %d, %%\n" RESET, "Hello World", 12345);

    // 2. Тест отрицательных чисел и INT64_MIN
    my_printf("2. Negative numbers: %d, %d\n", -42, -2147483648);
    // printf(GREEN "2. Negative numbers: %d, %d\n" RESET, -42, -2147483648);
    // 4. Тест систем счисления
    my_printf("3. Bases: Bin: %b, Oct: %o, Hex: %x\n", 255, 255, 255);
    // printf(GREEN "3. Bases: Bin: %b, Oct: %o, Hex: %x\n" RESET, 255, 255, 255);

    my_printf("4. Stack test: %d %d %d %d %d %d %d %d %d %d\n", 
               1, 2, 3, 4, 5, 6, 7, 8, 9, 10);
    // printf(GREEN "4. Stack test: %d %d %d %d %d %d %d %d %d %d\n" RESET, 
            //    1, 2, 3, 4, 5, 6, 7, 8, 9, 10);
    // 5. Тест float (double)
    my_printf("5. Float test: %f, Negative float: %f %d %s %x %d%%%c\n", 3.141592, -0.000123, 1982, "hello", 5, 'a');
    // printf(GREEN "5. Float test: %f, Negative float: %f %d %s %x %d%%%c\n" RESET, 3.141592, -0.000123);

    return 0;
}
