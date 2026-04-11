#include <stdio.h>

// Объявляем вашу функцию как внешнюю
extern void my_printf(const char *format, ...);

int main() {
    // 1. Тест строк и простых чисел
    my_printf("1. Basic test: %s, %d, %%\n", "Hello World", 12345);

    // 2. Тест отрицательных чисел и INT64_MIN
    my_printf("2. Negative numbers: %d, %d\n", -42, -2147483648);
    // 4. Тест систем счисления
    my_printf("3. Bases: Bin: %b, Oct: %o, Hex: %x\n", 255, 255, 255);

    my_printf("4. Stack test: %d %d %d %d %d %d %d %d %d %d\n", 
               1, 2, 3, 4, 5, 6, 7, 8, 9, 10);
    // 5. Тест float (double)
    my_printf("5. Float test: %f, Negative float: %f\n", 3.141592, -0.000123);

    // Первые 6 аргументов (включая формат) уйдут в регистры, остальные в стек


    return 0;
}
