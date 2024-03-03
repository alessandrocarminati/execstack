#include "asm_const.h"
.section .text
.globl asm_foo
.type asm_foo, @function
asm_foo:
  mov $ASM_CONST_1, %eax
  /* asm code with proper stack manipulation for C calling conventions */
  ret
