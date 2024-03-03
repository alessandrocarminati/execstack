
## intro

Sometimes, what we perceive as a constant in our programming environments
can undergo unexpected shifts, challenging our assumptions.
In my journey to understand the mechanics behind stack overflow exploits,
I encountered such a shift when grappling with the intricacies of the stack.
Initially, as I delved into these techniques using machines devoid of MMUs,
namely, plain m68k and x86 real mode, I paid little heed to memory flags.
In those days, hackers could seamlessly inject binary payloads onto the
stack, redirect program flow to the designated stack address housing their
payloads, and execute their exploits with ease.

However, after setting aside these experiments for a time and revisiting
them on early Linux machines, I encountered a surprising obstacle around
2005: the once-reliable technique suddenly ceased to function.
Upon investigation, I came to the realization that assuming the
executability of the stack was no longer tenable. Henceforth, I found
myself grappling with the repercussions of this change, as the default
behavior of compilers had shifted to render the stack non-executable.
Or so I believed, until a recent inquiry from a client prompted me to 
revisit this assumption, revealing a truth starkly different from my
prior expectations.

## chapter 1 - What it seems like

So, what do we have here? Since 2005, something peculiar has emerged. 
When compiling a simple, trivial program using the C compiler, we observe
the following:

```
$ echo -e "#include <stdio.h>\nint main(){printf(\"hello\\\n\");}"| gcc -x c -o hello - ;readelf -l hello

Elf file type is EXEC (Executable file)
Entry point 0x4004a0
There are 9 program headers, starting at offset 64

Program Headers:
  Type           Offset             VirtAddr           PhysAddr
                 FileSiz            MemSiz              Flags  Align
  PHDR           0x0000000000000040 0x0000000000400040 0x0000000000400040
                 0x00000000000001f8 0x00000000000001f8  R      0x8
  INTERP         0x0000000000000238 0x0000000000400238 0x0000000000400238
                 0x000000000000001c 0x000000000000001c  R      0x1
      [Requesting program interpreter: /lib64/ld-linux-x86-64.so.2]
  LOAD           0x0000000000000000 0x0000000000400000 0x0000000000400000
                 0x0000000000000768 0x0000000000000768  R E    0x200000
  LOAD           0x0000000000000e00 0x0000000000600e00 0x0000000000600e00
                 0x0000000000000224 0x0000000000000228  RW     0x200000
  DYNAMIC        0x0000000000000e10 0x0000000000600e10 0x0000000000600e10
                 0x00000000000001d0 0x00000000000001d0  RW     0x8
  NOTE           0x0000000000000254 0x0000000000400254 0x0000000000400254
                 0x0000000000000044 0x0000000000000044  R      0x4
  GNU_EH_FRAME   0x0000000000000640 0x0000000000400640 0x0000000000400640
                 0x000000000000003c 0x000000000000003c  R      0x4
  GNU_STACK      0x0000000000000000 0x0000000000000000 0x0000000000000000
                 0x0000000000000000 0x0000000000000000  RW     0x10
  GNU_RELRO      0x0000000000000e00 0x0000000000600e00 0x0000000000600e00
                 0x0000000000000200 0x0000000000000200  R      0x1

 Section to Segment mapping:
  Segment Sections...
   00     
   01     .interp 
   02     .interp .note.ABI-tag .note.gnu.build-id .gnu.hash .dynsym .dynstr .gnu.version .gnu.version_r .rela.dyn .rela.plt .init .plt .text .fini .rodata .eh_frame_hdr .eh_frame 
   03     .init_array .fini_array .dynamic .got .got.plt .data .bss 
   04     .dynamic 
   05     .note.ABI-tag .note.gnu.build-id 
   06     .eh_frame_hdr 
   07     
   08     .init_array .fini_array .dynamic .got 
```

Not much needs to be said; the stack lacks an executable flag: `RW`
in the `GNU_STACK` section. 
Any attempt to execute code from this space inevitably results in a 
graceful crash, marked by the familiar segmentation fault (SIGSEGV).

Conversely, if our intention is to create an executable stack, we must
explicitly instruct the compiler to do so. 

