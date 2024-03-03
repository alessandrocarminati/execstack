#include "asm_const.h"
.section .text
.globl asm_foo
.type asm_foo, @function
asm_foo:
  ldr x0, =ASM_CONST_1
  ret
