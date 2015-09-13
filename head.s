.code32

.section .multiboot

.balign 8
multiboot_header:
    .long 0xe85250d6 # magic
    .long 0 # architecture (i386, 32-bit)
    .long .multiboot_header_end-multiboot_header # header length
    .long -(.multiboot_header_end-multiboot_header+0xe85250d6) # checksum
    # tags
    # module align
    .word 6 # type
    .word 0 # flags
    .long 8 # size in bytes (spec says 12?)
    .balign 8
    # loader entry
    .word 3
    .word 0
    .long 12
    .long loader
    .balign 8
    # console flags
    .word 4
    .word 0
    .long 12
    .long 0x03 # EGA text support, require console
    .balign 8
    # info request 
    .word 1
    .word 0
    .long 4*6+8
    .long 5 # BIOS boot device
    .long 1 # command line
    .long 3 # modules
    .long 9 # ELF symbols
    .long 6 # memory map
    .long 10 # APM table
    .balign 8
    # address info
    .word 2 # type
    .word 0 # flags
    .long 24 # size
    .long multiboot_header # header load addr
    .long 0x100000 # load addr
    .long 0 # load end addr (entire file)
    .long 0 # BSS end addr (no BSS)
    .balign 8
    # terminating tag
    .word 0
    .word 0
    .long 8
.multiboot_header_end:

.section .setup

# reserve initial kernel stack space
.set STACKSIZE, 0x1000
stack:
    .rept   1024
    .long   0
    .endr

.global loader
.extern platform_init
.extern VIRTUAL_BASE

loader:
	cli
	mov  $(stack + STACKSIZE), %esp
	push %eax
	push %ebx

hide_cursor:
	// Hide the text cursor
	push %eax
	mov $0x0A, %al
	mov $0x3D4, %dx
	outb %al,%dx
	mov $0x20, %al
	mov $0x3D5, %dx
	outb %al,%dx
	pop %eax
	
check_multiboot:
    cmp $0x36d76289, %eax
    jne multiboot_fail

PSE_Test:
	// Check for PSE support
	// Use CPUID function 1 to get the feature flags stored in %edx.
	mov $0x01, %eax
	cpuid
	and $0x20000, %edx
	cmp $0x20000, %edx
    jne no_support_pse

    // First we need to configure an operational long mode page table.
    // This page table needs both identity mapped memory as well as
    // virtual mapped memory so that this initialisation code can
    // enable paging and then jump into the higher half.
    //
    // The identity mapped part is easy.
    // Set the PML4 entry [0] to the First PDPT (Page Directory Pointer Table)

    // ------------------------------
    // Configure the Page Map Level 4
    // ------------------------------
    lea InitialPML4, %eax
    lea InitialPDPT, %ebx
    xor %ecx, %ecx
    
    // Set the flags for the entry
    or $0x03, %ebx
    
    // Load the PDPT address to PML4 Entry 0
    mov %ebx, (%eax, %ecx, 8)

    // Load the PDPT address to PML4 Entry 511
    mov $0x1FF, %ecx
    mov %ebx, (%eax, %ecx, 8)

    // ------------------------------------------
    // Configure the Page Directory Pointer Table
    // ------------------------------------------
    lea InitialPDPT, %eax
    xor %ebx, %ebx
    xor %ecx, %ecx
    
    // Load the Page Directory address to PDPT Entry 0
    or $0x83, %ebx
    mov %ebx, (%eax, %ecx, 8)

    // Load the fist gigabyte of memory to PDPT Entry 510 (-2GB position)
    mov $0x1FE, %ecx
    mov %ebx, (%eax, %ecx, 8)

    // Load the second gigabye of memory to PDPT Entry 511 (-1GB position) 
    inc %ecx
    add $0x40000000, %ebx
    mov %ebx, (%eax, %ecx, 8)

    // We have now determined that the Multiboot magic number is valid,
    // we should attempt to bounce into long mode to continue loading
    // the kernel.
    //
    // To get in to long mode, the following procedure must be followed
    // 
    // - Set the PAE enable bit in CR4
    // - Load CR3 with the physical address of the PML4
    // - Enable long mode by setting the EFER.LME flag in MSR 0xC0000080
    // - Enable paging
    // 
    // At this stage the processor is in compatibility mode, the 32-bit stepping
    // stone into 64-bit long mode.
    //
    // To enter long mode proper, the following steps must be followed
    // 
    // - Load a GDT containing a long mode code and data segment
    // - Jump into the long mode code segment
    
    //
    // Set the PAE Enable bit in CR4
    mov %cr4, %eax
    or $0x20, %eax
    mov %eax, %cr4
    
    //
    // Load CR3 with the physical address of the PML4
    mov $InitialPML4, %eax
    mov %eax, %cr3
    
    //
    // Enable long mode by setting the EFER.LME flag in MSR 0xC0000080
    mov $0xC0000080, %ecx
    rdmsr
    or $0x100, %eax
    wrmsr
    
	//
	// Enabling paging now will also enable IA32_EFER.LMA
	mov %cr0, %ecx
	or $0x80000000, %ecx
	mov %ecx, %cr0

	//
	// Load the 64-bit GDT and jump to 64-bit code
	lgdt (GDTPointer)
	
	// Recover the multiboot magic and information block pointer address
	// and pass them to the setup function using x86-64 register parameter
	// passing.
	pop %edi
	pop %esi
	
	// The CPU is ready to enter long mode, long jump into the new long mode segment
	// and start running 64-bit code.
	ljmp $0x08, $longmode

1:  hlt
    jb 1

.code64

longmode:
    // We are now in long mode proper, we can now directly jump into the higher half code
    // without the address being truncated.
    movw $0x1F4C, 0xB8000
    movw $0x1F4D, 0xB8002

    // Update the stack pointer registers
    add $0xffffffff80000000, %rsp

    // Perform an absolute jump to platform_init
    jmp platform_init

    // This point should never be reached, here be dragons
1:  hlt
    jb 1
        
        
no_support_pse:
    # Print the red PSE of death
    movw $0x4F50, 0xB8000
    movw $0x4F53, 0xB8002
    movw $0x4F45, 0xB8004
    jmp forever

multiboot_fail:
    # Print the red Multiboot of death
    movw $0x4F4d, 0xB8000
    movw $0x4F75, 0xB8002
    movw $0x4F6c, 0xB8004
    movw $0x4F74, 0xB8006
    movw $0x4F69, 0xB8008
    movw $0x4F62, 0xB800A
    movw $0x4F6f, 0xB800C
    movw $0x4F6f, 0xB800E
    movw $0x4F74, 0xB8010
    jmp forever

forever:
    # It's a tarp
	hlt
	jmp forever

.align 8
GDT:
    .quad 0x0000000000000000 // Null Descriptor
    .quad 0x0020980000000000 // Code Descriptor
    .quad 0x0000900000000000 // Data Descriptor
    
GDTPointer:
    .word (GDTPointer - GDT - 1)
    .quad GDT

# Paging data
.section .paging
.global InitialPML4
InitialPML4:
	# Ensure the PML4 (Page Map Level 4) is empty 
	.rept   512
	.long   0
	.long   0
	.endr
	
.global InitialPDPT
InitialPDPT:
	# Ensure the PDPT (Page Directory Pointer Table) is empty 
	.rept   512
	.long   0
	.long   0
	.endr