```
$ echo -e "#include <stdio.h>\nint main(){printf(\"hello\\\n\");}"| gcc -x c -z execstack -o hello - ;readelf -l hello

Elf file type is EXEC (Executable file)
Entry point 0x4004a0
There are 9 program headers, starting at offset 64

Program Headers:
  Type           Offset             VirtAddr           PhysAddr
                 FileSiz            MemSiz              Flags  Align
  PHDR           0x0000000000000040 0x0000000000400040 0x0000000000400040
                 0x00000000000001f8 0x00000000000001f8  R      0x8
  INTERP         0x0000000000000238 0x0000000000400238 0x0000000000400238
                 0x000000000000001c 0x000000000000001c  R      0x1
      [Requesting program interpreter: /lib64/ld-linux-x86-64.so.2]
  LOAD           0x0000000000000000 0x0000000000400000 0x0000000000400000
                 0x0000000000000768 0x0000000000000768  R E    0x200000
  LOAD           0x0000000000000e00 0x0000000000600e00 0x0000000000600e00
                 0x0000000000000224 0x0000000000000228  RW     0x200000
  DYNAMIC        0x0000000000000e10 0x0000000000600e10 0x0000000000600e10
                 0x00000000000001d0 0x00000000000001d0  RW     0x8
  NOTE           0x0000000000000254 0x0000000000400254 0x0000000000400254
                 0x0000000000000044 0x0000000000000044  R      0x4
  GNU_EH_FRAME   0x0000000000000640 0x0000000000400640 0x0000000000400640
                 0x000000000000003c 0x000000000000003c  R      0x4
  GNU_STACK      0x0000000000000000 0x0000000000000000 0x0000000000000000
                 0x0000000000000000 0x0000000000000000  RWE    0x10
  GNU_RELRO      0x0000000000000e00 0x0000000000600e00 0x0000000000600e00
                 0x0000000000000200 0x0000000000000200  R      0x1

 Section to Segment mapping:
  Segment Sections...
   00     
   01     .interp 
   02     .interp .note.ABI-tag .note.gnu.build-id .gnu.hash .dynsym .dynstr .gnu.version .gnu.version_r .rela.dyn .rela.plt .init .plt .text .fini .rodata .eh_frame_hdr .eh_frame 
   03     .init_array .fini_array .dynamic .got .got.plt .data .bss 
   04     .dynamic 
   05     .note.ABI-tag .note.gnu.build-id 
   06     .eh_frame_hdr 
   07     
   08     .init_array .fini_array .dynamic .got  
```

Upon inspection, `RWE` in the `GNU_STACK` section, we confirm the presence
of an executable stack.

In summary, the probability of encountering a new binary with an executable
stack in contemporary settings is close to zero. Such instances may occur
only if someone utilizes an outdated compiler or requires an executable
stack for specific reasons. So, why would anyone desire an executable stack?

Perhaps solely to revisit the methods employed in old-fashioned stack 
overflow exploits!

# Chapter 2 - Things are never a easy as they seems
￼
Recently, a customer posed what initially appeared to be a trivial question: 
"What flag should I use to ensure that the stack remains non-executable?"
I brushed it off as a simple matter, assuming that no action was needed since
it was the default behavior.

However, the response from a knowledgeable individual surprised me: 
simply use `-z nostackexec`. 
This prompted me to question why such a flag even existed. 
After all, if the default behavior is to have a non-executable stack, what
purpose does this flag serve?

Reflecting on past encounters with this flag, I had rationalized its existence
by speculating, "Perhaps it's necessary for exotic architectures where the
default is to have an executable stack". 

However, I soon realized that the reality is far more complex than it initially
seemed.

Let's begin by clarifying: compilers do not manipulate stack flags; this task 
falls under the responsibility of the linker. The final executable is created by 
linking together all the object files generated by the compiler.

During the creation of ELF sections, the linker scans the input files for a 
specific section named ".note.GNU-stack". This section conveys whether an 
executable stack is required or not.

According to the linker's [manual page](https://man7.org/linux/man-pages/man1/ld.1.html), 
if an input file lacks a `.note.GNU-stack` section, then the default behavior 
is architecture-specific.

As I couldn't find where this default behavior is specified, let's conduct a 
couple of tests. You can find a collection of tests I've prepared in this 
repository.

Consider the `gcc/asm_function` executable file, which is a simple C executable 
that includes  a basic function from an assembly file. 
Below is the relevant portion of the Makefile used to build it:

```
gcc/asm_function.o: src/asm_function.S
        gcc -g -c -o gcc/asm_function.o src/asm_function.S

gcc/test_asm.o: src/test_asm.c
        gcc -g -c -o gcc/test_asm.o src/test_asm.c

gcc/test_asm: gcc/test_asm.o gcc/asm_function.o
        gcc -g gcc/test_asm.o gcc/asm_function.o -o gcc/asm_function
```
Upon examining the generated object file, you'll notice the absence of the 
`.note.GNU-stack` section. However, upon inspecting the resultant executable, 
you'll observe that the stack is indeed marked as executable.

