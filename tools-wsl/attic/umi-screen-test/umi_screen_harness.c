/*
 * Host harness for the umi boot screen painter: compiles the painter exactly as
 * it sits at the tail of osfmk/console/video_console.c, against the real
 * iso_font, and renders a synthetic 1080x2340x32 framebuffer to a PPM so the
 * geometry and legibility can be checked without a phone.
 */

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

/*
 * The device faults on an unaligned bcopy; glibc silently does not. Emulating the
 * hardware rule here is what keeps a painter change from only being caught on a phone.
 */
static void
umi_test_bcopy(const void *umi_src, void *umi_dst, size_t umi_len)
{
	if ((((uintptr_t) umi_src | (uintptr_t) umi_dst | (uintptr_t) umi_len) & 7UL) != 0) {
		fprintf(stderr, "bcopy 未对齐 src=%p dst=%p len=%zu（真机会对齐异常）\n",
		    umi_src, umi_dst, umi_len);
		exit(2);
	}
	memmove(umi_dst, umi_src, umi_len);
}

#define bcopy(src, dst, len) umi_test_bcopy((src), (dst), (len))

struct umi_test_video {
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

struct umi_test_pe_state {
	struct umi_test_video video;
};

#define PE_Video struct umi_test_video

static struct umi_test_pe_state umi_test_pe;
#define PE_state umi_test_pe

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
			umi_rgb[0] = (unsigned char) ((umi_bgra >> 16) & 0xff);
			umi_rgb[1] = (unsigned char) ((umi_bgra >> 8) & 0xff);
			umi_rgb[2] = (unsigned char) (umi_bgra & 0xff);
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
	char umi_dump[1300];

	umi_test_fb = umi_fb;
	umi_test_pe.video.v_baseAddr = 0x9C000000UL;
	umi_test_pe.video.v_rowBytes = umi_stride;
	umi_test_pe.video.v_width = umi_w;
	umi_test_pe.video.v_height = umi_h;
	umi_test_pe.video.v_depth = 32;
	umi_test_pe.video.v_display = 1;
	umi_test_pe.video.v_length = 0;

	if (argc > 1 && strcmp(argv[1], "panic") == 0) {
		for (unsigned long umi_phase = 0x21; umi_phase <= 0x2d; umi_phase++) {
			umi_screen_mark(umi_phase, 0xC00004000UL + umi_phase);
		}
		/*
		 * Same shape as osfmk/arm64/sleh.c panic_with_thread_kernel_state(),
		 * which is what the red page has to hold.
		 */
		snprintf(umi_dump, sizeof(umi_dump),
		    "Kernel data abort. at pc 0x%016llx, lr 0x%016llx (saved state: %p)\n"
		    "\t  x0:  0x%016llx x1:  0x%016llx  x2:  0x%016llx  x3:  0x%016llx\n"
		    "\t  x4:  0x%016llx x5:  0x%016llx  x6:  0x%016llx  x7:  0x%016llx\n"
		    "\t  x8:  0x%016llx x9:  0x%016llx  x10: 0x%016llx  x11: 0x%016llx\n"
		    "\t  x12: 0x%016llx x13: 0x%016llx  x14: 0x%016llx  x15: 0x%016llx\n"
		    "\t  x16: 0x%016llx x17: 0x%016llx  x18: 0x%016llx  x19: 0x%016llx\n"
		    "\t  x20: 0x%016llx x21: 0x%016llx  x22: 0x%016llx  x23: 0x%016llx\n"
		    "\t  x24: 0x%016llx x25: 0x%016llx  x26: 0x%016llx  x27: 0x%016llx\n"
		    "\t  x28: 0x%016llx fp:  0x%016llx  lr:  0x%016llx  sp:  0x%016llx\n"
		    "\t  pc:  0x%016llx cpsr: 0x%08x         esr: 0x%08x          far: 0x%016llx\n",
		    0xfffffff0078dbb3cULL, 0xfffffff00794601cULL, (void *)0xfffffffbebdcb9f0UL,
		    0xfffffffbebdcbd80ULL, 0xfffffff007afc060ULL, 0ULL, 1ULL,
		    2ULL, 3ULL, 4ULL, 5ULL,
		    6ULL, 7ULL, 8ULL, 9ULL,
		    10ULL, 11ULL, 12ULL, 13ULL,
		    14ULL, 15ULL, 16ULL, 17ULL,
		    18ULL, 19ULL, 20ULL, 21ULL,
		    22ULL, 23ULL, 24ULL, 25ULL,
		    26ULL, 27ULL, 28ULL, 29ULL,
		    0xfffffff0078dbb3cULL, 0x804003c4U, 0x96000004U, 0x28ULL);
		umi_screen_halt(umi_dump);
		printf("panic text length=%zu\n", strlen(umi_dump));
	} else {
		for (unsigned long umi_phase = 0x21; umi_phase <= 0x2d; umi_phase++) {
			umi_screen_mark(umi_phase, 0xC00004000UL + umi_phase);
		}
		umi_screen_text("kernel_bootstrap_thread: call_current_thread_start");
		umi_screen_mark(0x50, 0xFFFFFE0001234ABCUL);
		umi_screen_text("bsd_init: setting up root mount");
		int umi_lines = (argc > 1 && strcmp(argv[1], "openloop") == 0) ? 12 : 60;
		for (int umi_loop = 0; umi_loop < umi_lines; umi_loop++) {
			umi_screen_mark(0x51, (unsigned long) umi_loop * 0x1122334455667788UL);
		}
		for (int umi_loop = 0; umi_loop < 4000; umi_loop++) {
			umi_screen_mark(0x50, 0xfffffff007a15f94UL);
		}
		if (argc > 1 && strcmp(argv[1], "openloop") == 0) {
			printf("bookkeeping open loop: prev_row=%u prev_col=%u prev_scroll=%u scrolls=%u reps=%lu\n",
			    umi_scr_prev_row, umi_scr_prev_col, umi_scr_prev_scroll,
			    umi_scr_scrolls, umi_scr_reps);
			printf("expect x%lu from the periodic restamp only\n",
			    umi_scr_reps & ~0x3fUL);
		} else {
			umi_screen_text("sysctl");
			umi_screen_mark(0x50, 0xfffffff007a16018UL);
			printf("bookkeeping prev_row=%u prev_col=%u prev_scroll=%u scrolls=%u reps=%lu\n",
			    umi_scr_prev_row, umi_scr_prev_col, umi_scr_prev_scroll,
			    umi_scr_scrolls, umi_scr_reps);
		}
	}
	if (umi_scr_state != 1) {
		fprintf(stderr, "painter unusable, state %d\n", umi_scr_state);
		return 1;
	}
	printf("mapped=%lu cols=%u rows=%u scale=%u x0=%u y0=%u marks=%lu\n",
	    umi_test_mapped, umi_scr_cols, umi_scr_rows, umi_scr_scale,
	    umi_scr_x0, umi_scr_y0, umi_scr_total);
	umi_save_ppm(argc > 2 ? argv[2] : "out.ppm", umi_fb, umi_w, umi_h, umi_stride);
	free(umi_fb);
	return 0;
}
