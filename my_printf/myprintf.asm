global my_printf

section .text

my_printf:
    ; 1. Сохраняю состояние вызывающей функции
    push rbp
    mov rbp, rsp
    
    ; Сохраняю callee-saved регистры, которые буду использовать
    push r12
    push r13
    push r14
    push r15 ; на всякий случай, если понадобится для расчетов

    ; 2. Инициализирую  указатель в буфере
    mov qword [buf_ptr], buffer 

    ; 3. Сохраняю аргументы из регистров в .bss 
    mov [arg_storage],      rsi
    mov [arg_storage + 8],  rdx
    mov [arg_storage + 16], rcx
    mov [arg_storage + 24], r8
    mov [arg_storage + 32], r9

    ; 4. Обработка XMM (AL)
    test al, al
    jz .skip_xmm

    movups [xmm_storage],       xmm0
    movups [xmm_storage + 16],  xmm1
    movups [xmm_storage + 32],  xmm2
    movups [xmm_storage + 48],  xmm3
    movups [xmm_storage + 64],  xmm4
    movups [xmm_storage + 80],  xmm5
    movups [xmm_storage + 96],  xmm6
    movups [xmm_storage + 112], xmm7.skip_xmm:

    ; 5. Подготовка к работе
    mov r12, rdi        ; R12 = форматная строка
    xor r13, r13        ; R13 =  текущего int-аргумента (0-4)
    xor r14, r14        ; R14 = индекс текущего xmm-аргумента (0-7)


.scan_loop:
    movzx rax, byte [r12]   ; Беру текущий символ из форматной строки
    test al, al             ; Проверка на конец строки (NULL-терминатор)
    jz .flush_and_exit      ; Если 0, выходим и сбрасываем буфер на экран

    cmp al, '%'             ; Проверяю, не встретили ли '%' 
    je .handle_specifier    ; Если да, иду обрабатывать аргумент

    ; --- Секция обычного символа ---
    ; Копирую символ прямо в наш основной буфер
    mov rdi, [buf_ptr]      ; Загружаю адрес текущей свободной позиции
    mov [rdi], al           ; Пишу символ в буфер
    inc qword [buf_ptr]     ; Сдвигаю указатель буфера на 1
    
    ; Проверка переполнения буфера (опционально, но полезно)
    ; Если (buf_ptr - buffer) >= BUF_SIZE, пора делать syscall write

    inc r12                 ; Перехожу к следующему символу форматной строки
    jmp .scan_loop          ; Повторяю

.handle_specifier:
    inc r12                 ; Пропускаю '%'
    movzx rax, byte [r12]   ; Получаем символ спецификатора 
    
    ; Прыгаю по адресу: jump_table + (rax * 8)
    jmp [jump_table + rax * 8]

.print_string:
    ; 1. Достаем адрес строки из аргументов
    call get_argument

    ; 2. Проверяем, не пришел ли NULL (защита от падения)
    test rsi, rsi
    jnz .string_copy_loop
    mov rsi, .null_str       ; Если NULL, подменяем на "(null)"

.string_copy_loop:
    mov al, [rsi]            ; Читаем байт из строки-аргумента
    test al, al              ; Конец строки-аргумента?
    jz .string_done

    ; 3. Пишем в наш основной буфер
    mov rdi, [buf_ptr]
    mov [rdi], al
    inc qword [buf_ptr]
    

    inc rsi                  ; К следующему символу аргумента
    jmp .string_copy_loop

.string_done:
    inc r12                  ; Пропускаем 's' в форматной строке
    jmp .scan_loop           ; Возвращаемся к парсингу формата


.print_percent:
    ; Логика для %%
    mov rdi, [buf_ptr]
    mov byte [rdi], '%'
    inc qword [buf_ptr]
    inc r12
    jmp .scan_loop

.print_bin:
    mov rcx, 2          ; Основание системы счисления
    jmp .prepare_number

.print_oct:
    mov rcx, 8
    jmp .prepare_number

.print_int:

    
    ; Проверяю знаковый бит (MSB)
    test rax, rax
    jns .unsigned_prepare    ; Если число >= 0, иду как обычно

    ; Если число отрицательное:
    abs rax                  ; Делаю число положительным (rax = -rax)
    
    ; Сохраняю rax, так как вывод знака может его затронуть
    push rax
    mov rdi, [buf_ptr]
    mov byte [rdi], '-'      ; Пишу минус в буфер
    inc qword [buf_ptr]
    pop rax

