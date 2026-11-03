#define UMI_SCR_SCALE_MAX 3U

extern vm_offset_t ml_io_map_unmappable(vm_offset_t phys_addr, vm_size_t size, uint32_t flags);

static uintptr_t umi_scr_fb;
static unsigned long umi_scr_row_bytes;
static unsigned int umi_scr_width, umi_scr_height;
static unsigned int umi_scr_scale = UMI_SCR_SCALE_MAX;
static unsigned int umi_scr_x0, umi_scr_y0;
static unsigned int umi_scr_cols, umi_scr_rows;
static unsigned int umi_scr_cx, umi_scr_cy;
static unsigned int umi_scr_scrolls;
static unsigned int umi_scr_prev_row, umi_scr_prev_col, umi_scr_prev_scroll;
static unsigned long umi_scr_sig_kind, umi_scr_sig_a, umi_scr_sig_b;
static unsigned long umi_scr_reps, umi_scr_total;
static int umi_scr_state;                   /* 0 untried, 1 ready, -1 unusable */
static bool umi_scr_halted;
static uint32_t umi_scr_fg = 0xFF40E040;    /* BGRA green on black */
static uint32_t umi_scr_bg = 0xFF000000;

static const char umi_scr_hex[] = "0123456789abcdef";

static void umi_scr_put_hex(unsigned long umi_value, unsigned int umi_digits);
static void umi_scr_puts(const char *umi_text);
static void umi_scr_row_bg_tail(void);

static void
umi_scr_cell(unsigned int umi_col, unsigned int umi_row, unsigned char umi_glyph, uint32_t umi_fore, uint32_t umi_back)
{
	const unsigned char *umi_bitmap = &iso_font[(size_t) umi_glyph * ISO_CHAR_HEIGHT];
	unsigned int umi_top = umi_scr_y0 + umi_row * ISO_CHAR_HEIGHT * umi_scr_scale;
	unsigned int umi_left = umi_scr_x0 + umi_col * ISO_CHAR_WIDTH * umi_scr_scale;

	for (unsigned int umi_scan = 0; umi_scan < ISO_CHAR_HEIGHT; umi_scan++) {
		unsigned char umi_bits = umi_bitmap[umi_scan];

		for (unsigned int umi_dy = 0; umi_dy < umi_scr_scale; umi_dy++) {
			uint32_t *umi_pixel = (uint32_t *)(umi_scr_fb +
			    (uintptr_t)(umi_top + umi_scan * umi_scr_scale + umi_dy) * umi_scr_row_bytes +
			    (uintptr_t) umi_left * sizeof(uint32_t));

			for (unsigned int umi_dx = 0; umi_dx < ISO_CHAR_WIDTH * umi_scr_scale; umi_dx++) {
				*umi_pixel++ = (umi_bits & (1U << (umi_dx / umi_scr_scale))) ? umi_fore : umi_back;
			}
		}
	}
}

static void
umi_scr_row_bg(unsigned int umi_row)
{
	for (unsigned int umi_col = 0; umi_col < umi_scr_cols; umi_col++) {
		umi_scr_cell(umi_col, umi_row, ' ', umi_scr_fg, umi_scr_bg);
	}
}

static void
umi_scr_row_bg_tail(void)
{
	for (unsigned int umi_col = umi_scr_cx; umi_col < umi_scr_cols; umi_col++) {
		umi_scr_cell(umi_col, umi_scr_cy, ' ', umi_scr_fg, umi_scr_bg);
	}
}

/*
 * Scrolls the text band up by one line. Deliberately a 32-bit word loop rather
 * than bcopy: the frame is only 4-byte aligned, and libc memmove's ldp fast path
 * takes an alignment fault on real silicon (TCG does not check, so QEMU misses it).
 */
