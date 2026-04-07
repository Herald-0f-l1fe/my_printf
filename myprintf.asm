global my_printf

section .text

my_printf:
    ; 1. Сохраняем состояние вызывающей функции
    push rbp
    mov rbp, rsp
    
    ; Сохраняем callee-saved регистры, которые МЫ будем использовать
    push r12
    push r13
    push r14
    push r15 ; на всякий случай, если понадобится для расчетов

    ; 2. Инициализируем наш "курсор" в буфере
    mov qword [buf_ptr], buffer 

    ; 3. Сохраняем аргументы из регистров в .bss (как в прошлом шаге)
    mov [arg_storage],      rsi
    mov [arg_storage + 8],  rdx
    mov [arg_storage + 16], rcx
    mov [arg_storage + 24], r8
    mov [arg_storage + 32], r9

    ; 4. Обработка XMM (AL)
    test al, al
    jz .skip_xmm
    ; (код копирования XMM0-XMM7 в xmm_storage...)
.skip_xmm:

    ; 5. Подготовка к работе
    mov r12, rdi        ; R12 = форматная строка
    xor r13, r13        ; R13 = индекс текущего int-аргумента (0-4)
    xor r14, r14        ; R14 = индекс текущего xmm-аргумента (0-7)

    ; Теперь мы готовы входить в цикл .loop

    .scan_loop:
    movzx rax, byte [r12]   ; Берем текущий символ из форматной строки
    test al, al             ; Проверка на конец строки (NULL-терминатор)
    jz .flush_and_exit      ; Если 0, выходим и сбрасываем буфер на экран

    cmp al, '%'             ; Проверяем, не встретили ли мы спецсимвол
    je .handle_specifier    ; Если да, идем обрабатывать аргумент

    ; --- Секция обычного символа ---
    ; Копируем символ прямо в наш основной буфер
    mov rdi, [buf_ptr]      ; Загружаем адрес текущей свободной позиции
    mov [rdi], al           ; Пишем символ в буфер
    inc qword [buf_ptr]     ; Сдвигаем указатель буфера на 1
    
    ; Проверка переполнения буфера (опционально, но полезно)
    ; Если (buf_ptr - buffer) >= BUF_SIZE, пора делать syscall write

    inc r12                 ; Переходим к следующему символу форматной строки
    jmp .scan_loop          ; Повторяем

.handle_specifier:
    inc r12                 ; Пропускаем '%'
    movzx rax, byte [r12]   ; Получаем символ спецификатора (напр. 'd')
    
    ; Прыгаем по адресу: jump_table + (rax * 8)
    jmp [jump_table + rax * 8]

.print_int:
    ; Логика для %d
    inc r12
    jmp .scan_loop

.print_string:
    ; Логика для %s
    inc r12
    jmp .scan_loop

.print_percent:
    ; Логика для %%
    mov rdi, [buf_ptr]
    mov byte [rdi], '%'
    inc qword [buf_ptr]
    inc r12
    jmp .scan_loop

.default_case:
    ; Если встретили неизвестный символ после % (напр. %z)
    ; Просто печатаем его или игнорируем
    inc r12
    jmp .scan_loop



.done:
    ; (Тут код финального вывода буфера через syscall write)

    ; Восстанавливаем сохраненные регистры в обратном порядке
    pop r15
    pop r14
    pop r13
    pop r12
    
    pop rbp
    ret

section .data
    ; Константы для системного вызова write (Linux x64)
    SYS_WRITE     equ 1
    STDOUT        equ 1

    ; Таблица символов для перевода чисел в разные системы счисления (10, 16, 2)
    HEX_CHARS     db "0123456789abcdef"

    align 8

    jump_table:
    %assign i 0
    %rep 256
        %if i == 'd'
            dq .print_int
        %elif i == 's'
            dq .print_string
        %elif i == 'f'
            dq .print_float
        %elif i == '%'
            dq .print_percent
        %else
            dq .default_case
        %endif
        %assign i i+1
    %endrep


section .bss
    ; Основной выходной буфер (4КБ — стандартный размер страницы)
    BUF_SIZE      equ 4096
    buffer        resb BUF_SIZE
    
    ; Указатель на текущую свободную позицию в буфере
    buf_ptr       resq 1

    ; Временный буфер для конвертации ОДНОГО числа (макс ~64 символа для двоичной системы)
    ; Мы сначала пишем число сюда (задом наперед), а потом копируем в основной буфер
    num_buffer    resb 64

    ; Место для хранения всех целочисленных аргументов из регистров (RSI, RDX, RCX, R8, R9)
    ; Мы сохраним их сюда в начале функции, чтобы обращаться как к массиву
    arg_storage   resq 5

    ; Место для хранения XMM регистров (8 штук по 16 байт), если решим парсить float
    xmm_storage   resb 128
