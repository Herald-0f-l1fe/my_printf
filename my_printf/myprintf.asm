section .text
global my_printf
extern printf
my_printf:
    push rbp
    mov rbp, rsp
    push rbx
    push r12
    push r13
    push r14
    push r15 
    lea    rax, [buffer]        ; загружаю
    mov    [buf_ptr], rax

    ; Сохраняю аргументы из регистров в .bss 
    mov [orig_format_ptr],  rdi
    mov [arg_storage],      rsi
    mov [arg_storage + 8],  rdx
    mov [arg_storage + 16], rcx
    mov [arg_storage + 24], r8
    mov [arg_storage + 32], r9

    
    ; test al, al
    ; jz .skip_xmm

    movsd [xmm_storage],       xmm0
    movsd [xmm_storage + 8],   xmm1
    movsd [xmm_storage + 16],  xmm2
    movsd [xmm_storage + 24],  xmm3
    movsd [xmm_storage + 32],  xmm4
    movsd [xmm_storage + 40],  xmm5
    movsd [xmm_storage + 48],  xmm6
    movsd [xmm_storage + 56],  xmm7

.skip_xmm:

    mov r12, rdi        ; R12 = форматная строка
    xor r13, r13        ; R13 =  текущего аргумента (не double)
    xor r14, r14        ; R14 = индекс текущего xmm-аргумента 


.scan_loop:
    movzx rax, byte [r12]   
    test al, al             
    jz .flush_and_exit     
    

    cmp al, '%'             
    je .handle_specifier    

    
    mov rdi, [buf_ptr]      
    mov [rdi], al           
    inc qword [buf_ptr]     
    inc r12                 
    jmp .scan_loop          

.handle_specifier:
    inc r12                 
    movzx rax, byte [r12]   
    jmp [jump_table + rax * 8]

.print_string:
    call get_argument
    mov rsi, rax
    test rsi, rsi
    jnz .string_copy_loop
    lea rsi, [null_str]       ; Если NULL, подменяем на "(null)"

.string_copy_loop:
    mov al, [rsi]            
    test al, al              
    jz .string_done
    mov rdi, [buf_ptr]
    mov [rdi], al
    inc qword [buf_ptr]
    inc rsi                  
    jmp .string_copy_loop

.string_done:
    inc r12                  
    jmp .scan_loop           


.print_percent:
    mov rdi, [buf_ptr]
    mov byte [rdi], '%'
    inc qword [buf_ptr]
    inc r12
    jmp .scan_loop

.print_char:
    call get_argument            
    mov  rdi, [buf_ptr]          
    mov  [rdi], al               
    inc  qword [buf_ptr]         
    inc  r12                     
    jmp  .scan_loop              

.print_bin:
    mov rcx, 2          ; Основание системы счисления
    jmp .prepare_number

.print_oct:
    mov rcx, 8
    jmp .prepare_number

.print_hex:
    mov rcx, 16
    jmp .prepare_number


.print_int:    
    call get_argument
    test eax, eax
    jns .unsigned_prepare    
    
    movsxd rax, eax         ; потому что расширялось до 8 байт
    push rax
    mov rdi, [buf_ptr]
    mov byte [rdi], '-'      
    inc qword [buf_ptr]
    pop rax
    neg rax                  


.unsigned_prepare:
    test eax, eax
    js .skip_clear
    mov eax, eax        ; загляушка
.skip_clear:
    mov rcx, 10              ; Основание 10
    call convert_number
    inc r12
    jmp .scan_loop