.unsigned_prepare:
    mov rcx, 10              ; Основание 10
    call convert_number
    inc r12
    jmp .scan_loop


.print_hex:
    mov rcx, 16
    jmp .prepare_number

.prepare_number:
    call get_argument    
    ; Теперь вызываю функцию конвертации (передаем число в RAX, базу в RCX)
    call convert_number
    
    inc r12             ; Пропускаю символ спецификатора в форматной строке
    jmp .scan_loop      ; Возвращаюсь в основной цикл

.default_case:
    ; Если встретил неизвестный символ после % (напр. %z)
    ; Просто печатаю его или игнорируем
    inc r12
    jmp .scan_loop


.done:
    ; (Тут код финального вывода буфера через syscall write)

    ; Восстанавливаю сохраненные регистры в обратном порядке
    pop r15
    pop r14
    pop r13
    pop r12
    
    pop rbp
    ret


convert_number proc
    ; Сохраняю регистры
    push rbx
    push rdx
    
    mov rdi, num_buffer + 63 ; Начинаю с конца временного буфера
    mov rbx, rcx             ; В RBX — основание (делитель)

.conv_loop:
    xor rdx, rdx
    div rbx                  ; RAX / RBX, остаток в RDX
    
    ; Превращаю остаток в символ из HEX_CHARS
    movzx rdx, byte [HEX_CHARS + rdx]
    mov [rdi], dl            ; Записываю символ в num_buffer
    dec rdi                  ; Сдвигаюсь влево
    
    test rax, rax            ; Число закончилось?
    jnz .conv_loop

    ; Теперь копирую из num_buffer в основной buffer
    ; rdi сейчас указывает на байт перед первым символом числа
    inc rdi                  ; Указываю на первый символ
    
.copy_to_main:
    ; Вычисляю, сколько байт копировать
    mov rcx, (num_buffer + 64)
    sub rcx, rdi             ; RCX = количество символов числа
    
    mov rsi, rdi             ; Откуда (num_buffer)
    mov rdi, [buf_ptr]       ; Куда (основной буфер)
    
    push rcx                 ; Сохраняю длину для обновления buf_ptr
    rep movsb                ; Копирую RCX байт
    pop rcx
    
    add [buf_ptr], rcx       ; Обновляю курсор основного буфера
    
    pop rdx
    pop rbx
    ret
convert_number endp

get_argument proc
    ; Вход: R13 (счетчик аргументов, начиная с 0)
    ; Выход: RAX (значение аргумента)
    
    cmp r13, 5          ; Мы уже использовали все 5 регистров (RSI, RDX, RCX, R8, R9)?
    jl .from_storage    ; Если нет, берем из нашего массива в .bss

    ; --- Берем из стека ---
    ; Первый аргумент в стеке лежит по адресу [rbp + 16]
    ; r13 = 5 должен соответствовать [rbp + 16]
    ; r13 = 6 должен соответствовать [rbp + 24]
    ; Формула: [rbp + 16 + (r13 - 5) * 8]
    
    mov rax, r13        ; копируем индекс
    sub rax, 5          ; вычитаем 5
    shl rax, 3          ; умножаем на 8 (сдвиг на 3 бита влево)
    add rax, 16         ; прибавляем смещение
    mov rax, [rbp + rax] ; достаем значение из стека
    jmp .arg_found

.from_storage:
    mov rax, [arg_storage + r13 * 8]

.arg_found:
    inc r13             ; Готовим индекс для следующего вызова
    ret
get_argument endp


section .data
    ; Константы для системного вызова write (Linux x64)
    SYS_WRITE     equ 1
    STDOUT        equ 1

    ; Таблица символов для перевода чисел в разные системы счисления (10, 16, 2)
    HEX_CHARS     db "0123456789abcdef"
    .null_str db "(null)", 0
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
        %elif i == 'b'
            dq .print_bin    ; Двоичная
        %elif i == 'o'
            dq .print_oct    ; Восьмеричная
        %elif i == 'x'
            dq .print_hex    ; Шестнадцатеричная
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

    ; Временный буфер для конвертации числа (макс ~64 символа для двоичной системы)
    ; Сначала пишу число сюда (задом наперед), а потом копирую в основной буфер
    num_buffer    resb 64

    ; Место для хранения всех целочисленных аргументов из регистров (RSI, RDX, RCX, R8, R9)
    ; Я сохраняю их сюда в начале функции, чтобы обращаться как к массиву
    arg_storage   resq 5

    ; Место для хранения XMM регистров (8 штук по 16 байт)
    xmm_storage   resb 128