```
$ readelf -S gcc/asm_function.o
There are 15 section headers, starting at offset 0x3b8:

Section Headers:
  [Nr] Name              Type             Address           Offset
       Size              EntSize          Flags  Link  Info  Align
  [ 0]                   NULL             0000000000000000  00000000
       0000000000000000  0000000000000000           0     0     0
  [ 1] .text             PROGBITS         0000000000000000  00000040
       0000000000000006  0000000000000000  AX       0     0     1
  [ 2] .data             PROGBITS         0000000000000000  00000046
       0000000000000000  0000000000000000  WA       0     0     1
  [ 3] .bss              NOBITS           0000000000000000  00000046
       0000000000000000  0000000000000000  WA       0     0     1
  [ 4] .debug_line       PROGBITS         0000000000000000  00000046
       0000000000000045  0000000000000000           0     0     1
  [ 5] .rela.debug_line  RELA             0000000000000000  00000248
       0000000000000018  0000000000000018   I      12     4     8
  [ 6] .debug_info       PROGBITS         0000000000000000  0000008b
       000000000000002e  0000000000000000           0     0     1
  [ 7] .rela.debug_info  RELA             0000000000000000  00000260
       00000000000000a8  0000000000000018   I      12     6     8
  [ 8] .debug_abbrev     PROGBITS         0000000000000000  000000b9
       0000000000000014  0000000000000000           0     0     1
  [ 9] .debug_aranges    PROGBITS         0000000000000000  000000d0
       0000000000000030  0000000000000000           0     0     16
  [10] .rela.debug_arang RELA             0000000000000000  00000308
       0000000000000030  0000000000000018   I      12     9     8
  [11] .debug_str        PROGBITS         0000000000000000  00000100
       0000000000000045  0000000000000001  MS       0     0     1
  [12] .symtab           SYMTAB           0000000000000000  00000148
       00000000000000f0  0000000000000018          13     9     8
  [13] .strtab           STRTAB           0000000000000000  00000238
       0000000000000009  0000000000000000           0     0     1
  [14] .shstrtab         STRTAB           0000000000000000  00000338
       000000000000007b  0000000000000000           0     0     1
Key to Flags:
  W (write), A (alloc), X (execute), M (merge), S (strings), I (info),
  L (link order), O (extra OS processing required), G (group), T (TLS),
  C (compressed), x (unknown), o (OS specific), E (exclude),
  l (large), p (processor specific)
$ readelf -l gcc/asm_function

Elf file type is DYN (Shared object file)
Entry point 0x1040
There are 11 program headers, starting at offset 64

Program Headers:
  Type           Offset             VirtAddr           PhysAddr
                 FileSiz            MemSiz              Flags  Align
  PHDR           0x0000000000000040 0x0000000000000040 0x0000000000000040
                 0x0000000000000268 0x0000000000000268  R      0x8
  INTERP         0x00000000000002a8 0x00000000000002a8 0x00000000000002a8
                 0x000000000000001c 0x000000000000001c  R      0x1
      [Requesting program interpreter: /lib64/ld-linux-x86-64.so.2]
  LOAD           0x0000000000000000 0x0000000000000000 0x0000000000000000
                 0x0000000000000530 0x0000000000000530  R      0x1000
  LOAD           0x0000000000001000 0x0000000000001000 0x0000000000001000
                 0x00000000000001d5 0x00000000000001d5  R E    0x1000
  LOAD           0x0000000000002000 0x0000000000002000 0x0000000000002000
                 0x0000000000000130 0x0000000000000130  R      0x1000
  LOAD           0x0000000000002df0 0x0000000000003df0 0x0000000000003df0
                 0x0000000000000220 0x0000000000000228  RW     0x1000
  DYNAMIC        0x0000000000002e00 0x0000000000003e00 0x0000000000003e00
                 0x00000000000001c0 0x00000000000001c0  RW     0x8
  NOTE           0x00000000000002c4 0x00000000000002c4 0x00000000000002c4
                 0x0000000000000044 0x0000000000000044  R      0x4
  GNU_EH_FRAME   0x0000000000002004 0x0000000000002004 0x0000000000002004
                 0x000000000000003c 0x000000000000003c  R      0x4
  GNU_STACK      0x0000000000000000 0x0000000000000000 0x0000000000000000
                 0x0000000000000000 0x0000000000000000  RWE    0x10
  GNU_RELRO      0x0000000000002df0 0x0000000000003df0 0x0000000000003df0
                 0x0000000000000210 0x0000000000000210  R      0x1

 Section to Segment mapping:
  Segment Sections...
   00     
   01     .interp 
   02     .interp .note.gnu.build-id .note.ABI-tag .gnu.hash .dynsym .dynstr .gnu.version .gnu.version_r .rela.dyn 
   03     .init .plt .plt.got .text .fini 
   04     .rodata .eh_frame_hdr .eh_frame 
   05     .init_array .fini_array .dynamic .got .data .bss 
   06     .dynamic 
   07     .note.gnu.build-id .note.ABI-tag 
   08     .eh_frame_hdr 
   09     
   10     .init_array .fini_array .dynamic .got 
```
This suggests that the default for x86_64 architecture is executable stack.
Doing the same for aarch64, produces the followings:
```
$ readelf -S gcc/asm_function.aarch64.o
There are 15 section headers, starting at offset 0x400:

Section Headers:
  [Nr] Name              Type             Address           Offset
       Size              EntSize          Flags  Link  Info  Align
  [ 0]                   NULL             0000000000000000  00000000
       0000000000000000  0000000000000000           0     0     0
  [ 1] .text             PROGBITS         0000000000000000  00000040
       0000000000000010  0000000000000000  AX       0     0     8
  [ 2] .data             PROGBITS         0000000000000000  00000050
       0000000000000000  0000000000000000  WA       0     0     1
  [ 3] .bss              NOBITS           0000000000000000  00000050
       0000000000000000  0000000000000000  WA       0     0     1
  [ 4] .debug_line       PROGBITS         0000000000000000  00000050
       000000000000004c  0000000000000000           0     0     1
  [ 5] .rela.debug_line  RELA             0000000000000000  00000290
       0000000000000018  0000000000000018   I      12     4     8
  [ 6] .debug_info       PROGBITS         0000000000000000  0000009c
       000000000000002e  0000000000000000           0     0     1
  [ 7] .rela.debug_info  RELA             0000000000000000  000002a8
       00000000000000a8  0000000000000018   I      12     6     8
  [ 8] .debug_abbrev     PROGBITS         0000000000000000  000000ca
       0000000000000014  0000000000000000           0     0     1
  [ 9] .debug_aranges    PROGBITS         0000000000000000  000000e0
       0000000000000030  0000000000000000           0     0     16
  [10] .rela.debug_arang RELA             0000000000000000  00000350
       0000000000000030  0000000000000018   I      12     9     8
  [11] .debug_str        PROGBITS         0000000000000000  00000110
       000000000000004d  0000000000000001  MS       0     0     1
  [12] .symtab           SYMTAB           0000000000000000  00000160
       0000000000000120  0000000000000018          13    11     8
  [13] .strtab           STRTAB           0000000000000000  00000280
       000000000000000f  0000000000000000           0     0     1
  [14] .shstrtab         STRTAB           0000000000000000  00000380
       000000000000007b  0000000000000000           0     0     1
Key to Flags:
  W (write), A (alloc), X (execute), M (merge), S (strings), I (info),
  L (link order), O (extra OS processing required), G (group), T (TLS),
  C (compressed), x (unknown), o (OS specific), E (exclude),
  p (processor specific)
$ readelf -l gcc/asm_function.aarch64

Elf file type is DYN (Shared object file)
Entry point 0x610
There are 9 program headers, starting at offset 64

Program Headers:
  Type           Offset             VirtAddr           PhysAddr
                 FileSiz            MemSiz              Flags  Align
  PHDR           0x0000000000000040 0x0000000000000040 0x0000000000000040
                 0x00000000000001f8 0x00000000000001f8  R      0x8
  INTERP         0x0000000000000238 0x0000000000000238 0x0000000000000238
                 0x000000000000001b 0x000000000000001b  R      0x1
      [Requesting program interpreter: /lib/ld-linux-aarch64.so.1]
  LOAD           0x0000000000000000 0x0000000000000000 0x0000000000000000
                 0x000000000000090c 0x000000000000090c  R E    0x10000
  LOAD           0x0000000000000d88 0x0000000000010d88 0x0000000000010d88
                 0x0000000000000288 0x0000000000000290  RW     0x10000
  DYNAMIC        0x0000000000000d98 0x0000000000010d98 0x0000000000010d98
                 0x00000000000001f0 0x00000000000001f0  RW     0x8
  NOTE           0x0000000000000254 0x0000000000000254 0x0000000000000254
                 0x0000000000000044 0x0000000000000044  R      0x4
  GNU_EH_FRAME   0x00000000000007e0 0x00000000000007e0 0x00000000000007e0
                 0x0000000000000044 0x0000000000000044  R      0x4
  GNU_STACK      0x0000000000000000 0x0000000000000000 0x0000000000000000
                 0x0000000000000000 0x0000000000000000  RW     0x10
  GNU_RELRO      0x0000000000000d88 0x0000000000010d88 0x0000000000010d88
                 0x0000000000000278 0x0000000000000278  R      0x1

 Section to Segment mapping:
  Segment Sections...
   00     
   01     .interp 
   02     .interp .note.gnu.build-id .note.ABI-tag .gnu.hash .dynsym .dynstr .gnu.version .gnu.version_r .rela.dyn .rela.plt .init .plt .text .fini .rodata .eh_frame_hdr .eh_frame 
   03     .init_array .fini_array .dynamic .got .data .bss 
   04     .dynamic 
   05     .note.gnu.build-id .note.ABI-tag 
   06     .eh_frame_hdr 
   07     
   08     .init_array .fini_array .dynamic .got 
```
Which is the opposite, non-executable stack, suggesting that the default
for this architecture is to have the stack not executable.


