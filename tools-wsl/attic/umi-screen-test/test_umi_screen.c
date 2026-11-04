#!/bin/bash
# Host harness for the umi boot screen painter: compiles the painter exactly as
# it sits at the tail of osfmk/console/video_console.c, against the real
# iso_font, and renders a synthetic 1080x2340x32 framebuffer to a PPM so the
# geometry and legibility can be checked without a phone.

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

typedef unsigned long vm_offset_t;
typedef unsigned long vm_size_t;

#define VM_WIMG_IO 0x10u
#define kernel_map ((void *)1)
#define VM_MAP_NULL ((void *)0)
#define bcopy(src, dst, len) memmove((dst), (src), (len))

struct test_pe_video {
	unsigned long v_baseAddr;
	unsigned long v_rowBytes;
	unsigned long v_width;
	unsigned long v_height;
	unsigned long v_depth;
	unsigned long v_display;
	char v_pixelFormat[64];
	unsigned long v_offset;
	unsigned long v_length;
	unsigned char v_rotate;
	unsigned char v_scale;
};

#define PE_Video struct test_pe_video

static struct test_pe_video umi_test_state;
#define PE_state umi_test_state

static void *umi_test_fb;
static unsigned long umi_test_mapped;

static vm_offset_t
ml_io_map_unmappable(vm_offset_t umi_phys, vm_size_t umi_size, uint32_t umi_flags)
{
	(void) umi_phys;
	(void) umi_flags;
	umi_test_mapped = umi_size;
	return (vm_offset_t)(uintptr_t) umi_test_fb;
}

#include "umi_test_font.h"
#include "umi_test_part.c"

static void
umi_save_ppm(const char *umi_path, unsigned char *umi_fb, unsigned int umi_w,
    unsigned int umi_h, unsigned long umi_stride)
{
	FILE *umi_file = fopen(umi_path, "wb");

	if (umi_file == NULL) {
		fprintf(stderr, "cannot write %s\n", umi_path);
		exit(1);
	}
	fprintf(umi_file, "P6\n%u %u\n255\n", umi_w, umi_h);
	for (unsigned int umi_y = 0; umi_y < umi_h; umi_y++) {
		unsigned char *umi_row = umi_fb + (size_t) umi_y * umi_stride;
		for (unsigned int umi_x = 0; umi_x < umi_w; umi_x++) {
			unsigned int umi_bgra = ((unsigned int *) umi_row)[umi_x];
			unsigned char umi_rgb[3];
			umi_rgb[0] = (umi_bgra >> 16) & 0xff;
			umi_rgb[1] = (umi_bgra >> 8) & 0xff;
			umi_rgb[2] = umi_bgra & 0xff;
			fwrite(umi_rgb, 1, 3, umi_file);
		}
	}
	fclose(umi_file);
}

int
main(int argc, char **argv)
{
	const unsigned int umi_w = 1080, umi_h = 2340;
	const unsigned long umi_stride = 4320;
	unsigned char *umi_fb = calloc((size_t) umi_stride, umi_h);

	umi_test_fb = umi_fb;
	umi_test_state.v_baseAddr = 0x9C000000UL;
	umi_test_state.v_rowBytes = umi_stride;
	umi_test_state.v_width = umi_w;
	umi_test_state.v_height = umi_h;
	umi_test_state.v_depth = 32;
	umi_test_state.v_display = 1;
	umi_test_state.v_length = 0;

	if (argc > 1 && strcmp(argv[1], "panic") == 0) {
		umi_screen_halt("arm_init: Unable to find 'dram-base' entry in the 'chosen' DT node");
	} else {
		for (unsigned long umi_phase = 0x21; umi_phase <= 0x2d; umi_phase++) {
			umi_screen_mark(umi_phase, 0xC00004000UL + umi_phase);
		}
		umi_screen_text("kernel_bootstrap_thread: call_current_thread_start");
		umi_screen_mark(0x50, 0xFFFFFE0001234ABCUL);
		umi_screen_text("bsd_init: setting up root mount");
		for (int umi_loop = 0; umi_loop < 90; umi_loop++) {
			umi_screen_mark(0x51, (unsigned long) umi_loop * 0x1122334455667788UL);
		}
	}
	if (umi_scr_state != 1) {
		fprintf(stderr, "painter unusable, state %d\n", umi_scr_state);
		return 1;
	}
	printf("mapped=%lu cols=%u rows=%u\n", umi_test_mapped, umi_scr_cols, umi_scr_rows);
	umi_save_ppm(argc > 2 ? argv[2] : "out.ppm", umi_fb, umi_w, umi_h, umi_stride);
	free(umi_fb);
	return 0;
}
