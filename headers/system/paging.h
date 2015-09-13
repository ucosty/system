#ifndef _SYSTEM_PAGING_H
#define _SYSTEM_PAGING_H

static const uint64_t kernel_base = 0xFFFFFFFF80000000;

void bootstrap_paging();

#endif
