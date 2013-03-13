# Makefile for linux 0.00

all: Image

Image: boot head
	dd bs=32 if=boot of=Image.img skip=1
	dd bs=512 if=head of=Image.img skip=8 seek=1

boot: boot.s
	as86 -0 -a -o boot.o boot.s
	ld86 -0 -s -o boot boot.o
head: head.s
	as -o head.o head.s
	ld -m elf_i386 -Ttext 0 -e startup_32 -o head head.o