.print_float:
    mov     rax, r14
    shl     rax, 3
    movsd   xmm0, [xmm_storage + rax]
    inc     r14
    sub     rsp, 16
    movsd   [rsp], xmm0

    ; Проверяю зна  к числа
    movmskpd eax, xmm0
    test eax, eax
    jz     .positive
    mov rdi, [buf_ptr]
    mov byte [rdi], '-'     
    inc qword [buf_ptr]
    movsd   xmm0, [rsp]         ; Загружаю число обратно
    andps   xmm0, [abs_mask]    ; Беру абсолютное значение (

.positive:
    movsd   [rsp], xmm0
    ; Целая часть
    cvttsd2si rax, xmm0         
    push    rax                 ; сохраняю целую часть для дробной части

    mov     rcx, 10
    call    convert_number       ; печатаю целую часть

    mov     rdi, [buf_ptr]
    mov     byte [rdi], '.'
    inc     qword [buf_ptr]

    ; Вычисляю дробную часть
    pop     rax             
    movsd   xmm0, [rsp]     
    cvtsi2sd xmm1, rax
    subsd   xmm0, xmm1      

    ; Умножаю на 1 000 000 (6 знаков)
    mov     rax, 1000000
    cvtsi2sd xmm1, rax
    mulsd   xmm0, xmm1
    addsd   xmm0, [half]        ; округление
    cvttsd2si rax, xmm0         

    ; Печатаем дробную часть с ведущими нулями
    mov     rcx, 6              ; требуемое количество цифр
    mov     rdi, num_buffer + 63

.fraction_loop:
    xor     rdx, rdx
    mov     rbx, 10
    div     rbx                 ; RAX / 10, остаток в RDX
    add     dl, '0'
    mov     [rdi], dl
    dec     rdi
    dec     rcx
    test    rax, rax
    jnz     .fraction_loop

    ; Заполняю остаток нулями
.fill_zeros:
    test    rcx, rcx
    jz      .copy_fraction
    mov     byte [rdi], '0'
    dec     rdi
    dec     rcx
    jmp     .fill_zeros

.copy_fraction:
    inc     rdi                 ; rdi указывает на первый символ
    mov     rcx, (num_buffer + 64)
    sub     rcx, rdi            ; длина строки
    mov     rsi, rdi
    mov     rdi, [buf_ptr]      ; текущая позиция в основном буфере
    rep     movsb
    mov     [buf_ptr], rdi      ; обновляю указатель

    add     rsp, 16

    inc     r12                
    jmp     .scan_loop

.prepare_number:
    call get_argument    
    call convert_number
    
    inc r12             ; Пропускаю символ спецификатора в форматной строке
    jmp .scan_loop      ; Возвращаюсь в основной цикл

.default_case:
    inc r12
    jmp .scan_loop


.flush_and_exit:
    call flush_buffer
    call restore_regs   
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    pop rbp
    jmp printf wrt ..plt  ; wrt ..plt нужно для динамической линковки (PIC)
    


convert_number:
    push rbx
    push rdx
    mov rdi, num_buffer + 63 
    mov rbx, rcx            

.conv_loop:
    xor rdx, rdx
    div rbx                  
    
    movzx rdx, byte [HEX_CHARS + rdx]
    mov [rdi], dl           
    dec rdi                 
    
    test rax, rax           
    jnz .conv_loop

    inc rdi
    
.copy_to_main:
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

get_argument:
    cmp r13, 5         
    jl .from_storage   
    mov rax, r13       
    sub rax, 5         
    shl rax, 3         
    add rax, 16
    mov rax, [rbp + rax] 
    jmp .arg_found

.from_storage:
    mov rax, [arg_storage + r13 * 8]

.arg_found:
    inc r13             
    ret

flush_buffer:
    mov rax, 1 ; sys_write
    mov rdi, 1 ; stdout
    mov rsi, buffer
    mov rdx, [buf_ptr]
    sub rdx, buffer
    syscall
    mov qword [buf_ptr], buffer
    ret

restore_regs:
    mov rdi, [orig_format_ptr]
    mov rsi, [arg_storage]
    mov rdx, [arg_storage + 8 ]
    mov rcx, [arg_storage + 16]
    mov r8,  [arg_storage + 24]
    mov r9,  [arg_storage + 32]

    movsd xmm0, [xmm_storage]
    movsd xmm1, [xmm_storage +  8]  
    movsd xmm2, [xmm_storage + 16]  
    movsd xmm3, [xmm_storage + 24]  
    movsd xmm4, [xmm_storage + 32]  
    movsd xmm5, [xmm_storage + 40]  
    movsd xmm6, [xmm_storage + 48]  
    movsd xmm7, [xmm_storage + 56]  

section .data
    align 8
    ; Константы для системного вызова write (Linux x64)
    SYS_WRITE     equ 1
    STDOUT        equ 1

    ; Таблица символов для перевода чисел в разные системы счисления (10, 16, 8, 2)
    HEX_CHARS     db "0123456789abcdef"

    ; Данные для работы с float
    align 16
    abs_mask:   dq 0x7FFFFFFFFFFFFFFF, 0x7FFFFFFFFFFFFFFF
    half:   dq 0.5

    ; Данные для работы со строкой
    null_str      db "(null)", 0

    ; jump таблица
    align 8
    jump_table:
    %assign i 0
    %rep 256
        %if i == 'd'
            dq my_printf.print_int
        %elif i == 's'
            dq my_printf.print_string
        %elif i == 'f'
            dq my_printf.print_float
        %elif i == '%'
            dq my_printf.print_percent
        %elif i == 'b'
            dq my_printf.print_bin    
        %elif i == 'c'
            dq my_printf.print_char
        %elif i == 'o'
            dq my_printf.print_oct    
        %elif i == 'x'
            dq my_printf.print_hex    
        %else
            dq my_printf.default_case
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
    arg_storage   resq 5

    ; Место для хранения XMM регистров (8 штук по 8 байт)
    xmm_storage   resb 64

    ; Данные для callback 
    orig_format_ptr resq 1