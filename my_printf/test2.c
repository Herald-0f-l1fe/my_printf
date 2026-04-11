#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <assert.h>
#include <stdint.h>
#include <math.h>

void my_printf(const char *format, ...);

char captured[65536];
int capture_stdout(void (*func)(void)) {
    int pipefd[2];
    if (pipe(pipefd) == -1) { perror("pipe"); return -1; }
    int saved_stdout = dup(STDOUT_FILENO);
    dup2(pipefd[1], STDOUT_FILENO);
    close(pipefd[1]);
    
    func();
    
    fflush(stdout);
    dup2(saved_stdout, STDOUT_FILENO);
    close(saved_stdout);
    
    ssize_t n = read(pipefd[0], captured, sizeof(captured) - 1);
    if (n >= 0) captured[n] = '\0';
    close(pipefd[0]);
    return n;
}

#define TEST(description, test_func) do { \
    printf("Testing %s... ", description); \
    fflush(stdout); \
    char expected[65536]; \
    int out_pipe[2]; \
    pipe(out_pipe); \
    int saved_stdout = dup(STDOUT_FILENO); \
    fflush(stdout);  \
    dup2(out_pipe[1], STDOUT_FILENO); \
    close(out_pipe[1]); \
    test_func(printf); \
    fflush(stdout); \
    dup2(saved_stdout, STDOUT_FILENO); \
    close(saved_stdout); \
    read(out_pipe[0], expected, sizeof(expected)-1); \
    close(out_pipe[0]); \
    \
    int my_pipe[2]; \
    pipe(my_pipe); \
    saved_stdout = dup(STDOUT_FILENO); \
    fflush(stdout);  \
    dup2(my_pipe[1], STDOUT_FILENO); \
    close(my_pipe[1]); \
    test_func(my_printf); \
    fflush(stdout); \
    dup2(saved_stdout, STDOUT_FILENO); \
    close(saved_stdout); \
    read(my_pipe[0], captured, sizeof(captured)-1); \
    close(my_pipe[0]); \
    \
    if (strcmp(expected, captured) == 0) \
        printf("OK\n"); \
    else { \
        printf("FAIL\nExpected: %s\nGot:      %s\n", expected, captured); \
    } \
} while(0)

// Тесты
void test_mixed_all(void (*pf)(const char*, ...)) {
    pf("Int: %d, Str: %s, Char: %c, Hex: %x, Oct: %o, Bin: %b, Float: %f\n",
       -12345, "Hello!", 'X', 0xDEADBEEF, 0755, 0b101010, 3.14159);
}

void test_negative_zero_int(void (*pf)(const char*, ...)) {
    pf("%d %d %d %d\n", 0, -0, -2147483648, 2147483647);
}

void test_float_edge_cases(void (*pf)(const char*, ...)) {
    pf("%f %f %f %f\n", 0.0, -0.0, 1e-6, -98765.4321);
}

void test_float_large_small(void (*pf)(const char*, ...)) {
    pf("%f %f\n", 1e9, 1e-9);
}

void test_string_null(void (*pf)(const char*, ...)) {
    pf("Null: %s\n", (char*)NULL);
}

void test_percent_escaping(void (*pf)(const char*, ...)) {
    pf("%% %% %%d %%s\n");
}

void test_many_args(void (*pf)(const char*, ...)) {
    pf("%d %s %c %x %o %b %f %d %s\n",
       42, "many", 'M', 0xABCD, 01234, 0b11110000, 2.71828, -99, "end");
}

void test_binary_representation(void (*pf)(const char*, ...)) {
    pf("%b %b %b\n", 0, 1, 255);
}

void test_hex_oct_bin_combinations(void (*pf)(const char*, ...)) {
    pf("Hex: %x, Oct: %o, Bin: %b\n", 0xCAFE, 0644, 0b11001010);
}

void test_float_rounding(void (*pf)(const char*, ...)) {
    pf("%f %f\n", 1.9999994, 1.9999995);
}

void test_float_negative_zero_precision(void (*pf)(const char*, ...)) {
    pf("%f %f\n", -0.000001, -0.0);
}

void test_char_boundaries(void (*pf)(const char*, ...)) {
    pf("%c%c%c\n", 0, 127, 255);
}

void test_embedded_format_string(void (*pf)(const char*, ...)) {
    pf("Start %d %s %c End\n", 10, "embedded", 'E');
}

void test_no_specifiers(void (*pf)(const char*, ...)) {
    pf("Plain text without any specifiers.\n");
}

void test_alternating_types(void (*pf)(const char*, ...)) {
    pf("%d %f %x %s %c %o %b %f %d\n",
       -1, -1.5, 0xFFFFFFFF, "alt", 'Z', 0777, 0b101, 0.123456, 2147483647);
}

int main() {
    TEST("Mixed all specifiers", test_mixed_all);
    TEST("Negative zero and int limits", test_negative_zero_int);
    TEST("Float edge cases", test_float_edge_cases);
    TEST("Float large and small", test_float_large_small);
    TEST("Null string handling", test_string_null);
    TEST("Percent escaping", test_percent_escaping);
    TEST("Many arguments", test_many_args);
    TEST("Binary representation", test_binary_representation);
    TEST("Hex, Oct, Bin combinations", test_hex_oct_bin_combinations);
    TEST("Float rounding", test_float_rounding);
    TEST("Float negative zero and precision", test_float_negative_zero_precision);
    TEST("Char boundaries", test_char_boundaries);
    TEST("Embedded format string", test_embedded_format_string);
    TEST("No specifiers", test_no_specifiers);
    TEST("Alternating types", test_alternating_types);
    
    printf("\nAll tests completed.\n");
    return 0;
}