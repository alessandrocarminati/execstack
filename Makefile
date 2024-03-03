
all: gcc/nested_no_local gcc/nested_local gcc/test_asm clang/test_asm clang/hello gcc/hello gcc/asm_hello_as gcc/asm_hello_gcc gcc/test_asm.aarch64 gcc/nested_local.aarch64 gcc/nested_local.ne gcc/nested_local.ppc64 gcc/test_asm.ppc64 gcc/nested_local.mipsel gcc/test_asm.mipsel gcc/nested_local.mipsel.s gcc/nested_local.mipsel.sn

clean:
	rm -rf clang/* gcc/*

gcc/nested_no_local: gcc/nested_no_local.o
	gcc gcc/nested_no_local.o -o gcc/nested_no_local

gcc/nested_no_local.o: src/nested_no_local.c
	gcc -g -c src/nested_no_local.c -o gcc/nested_no_local.o

gcc/nested_local: gcc/nested_local.o
	gcc gcc/nested_local.o -o gcc/nested_local

gcc/nested_local.ne: gcc/nested_local.o
	gcc gcc/nested_local.o -z noexecstack -o gcc/nested_local.ne

gcc/nested_local.o: src/nested_local.c
	gcc -g -c src/nested_local.c -o gcc/nested_local.o

#gcc -g -o test asm_function.S asm.c

gcc/asm_function.o: src/asm_function.S
	gcc -g -c -o gcc/asm_function.o src/asm_function.S

gcc/test_asm.o: src/test_asm.c
	gcc -g -c -o gcc/test_asm.o src/test_asm.c

gcc/test_asm: gcc/test_asm.o gcc/asm_function.o
	gcc -g gcc/test_asm.o gcc/asm_function.o -o gcc/asm_function

clang/asm_function.o: src/asm_function.S
	clang -g -c -o clang/asm_function.o src/asm_function.S

clang/test_asm.o: src/test_asm.c
	clang -g -c -o clang/test_asm.o src/test_asm.c

clang/test_asm: clang/test_asm.o clang/asm_function.o
	clang -g clang/test_asm.o clang/asm_function.o -o clang/asm_function

gcc/hello: src/hello.c
	gcc -o gcc/hello src/hello.c

clang/hello: src/hello.c
	clang -o clang/hello src/hello.c

# src/asm_hello.s

gcc/asm_hello_as.o: src/asm_hello.s
	as -o gcc/asm_hello_as.o  src/asm_hello.s

gcc/asm_hello_as: gcc/asm_hello_as.o
	ld gcc/asm_hello_as.o -o gcc/asm_hello_as

gcc/asm_hello_gcc.o: src/asm_hello.s
	gcc -c -o gcc/asm_hello_gcc.o src/asm_hello.s

gcc/asm_hello_gcc: gcc/asm_hello_gcc.o
	ld gcc/asm_hello_gcc.o -o gcc/asm_hello_gcc



gcc/test_asm.aarch64: gcc/test_asm.aarch64.o gcc/asm_function.aarch64.o
	aarch64-linux-gnu-gcc -g gcc/test_asm.aarch64.o gcc/asm_function.aarch64.o -o gcc/asm_function.aarch64

gcc/test_asm.aarch64.o: src/test_asm.c
	aarch64-linux-gnu-gcc -g -c -o gcc/test_asm.aarch64.o src/test_asm.c

gcc/asm_function.aarch64.o: src/asm_function.aarch64.S
	aarch64-linux-gnu-gcc -g -c -o gcc/asm_function.aarch64.o src/asm_function.aarch64.S


gcc/nested_local.aarch64: gcc/nested_local.aarch64.o
	aarch64-linux-gnu-gcc gcc/nested_local.aarch64.o -o gcc/nested_local.aarch64

gcc/nested_local.aarch64.o: src/nested_local.c
	aarch64-linux-gnu-gcc -g -c src/nested_local.c -o gcc/nested_local.aarch64.o




gcc/test_asm.ppc64: gcc/test_asm.ppc64.o gcc/asm_function.ppc64.o
	powerpc64-linux-gnu-gcc -g gcc/test_asm.ppc64.o gcc/asm_function.ppc64.o -o gcc/asm_function.ppc64

gcc/test_asm.ppc64.o: src/test_asm.c
	powerpc64-linux-gnu-gcc -g -c -o gcc/test_asm.ppc64.o src/test_asm.c

gcc/asm_function.ppc64.o: src/asm_function.ppc64.S
	powerpc64-linux-gnu-gcc -g -c -o gcc/asm_function.ppc64.o src/asm_function.ppc64.S


gcc/nested_local.ppc64: gcc/nested_local.ppc64.o
	powerpc64-linux-gnu-gcc gcc/nested_local.ppc64.o -o gcc/nested_local.ppc64

gcc/nested_local.ppc64.o: src/nested_local.c
	powerpc64-linux-gnu-gcc -g -c src/nested_local.c -o gcc/nested_local.ppc64.o




gcc/test_asm.mipsel: gcc/test_asm.mipsel.o gcc/asm_function.mipsel.o
	mipsel-linux-gnu-gcc -g gcc/test_asm.mipsel.o gcc/asm_function.mipsel.o -o gcc/asm_function.mipsel

gcc/test_asm.mipsel.o: src/test_asm.c
	mipsel-linux-gnu-gcc -g -c -o gcc/test_asm.mipsel.o src/test_asm.c

gcc/asm_function.mipsel.o: src/asm_function.mipsel.S
	mipsel-linux-gnu-gcc -g -c -o gcc/asm_function.mipsel.o src/asm_function.mipsel.S


gcc/nested_local.mipsel: gcc/nested_local.mipsel.o
	mipsel-linux-gnu-gcc gcc/nested_local.mipsel.o -o gcc/nested_local.mipsel

gcc/nested_local.mipsel.s: gcc/nested_local.mipsel.o
	mipsel-linux-gnu-gcc gcc/nested_local.mipsel.o -static -o gcc/nested_local.mipsel.s

gcc/nested_local.mipsel.sn: gcc/nested_local.mipsel.o
	mipsel-linux-gnu-gcc gcc/nested_local.mipsel.o -z noexecstack -static -o gcc/nested_local.mipsel.sn

gcc/nested_local.mipsel.o: src/nested_local.c
	mipsel-linux-gnu-gcc -g -c src/nested_local.c -o gcc/nested_local.mipsel.o



