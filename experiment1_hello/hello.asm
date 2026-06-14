.global _start

.section .data
msg:
    .ascii "Hello, World!\n"
    len = . - msg

.section .text
_start:
    # write(1, msg, len)
    movq $1, %rax
    movq $1, %rdi
    movq $msg, %rsi
    movq $len, %rdx
    syscall

    # exit(0)
    movq $60, %rax
    movq $0, %rdi
    syscall
