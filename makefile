
all: free.bin

lbr: free.lbr

clean:
	rm -f free.lst
	rm -f free.bin
	rm -f free.lbr

free.bin: free.asm include/bios.inc include/kernel.inc
	asm02 -L -b free.asm
	rm -f free.build

free.lbr: free.bin
	rm -f free.lbr
	lbradd free.lbr free.bin

