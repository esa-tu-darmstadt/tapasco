/**
 *  @file	test.c
 *  @brief
 *  @author	J. Korinth, TU Darmstadt (jk@esa.cs.tu-darmstadt.de)
 **/
#include "gen_mem.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <time.h>

#define MAX_ALLOCS 100000
#define MAX_SIZE (1024 * 1024)

void print_block(block_t *b) {
  if (b) {
    printf("block @ 0x%x - 0x%x\n", (b->base), (addr_t)(b->base + b->range));
    print_block(b->next);
  } else
    printf("\n");
}

inline static size_t allocate(block_t **mem, block_t allocs[MAX_ALLOCS]) {
  size_t idx = rand() % MAX_ALLOCS;
  while (allocs[idx].range != 0)
    idx = (idx + 1) % MAX_ALLOCS;
  allocs[idx].range = rand() % MAX_SIZE;
  allocs[idx].base = gen_mem_malloc(mem, allocs[idx].range);
  return idx;
}

inline static size_t deallocate(block_t **mem, block_t allocs[MAX_ALLOCS]) {
  size_t idx = rand() % MAX_ALLOCS;
  while (allocs[idx].range == 0)
    idx = (idx + 1) % MAX_ALLOCS;
  gen_mem_free(mem, allocs[idx].base, allocs[idx].range);
  allocs[idx].range = 0;
  allocs[idx].base = 0;
  return idx;
}

inline static void clean(block_t **mem, block_t allocs[MAX_ALLOCS]) {
  for (size_t idx = 0; idx < MAX_ALLOCS; ++idx) {
    if (allocs[idx].range != 0) {
      gen_mem_free(mem, allocs[idx].base, allocs[idx].range);
    }
  }
}

void merge_nxt() {
  srand(time(NULL));
  printf("merge_nxt:\n");
  block_t *mem = gen_mem_create(0, 0x1000);
  addr_t a = gen_mem_malloc(&mem, 16);
  addr_t b = gen_mem_malloc(&mem, 16);
  addr_t c = gen_mem_malloc(&mem, 16);
  addr_t d = gen_mem_malloc(&mem, 16);

  printf("freeing b\n");
  gen_mem_free(&mem, b, 16);
  print_block(mem);

  printf("freeing d\n");
  gen_mem_free(&mem, d, 16);
  print_block(mem);

  printf("freeing a\n");
  gen_mem_free(&mem, a, 16);
  print_block(mem);

  printf("freeing c\n");
  gen_mem_free(&mem, c, 16);
  print_block(mem);

  assert(mem->next == NULL || "expected single block after all frees");
  free(mem);
}

void merge_prv() {
  srand(time(NULL));
  printf("merge_prv:\n");
  block_t *mem = gen_mem_create(0, 0x1000);
  addr_t a = gen_mem_malloc(&mem, 16);
  addr_t b = gen_mem_malloc(&mem, 16);
  addr_t c = gen_mem_malloc(&mem, 16);
  addr_t d = gen_mem_malloc(&mem, 16);
  print_block(mem);

  printf("freeing c\n");
  gen_mem_free(&mem, c, 16);
  print_block(mem);

  printf("freeing a\n");
  gen_mem_free(&mem, a, 16);
  print_block(mem);

  printf("freeing d\n");
  gen_mem_free(&mem, d, 16);
  print_block(mem);

  printf("freeing b\n");
  gen_mem_free(&mem, b, 16);
  print_block(mem);

  assert(mem->next == NULL || "expected single block after all frees");
  free(mem);
}

void malloc_corners() {
  srand(time(NULL));
  printf("malloc_corners:\n");
  block_t *mem = gen_mem_create(0, 32);
  addr_t a = gen_mem_malloc(&mem, 16);
  addr_t b = gen_mem_malloc(&mem, 16);
  assert(a != INVALID_ADDRESS || "a must not be invalid");
  assert(b != INVALID_ADDRESS || "b must not be invalid");
  print_block(mem);

  printf("freeing b\n");
  gen_mem_free(&mem, b, 16);
  print_block(mem);

  b = gen_mem_malloc(&mem, 16);
  printf("freeing b, a\n");
  gen_mem_free(&mem, b, 16);
  gen_mem_free(&mem, a, 16);
  print_block(mem);

  assert(mem->next == NULL || "expected single block after all frees");
  free(mem);
}

void check_blocks(block_t *mem) {
  assert(mem || "check_blocks argument must not be NULL");
  block_t *prv = mem, *nxt = mem->next;
  while (nxt && prv->base + prv->range < nxt->base) {
    prv = nxt;
    nxt = nxt->next;
  }
  if (nxt) {
    fprintf(stderr, "ERROR: block list is invalid!\n");
    print_block(mem);
    exit(1);
  }
}

void stress_test() {
  srand(time(NULL));
  block_t *mem = gen_mem_create(0, 1 << 31);
  struct timeval tv_start, tv_now;
  gettimeofday(&tv_start, NULL);

  block_t allocs[MAX_ALLOCS];
  memset(allocs, 0, sizeof(allocs));
  size_t total_alloc = 0;
  size_t curr_alloc = 0;
  size_t curr_sz = 0;

  do {
    if (!curr_alloc || (curr_alloc < MAX_ALLOCS && rand() % 2)) {
      // printf("allocating (%zd / %zd)\n", curr_alloc, total_alloc);
      curr_sz += allocs[allocate(&mem, allocs)].range;
      ++curr_alloc;
      ++total_alloc;
    } else {
      // printf("deallocating (%zd / %zd)\n", curr_alloc, total_alloc);
      curr_sz -= allocs[deallocate(&mem, allocs)].range;
      --curr_alloc;
    }
    check_blocks(mem);
    gettimeofday(&tv_now, NULL);
  } while (tv_now.tv_sec - tv_start.tv_sec < 30);
  clean(&mem, allocs);
  printf("finished after %zd allocations.\n", total_alloc);
  print_block(mem);
  free(mem);
}

int main() {
  malloc_corners();
  merge_prv();
  merge_nxt();

  printf("now performing stress test for 30secs ... ");
  fflush(stdout);
  stress_test();
  printf(" done.\n");
}
/* vim: set foldmarker=@{,@} foldlevel=0 foldmethod=marker : */