## chapter 3 - is it all?

Returning to the original topic, based on the previous chapter observations,
it is possible to deduce that the two architectures, x86_64 and aarch64,
have different defaults regarding executable stacks. 
But is this the extent of the matter?

Apparently not. 
There are instances where the compiler needs to generate code and execute
it, often utilizing the stack for this purpose. 
In such cases, the resulting executable file will indeed have an executable
stack.

There might be other cases out there, but after a thorough search, I couldn't
find anything except for the GCC GNU extension "nested functions."
It's possible that not many people are aware of this feature - I certainly 
wasn't until recently. 
However, it appears that nested functions can be implemented in C, but only 
when using GCC, clang does not support them.

Nested functions are functions defined within the body of another function. 
These inner functions have access to the variables and parameters of the 
enclosing function and can only be invoked within its scope. 
GCC allows them to exist, but for them to work, the stack needs to be 
executable, at least when they are called indirectly from another function.

Let's consider an example:

```
int nested_carrier(int a, int b, int n) {
    int loc_var = n;
    int multiply2(int z) { return z + z + loc_var; }
    return sum_func(multiply2, a, b);
}
```
In this function, `multiply2` is passed to be executed by the external
function `sum_func`. 
Now, let's examine the assembly implementation of `nested_carrier`.
```
┌ 151: dbg.nested_carrier (int64_t arg1, int64_t arg2, int64_t arg3, int64_t arg_10h);
│     ; arg int64_t arg1 @ rdi
│     ; arg int64_t arg2 @ rsi
│     ; arg int64_t arg3 @ rdx
│     ; arg int64_t arg_10h @ rbp+0x10
│     ; var int z @ rbp-0x4
│     ; var int64_t canary @ rbp-0x8
│     ; var int64_t var_10h @ rbp-0x10
│     ; var int loc_var @ rbp-0x30
│     ; var int a @ rbp-0x34
│     ; var int b @ rbp-0x38
│     ; var int n @ rbp-0x3c
│     0x00001187      f30f1efa       endbr64                            ; nested_local.c:5 int nested_carrier (int a, int b, int n) { 
│                                                                       ; int nested_carrier(int a,int b,int n);
│     0x0000118b      55             push rbp
│     0x0000118c      4889e5         mov rbp, rsp
│     0x0000118f      4883ec40       sub rsp, 0x40
│     0x00001193      897dcc         mov dword [a], edi                 ; arg1
│     0x00001196      8975c8         mov dword [b], esi                 ; arg2
│     0x00001199      8955c4         mov dword [n], edx                 ; arg3
│     0x0000119c      64488b0425..   mov rax, qword fs:[0x28]
│     0x000011a5      488945f8       mov qword [canary], rax            ; Just bought my self a new canary
│     0x000011a9      31c0           xor eax, eax
│     0x000011ab      488d4510       lea rax, [arg_10h]
│     0x000011af      488945f0       mov qword [var_10h], rax
│     0x000011b3      488d45d0       lea rax, [loc_var]
│     0x000011b7      4883c004       add rax, 4
│     0x000011bb      488d55d0       lea rdx, [loc_var]
│     0x000011bf      c700f30f1efa   mov dword [rax], 0xfa1e0ff3        ; Here it is writing the trampoline, note the endbr64 opcode
│     0x000011c5      66c7400449bb   mov word [rax + 4], 0xbb49         ; it stores in the stack
│     0x000011cb      488d0d97ff..   lea rcx, [dbg.multiply2]           ; as the multiply2 address
│     0x000011d2      48894806       mov qword [rax + 6], rcx
│     0x000011d6      66c7400e49ba   mov word [rax + 0xe], 0xba49       ; another opcode 
│     0x000011dc      48895010       mov qword [rax + 0x10], rdx        ; this is the base address to locate parent local vars
│     0x000011e0      c7401849ff..   mov dword [rax + 0x18], 0x90e3ff49 ; more opcodes
│     0x000011e7      8b45c4         mov eax, dword [n]                 ; nested_local.c:6  int loc_var = n;
│     0x000011ea      8945d0         mov dword [loc_var], eax
│     0x000011ed      488d45d0       lea rax, [loc_var]                 ; nested_local.c:8  return sum_func (multiply2, a, b);
│     0x000011f1      4883c004       add rax, 4
│     0x000011f5      4889c1         mov rcx, rax                       ; save trampoline address
│     0x000011f8      8b55c8         mov edx, dword [b]                 ; int64_t arg3 = b
│     0x000011fb      8b45cc         mov eax, dword [a]
│     0x000011fe      89c6           mov esi, eax                       ; int64_t arg2 = a
│     0x00001200      4889cf         mov rdi, rcx                       ; int64_t arg1 = trampoline address!
│     0x00001203      e847000000     call dbg.sum_func
│     0x00001208      488b75f8       mov rsi, qword [canary]            ; Hey canary, are you there?!
│     0x0000120c      6448333425..   xor rsi, qword fs:[0x28]           ; are still you!?
│ ┌─< 0x00001215      7405           je 0x121c                          ; stack overflow check
│ │   0x00001217      e844feffff     call sym.imp.__stack_chk_fail      ; crash if canary is failing
│ └─> 0x0000121c      c9             leave
└     0x0000121d      c3             ret
```
Examining this code, we notice some "alien code" added by our trusty compiler
friend.
Let's set aside the stack check with canary for now; our current focus is on 
the trampoline it's constructing to facilitate the external call. 
Within the function body, we can clearly see the trampoline being constructed,
followed by the point at which the trampoline address is utilized for the
external function call.

