MAKEFLAGS += -rR --no-print-directory

PREFIX := x86_64-elf

CC  := $(PREFIX)-gcc
CXX := $(PREFIX)-g++
LD  := $(PREFIX)-ld

COMPILER_FLAGS := -g -c -nostdinc -fno-builtin -Iheaders -mcmodel=kernel -mno-red-zone
COMPILER_WARNS := -Wall -Werror -Wextra -pedantic -pedantic-errors -Wno-long-long

BOOT := head.o kernel/init.o kernel/paging.o
KERNEL := $(BOOT)

all: kernel.elf

kernel.elf: $(KERNEL)
	@$(LD) -T kernel.ld -Map kernel.map -z max-page-size=0x1000 -o $@ $^
	@echo "  LD    $@"

# Build rules for image assembly
################################ 

kernel_installed: kernel.elf
	cp kernel.elf iso-image/

iso: kernel_installed
	grub-mkrescue -o boot.iso iso-image


# Generic build rules for files
################################ 

.c.o:
	@$(CC) $(COMPILER_FLAGS) $(COMPILER_WARNS) $(KERNEL_INCLUDES) $< -o $@
	@echo "  CC    $<"

.s.o:
	@$(CC) $(COMPILER_FLAGS) $(COMPILER_WARNS) $(KERNEL_INCLUDES) $< -o $@
	@echo "  AS    $<"

clean:
	-@for file in $(KERNEL) kernel.elf kernel.map; do if [ -f $$file ]; then rm $$file; fi; done

loc:
	find . -iname '*.c' -or -iname '*.s'  -or -iname '*.h' | xargs wc -l