static void
umi_scr_scroll(void)
{
	uint32_t *umi_dst = (uint32_t *)(umi_scr_fb +
	    (uintptr_t) umi_scr_y0 * umi_scr_row_bytes);
	unsigned long umi_line_words = (unsigned long) ISO_CHAR_HEIGHT * umi_scr_scale *
	    (umi_scr_row_bytes / sizeof(uint32_t));
	uint32_t *umi_src = umi_dst + umi_line_words;
	unsigned long umi_words = umi_line_words * (umi_scr_rows - 1);

	for (unsigned long umi_index = 0; umi_index < umi_words; umi_index++) {
		umi_dst[umi_index] = umi_src[umi_index];
	}

	umi_scr_cy = umi_scr_rows - 1;
	umi_scr_scrolls++;
	umi_scr_row_bg(umi_scr_cy);
}

static void
umi_scr_fill(unsigned long umi_color)
{
	uint32_t *umi_pixel = (uint32_t *)umi_scr_fb;
	unsigned long umi_words = (umi_scr_row_bytes / sizeof(uint32_t)) * umi_scr_height;

	for (unsigned long umi_index = 0; umi_index < umi_words; umi_index++) {
		umi_pixel[umi_index] = (uint32_t) umi_color;
	}
}

static void
umi_scr_putc(unsigned char umi_char)
{
	if (umi_char == 10 || umi_char == 13) {
		if (umi_char == 10) {
			umi_scr_row_bg_tail();
			umi_scr_cy++;
		}
		umi_scr_cx = 0;
	} else if (umi_char >= ' ') {
		umi_scr_cell(umi_scr_cx, umi_scr_cy, umi_char, umi_scr_fg, umi_scr_bg);
		if (++umi_scr_cx >= umi_scr_cols) {
			umi_scr_cx = 0;
			umi_scr_cy++;
		}
	}

	if (umi_scr_cy >= umi_scr_rows) {
		umi_scr_scroll();
	}
}

/*
 * Word-wraps so a hex value never splits across two panel rows, which would
 * make a photograph of a panic page unreadable.
 */
static void
umi_scr_puts(const char *umi_text)
{
	if (umi_text == NULL) {
		umi_text = "(null)";
	}

	while (*umi_text != '\0') {
		unsigned int umi_len = 0;

		if (*umi_text == 10 || *umi_text == 13 || *umi_text == ' ') {
			umi_scr_putc((unsigned char) *umi_text);
			umi_text++;
			continue;
		}
		while (umi_text[umi_len] != '\0' && umi_text[umi_len] != ' ' &&
		    umi_text[umi_len] != 10 && umi_text[umi_len] != 13) {
			umi_len++;
		}
		if (umi_scr_cx != 0 && umi_scr_cx + umi_len > umi_scr_cols) {
			umi_scr_putc(10);
		}
		for (unsigned int umi_index = 0; umi_index < umi_len; umi_index++) {
			umi_scr_putc((unsigned char) umi_text[umi_index]);
		}
		umi_text += umi_len;
	}
}

static void
umi_scr_put_hex(unsigned long umi_value, unsigned int umi_digits)
{
	for (unsigned int umi_index = umi_digits; umi_index > 0; umi_index--) {
		umi_scr_putc((unsigned char) umi_scr_hex[(umi_value >> ((umi_index - 1) * 4)) & 0xfUL]);
	}
}

static void
umi_scr_puts_dec(unsigned long umi_value)
{
	unsigned char umi_digits[12];
	unsigned int umi_n = 0;

	do {
		umi_digits[umi_n++] = (unsigned char)('0' + (umi_value % 10UL));
		umi_value /= 10UL;
	} while (umi_value != 0);

	while (umi_n > 0) {
		umi_n--;
		umi_scr_putc(umi_digits[umi_n]);
	}
}

/*
 * Marks the repeat count of the line that is already on the panel, without
 * disturbing the print cursor: the sysctl stage table runs to thousands of
 * entries that all share one function address.
 */
static void
umi_scr_put_dec_at(unsigned int umi_row, unsigned int umi_col, unsigned long umi_value)
{
	unsigned char umi_digits[12];
	unsigned int umi_n = 0;

	do {
		umi_digits[umi_n++] = (unsigned char)('0' + (umi_value % 10UL));
		umi_value /= 10UL;
	} while (umi_value != 0);

	if (umi_col + umi_n + 2U >= umi_scr_cols) {
		return;
	}
	umi_scr_cell(umi_col, umi_row, 'x', umi_scr_fg, umi_scr_bg);
	umi_col++;
	while (umi_n > 0) {
		umi_n--;
		umi_scr_cell(umi_col++, umi_row, umi_digits[umi_n], umi_scr_fg, umi_scr_bg);
	}
}