```
(gdb) x/10i $pc
=> 0x7fffffffdcc0:      endbr64
   0x7fffffffdcc4:      movabs $0x555555555169,%r11
   0x7fffffffdcce:      movabs $0x7fffffffdcc0,%r10
   0x7fffffffdcd8:      rex.WB jmpq *%r11
```
Let's delve into how the trampoline is constructed using our buddy GDB. 
We'll break it down into four instructions:
1. The `endbr64` instruction was introduced as part of the 
Intel Control-flow Enforcement Technology (CET) extension. 
Don't confuse it with Cache Allocation Technology (CAT), another CPU 
feature. 
Phew, the acronyms are piling up! 
Anyway, this instruction isn't pertinent to our analysis; 
it's included because the machine executing this code expects it to be 
present. The `endbr64` instruction marks the end of a code sequence and 
helps prevent ROP gadgets from being chained together.
2. `movabs $0x555555555169,%r11`: This instruction loads our target 
function address, `multiply2`, into register `r11`.
3. `movabs $0x7fffffffdcc0,%r10`: Let's recall the x86_64 ABI: 
Parameters to functions are passed in the registers `rdi`, `rsi`, `rdx`,
`rcx`, `r8`, `r9`, and additional values are passed on the stack in 
reverse order. This instruction deviates from the conventional ABI, using a 
register `r10`, to pass the base address for the parent's local variables.
4. `rex.WB jmpq *%r11`: This is a straightforward indirect call that we 
know will lead us to address `0x555555555169`, corresponding to the 
`multiply2` function.


