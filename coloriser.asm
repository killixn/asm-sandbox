SYS_WRITE  equ 1
SYS_EXIT   equ 60
STDOUT     equ 1

section .data
    setground_text   db "--set-ground",0
    setcolor_text    db "--set-color",0
    inputerror_text  db "error",10,0
    ; --- Foreground ANSI Color Code ---
    fblack           db 27,"[30m",0
    fred             db 27,"[31m",0
    fgreen           db 27,"[32m",0
    fyellow          db 27,"[33m",0
    fblue            db 27,"[34m",0
    fmagenta         db 27,"[35m",0
    fcyan            db 27,"[36m",0
    fwhite           db 27,"[37m",0
    fdefault         db 27,"[39m",0
    ; --- Background ANSI Color Code ---
    bblack           db 27,"[40m",0
    bred             db 27,"[41m",0
    bgreen           db 27,"[42m",0
    byellow          db 27,"[43m",0
    bblue            db 27,"[44m",0
    bmagenta         db 27,"[45m",0
    bcyan            db 27,"[46m",0
    bwhite           db 27,"[47m",0
    bdefault         db 27,"[49m",0
    ; --- Reset ANSI Color Code ---
    reset            db 27,"[0m",0
    ; --- Foreground Lookup Table ---
    fg_table         dq fdefault, fblack, fred, fgreen, fyellow, fblue, fmagenta, fcyan, fwhite
    ; --- Background Lookup Table ---
    bg_table         dq bdefault, bblack, bred, bgreen, byellow, bblue, bmagenta, bcyan, bwhite
    ; --- Help Command ---
    help_msg         db "coloriser - Text Coloring Utility",10,10
                     db "USAGE:",10
                     db '    ./coloriser [OPTIONS] "Text"',10,10
                     db "OPTIONS:",10
                     db "    --set-color <code>",10
                     db "        Set the foreground (text) color",10
                     db "    --set-ground <code>",10
                     db "        Set the background color",10,10
                     db "CODE:",10
                     db "    0    default",10
                     db "    1    black",10
                     db "    2    red",10
                     db "    3    green",10
                     db "    4    yellow",10
                     db "    5    blue",10
                     db "    6    magenta",10
                     db "    7    cyan",10
                     db "    8    white",10,10
                     db "EXAMPLES:",10
                     db '    ./coloriser --set-color 2 "Hello"',10
                     db '        > Prints "Hello" in red',10,10
                     db '    ./coloriser --set-ground 4 --set-color 2 "Hello"',10
                     db '        > Prints "Hello" in red with a yellow background',10,0

section .bss
	argc      resb 8
	curr_arg  resb 8
    color     resb 8
    ground    resb 8
    text      resb 8

section .text
    global _start

_start:  
    ; default colors
    mov qword [color], fdefault
    mov qword [ground], bdefault

	; recover argc from the stack
	pop rax
	mov [argc], rax

	; check argc == 1
	cmp rax, 1
	je _printhelp
  
    ; ignore the path (useless)
    pop rax

    ; update curr_arg
	mov qword [curr_arg], 1

_recoverarg:
    ; check argc>=curr_arg
	mov rax, [curr_arg]
	mov rbx, [argc]
	cmp rax, rbx
	jg _inputerror

    ; argv[curr_arg]
    pop rdi
    inc qword [curr_arg]

    ; save current pointer
    mov r12, rdi

    ; strcmp(argv[curr_arg], "--set-color")
    mov rsi, setcolor_text
    call _my_strcmp
    cmp rax, 0
    je _setcolor
  
    ; strcmp(argv[curr_arg], "--set-ground")
    mov rdi, r12
    mov rsi, setground_text
    call _my_strcmp
    cmp rax, 0
    je _setground
    
    ; set text
    mov [text], r12
    jmp _main_print

_main_print:
    ; sys_write(stdout, color, sizeof(color))
    mov rax, [color]
    call _print
    ; sys_write(stdout, ground, sizeof(ground))
    mov rax, [ground]
    call _print
    ; sys_write(stdout, text, sizeof(text))
    mov rax, [text]
    call _print
    ; sys_write(stdout, reset, sizeof(reset))
    mov rax, reset
    call _print
    call _exit

_printhelp:
    mov rax, help_msg
    call _print
    call _exit

_inputerror:
    mov rax, inputerror_text
    call _print
    call _exit

; recover text color (next value on the stack), then set it
_setcolor:
	pop rdi
    inc qword [curr_arg]

    ; first character ('0' .. '8')
    movzx rax, byte [rdi]
    ; index 0..8
    sub rax, '0'
    cmp rax, 0
    jl _inputerror
    cmp rax, 8
    jg _inputerror

    ; color = fg_table[index]
    lea rbx, [fg_table]
    mov rax, [rbx + rax*8]
    mov [color], rax
    jmp _recoverarg

; recover ground color (next value on the stack), then set it
_setground:
    pop rdi
    inc qword [curr_arg]

    movzx rax, byte [rdi]
    sub rax, '0'
    cmp rax, 0
    jl _inputerror
    cmp rax, 8
    jg _inputerror

    lea rbx, [bg_table]
    mov rax, [rbx + rax*8]
    mov [ground], rax
    jmp _recoverarg
 
;input: rax as pointer to string
;output: print string at rax
_print:
	push rax
	mov rbx, rax
_printlen:
    mov cl, [rbx]
    cmp cl, 0
    je _printwrite
    inc rbx
    jmp _printlen
_printwrite:
    sub rbx, rax
    mov rdx, rbx
    mov rax, SYS_WRITE
    mov rdi, STDOUT
    pop rsi
    syscall
    ret

_my_strcmp:
    ; set RAX (result) to 0
    xor rax, rax
_next_char:
    ; load byte from first string
    mov al, [rdi]
    ; compare with second string
    cmp al, [rsi]
    ; if not equal, jump to diff
    jne _strcmp_diff
    ; check if we’ve hit \0
    test al, al
    ; if \0, strings are equal
    je _strcmp_done
    ; advance pointers
    inc rdi
    inc rsi
    ; repeat
    jmp _next_char
_strcmp_diff:
    ; Return difference
    movzx rax, byte [rdi]
    sub rax, [rsi]
_strcmp_done:
    ret

_exit:
    ; sys_exit(0)
    mov rax, SYS_EXIT
    xor rdi, rdi
    syscall