static void
umi_scr_stamp(void)
{
	unsigned int umi_row;

	if (umi_scr_reps < 2 || umi_scr_prev_row >= umi_scr_rows) {
		return;
	}
	umi_row = umi_scr_prev_row - ((umi_scr_scrolls - umi_scr_prev_scroll) & 0xffffU);
	if (umi_row >= umi_scr_rows) {
		return;
	}
	umi_scr_put_dec_at(umi_row, umi_scr_prev_col + 1U, umi_scr_reps);
}

/*
 * Picks the largest glyph scale that still leaves a useful page, and keeps the
 * text away from the punch-hole camera, the rounded corners and the gesture bar.
 */
static unsigned long
umi_scr_grid(unsigned int umi_scale, unsigned int *umi_out_cols, unsigned int *umi_out_rows,
    unsigned int *umi_out_x0, unsigned int *umi_out_y0)
{
	unsigned int umi_x0 = umi_scr_width / 16U;
	unsigned int umi_y0 = umi_scr_height / 12U;
	unsigned int umi_cols = (umi_scr_width - umi_x0 - umi_scr_width / 40U) / (ISO_CHAR_WIDTH * umi_scale);
	unsigned int umi_rows = (umi_scr_height - umi_y0 - umi_scr_height / 24U) / (ISO_CHAR_HEIGHT * umi_scale);

	*umi_out_cols = umi_cols;
	*umi_out_rows = umi_rows;
	*umi_out_x0 = umi_x0;
	*umi_out_y0 = umi_y0;

	return (unsigned long) umi_cols * umi_rows;
}

/*
 * Maps the framebuffer the firmware handed over. Returns 0 while the kernel VM
 * is not up yet, so the next milestone retries instead of giving up.
 */
static int
umi_scr_setup(void)
{
	const PE_Video *umi_video = &PE_state.video;
	unsigned long umi_length = umi_video->v_rowBytes * umi_video->v_height;
	unsigned int umi_try_cols, umi_try_rows, umi_try_x0, umi_try_y0;
	unsigned int umi_scale = 1U;
	vm_offset_t umi_va;

	if (kernel_map == VM_MAP_NULL) {
		return 0;
	}
	if (umi_video->v_display == 0 || umi_video->v_baseAddr == 0 ||
	    umi_video->v_rowBytes < 4 || umi_video->v_width < 64 ||
	    umi_video->v_height < 64 || umi_video->v_depth != 32 ||
	    (umi_video->v_length != 0 && umi_video->v_length < umi_length)) {
		umi_scr_state = -1;
		return 0;
	}
	if (umi_video->v_length != 0) {
		umi_length = umi_video->v_length;
	}
	umi_va = ml_io_map_unmappable((vm_offset_t) umi_video->v_baseAddr,
	    (vm_size_t) umi_length, VM_WIMG_IO);
	if (umi_va == 0) {
		umi_scr_state = -1;
		return 0;
	}

	umi_scr_fb = (uintptr_t) umi_va;
	umi_scr_row_bytes = umi_video->v_rowBytes;
	umi_scr_width = (unsigned int) umi_video->v_width;
	umi_scr_height = (unsigned int) umi_video->v_height;

	for (unsigned int umi_candidate = UMI_SCR_SCALE_MAX; umi_candidate > 0U; umi_candidate--) {
		if (umi_scr_grid(umi_candidate, &umi_try_cols, &umi_try_rows, &umi_try_x0, &umi_try_y0) >= 900UL &&
		    umi_try_cols >= 30U && umi_try_rows >= 12U) {
			umi_scale = umi_candidate;
			break;
		}
	}
	umi_scr_scale = umi_scale;
	umi_scr_grid(umi_scr_scale, &umi_scr_cols, &umi_scr_rows, &umi_scr_x0, &umi_scr_y0);
	if (umi_scr_cols < 2U || umi_scr_rows < 2U) {
		umi_scr_state = -1;
		return 0;
	}
	umi_scr_state = 1;

	umi_scr_puts("UMI SCREEN fb=");
	umi_scr_put_hex(umi_video->v_baseAddr, 16);
	umi_scr_puts(" row=");
	umi_scr_put_hex(umi_video->v_rowBytes, 6);
	umi_scr_puts(" geom=");
	umi_scr_put_hex(umi_video->v_width, 4);
	umi_scr_puts("x");
	umi_scr_put_hex(umi_video->v_height, 4);
	umi_scr_puts(" map=");
	umi_scr_put_hex(umi_va, 16);
	umi_scr_puts(" sc=");
	umi_scr_puts_dec(umi_scr_scale);
	umi_scr_puts(" grid=");
	umi_scr_puts_dec(umi_scr_cols);
	umi_scr_puts("x");
	umi_scr_puts_dec(umi_scr_rows);
	umi_scr_putc(10);
	return 1;
}