Now that we are aware of at least one other scenario where the compiler may 
necessitate an executable stack, let's explore how this is reflected in 
the executable:

```
$ readelf -l  gcc/nested_local

Elf file type is DYN (Shared object file)
Entry point 0x1080
There are 13 program headers, starting at offset 64

Program Headers:
  Type           Offset             VirtAddr           PhysAddr
                 FileSiz            MemSiz              Flags  Align
  PHDR           0x0000000000000040 0x0000000000000040 0x0000000000000040
                 0x00000000000002d8 0x00000000000002d8  R      0x8
  INTERP         0x0000000000000318 0x0000000000000318 0x0000000000000318
                 0x000000000000001c 0x000000000000001c  R      0x1
      [Requesting program interpreter: /lib64/ld-linux-x86-64.so.2]
  LOAD           0x0000000000000000 0x0000000000000000 0x0000000000000000
                 0x0000000000000658 0x0000000000000658  R      0x1000
  LOAD           0x0000000000001000 0x0000000000001000 0x0000000000001000
                 0x0000000000000315 0x0000000000000315  R E    0x1000
  LOAD           0x0000000000002000 0x0000000000002000 0x0000000000002000
                 0x00000000000001e0 0x00000000000001e0  R      0x1000
  LOAD           0x0000000000002db0 0x0000000000003db0 0x0000000000003db0
                 0x0000000000000260 0x0000000000000268  RW     0x1000
  DYNAMIC        0x0000000000002dc0 0x0000000000003dc0 0x0000000000003dc0
                 0x00000000000001f0 0x00000000000001f0  RW     0x8
  NOTE           0x0000000000000338 0x0000000000000338 0x0000000000000338
                 0x0000000000000020 0x0000000000000020  R      0x8
  NOTE           0x0000000000000358 0x0000000000000358 0x0000000000000358
                 0x0000000000000044 0x0000000000000044  R      0x4
  GNU_PROPERTY   0x0000000000000338 0x0000000000000338 0x0000000000000338
                 0x0000000000000020 0x0000000000000020  R      0x8
  GNU_EH_FRAME   0x000000000000201c 0x000000000000201c 0x000000000000201c
                 0x000000000000005c 0x000000000000005c  R      0x4
  GNU_STACK      0x0000000000000000 0x0000000000000000 0x0000000000000000
                 0x0000000000000000 0x0000000000000000  RWE    0x10
  GNU_RELRO      0x0000000000002db0 0x0000000000003db0 0x0000000000003db0
                 0x0000000000000250 0x0000000000000250  R      0x1

 Section to Segment mapping:
  Segment Sections...
   00     
   01     .interp 
   02     .interp .note.gnu.property .note.gnu.build-id .note.ABI-tag .gnu.hash .dynsym .dynstr .gnu.version .gnu.version_r .rela.dyn .rela.plt 
   03     .init .plt .plt.got .plt.sec .text .fini 
   04     .rodata .eh_frame_hdr .eh_frame 
   05     .init_array .fini_array .dynamic .got .data .bss 
   06     .dynamic 
   07     .note.gnu.property 
   08     .note.gnu.build-id .note.ABI-tag 
   09     .note.gnu.property 
   10     .eh_frame_hdr 
   11     
   12     .init_array .fini_array .dynamic .got 
$ readelf -l  gcc/nested_local.ne

Elf file type is DYN (Shared object file)
Entry point 0x1080
There are 13 program headers, starting at offset 64

Program Headers:
  Type           Offset             VirtAddr           PhysAddr
                 FileSiz            MemSiz              Flags  Align
  PHDR           0x0000000000000040 0x0000000000000040 0x0000000000000040
                 0x00000000000002d8 0x00000000000002d8  R      0x8
  INTERP         0x0000000000000318 0x0000000000000318 0x0000000000000318
                 0x000000000000001c 0x000000000000001c  R      0x1
      [Requesting program interpreter: /lib64/ld-linux-x86-64.so.2]
  LOAD           0x0000000000000000 0x0000000000000000 0x0000000000000000
                 0x0000000000000658 0x0000000000000658  R      0x1000
  LOAD           0x0000000000001000 0x0000000000001000 0x0000000000001000
                 0x0000000000000315 0x0000000000000315  R E    0x1000
  LOAD           0x0000000000002000 0x0000000000002000 0x0000000000002000
                 0x00000000000001e0 0x00000000000001e0  R      0x1000
  LOAD           0x0000000000002db0 0x0000000000003db0 0x0000000000003db0
                 0x0000000000000260 0x0000000000000268  RW     0x1000
  DYNAMIC        0x0000000000002dc0 0x0000000000003dc0 0x0000000000003dc0
                 0x00000000000001f0 0x00000000000001f0  RW     0x8
  NOTE           0x0000000000000338 0x0000000000000338 0x0000000000000338
                 0x0000000000000020 0x0000000000000020  R      0x8
  NOTE           0x0000000000000358 0x0000000000000358 0x0000000000000358
                 0x0000000000000044 0x0000000000000044  R      0x4
  GNU_PROPERTY   0x0000000000000338 0x0000000000000338 0x0000000000000338
                 0x0000000000000020 0x0000000000000020  R      0x8
  GNU_EH_FRAME   0x000000000000201c 0x000000000000201c 0x000000000000201c
                 0x000000000000005c 0x000000000000005c  R      0x4
  GNU_STACK      0x0000000000000000 0x0000000000000000 0x0000000000000000
                 0x0000000000000000 0x0000000000000000  RW     0x10
  GNU_RELRO      0x0000000000002db0 0x0000000000003db0 0x0000000000003db0
                 0x0000000000000250 0x0000000000000250  R      0x1

 Section to Segment mapping:
  Segment Sections...
   00     
   01     .interp 
   02     .interp .note.gnu.property .note.gnu.build-id .note.ABI-tag .gnu.hash .dynsym .dynstr .gnu.version .gnu.version_r .rela.dyn .rela.plt 
   03     .init .plt .plt.got .plt.sec .text .fini 
   04     .rodata .eh_frame_hdr .eh_frame 
   05     .init_array .fini_array .dynamic .got .data .bss 
   06     .dynamic 
   07     .note.gnu.property 
   08     .note.gnu.build-id .note.ABI-tag 
   09     .note.gnu.property 
   10     .eh_frame_hdr 
   11     
   12     .init_array .fini_array .dynamic .got 
```
In the following, you can observe the ELF program header table of two 
executable files, both generated from the same source file, 
`src/nested_local.c`, in the repository. 
They differ because in one instance, I added `-z noexecstack` to enforce
a non-executable stack.
This is what's happen if they get executed:
```
$ ./gcc/nested_local; echo
Fancy calculation (34)
alessandro@r5:~/tmp/stack/nested_prt$ ./gcc/nested_local.ne; echo
Segmentation fault (core dumped)
```
Since the trampoline is in the stack, when the second file is executed it 
crashes since it tries to execute code from the stack.
Here's the proof the crash is caused by it:
```
$ gdb ./gcc/nested_local.ne
GNU gdb (Ubuntu 9.2-0ubuntu1~20.04.1) 9.2
Copyright (C) 2020 Free Software Foundation, Inc.
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.
Type "show copying" and "show warranty" for details.
This GDB was configured as "x86_64-linux-gnu".
Type "show configuration" for configuration details.
For bug reporting instructions, please see:
<http://www.gnu.org/software/gdb/bugs/>.
Find the GDB manual and other documentation resources online at:
    <http://www.gnu.org/software/gdb/documentation/>.

For help, type "help".
Type "apropos word" to search for commands related to "word"...
Reading symbols from ./gcc/nested_local.ne...
(gdb) r
Starting program: /home/alessandro/tmp/stack/nested_prt/gcc/nested_local.ne 

Program received signal SIGSEGV, Segmentation fault.
0x00007fffffffdc34 in ?? ()
(gdb) x/10i $pc
=> 0x7fffffffdc34:	endbr64 
   0x7fffffffdc38:	movabs $0x555555555169,%r11
   0x7fffffffdc42:	movabs $0x7fffffffdc30,%r10
   0x7fffffffdc4c:	rex.WB jmpq *%r11
   0x7fffffffdc4f:	nop
   0x7fffffffdc50:	jo     0x7fffffffdc2e
   0x7fffffffdc52:	(bad)  
   0x7fffffffdc53:	(bad)  
   0x7fffffffdc54:	(bad)  
   0x7fffffffdc55:	jg     0x7fffffffdc57
(gdb) 
```
Finally, let's consider that to further complicate matters, GCC employs 
different conventions across architectures. 
Please do not expect this to be straightforward, as it certainly isn't!

In **x86_64**, executable ELF files always contain an entry in the program
header `GNU_STACK`, which reflects the actual permissions over the stack.
When the loader combines objects to create the executable, it looks at 
`.note.GNU-stack` and its contents to set the stack accordingly. 
If `.note.GNU-stack` is missing, the stack defaults to **executable**.

Similarly, in **aarch64**, executable ELF files always include an entry in 
the program header `GNU_STACK`, with flags reflecting the stack's permissions.
The loader examines `.note.GNU-stack` during the executable creation process 
to determine the stack's permissions. If `.note.GNU-stack` is absent, the
stack defaults to **non-executable**.

On **PPC64**, executable ELF files only include an entry in the program header
`GNU_STACK` if it needs to be executable; 
otherwise, it defaults to **non-executable**.

Conversely, in **MIPS32**, executable ELF files only have an entry in the 
program header `GNU_STACK` if it needs to be non-executable; 
otherwise, it defaults to `executable`.

As a final note for this extensive and perhaps tedious discussion on executable
stacks, allow me to share what I discovered while verifying this information on
a MIPS system.

Look at how some MIPS SoCs do not enforce the stack permissions
https://www.youtube.com/watch?v=RwNUBkpn25o
