OUTPUT_FORMAT(elf32-i386)
OUTPUT_ARCH(i386:x86-64)
ENTRY(loader)

PHYSICAL_BASE = 0x00100000;
VIRTUAL_BASE = 0xFFFFFFFF80000000;

SECTIONS
{
	. = PHYSICAL_BASE;
	__kernel_start = .;
	
	.init :
	{
		*(.multiboot);
        *(.setup);
		. = ALIGN(0x1000);
		*(.paging);
    }

	. += VIRTUAL_BASE;
	
	.text : AT(ADDR(.text))
    {
		__text_start = .;
        *(.text)
    }


	.data : AT(ADDR(.data))
	{
		__data_start = .;		
		*(.data)
		*(.rodata)
	}

    .bss : AT(ADDR(.bss))
    {
        __bss_start = .;
		
        *(COMMON)
        *(.bss)

        __bss_end = .;
    }

	__kernel_end = .;
}

