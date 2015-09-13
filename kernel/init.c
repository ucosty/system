#include <stdint.h>
#include <multiboot/multiboot.h>
#include <system/paging.h>


void platform_init(uint32_t multiboot __attribute__ ((unused)), uint32_t multiboot_signature) {

	unsigned short *video = (unsigned short *)(0xB8000 + kernel_base);

	if(multiboot_signature != 0x36d76289) {
		// Something odd has happened, the problem must be in head.s
		video[0] = ('M' | 0x2F << 8);
		video[1] = ('B' | 0x2F << 8);
		while(1);
	}

	// Let's begin loading the kernel
	bootstrap_paging();

	video[0] = ('P' | 0x3F << 8);
	video[1] = ('!' | 0x3F << 8);

	// We can't go home
	while(1);
}