static int
umi_scr_live(void)
{
	if (umi_scr_state == 0) {
		return umi_scr_setup() == 1;
	}
	return umi_scr_state == 1;
}

void
umi_screen_mark(unsigned long umi_phase, unsigned long umi_value)
{
	if (umi_scr_halted || umi_scr_live() == 0) {
		return;
	}

	umi_scr_total++;
	if (umi_scr_sig_kind == 1 && umi_scr_sig_a == umi_phase && umi_scr_sig_b == umi_value) {
		umi_scr_reps++;
		if ((umi_scr_reps & 0x3fUL) == 0) {
			umi_scr_stamp();
		}
		return;
	}
	umi_scr_stamp();
	umi_scr_sig_kind = 1;
	umi_scr_sig_a = umi_phase;
	umi_scr_sig_b = umi_value;
	umi_scr_reps = 1;
	umi_scr_prev_row = umi_scr_cy;
	umi_scr_prev_scroll = umi_scr_scrolls;

	umi_scr_puts("UMI ");
	umi_scr_put_hex(umi_phase, 2);
	umi_scr_puts(" ");
	umi_scr_put_hex(umi_value, 16);
	umi_scr_prev_col = umi_scr_cx;
	umi_scr_putc(10);
}

void
umi_screen_text(const char *umi_message)
{
	if (umi_scr_halted || umi_scr_live() == 0) {
		return;
	}

	umi_scr_total++;
	if (umi_scr_sig_kind == 2 && umi_scr_sig_a == (unsigned long) umi_message) {
		umi_scr_reps++;
		if ((umi_scr_reps & 0x3fUL) == 0) {
			umi_scr_stamp();
		}
		return;
	}
	umi_scr_stamp();
	umi_scr_sig_kind = 2;
	umi_scr_sig_a = (unsigned long) umi_message;
	umi_scr_sig_b = 0;
	umi_scr_reps = 1;
	umi_scr_prev_row = umi_scr_cy;
	umi_scr_prev_scroll = umi_scr_scrolls;

	umi_scr_puts("UMI .. ");
	umi_scr_puts(umi_message);
	umi_scr_prev_col = umi_scr_cx;
	umi_scr_putc(10);
}

/*
 * Last thing the panel ever shows: the reason on a red page, left standing
 * until the display loses power.
 */
void
umi_screen_halt(const char *umi_message)
{
	umi_scr_halted = true;

	if (umi_scr_live() == 0) {
		return;
	}

	umi_scr_fg = 0xFFFFFFFF;
	umi_scr_bg = 0xFFFF0000;
	umi_scr_fill(umi_scr_bg);
	umi_scr_cx = 0;
	umi_scr_cy = 0;
	umi_scr_puts("UMI PANIC ");
	umi_scr_puts(umi_message);
	umi_scr_puts("UMI marks=");
	umi_scr_puts_dec(umi_scr_total);
	umi_scr_puts(" tail=");
	umi_scr_puts_dec(umi_scr_reps);
	umi_scr_puts(" grid=");
	umi_scr_puts_dec(umi_scr_cols);
	umi_scr_puts("x");
	umi_scr_puts_dec(umi_scr_rows);
	umi_scr_putc(10);
}
