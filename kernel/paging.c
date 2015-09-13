#include <stdint.h>
#include <system/paging.h>

extern uint64_t InitialPML4;
extern uint64_t InitialPDPT;
extern uint64_t InitialPD;

static inline void flush_tlb() {
	uint64_t cr3;
	asm volatile ("mov %%cr3, %0" : "=r"(cr3));
	asm volatile ("mov %0, %%cr3" : : "r"(cr3));
}

static inline void flush_tlb_single(uint64_t address) {
	asm volatile("invlpg (%0)" : :  "r"(address));
}

void bootstrap_paging() {
	// Let's map the first nGB of memory using oversized pages	
	uint64_t *pml4 = (uint64_t *) ((kernel_base + InitialPML4) & 0xFFFFFFFFFFFFFF00);
	pml4[0] = 0;
	flush_tlb();
}

