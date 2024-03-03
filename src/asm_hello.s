.global _start

.text

_start:
    mov $1, %rax
    mov $1, %rdi
    mov $message, %rsi
    mov $7, %rdx
    syscall

    mov $60, %rax
    xor %rdi, %rdi
    syscall

message:
    .ascii "Hello!\n"
