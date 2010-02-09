/*
 Frodo, Commodore 64 emulator for the iPhone
 Copyright (C) 1994-1997,2002 Christian Bauer
 See gpl.txt for license information.
 
 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.
 
 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.
 
 You should have received a copy of the GNU General Public License
 along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/*
 *  VIC.cpp - 6569R5 emulation (line based)
 *
 *  Frodo (C) 1994-1997,2002 Christian Bauer
 *
 
 *
 * Notes:
 * ------
 *
 *  - The EmulateLine() function is called for every emulated
 *    raster line. It computes one pixel row of the graphics
 *    according to the current VIC register settings and returns
 *    the number of cycles available for the CPU in that line.
 *  - The graphics are output into an 8 bit chunky bitmap
 *  - The sprite-graphics priority handling and collision
 *    detection is done in a bit-oriented way with masks.
 *    The foreground/background pixel mask for the graphics
 *    is stored in the fore_mask_buf[] array. Multicolor
 *    sprites are converted from their original chunky format
 *    to a bitplane representation (two bit masks) for easier
 *    handling of priorities and collisions.
 *  - The sprite-sprite priority handling and collision
 *    detection is done in with the byte array spr_coll_buf[],
 *    that is used to keep track of which sprites are already
 *    visible at certain X positions.
 *
 * Incompatibilities:
 * ------------------
 *
 *  - Raster effects that are achieved by modifying VIC registers
 *    in the middle of a raster line cannot be emulated
 *  - Sprite collisions are only detected within the visible
 *    screen area (excluding borders)
 *  - Sprites are only drawn if they completely fit within the
 *    left/right limits of the chunky bitmap
 *  - The Char ROM is not visible in the bitmap displays at
 *    addresses $0000 and $8000
 *  - The IRQ is cleared on every write access to the flag
 *    register. This is a hack for the RMW instructions of the
 *    6510 that first write back the original value.
 */

#include "sysdeps.h"

#include "VIC.h"
#include "C64.h"
#include "CPUC64.h"
#include "Display.h"
#include "Prefs.h"
#include "SID.h"
#include "CIA.h"
#include "CPU1541.h"


// First and last displayed line
const unsigned int FIRST_DISP_LINE = 0x10;
const unsigned int LAST_DISP_LINE = 0x11f;

// First and last possible line for Bad Lines
const unsigned int FIRST_DMA_LINE = 0x30;
const unsigned int LAST_DMA_LINE = 0xf7;

// Display window coordinates
const unsigned int ROW25_YSTART = 0x33;
const unsigned int ROW25_YSTOP = 0xfb;
const unsigned int ROW24_YSTART = 0x37;
const unsigned int ROW24_YSTOP = 0xf7;

#if defined(SMALL_DISPLAY)
/* This does not work yet, the sprite code doesn't know about it. */
const int COL40_XSTART = 0x0;
const int COL40_XSTOP = 0x140;
const int COL38_XSTART = 0x7;
const int COL38_XSTOP = 0x137;
#else
const int COL40_XSTART = 0x20;
const int COL40_XSTOP = 0x160;
const int COL38_XSTART = 0x27;
const int COL38_XSTOP = 0x157;
#endif


// Tables for sprite X expansion
uint16 ExpTable[256] = {
0x0000, 0x0003, 0x000C, 0x000F, 0x0030, 0x0033, 0x003C, 0x003F,
0x00C0, 0x00C3, 0x00CC, 0x00CF, 0x00F0, 0x00F3, 0x00FC, 0x00FF,
0x0300, 0x0303, 0x030C, 0x030F, 0x0330, 0x0333, 0x033C, 0x033F,
0x03C0, 0x03C3, 0x03CC, 0x03CF, 0x03F0, 0x03F3, 0x03FC, 0x03FF,
0x0C00, 0x0C03, 0x0C0C, 0x0C0F, 0x0C30, 0x0C33, 0x0C3C, 0x0C3F,
0x0CC0, 0x0CC3, 0x0CCC, 0x0CCF, 0x0CF0, 0x0CF3, 0x0CFC, 0x0CFF,
0x0F00, 0x0F03, 0x0F0C, 0x0F0F, 0x0F30, 0x0F33, 0x0F3C, 0x0F3F,
0x0FC0, 0x0FC3, 0x0FCC, 0x0FCF, 0x0FF0, 0x0FF3, 0x0FFC, 0x0FFF,
0x3000, 0x3003, 0x300C, 0x300F, 0x3030, 0x3033, 0x303C, 0x303F,
0x30C0, 0x30C3, 0x30CC, 0x30CF, 0x30F0, 0x30F3, 0x30FC, 0x30FF,
0x3300, 0x3303, 0x330C, 0x330F, 0x3330, 0x3333, 0x333C, 0x333F,
0x33C0, 0x33C3, 0x33CC, 0x33CF, 0x33F0, 0x33F3, 0x33FC, 0x33FF,
0x3C00, 0x3C03, 0x3C0C, 0x3C0F, 0x3C30, 0x3C33, 0x3C3C, 0x3C3F,
0x3CC0, 0x3CC3, 0x3CCC, 0x3CCF, 0x3CF0, 0x3CF3, 0x3CFC, 0x3CFF,
0x3F00, 0x3F03, 0x3F0C, 0x3F0F, 0x3F30, 0x3F33, 0x3F3C, 0x3F3F,
0x3FC0, 0x3FC3, 0x3FCC, 0x3FCF, 0x3FF0, 0x3FF3, 0x3FFC, 0x3FFF,
0xC000, 0xC003, 0xC00C, 0xC00F, 0xC030, 0xC033, 0xC03C, 0xC03F,
0xC0C0, 0xC0C3, 0xC0CC, 0xC0CF, 0xC0F0, 0xC0F3, 0xC0FC, 0xC0FF,
0xC300, 0xC303, 0xC30C, 0xC30F, 0xC330, 0xC333, 0xC33C, 0xC33F,
0xC3C0, 0xC3C3, 0xC3CC, 0xC3CF, 0xC3F0, 0xC3F3, 0xC3FC, 0xC3FF,
0xCC00, 0xCC03, 0xCC0C, 0xCC0F, 0xCC30, 0xCC33, 0xCC3C, 0xCC3F,
0xCCC0, 0xCCC3, 0xCCCC, 0xCCCF, 0xCCF0, 0xCCF3, 0xCCFC, 0xCCFF,
0xCF00, 0xCF03, 0xCF0C, 0xCF0F, 0xCF30, 0xCF33, 0xCF3C, 0xCF3F,
0xCFC0, 0xCFC3, 0xCFCC, 0xCFCF, 0xCFF0, 0xCFF3, 0xCFFC, 0xCFFF,
0xF000, 0xF003, 0xF00C, 0xF00F, 0xF030, 0xF033, 0xF03C, 0xF03F,
0xF0C0, 0xF0C3, 0xF0CC, 0xF0CF, 0xF0F0, 0xF0F3, 0xF0FC, 0xF0FF,
0xF300, 0xF303, 0xF30C, 0xF30F, 0xF330, 0xF333, 0xF33C, 0xF33F,
0xF3C0, 0xF3C3, 0xF3CC, 0xF3CF, 0xF3F0, 0xF3F3, 0xF3FC, 0xF3FF,
0xFC00, 0xFC03, 0xFC0C, 0xFC0F, 0xFC30, 0xFC33, 0xFC3C, 0xFC3F,
0xFCC0, 0xFCC3, 0xFCCC, 0xFCCF, 0xFCF0, 0xFCF3, 0xFCFC, 0xFCFF,
0xFF00, 0xFF03, 0xFF0C, 0xFF0F, 0xFF30, 0xFF33, 0xFF3C, 0xFF3F,
0xFFC0, 0xFFC3, 0xFFCC, 0xFFCF, 0xFFF0, 0xFFF3, 0xFFFC, 0xFFFF
};

uint16 MultiExpTable[256] = {
0x0000, 0x0005, 0x000A, 0x000F, 0x0050, 0x0055, 0x005A, 0x005F,
0x00A0, 0x00A5, 0x00AA, 0x00AF, 0x00F0, 0x00F5, 0x00FA, 0x00FF,
0x0500, 0x0505, 0x050A, 0x050F, 0x0550, 0x0555, 0x055A, 0x055F,
0x05A0, 0x05A5, 0x05AA, 0x05AF, 0x05F0, 0x05F5, 0x05FA, 0x05FF,
0x0A00, 0x0A05, 0x0A0A, 0x0A0F, 0x0A50, 0x0A55, 0x0A5A, 0x0A5F,
0x0AA0, 0x0AA5, 0x0AAA, 0x0AAF, 0x0AF0, 0x0AF5, 0x0AFA, 0x0AFF,
0x0F00, 0x0F05, 0x0F0A, 0x0F0F, 0x0F50, 0x0F55, 0x0F5A, 0x0F5F,
0x0FA0, 0x0FA5, 0x0FAA, 0x0FAF, 0x0FF0, 0x0FF5, 0x0FFA, 0x0FFF,
0x5000, 0x5005, 0x500A, 0x500F, 0x5050, 0x5055, 0x505A, 0x505F,
0x50A0, 0x50A5, 0x50AA, 0x50AF, 0x50F0, 0x50F5, 0x50FA, 0x50FF,
0x5500, 0x5505, 0x550A, 0x550F, 0x5550, 0x5555, 0x555A, 0x555F,
0x55A0, 0x55A5, 0x55AA, 0x55AF, 0x55F0, 0x55F5, 0x55FA, 0x55FF,
0x5A00, 0x5A05, 0x5A0A, 0x5A0F, 0x5A50, 0x5A55, 0x5A5A, 0x5A5F,
0x5AA0, 0x5AA5, 0x5AAA, 0x5AAF, 0x5AF0, 0x5AF5, 0x5AFA, 0x5AFF,
0x5F00, 0x5F05, 0x5F0A, 0x5F0F, 0x5F50, 0x5F55, 0x5F5A, 0x5F5F,
0x5FA0, 0x5FA5, 0x5FAA, 0x5FAF, 0x5FF0, 0x5FF5, 0x5FFA, 0x5FFF,
0xA000, 0xA005, 0xA00A, 0xA00F, 0xA050, 0xA055, 0xA05A, 0xA05F,
0xA0A0, 0xA0A5, 0xA0AA, 0xA0AF, 0xA0F0, 0xA0F5, 0xA0FA, 0xA0FF,
0xA500, 0xA505, 0xA50A, 0xA50F, 0xA550, 0xA555, 0xA55A, 0xA55F,
0xA5A0, 0xA5A5, 0xA5AA, 0xA5AF, 0xA5F0, 0xA5F5, 0xA5FA, 0xA5FF,
0xAA00, 0xAA05, 0xAA0A, 0xAA0F, 0xAA50, 0xAA55, 0xAA5A, 0xAA5F,
0xAAA0, 0xAAA5, 0xAAAA, 0xAAAF, 0xAAF0, 0xAAF5, 0xAAFA, 0xAAFF,
0xAF00, 0xAF05, 0xAF0A, 0xAF0F, 0xAF50, 0xAF55, 0xAF5A, 0xAF5F,
0xAFA0, 0xAFA5, 0xAFAA, 0xAFAF, 0xAFF0, 0xAFF5, 0xAFFA, 0xAFFF,
0xF000, 0xF005, 0xF00A, 0xF00F, 0xF050, 0xF055, 0xF05A, 0xF05F,
0xF0A0, 0xF0A5, 0xF0AA, 0xF0AF, 0xF0F0, 0xF0F5, 0xF0FA, 0xF0FF,
0xF500, 0xF505, 0xF50A, 0xF50F, 0xF550, 0xF555, 0xF55A, 0xF55F,
0xF5A0, 0xF5A5, 0xF5AA, 0xF5AF, 0xF5F0, 0xF5F5, 0xF5FA, 0xF5FF,
0xFA00, 0xFA05, 0xFA0A, 0xFA0F, 0xFA50, 0xFA55, 0xFA5A, 0xFA5F,
0xFAA0, 0xFAA5, 0xFAAA, 0xFAAF, 0xFAF0, 0xFAF5, 0xFAFA, 0xFAFF,
0xFF00, 0xFF05, 0xFF0A, 0xFF0F, 0xFF50, 0xFF55, 0xFF5A, 0xFF5F,
0xFFA0, 0xFFA5, 0xFFAA, 0xFFAF, 0xFFF0, 0xFFF5, 0xFFFA, 0xFFFF
};

uint32 TextColorTable[16*16*16];
/*
 *  Constructor: Initialize variables
 */

static void init_text_color_table()
{
	uint8* tct = (uint8*)&TextColorTable;
	
	for (int i=0; i<16; i++) // Backcolor
		for(int j=0; j<16; j++) // Forecolor
			for (int k=0; k<16; k++) { // nibble data, 4 pixels=32 bits
				*tct++ = k & 8 ? j : i;
				*tct++ = k & 4 ? j : i;
				*tct++ = k & 2 ? j : i;
				*tct++ = k & 1 ? j : i;
			}
}

MOS6569::MOS6569(C64 *c64, C64Display *disp, MOS6510 *CPU, uint8 *RAM, uint8 *Char, uint8 *Color)
: ram(RAM), char_rom(Char), color_ram(Color), the_c64(c64), the_display(disp), the_cpu(CPU)
{
	int i;
	
	// Set pointers
	matrix_baseSC = 0;
	char_baseSC = 0;
	bitmap_baseSC = 0;
	
	matrix_base = RAM;
	char_base = RAM;
	bitmap_base = RAM;
	
	// Get bitmap info
	chunky_ptr = chunky_line_start = disp->BitmapBase();
	xmod = disp->BitmapXMod();
	
	// Initialize VIC registers
	mx8 = 0;
	ctrl1 = ctrl2 = 0;
	lpx = lpy = 0;
	me = mxe = mye = mdp = mmc = 0;
	vbase = irq_flag = irq_mask = 0;
	clx_spr = clx_bgr = 0;
	cia_vabase = 0;
	ec = b0c = b1c = b2c = b3c = mm0 = mm1 = 0;
	for (i=0; i<8; i++)
		mx[i] = my[i] = sc[i] = 0;
	init_mem_ptr();
	
	// Initialize other variables
	raster_y = TOTAL_RASTERS - 1;
	rc = 7;
	irq_raster = vc = vc_base = x_scroll = y_scroll = 0;
	dy_start = ROW24_YSTART;
	dy_stop = ROW24_YSTOP;
	
	ml_index = 0;
	cycle = 1;
	BALow = false;
	
	display_idx = 0;
	display_state = false;
	border_on = ud_border_on = vblanking = false;
	lp_triggered = draw_this_line = false;
	spr_dma_on = spr_disp_on = 0;
	sprite_on = 0;
	
	for (i=0; i<8; i++)
	{
		mc[i] = 63;
		spr_ptr[i] = 0;
	}

	frame_skipped = false;
	skip_counter = 1;
	
	// Clear foreground mask
	memset(spr_coll_buf, 0, 0x180);
	memset(fore_mask_buf, 0, sizeof(fore_mask_buf));
	
	// Preset colors to black
	init_text_color_table();
	ec_color = b0c_color = b1c_color = b2c_color = b3c_color = mm0_color = mm1_color = 0;
	ec_color_long = (ec << 24L) | (ec << 16L) | (ec << 8) | ec;
	for (i=0; i<8; i++) 
		spr_color[i] = 0;
	
	// SGC: Optimizations
	prefs_border_on = ThePrefs.BordersOn;
}


#define read_byte(adr) mem_ptr[(adr) >> 12][(adr) & 0xfff]


void MOS6569::make_mc_table(void)
{
	mc_color_lookup[0] = b0c | (b0c << 8);
	mc_color_lookup[1] = b1c | (b1c << 8);
	mc_color_lookup[2] = b2c | (b2c << 8);
}

void MOS6569::NewPrefs(Prefs *newPrefs) {
	prefs_border_on = newPrefs->BordersOn;
}
/*
 *  Switch from standard emulation to single cycle emulation
 */
void MOS6569::SwitchToSC(void)
{
	int i;
	
	ec_color = ec & 0xf;
	b0c_color = b0c & 0xf;
	b1c_color = b1c & 0xf;
	b2c_color = b2c & 0xf;
	b3c_color = b3c & 0xf;
	mm0_color = mm0 & 0xf;
	mm1_color = mm1 & 0xf;
	for (i=0; i<8; i++)
		spr_color[i] = sc[i] & 0xf;
	
	cycle = 0x101;
	matrix_baseSC = (vbase & 0xf0) << 6;
	char_baseSC = (vbase & 0x0e) << 10;
	bitmap_baseSC = (vbase & 0x08) << 10;
	
	is_bad_line = false;
	draw_this_line = false;
	display_state = false;
	vc_base = 0;
	
	ud_border_on = true;
	vblanking = false;
	
	spr_exp_y = ~mye;
	spr_dma_on = sprite_on;			// 8 flags: Sprite DMA active
	spr_disp_on = 0;
	for (i=0; i<8; i++)
		spr_ptr[i] = read_byte(matrix_baseSC | 0x03f8 | i) << 6;
	for (i=0; i<8; i++)
		mc_base[i] = 0;
	
	raster_x = (uint16) (0xfffc + 8 * 52);
	
	ml_index = 0;
	
	BALow = false;
	first_ba_cycle = 0;
	the_c64->CycleCounter = 3;
}


/*
 *  Switch from single cycle emulation to standard emulation
 */
void MOS6569::SwitchToStandard(void)
{
	make_mc_table();
	border_40_col = ctrl2 & 8;
	sprite_on = spr_dma_on;
	
	matrix_base = get_physical((vbase & 0xf0) << 6);
	char_base = get_physical((vbase & 0x0e) << 10);
	bitmap_base = get_physical((vbase & 0x08) << 10);
}


/*
 *  Convert video address to pointer
 */

inline uint8 *MOS6569::get_physical(uint16 adr)
{
	int va = adr | cia_vabase;
	if ((va & 0x7000) == 0x1000)
		return char_rom + (va & 0x0fff);
	else
		return ram + va;
}


/*
 *  Get VIC state
 */
void MOS6569::GetState(MOS6569State *vd)
{
	int i;
	
	vd->m0x = mx[0]; vd->m0y = my[0];
	vd->m1x = mx[1]; vd->m1y = my[1];
	vd->m2x = mx[2]; vd->m2y = my[2];
	vd->m3x = mx[3]; vd->m3y = my[3];
	vd->m4x = mx[4]; vd->m4y = my[4];
	vd->m5x = mx[5]; vd->m5y = my[5];
	vd->m6x = mx[6]; vd->m6y = my[6];
	vd->m7x = mx[7]; vd->m7y = my[7];
	vd->mx8 = mx8;
	
	vd->ctrl1 = ctrl1;
	vd->raster_y = raster_y;
	vd->lpx = lpx; vd->lpy = lpy;
	vd->ctrl2 = ctrl2;
	vd->vbase = vbase;
	vd->irq_flag = irq_flag;
	vd->irq_mask = irq_mask;
	
	vd->me = me; vd->mxe = mxe; vd->mye = mye; vd->mdp = mdp; vd->mmc = mmc;
	vd->clx_spr = clx_spr; vd->clx_bgr = clx_bgr;
	
	vd->ec = ec;
	vd->b0c = b0c; vd->b1c = b1c; vd->b2c = b2c; vd->b3c = b3c;
	vd->mm0 = mm0; vd->mm1 = mm1;
	
	vd->m0c = sc[0];
	vd->m1c = sc[1];
	vd->m2c = sc[2];
	vd->m3c = sc[3];
	vd->m4c = sc[4];
	vd->m5c = sc[5];
	vd->m6c = sc[6];
	vd->m7c = sc[7];
	
	vd->irq_raster = irq_raster;
	vd->vc = vc;
	vd->vc_base = vc_base;
	vd->rc = rc;
	
	if(ThePrefs.SingleCycleEmulation)
	{
		vd->spr_dma = spr_dma_on;
		vd->spr_disp = spr_disp_on;
		for (i=0; i<8; i++) {
			vd->mc[i] = mc[i];
			vd->mc_base[i] = mc_base[i];
		}
	}
	else
	{
		vd->spr_dma = vd->spr_disp = sprite_on;
		for (i=0; i<8; i++)
			vd->mc[i] = vd->mc_base[i] = mc[i];
	}
	
	vd->display_state = display_state;
	vd->bad_line = is_bad_line;
	vd->bad_line_enable = bad_lines_enabled;
	vd->lp_triggered = lp_triggered;
	vd->border_on = border_on;
	vd->frame_skipped = frame_skipped;
	vd->draw_this_line = draw_this_line;
	
	vd->bank_base = cia_vabase;
	vd->matrix_base = matrix_baseSC;
	vd->char_base = char_baseSC;
	vd->bitmap_base = bitmap_baseSC;
	
	vd->spr_exp_y = spr_exp_y;
	for (i=0; i<8; i++)
		vd->sprite_base[i] = spr_ptr[i];
	
	vd->cycle = cycle;
	vd->raster_x = raster_x;
	vd->ml_index = ml_index;
	vd->ud_border_on = ud_border_on;
	vd->first_ba_cycle = first_ba_cycle;
}


/*
 *  Set VIC state (only works if in VBlank)
 */

void MOS6569::SetState(MOS6569State *vd)
{
	int i;
	
	mx[0] = vd->m0x; my[0] = vd->m0y;
	mx[1] = vd->m1x; my[1] = vd->m1y;
	mx[2] = vd->m2x; my[2] = vd->m2y;
	mx[3] = vd->m3x; my[3] = vd->m3y;
	mx[4] = vd->m4x; my[4] = vd->m4y;
	mx[5] = vd->m5x; my[5] = vd->m5y;
	mx[6] = vd->m6x; my[6] = vd->m6y;
	mx[7] = vd->m7x; my[7] = vd->m7y;
	mx8 = vd->mx8;
	
	ctrl1 = vd->ctrl1;
	ctrl2 = vd->ctrl2;
	x_scroll = ctrl2 & 7;
	y_scroll = ctrl1 & 7;
	if (ctrl1 & 8) {
		dy_start = ROW25_YSTART;
		dy_stop = ROW25_YSTOP;
	} else {
		dy_start = ROW24_YSTART;
		dy_stop = ROW24_YSTOP;
	}
	border_40_col = ctrl2 & 8;
	display_idx = ((ctrl1 & 0x60) | (ctrl2 & 0x10)) >> 4;
	
	if(ThePrefs.SingleCycleEmulation)
		raster_y = vd->raster_y;
	else
		raster_y = vd->raster_y | ((vd->ctrl1 & 0x80) << 1);
	
	lpx = vd->lpx; lpy = vd->lpy;
	
	vbase = vd->vbase;
	cia_vabase = vd->bank_base;
	
	matrix_baseSC = vd->matrix_base;
	char_baseSC = vd->char_base;
	bitmap_baseSC = vd->bitmap_base;
	init_mem_ptr();
	
	matrix_base = get_physical((vbase & 0xf0) << 6);
	char_base = get_physical((vbase & 0x0e) << 10);
	bitmap_base = get_physical((vbase & 0x08) << 10);
	
	irq_flag = vd->irq_flag;
	irq_mask = vd->irq_mask;
	
	me = vd->me; mxe = vd->mxe; mye = vd->mye; mdp = vd->mdp; mmc = vd->mmc;
	clx_spr = vd->clx_spr; clx_bgr = vd->clx_bgr;
	
	ec = vd->ec;
	ec_color = ec & 0xf;
	ec_color_long = (ec_color << 24) | (ec_color << 16) | (ec_color << 8) | ec_color;
	
	b0c = vd->b0c; b1c = vd->b1c; b2c = vd->b2c; b3c = vd->b3c;
	b0c_color = b0c & 0xf;
	b1c_color = b1c & 0xf;
	b2c_color = b2c & 0xf;
	b3c_color = b3c & 0xf;
	make_mc_table();
	
	mm0 = vd->mm0; mm1 = vd->mm1;
	mm0_color = mm0 & 0xf;
	mm1_color = mm1 & 0xf;
	
	sc[0] = vd->m0c; sc[1] = vd->m1c;
	sc[2] = vd->m2c; sc[3] = vd->m3c;
	sc[4] = vd->m4c; sc[5] = vd->m5c;
	sc[6] = vd->m6c; sc[7] = vd->m7c;
	for (i=0; i<8; i++)
		spr_color[i] = sc[i] & 0xf;
	
	irq_raster = vd->irq_raster;
	vc = vd->vc;
	vc_base = vd->vc_base;
	rc = vd->rc;
	
	spr_dma_on = vd->spr_dma;
	spr_disp_on = vd->spr_disp;
	spr_exp_y = vd->spr_exp_y;
	for (i=0; i<8; i++) {
		mc[i] = vd->mc[i];
		mc_base[i] = vd->mc_base[i];
		spr_ptr[i] = vd->sprite_base[i];
	}
	sprite_on = vd->spr_dma;
	
	display_state = vd->display_state;
	bad_lines_enabled = vd->bad_line_enable;
	lp_triggered = vd->lp_triggered;
	border_on = vd->border_on;
	frame_skipped = vd->frame_skipped;
	is_bad_line = vd->bad_line;
	draw_this_line = vd->draw_this_line;
	
	BALow = false;
	cycle = vd->cycle;
	raster_x = vd->raster_x;
	ml_index = vd->ml_index;
	ud_border_on = vd->ud_border_on;
	first_ba_cycle = vd->first_ba_cycle;
}


/*
 *  Trigger raster IRQ
 */
inline void MOS6569::raster_irq(void)
{
	irq_flag |= 0x01;
	if (irq_mask & 0x01) {
		irq_flag |= 0x80;
		the_cpu->TriggerVICIRQ();
	}
}


/*
 *  Write to VIC register
 */

void MOS6569::WriteRegister(uint16 adr, uint8 byte)
{
	switch (adr) {
		case 0x00: case 0x02: case 0x04: case 0x06:
		case 0x08: case 0x0a: case 0x0c: case 0x0e:
			mx[adr >> 1] = (mx[adr >> 1] & 0xff00) | byte;
			break;
			
		case 0x10:{
			int i, j;
			mx8 = byte;
			for (i=0, j=1; i<8; i++, j<<=1) {
				if (mx8 & j)
					mx[i] |= 0x100;
				else
					mx[i] &= 0xff;
			}
			break;
		}
			
		case 0x01: case 0x03: case 0x05: case 0x07:
		case 0x09: case 0x0b: case 0x0d: case 0x0f:
			my[adr >> 1] = byte;
			break;
			
		case 0x11:{	// Control register 1
			ctrl1 = byte;
			y_scroll = byte & 7;
			
			uint16 new_irq_raster = (irq_raster & 0xff) | ((byte & 0x80) << 1);
			if (irq_raster != new_irq_raster && raster_y == new_irq_raster)
				raster_irq();
			irq_raster = new_irq_raster;
			
			if (byte & 8) {
				dy_start = ROW25_YSTART;
				dy_stop = ROW25_YSTOP;
			} else {
				dy_start = ROW24_YSTART;
				dy_stop = ROW24_YSTOP;
			}
			
			display_idx = ((ctrl1 & 0x60) | (ctrl2 & 0x10)) >> 4;
			break;
		}
			
		case 0x12:{	// Raster counter
			uint16 new_irq_raster = (irq_raster & 0xff00) | byte;
			if (irq_raster != new_irq_raster && raster_y == new_irq_raster)
				raster_irq();
			irq_raster = new_irq_raster;
			break;
		}
			
		case 0x15:	// Sprite enable
			me = byte;
			break;
			
		case 0x16:	// Control register 2
			ctrl2 = byte;
			x_scroll = byte & 7;
			border_40_col = byte & 8;
			display_idx = ((ctrl1 & 0x60) | (ctrl2 & 0x10)) >> 4;
			break;
			
		case 0x17:	// Sprite Y expansion
			mye = byte;
			break;
			
		case 0x18:	// Memory pointers
			vbase = byte;
			matrix_base = get_physical((byte & 0xf0) << 6);
			char_base = get_physical((byte & 0x0e) << 10);
			bitmap_base = get_physical((byte & 0x08) << 10);
			break;
			
		case 0x19: // IRQ flags
			irq_flag = irq_flag & (~byte & 0x0f);
			the_cpu->ClearVICIRQ();	// Clear interrupt (hack!)
			if (irq_flag & irq_mask) // Set master bit if allowed interrupt still pending
				irq_flag |= 0x80;
			break;
			
		case 0x1a:	// IRQ mask
			irq_mask = byte & 0x0f;
			if (irq_flag & irq_mask) { // Trigger interrupt if pending and now allowed
				the_cpu->TriggerVICIRQ();
			} else {
				irq_flag &= 0x7f;
				the_cpu->ClearVICIRQ();
			}
			break;
			
		case 0x1b:	// Sprite data priority
			mdp = byte;
			break;
			
		case 0x1c:	// Sprite multicolor
			mmc = byte;
			break;
			
		case 0x1d:	// Sprite X expansion
			mxe = byte;
			break;
			
		case 0x20:
			ec = byte & 0xf;
			ec_color_long = (ec << 24) | (ec << 16) | (ec << 8) | ec;
			break;
			
		case 0x21:
			if (b0c != byte) {
				b0c = byte & 0xF;
				mc_color_lookup[0] = b0c | (b0c << 8);
			}
			break;
			
		case 0x22: 
			if (b1c != byte) {
				b1c = byte & 0xF;
				mc_color_lookup[1] = b1c | (b1c << 8);
			}
			break;
			
		case 0x23: 
			if (b2c != byte) {
				b2c = byte & 0xF;
				mc_color_lookup[2] = b2c | (b2c << 8);
			}
			break;
			
		case 0x24: b3c = byte & 0xF; break;
		case 0x25: mm0 = byte & 0xf; break;
		case 0x26: mm1 = byte & 0xf; break;
			
		case 0x27: case 0x28: case 0x29: case 0x2a:
		case 0x2b: case 0x2c: case 0x2d: case 0x2e:
			sc[adr - 0x27] = byte & 0xf;
			break;
	}
}

#if SINGLE_CYCLE

/*
 *  Write to VIC register (single cycle emulation)
 */
void MOS6569::WriteRegisterSC(uint16 adr, uint8 byte)
{
	switch (adr) {
		case 0x00: case 0x02: case 0x04: case 0x06:
		case 0x08: case 0x0a: case 0x0c: case 0x0e:
			mx[adr >> 1] = (mx[adr >> 1] & 0xff00) | byte;
			break;
			
		case 0x10:{
			int i, j;
			mx8 = byte;
			for (i=0, j=1; i<8; i++, j<<=1) {
				if (mx8 & j)
					mx[i] |= 0x100;
				else
					mx[i] &= 0xff;
			}
			break;
		}
			
		case 0x01: case 0x03: case 0x05: case 0x07:
		case 0x09: case 0x0b: case 0x0d: case 0x0f:
			my[adr >> 1] = byte;
			break;
			
		case 0x11:{	// Control register 1
			ctrl1 = byte;
			y_scroll = byte & 7;
			
			uint16 new_irq_raster = (irq_raster & 0xff) | ((byte & 0x80) << 1);
			if (irq_raster != new_irq_raster && raster_y == new_irq_raster)
				raster_irq();
			irq_raster = new_irq_raster;
			
			if (byte & 8) {
				dy_start = ROW25_YSTART;
				dy_stop = ROW25_YSTOP;
			} else {
				dy_start = ROW24_YSTART;
				dy_stop = ROW24_YSTOP;
			}
			
			// In line $30, the DEN bit controls if Bad Lines can occur
			if (raster_y == 0x30 && byte & 0x10)
				bad_lines_enabled = true;
			
			// Bad Line condition?
			is_bad_line = (raster_y >= FIRST_DMA_LINE && raster_y <= LAST_DMA_LINE && ((raster_y & 7) == y_scroll) && bad_lines_enabled);
			if(is_bad_line)
				cycle = cycle | 0x080;
			else
				cycle = cycle & 0xf7f;
			
			display_idx = ((ctrl1 & 0x60) | (ctrl2 & 0x10)) >> 4;
			break;
		}
			
		case 0x12:{	// Raster counter
			uint16 new_irq_raster = (irq_raster & 0xff00) | byte;
			if (irq_raster != new_irq_raster && raster_y == new_irq_raster)
				raster_irq();
			irq_raster = new_irq_raster;
			break;
		}
			
		case 0x15:	// Sprite enable
			me = byte;
			break;
			
		case 0x16:	// Control register 2
			ctrl2 = byte;
			x_scroll = byte & 7;
			display_idx = ((ctrl1 & 0x60) | (ctrl2 & 0x10)) >> 4;
			break;
			
		case 0x17:	// Sprite Y expansion
			mye = byte;
			spr_exp_y |= ~byte;
			break;
			
		case 0x18:	// Memory pointers
			vbase = byte;
			matrix_baseSC = (byte & 0xf0) << 6;
			char_baseSC = (byte & 0x0e) << 10;
			bitmap_baseSC = (byte & 0x08) << 10;
			break;
			
		case 0x19: // IRQ flags
			irq_flag = irq_flag & (~byte & 0x0f);
			if (irq_flag & irq_mask) // Set master bit if allowed interrupt still pending
				irq_flag |= 0x80;
			else
				the_cpu->ClearVICIRQ();	// Else clear interrupt
			break;
			
		case 0x1a:	// IRQ mask
			irq_mask = byte & 0x0f;
			if (irq_flag & irq_mask) { // Trigger interrupt if pending and now allowed
				irq_flag |= 0x80;
				the_cpu->TriggerVICIRQ();
			} else {
				irq_flag &= 0x7f;
				the_cpu->ClearVICIRQ();
			}
			break;
			
		case 0x1b:	// Sprite data priority
			mdp = byte;
			break;
			
		case 0x1c:	// Sprite multicolor
			mmc = byte;
			break;
			
		case 0x1d:	// Sprite X expansion
			mxe = byte;
			break;
			
		case 0x20:
			ec = byte; 
			ec_color = byte & 0xf; 
			ec_color_long = (ec_color << 24) | (ec_color << 16) | (ec_color << 8) | ec_color;
			break;
		case 0x21: b0c = byte; b0c_color = byte & 0xf; break;
		case 0x22: b1c = byte; b1c_color = byte & 0xf; break;
		case 0x23: b2c = byte; b2c_color = byte & 0xf; break;
		case 0x24: b3c = byte; b3c_color = byte & 0xf; break;
		case 0x25: mm0 = byte; mm0_color = byte & 0xf; break;
		case 0x26: mm1 = byte; mm1_color = byte & 0xf; break;
			
		case 0x27: case 0x28: case 0x29: case 0x2a:
		case 0x2b: case 0x2c: case 0x2d: case 0x2e:
			sc[adr - 0x27] = byte;
			spr_color[adr - 0x27] = byte & 0xf;
			break;
	}
}

#endif

/*
 *  CIA VA14/15 has changed
 */

void MOS6569::ChangedVA(uint16 new_va)
{
	cia_vabase = new_va << 14;
#if SINGLE_CYCLE
	if(ThePrefs.SingleCycleEmulation)
		WriteRegisterSC(0x18, vbase); // Force update of memory pointers
	else
#endif
		WriteRegister(0x18, vbase); // Force update of memory pointers
	init_mem_ptr();
}

/*
 *  Trigger lightpen interrupt, latch lightpen coordinates
 */

void MOS6569::TriggerLightpen(void)
{
	if (!lp_triggered) 
	{	// Lightpen triggers only once per frame
		lp_triggered = true;
		
		if(ThePrefs.SingleCycleEmulation)
		{
			if((cycle & 0x3f) > 13)
				raster_x = 0xfffc + 8 * ((cycle & 0x3f) - 13);
			else
				raster_x = 0xfffc + 8 * ((cycle & 0x3f) + 51);
			lpx = raster_x >> 1;	// Latch current coordinates
		}
		else
			lpx = 0;			// Latch current coordinates
		lpy = raster_y;
		
		irq_flag |= 0x08;	// Trigger IRQ
		if (irq_mask & 0x08) {
			irq_flag |= 0x80;
			the_cpu->TriggerVICIRQ();
		}
	}
}


/*
 *  Init pointers for read_byte
 */
void MOS6569::init_mem_ptr(void)
{
	switch(cia_vabase)
	{
		case 0x0000:
			mem_ptr[0] = ram;
			mem_ptr[1] = char_rom;
			mem_ptr[2] = ram + 0x2000;
			mem_ptr[3] = ram + 0x3000;
			break;
		case 0x4000:
			mem_ptr[0] = ram + 0x4000;
			mem_ptr[1] = ram + 0x5000;
			mem_ptr[2] = ram + 0x6000;
			mem_ptr[3] = ram + 0x7000;
			break;
		case 0x8000:
			mem_ptr[0] = ram + 0x8000;
			mem_ptr[1] = char_rom;
			mem_ptr[2] = ram + 0xa000;
			mem_ptr[3] = ram + 0xb000;
			break;
		case 0xc000:
			mem_ptr[0] = ram + 0xc000;
			mem_ptr[1] = ram + 0xd000;
			mem_ptr[2] = ram + 0xe000;
			mem_ptr[3] = ram + 0xf000;
			break;
	}
}

#if SINGLE_CYCLE


/*
 *  Video matrix access
 */

void MOS6569::matrix_access(void)
{
	if (the_c64->CycleCounter-first_ba_cycle < 3)
		matrix_line[ml_index] = color_line[ml_index] = 0xff;
	else 
	{
		matrix_line[ml_index] = read_byte((vc & 0x03ff) | matrix_baseSC);
		color_line[ml_index] = color_ram[vc & 0x03ff];
	}
}


/*
 *  Graphics data access
 */
#define graphics_access(display_state) \
display_state ? graphics_access_ds() : read_byte(ctrl1 & 0x40 ? 0x39ff : 0x3fff);

uint32 MOS6569::graphics_access_ds()
{
	uint32 gcc;
	uint16 adr = 0;
	
	//switch(ctrl1 & 0x60)
	switch((ctrl1 >> 5) & 3)
	{
		case 0: //0x00: // Text
			adr = (matrix_line[ml_index] << 3) | char_baseSC | rc;
			break;
		case 1: //0x20: // Bitmap
			adr = ((vc & 0x03ff) << 3) | bitmap_baseSC | rc;
			break;
		case 2: //0x40: // ECM Text
			adr = ((matrix_line[ml_index] << 3) | char_baseSC | rc) & 0xf9ff;
			break;
		case 3: //0x60: // ECM Bitmap
			adr = (((vc & 0x03ff) << 3) | bitmap_baseSC | rc) & 0xf9ff;
			break;
	}
	vc++;
	gcc = read_byte(adr) | (matrix_line[ml_index] << 8) | (color_line[ml_index] << 16);
	ml_index++;
	
	return gcc;
}


/*
 *  Graphics display (8 pixels)
 */
void MOS6569::draw_graphics(uint32 gfxcharcolor)
{
	uint32 *tct = 0;
	uint8 gfx_data, char_data, color_data;
	uint8 *p;
	uint16 *wp;
	uint32 *lp;
	
	gfx_data = gfxcharcolor;
	char_data = gfxcharcolor >> 8;
	color_data = gfxcharcolor >> 16;
	
	if(x_scroll)
	{
		switch (display_idx) 
		{
			case 0:		// Standard text
				tct = &TextColorTable[(b0c_color << 8) | (color_data << 4)];
				break;
				
			case 1:		// Multicolor text
				if (color_data & 8) 
				{
					uint8 c[4];
					p = chunky_ptr + x_scroll;
					
					c[0] = b0c_color;
					c[1] = b1c_color;
					c[2] = b2c_color;
					c[3] = color_data & 7;
					
					// draw_multi
					fore_mask_ptr[0] |= ((gfx_data & 0xaa) | (gfx_data & 0xaa) >> 1) >> x_scroll;
					fore_mask_ptr[1] |= ((gfx_data & 0xaa) | (gfx_data & 0xaa) >> 1) << (8-x_scroll);
					
					p[7] = p[6] = c[gfx_data & 3];
					p[5] = p[4] = c[(gfx_data >> 2) & 3];
					p[3] = p[2] = c[(gfx_data >> 4) & 3];
					p[1] = p[0] = c[gfx_data >> 6];
					return;
				} 
				
				tct = &TextColorTable[(b0c_color << 8) | (color_data << 4)];
				break;
				
			case 2:		// Standard bitmap
				tct = &TextColorTable[((char_data & 0xf) << 8) | (char_data & 0xf0)];
				break;
				
			case 3:		// Multicolor bitmap
			{
				uint8 c[4];
				p = chunky_ptr + x_scroll;
				
    			c[0]= b0c_color;
    			c[1] = (char_data >> 4) & 0xf;
    			c[2] = char_data & 0xf;
    			c[3] = color_data & 0xf;
    			
				// draw_multi
				fore_mask_ptr[0] |= ((gfx_data & 0xaa) | (gfx_data & 0xaa) >> 1) >> x_scroll;
				fore_mask_ptr[1] |= ((gfx_data & 0xaa) | (gfx_data & 0xaa) >> 1) << (8-x_scroll);
				
				p[7] = p[6] = c[gfx_data & 3];
				p[5] = p[4] = c[(gfx_data >> 2) & 3];
				p[3] = p[2] = c[(gfx_data >> 4) & 3];
				p[1] = p[0] = c[gfx_data >> 6];
				return;
  			} 
				
			case 4:		// ECM text
				if (char_data & 0x80)
					if (char_data & 0x40)
						tct = &TextColorTable[(b3c_color << 8) | (color_data << 4)];
					else
						tct = &TextColorTable[(b2c_color << 8) | (color_data << 4)];
					else
						if (char_data & 0x40)
							tct = &TextColorTable[(b1c_color << 8) | (color_data << 4)];
						else
							tct = &TextColorTable[(b0c_color << 8) | (color_data << 4)];
				break;
				
			case 5:		// Invalid multicolor text
				memset(chunky_ptr + x_scroll, 0, 8);
				if (color_data & 8) {
					fore_mask_ptr[0] |= ((gfx_data & 0xaa) | (gfx_data & 0xaa) >> 1) >> x_scroll;
					fore_mask_ptr[1] |= ((gfx_data & 0xaa) | (gfx_data & 0xaa) >> 1) << (8-x_scroll);
				} else {
					fore_mask_ptr[0] |= gfx_data >> x_scroll;
					fore_mask_ptr[1] |= gfx_data << (7-x_scroll);
				}
				return;
				
			case 6:		// Invalid standard bitmap
				memset(chunky_ptr + x_scroll, 0, 8);
				fore_mask_ptr[0] |= gfx_data >> x_scroll;
				fore_mask_ptr[1] |= gfx_data << (7-x_scroll);
				return;
				
			case 7:		// Invalid multicolor bitmap
				memset(chunky_ptr + x_scroll, 0, 8);
				fore_mask_ptr[0] |= ((gfx_data & 0xaa) | (gfx_data & 0xaa) >> 1) >> x_scroll;
				fore_mask_ptr[1] |= ((gfx_data & 0xaa) | (gfx_data & 0xaa) >> 1) << (8-x_scroll);
				return;
		}
		
		// draw_std
		switch(x_scroll)
		{
			case 1: case 3: case 5: case 7:
			{
				uint32 tct_data = tct[gfx_data >> 4];
				p = chunky_ptr + x_scroll;
				*p++ = tct_data;
				*((uint16 *) p) = tct_data >> 8;
				p += 2;
				*p++ = tct_data >> 24;
				tct_data = tct[gfx_data & 0xf];
				*p++ = tct_data;
				*((uint16 *) p) = tct_data >> 8;
				p += 2;
				*p = tct_data >> 24;
				fore_mask_ptr[0] |= gfx_data >> x_scroll;
				fore_mask_ptr[1] = gfx_data << (7-x_scroll);
			}
				break;
				
			case 2: case 6:
			{
				uint32 tct_data = tct[gfx_data >> 4];
				wp = (uint16 *) (chunky_ptr + x_scroll);
				*wp++ = tct_data;
				*wp++ = tct_data >> 16;
				tct_data = tct[gfx_data & 0xf];
				*wp++ = tct_data;
				*wp = tct_data >> 16;
				fore_mask_ptr[0] |= gfx_data >> x_scroll;
				fore_mask_ptr[1] = gfx_data << (7-x_scroll);
			}
				break;
				
			case 4:
				lp = (uint32 *) (chunky_ptr + x_scroll);
				*lp++ = tct[gfx_data >> 4];
				*lp = tct[gfx_data & 0xf];
				fore_mask_ptr[0] |= gfx_data >> x_scroll;
				fore_mask_ptr[1] = gfx_data << (7-x_scroll);
				break;
		}
	}
	else // No x_scroll
	{
		switch (display_idx) 
		{
			case 0:		// Standard text
				tct = &TextColorTable[(b0c_color << 8) | (color_data << 4)];
				break;
				
			case 1:		// Multicolor text
				if (color_data & 8) 
				{
					uint8 c[4];
					p = chunky_ptr;
					
					c[0] = b0c_color;
					c[1] = b1c_color;
					c[2] = b2c_color;
					c[3] = color_data & 7;
					
					// draw_multi
					fore_mask_ptr[0] = ((gfx_data & 0xaa) | (gfx_data & 0xaa) >> 1);
					
					p[7] = p[6] = c[gfx_data & 3];
					p[5] = p[4] = c[(gfx_data >> 2) & 3];
					p[3] = p[2] = c[(gfx_data >> 4) & 3];
					p[1] = p[0] = c[gfx_data >> 6];
					return;
				} 
				
				tct = &TextColorTable[(b0c_color << 8) | (color_data << 4)];
				break;
				
			case 2:		// Standard bitmap
				tct = &TextColorTable[((char_data & 0xf) << 8) | (char_data & 0xf0)];
				break;
				
			case 3:		// Multicolor bitmap
			{
				uint8 c[4];
				p = chunky_ptr;
				
    			c[0]= b0c_color;
    			c[1] = (char_data >> 4) & 0xf;
    			c[2] = char_data & 0xf;
    			c[3] = color_data & 0xf;
    			
				// draw_multi
				fore_mask_ptr[0] = ((gfx_data & 0xaa) | (gfx_data & 0xaa) >> 1);
				
				p[7] = p[6] = c[gfx_data & 3];
				p[5] = p[4] = c[(gfx_data >> 2) & 3];
				p[3] = p[2] = c[(gfx_data >> 4) & 3];
				p[1] = p[0] = c[gfx_data >> 6];
				return;
  			} 
				
			case 4:		// ECM text
				if (char_data & 0x80)
					if (char_data & 0x40)
						tct = &TextColorTable[(b3c_color << 8) | (color_data << 4)];
					else
						tct = &TextColorTable[(b2c_color << 8) | (color_data << 4)];
					else
						if (char_data & 0x40)
							tct = &TextColorTable[(b1c_color << 8) | (color_data << 4)];
						else
							tct = &TextColorTable[(b0c_color << 8) | (color_data << 4)];
				break;
				
			case 5:		// Invalid multicolor text
				//memset8(chunky_ptr, 0);
				memset(chunky_ptr, 0, 8);
				if (color_data & 8) {
					fore_mask_ptr[0] = ((gfx_data & 0xaa) | (gfx_data & 0xaa) >> 1);
				} else {
					fore_mask_ptr[0] = gfx_data;
				}
				return;
				
			case 6:		// Invalid standard bitmap
				//memset8(chunky_ptr, 0);
				memset(chunky_ptr, 0, 8);
				fore_mask_ptr[0] = gfx_data;
				return;
				
			case 7:		// Invalid multicolor bitmap
				//memset8(chunky_ptr, 0);
				memset(chunky_ptr, 0, 8);
				fore_mask_ptr[0] = ((gfx_data & 0xaa) | (gfx_data & 0xaa) >> 1);
				return;
		}
		
		// draw_std
		lp = (uint32 *) chunky_ptr;
		*lp++ = tct[gfx_data >> 4];
		*lp = tct[gfx_data & 0xf];
		fore_mask_ptr[0] = gfx_data;
	}
}


/*
 *  Sprite display
 */

void MOS6569::draw_sprites(void)
{
	int i;
	int snum, sbit;		// Sprite number/bit mask
	int spr_coll=0, gfx_coll=0;
	int xoffs = (C64DISPLAY_X-DISPLAY_X)/2; // 32 if the screen is 320 wide
	
	// Clear sprite collision buffer
	//memset16(spr_coll_buf, 0x0, sizeof(spr_coll_buf));
	memset(spr_coll_buf, 0x00, sizeof(spr_coll_buf));
	
	// Loop for all sprites
	for (snum=0, sbit=1; snum<8; snum++, sbit<<=1) {
		
		// Is sprite visible?
		if ((spr_disp_on & sbit) && mx[snum] < C64DISPLAY_X-32) {
			uint8 *p = chunky_line_start + (mx[snum]-xoffs) + 8;
			uint8 *q = spr_coll_buf + mx[snum] + 8;
			uint8 color = spr_color[snum];
			
			// Fetch sprite data and mask
			uint32 sdata = (spr_data[snum][0] << 24) | (spr_data[snum][1] << 16) | (spr_data[snum][2] << 8);
			
			int spr_mask_pos = mx[snum] + 8;	// Sprite bit position in fore_mask_buf
			
			uint8 *fmbp = fore_mask_buf + (spr_mask_pos >> 3);
			int sshift = spr_mask_pos & 7;
			uint32 fore_mask = (((*(fmbp+0) << 24) | (*(fmbp+1) << 16) | (*(fmbp+2) << 8)
								 | (*(fmbp+3))) << sshift) | (*(fmbp+4) >> (8-sshift));
			
			// Don't draw outside the screen buffer!
			uint8 xstart=0, xstop=24, xstop1 = 24;
			if (mxe & sbit) {
				xstop=48;
				xstop1=32;
			}
			// DEBUG
			
			if (mx[snum]+8 < xoffs) xstart=xoffs-mx[snum]-8;
			if (mx[snum]+8-xoffs+xstop > DISPLAY_X) {
				xstop = DISPLAY_X-mx[snum]-8+xoffs;
				if (xstop<xstop1) xstop1=xstop;
			}
			
			if (mxe & sbit) {		// X-expanded
				if (mx[snum] >= C64DISPLAY_X-56)
					continue;
				
				uint32 sdata_l = 0, sdata_r = 0, fore_mask_r;
				fore_mask_r = (((*(fmbp+4) << 24) | (*(fmbp+5) << 16) | (*(fmbp+6) << 8)
								| (*(fmbp+7))) << sshift) | (*(fmbp+8) >> (8-sshift));
				
				if (mmc & sbit) {	// Multicolor mode
					uint32 plane0_l, plane0_r, plane1_l, plane1_r;
					
					// Expand sprite data
					sdata_l = MultiExpTable[sdata >> 24 & 0xff] << 16 | MultiExpTable[sdata >> 16 & 0xff];
					sdata_r = MultiExpTable[sdata >> 8 & 0xff] << 16;
					
					// Convert sprite chunky pixels to bitplanes
					plane0_l = (sdata_l & 0x55555555) | (sdata_l & 0x55555555) << 1;
					plane1_l = (sdata_l & 0xaaaaaaaa) | (sdata_l & 0xaaaaaaaa) >> 1;
					plane0_r = (sdata_r & 0x55555555) | (sdata_r & 0x55555555) << 1;
					plane1_r = (sdata_r & 0xaaaaaaaa) | (sdata_r & 0xaaaaaaaa) >> 1;
					
					// Collision with graphics?
					if ((fore_mask & (plane0_l | plane1_l)) || (fore_mask_r & (plane0_r | plane1_r))) {
						gfx_coll |= sbit;
						if (mdp & sbit)	{
							plane0_l &= ~fore_mask;	// Mask sprite if in background
							plane1_l &= ~fore_mask;
							plane0_r &= ~fore_mask_r;
							plane1_r &= ~fore_mask_r;
						}
					}
					
					// Paint sprite
					plane0_l<<=xstart; plane1_l<<=xstart;
					for (i=xstart; i<xstop1; i++, plane0_l<<=1, plane1_l<<=1) {
						uint8 col;
						if (plane1_l & 0x80000000) {
							if (plane0_l & 0x80000000)
								col = mm1_color;
							else
								col = color;
						} else {
							if (plane0_l & 0x80000000)
								col = mm0_color;
							else
								continue;
						}
						if (q[i])
							spr_coll |= q[i] | sbit;
						else {
							p[i] = col;
							q[i] = sbit;
						}
					}
					if (xstart>32) {
						plane0_r<<=xstart-32;
						plane1_r<<=xstart-32;
					}
					for (; i<xstop; i++, plane0_r<<=1, plane1_r<<=1) {
						uint8 col;
						if (plane1_r & 0x80000000) {
							if (plane0_r & 0x80000000)
								col = mm1_color;
							else
								col = color;
						} else {
							if (plane0_r & 0x80000000)
								col = mm0_color;
							else
								continue;
						}
						if (q[i])
							spr_coll |= q[i] | sbit;
						else {
							p[i] = col;
							q[i] = sbit;
						}
					}
					
				} else {			// Standard mode
					
					// Expand sprite data
					sdata_l = ExpTable[sdata >> 24 & 0xff] << 16 | ExpTable[sdata >> 16 & 0xff];
					sdata_r = ExpTable[sdata >> 8 & 0xff] << 16;
					
					// Collision with graphics?
					if ((fore_mask & sdata_l) || (fore_mask_r & sdata_r)) {
						gfx_coll |= sbit;
						if (mdp & sbit)	{
							sdata_l &= ~fore_mask;	// Mask sprite if in background
							sdata_r &= ~fore_mask_r;
						}
					}
					
					// Paint sprite
					sdata_l<<=xstart;
					for (i=xstart; i<xstop1; i++, sdata_l<<=1)
						if (sdata_l & 0x80000000) {
							if (q[i])	// Collision with sprite?
								spr_coll |= q[i] | sbit;
							else {		// Draw pixel if no collision
								p[i] = color;
								q[i] = sbit;
							}
						}
					if (xstart>32)
						sdata_r<<=xstart-32;
					for (; i<xstop; i++, sdata_r<<=1)
						if (sdata_r & 0x80000000) {
							if (q[i]) 	// Collision with sprite?
								spr_coll |= q[i] | sbit;
							else {		// Draw pixel if no collision
								p[i] = color;
								q[i] = sbit;
							}
						}
				}
				
			} else {				// Unexpanded
				
				if (mmc & sbit) {	// Multicolor mode
					uint32 plane0, plane1;
					
					// Convert sprite chunky pixels to bitplanes
					plane0 = (sdata & 0x55555555) | (sdata & 0x55555555) << 1;
					plane1 = (sdata & 0xaaaaaaaa) | (sdata & 0xaaaaaaaa) >> 1;
					
					// Collision with graphics?
					if (fore_mask & (plane0 | plane1)) {
						gfx_coll |= sbit;
						if (mdp & sbit) {
							plane0 &= ~fore_mask;	// Mask sprite if in background
							plane1 &= ~fore_mask;
						}
					}
					
					// Paint sprite
					plane0<<=xstart; plane1<<=xstart;
					for (i=xstart; i<xstop; i++, plane0<<=1, plane1<<=1) {
						uint8 col;
						if (plane1 & 0x80000000) {
							if (plane0 & 0x80000000)
								col = mm1_color;
							else
								col = color;
						} else {
							if (plane0 & 0x80000000)
								col = mm0_color;
							else
								continue;
						}
						if (q[i])
							spr_coll |= q[i] | sbit;
						else {
							p[i] = col;
							q[i] = sbit;
						}
					}
					
				} else {			// Standard mode
					
					// Collision with graphics?
					if (fore_mask & sdata) {
						gfx_coll |= sbit;
						if (mdp & sbit)
							sdata &= ~fore_mask;	// Mask sprite if in background
					}
					
					// Paint sprite
					sdata<<=xstart;
					for (i=xstart; i<xstop; i++, sdata<<=1)
						if (sdata & 0x80000000) {
							if (q[i]) {	// Collision with sprite?
								spr_coll |= q[i] | sbit;
							} else {		// Draw pixel if no collision
								p[i] = color;
								q[i] = sbit;
							}
						}
				}
			}
		}
	}
	
	if (ThePrefs.SpriteCollisions) {
		
		// Check sprite-sprite collisions
		if (clx_spr)
			clx_spr |= spr_coll;
		else {
			clx_spr |= spr_coll;
			irq_flag |= 0x04;
			if (irq_mask & 0x04) {
				irq_flag |= 0x80;
				the_cpu->TriggerVICIRQ();
			}
		}
		
		// Check sprite-background collisions
		if (clx_bgr)
			clx_bgr |= gfx_coll;
		else {
			clx_bgr |= gfx_coll;
			irq_flag |= 0x02;
			if (irq_mask & 0x02) {
				irq_flag |= 0x80;
				the_cpu->TriggerVICIRQ();
			}
		}
	}
}



/*
 *  Emulate one clock cycle, returns true if new raster line has started
 */

// Set BA low
#define SetBALow \
if (!BALow) { \
first_ba_cycle = the_c64->CycleCounter; \
BALow = true; \
}

// Turn on sprite DMA if necessary
#define CheckSpriteDMA \
mask = 1; \
for (i=0; i<8; i++, mask<<=1) \
if ((me & mask) && (raster_y & 0xff) == my[i]) { \
spr_dma_on |= mask; \
mc_base[i] = 0; \
if (mye & mask) \
spr_exp_y &= ~mask; \
}

// Fetch sprite data pointer
//#define SprPtrAccess(num)
//	spr_ptr[num] = read_byte(matrix_baseSC | 0x03f8 | num) << 6;
#define SprPtrAccess(num) \
spr_ptr[num] = read_byte(matrix_baseSC | 0x03f8 | num) << 6; \
if (spr_dma_on & (1 << num)) { \
spr_data[num][0] = read_byte(mc[num] & 0x3f | spr_ptr[num]); \
mc[num]++; \
}

// Fetch sprite data, increment data counter
void MOS6569::SprDataAccess23(uint8 spr_dma_on, uint8 num)
{
	if (spr_dma_on & (1 << num)) 
	{
		spr_data[num][1] = read_byte(mc[num] & 0x3f | spr_ptr[num]);
		mc[num]++;
		spr_data[num][2] = read_byte(mc[num] & 0x3f | spr_ptr[num]);
		mc[num]++;
	}
}
#define SprDataAccess(num) \
if (spr_dma_on) SprDataAccess23(spr_dma_on, num);


void MOS6569::EmulateLineSC(void)
{
	uint8 spr_dma_on; // just to hold var in register
	bool BALow; // just to hold var in register
	bool display_state; // just to hold var in register
	int i;
	uint8 mask;
	uint32 gfxcharcolor = 0;
	
	// Use local vars for some members -> smaller and faster code
	spr_dma_on = this->spr_dma_on;
	BALow = this->BALow;
	display_state = this->display_state;
	
	while(cycle & 0x3f)
	{
		switch (cycle) {
				
				//-----------------------------------------------------------
				//-----------------------------------------------------------
				// Cycles if bad line is false and draw_this_line is true
				//-----------------------------------------------------------
				//-----------------------------------------------------------
				// Fetch sprite pointer 3, increment raster counter, trigger raster IRQ,
				// test for Bad Line, reset BA if sprites 3 and 4 off, read data of sprite 3
			case 1:
			case 128+1:
			case 256+1:
			case 256+128+1:
				if (raster_y == TOTAL_RASTERS-1)
					
					// Trigger VBlank in cycle 2
					vblanking = true;
				
				else {
					
					// Increment raster counter
					raster_y++;
					
					// Trigger raster IRQ if IRQ line reached
					if (raster_y == irq_raster)
						raster_irq();
					
					// In line $30, the DEN bit controls if Bad Lines can occur
					if (raster_y == 0x30)
						bad_lines_enabled = ctrl1 & 0x10;
					
					// Bad Line condition?
					is_bad_line = (raster_y >= FIRST_DMA_LINE && raster_y <= LAST_DMA_LINE && ((raster_y & 7) == y_scroll) && bad_lines_enabled);
					if(is_bad_line)
						cycle = cycle | 0x080;
					else
						cycle = cycle & 0xf7f;
					
					// Don't draw all lines, hide some at the top and bottom
					draw_this_line = (raster_y >= FIRST_DISP_LINE && raster_y <= LAST_DISP_LINE && !frame_skipped);
					if(draw_this_line)
						cycle = cycle & 0xeff;
					else
						cycle = cycle | 0x100;
				}
				
				SprPtrAccess(3);
				if (is_bad_line)
					display_state = true;
				if (!(spr_dma_on & 0x18))
					BALow = false;
				break;
				
				// Set BA for sprite 5, read data of sprite 3
			case 2:
			case 128+2:
			case 256+2:
			case 256+128+2:
				if (vblanking) {
					
					// Vertical blank, reset counters
					raster_y = vc_base = 0;
					lp_triggered = vblanking = false;
					
					this->spr_dma_on = spr_dma_on;
					this->BALow = BALow;
					this->display_state = display_state;
					
					skip_counter--;
					frame_skipped = skip_counter == 0;
					if (!frame_skipped)
						skip_counter = ThePrefs.SkipFrames;
					
					the_c64->VBlank(!frame_skipped);
					
					spr_dma_on = this->spr_dma_on;
					BALow = this->BALow;
					display_state = this->display_state;
					
					// Get bitmap pointer for next frame. This must be done
					// after calling the_c64->VBlank() because the preferences
					// and screen configuration may have been changed there
					chunky_line_start = the_display->BitmapBase();
					xmod = the_display->BitmapXMod();
					
					// Trigger raster IRQ if IRQ in line 0
					if (irq_raster == 0)
						raster_irq();
				}
				
				// Our output goes here
				chunky_ptr = chunky_line_start;
				
				// Clear foreground mask
				memset(fore_mask_buf, 0, sizeof(fore_mask_buf));
				fore_mask_ptr = fore_mask_buf + 4;
				
				SprDataAccess(3);
				if (is_bad_line)
					display_state = true;
				if (spr_dma_on & 0x20)
					SetBALow;
				break;
				
				// Fetch sprite pointer 4, reset BA is sprite 4 and 5 off
			case 3:
				SprPtrAccess(4);
				if (!(spr_dma_on & 0x30))
					BALow = false;
				break;
				
				// Set BA for sprite 6, read data of sprite 4 
			case 4:
				SprDataAccess(4);
				if (spr_dma_on & 0x40)
					SetBALow;
				break;
				
				// Fetch sprite pointer 5, reset BA if sprite 5 and 6 off
			case 5:
				SprPtrAccess(5);
				if (!(spr_dma_on & 0x60))
					BALow = false;
				break;
				
				// Set BA for sprite 7, read data of sprite 5
			case 6:
				SprDataAccess(5);
				if (spr_dma_on & 0x80)
					SetBALow;
				break;
				
				// Fetch sprite pointer 6, reset BA if sprite 6 and 7 off
			case 7:
				SprPtrAccess(6);
				if (!(spr_dma_on & 0xc0))
					BALow = false;
				break;
				
				// Read data of sprite 6
			case 8:
				SprDataAccess(6);
				break;
				
				// Fetch sprite pointer 7, reset BA if sprite 7 off
			case 9:
				SprPtrAccess(7);
				if (!(spr_dma_on & 0x80))
					BALow = false;
				break;
				
				// Read data of sprite 7
			case 10:
				SprDataAccess(7);
				break;
				
				// Refresh, reset BA
			case 11:
				BALow = false;
				break;
				
				// Refresh, VCBASE->VCCOUNT, turn on matrix access and reset RC if Bad Line
			case 14:
				vc = vc_base;
				break;
				
				// Refresh and matrix access, increment mc_base by 2 if y expansion flipflop is set
			case 15:
				for (i=0; i<8; i++)
					if (spr_exp_y & (1 << i))
						mc_base[i] += 2;
				
				ml_index = 0;
				break;
				
				// Graphics and matrix access, increment mc_base by 1 if y expansion flipflop is set
				// and check if sprite DMA can be turned off
			case 16:
				gfxcharcolor = graphics_access(display_state);
				
				mask = 1;
				for (i=0; i<8; i++, mask<<=1) {
					if (spr_exp_y & mask)
						mc_base[i]++;
					if ((mc_base[i] & 0x3f) == 0x3f)
						spr_dma_on &= ~mask;
				}
				break;
				
				// Graphics and matrix access, turn off border in 40 column mode, display window starts here
			case 17:
				if (raster_y == dy_stop)
					ud_border_on = true;
				else if(ctrl1 & 0x10 && raster_y == dy_start)
					ud_border_on = false;
				
				if (ctrl2 & 8 && !ud_border_on) 
					border_on = false;
				
				if (ud_border_on)
					draw_border(chunky_ptr, ec_color_long)
				else
				{
					draw_graphics(gfxcharcolor);
					if (border_on)
						draw_border(chunky_ptr, ec_color_long)
				}
				chunky_ptr += 8;
				fore_mask_ptr++;
				gfxcharcolor = graphics_access(display_state);
				break;
				
				// Turn off border in 38 column mode
			case 18:
				if (!(ctrl2 & 8) && !ud_border_on)
					border_on = false;
				
				// Falls through
				
				// Graphics and matrix access
			case 19: case 20: case 21: case 22: case 23: case 24:
			case 25: case 26: case 27: case 28: case 29: case 30:
			case 31: case 32: case 33: case 34: case 35: case 36:
			case 37: case 38: case 39: case 40: case 41: case 42:
			case 43: case 44: case 45: case 46: case 47: case 48:
			case 49: case 50: case 51: case 52: case 53: case 54:	// Gnagna...
				if (ud_border_on)
					draw_border(chunky_ptr, ec_color_long)
				else
					draw_graphics(gfxcharcolor);
				chunky_ptr += 8;
				fore_mask_ptr++;
				gfxcharcolor = graphics_access(display_state);
				break;
				
				// Last graphics access, turn off matrix access, turn on sprite DMA if Y coordinate is
				// right and sprite is enabled, handle sprite y expansion, set BA for sprite 0
			case 55:
				if (ud_border_on)
					draw_border(chunky_ptr, ec_color_long)
				else
					draw_graphics(gfxcharcolor);
				chunky_ptr += 8;
				fore_mask_ptr++;
				gfxcharcolor = graphics_access(display_state);
				
				// Invert y expansion flipflop if bit in MYE is set
				mask = 1;
				for (i=0; i<8; i++, mask<<=1)
					if (mye & mask)
						spr_exp_y ^= mask;
				CheckSpriteDMA;
				
				if (spr_dma_on & 0x01) {	// Don't remove these braces!
					SetBALow;
				} else
					BALow = false;
				break;
				
				// Turn on border in 38 column mode, turn on sprite DMA if Y coordinate is right and
				// sprite is enabled, set BA for sprite 0, display window ends here
			case 56:
				if (!(ctrl2 & 8))
					border_on = true;
				
				if (ud_border_on)
					draw_border(chunky_ptr, ec_color_long)
				else
				{
					draw_graphics(gfxcharcolor);
					if (border_on)
						draw_border(chunky_ptr, ec_color_long)
				}
				chunky_ptr += 8;
				CheckSpriteDMA;
				
				if (spr_dma_on & 0x01)
					SetBALow;
				break;
				
				// Turn on border in 40 column mode, set BA for sprite 1, paint sprites
			case 57:
				if (ctrl2 & 8)
					border_on = true;
				
				// Draw sprites
				if (spr_disp_on && ThePrefs.SpritesOn && !ud_border_on)
					draw_sprites();
				
				// Turn off sprite display if DMA is off
				mask = 1;
				for (i=0; i<8; i++, mask<<=1)
					if ((spr_disp_on & mask) && !(spr_dma_on & mask))
						spr_disp_on &= ~mask;
				
				if (spr_dma_on & 0x02)
					SetBALow;
				break;
				
				// Fetch sprite pointer 0, mc_base->mc, turn on sprite display if necessary,
				// turn off display if RC=7, read data of sprite 0
			case 58:
				mask = 1;
				for (i=0; i<8; i++, mask<<=1) {
					mc[i] = mc_base[i];
					if ((spr_dma_on & mask) && (raster_y & 0xff) == my[i])
						spr_disp_on |= mask;
				}
				SprPtrAccess(0);
				
				if (rc == 7) {
					vc_base = vc;
					display_state = false;
				}
				if (display_state)
					rc = (rc + 1) & 7;
				break;
				
				// Set BA for sprite 2, read data of sprite 0
			case 59:
				SprDataAccess(0);
				if (spr_dma_on & 0x04)
					SetBALow;
				break;
				
				// Fetch sprite pointer 1, reset BA if sprite 1 and 2 off, graphics display ends here
			case 60:
				// Increment pointer in chunky buffer
				chunky_line_start += xmod;
				
				SprPtrAccess(1);
				if (!(spr_dma_on & 0x06))
					BALow = false;
				break;
				
				// Set BA for sprite 3, read data of sprite 1
			case 61:
				SprDataAccess(1);
				if (spr_dma_on & 0x08)
					SetBALow;
				break;
				
				// Read sprite pointer 2, reset BA if sprite 2 and 3 off, read data of sprite 2
			case 62:
				SprPtrAccess(2);
				if (!(spr_dma_on & 0x0c))
					BALow = false;
				break;
				
				// Set BA for sprite 4, read data of sprite 2
			case 63:
				SprDataAccess(2);
				
				if (raster_y == dy_stop)
					ud_border_on = true;
				else
					if (ctrl1 & 0x10 && raster_y == dy_start)
						ud_border_on = false;
				
				if (spr_dma_on & 0x10)
					SetBALow;
				
				// Last cycle
				if(ThePrefs.SIDOn)
					the_c64->TheSID->EmulateLine();
				break;
				
				//-----------------------------------------------------------
				//-----------------------------------------------------------
				// Cycles if bad line is true and draw_this_line is true
				// (cycles 1 and 2 always same)
				//-----------------------------------------------------------
				//-----------------------------------------------------------
				
				// Fetch sprite pointer 4, reset BA is sprite 4 and 5 off
			case 128+3:
				SprPtrAccess(4);
				display_state = true;
				if (!(spr_dma_on & 0x30))
					BALow = false;
				break;
				
				// Set BA for sprite 6, read data of sprite 4 
			case 128+4:
				SprDataAccess(4);
				display_state = true;
				if (spr_dma_on & 0x40)
					SetBALow;
				break;
				
				// Fetch sprite pointer 5, reset BA if sprite 5 and 6 off
			case 128+5:
				SprPtrAccess(5);
				display_state = true;
				if (!(spr_dma_on & 0x60))
					BALow = false;
				break;
				
				// Set BA for sprite 7, read data of sprite 5
			case 128+6:
				SprDataAccess(5);
				display_state = true;
				if (spr_dma_on & 0x80)
					SetBALow;
				break;
				
				// Fetch sprite pointer 6, reset BA if sprite 6 and 7 off
			case 128+7:
				SprPtrAccess(6);
				display_state = true;
				if (!(spr_dma_on & 0xc0))
					BALow = false;
				break;
				
				// Read data of sprite 6
			case 128+8:
				SprDataAccess(6);
				display_state = true;
				break;
				
				// Fetch sprite pointer 7, reset BA if sprite 7 off
			case 128+9:
				SprPtrAccess(7);
				display_state = true;
				if (!(spr_dma_on & 0x80))
					BALow = false;
				break;
				
				// Read data of sprite 7
			case 128+10:
				SprDataAccess(7);
				display_state = true;
				break;
				
				// Refresh, reset BA
			case 128+11:
				display_state = true;
				BALow = false;
				break;
				
				// Refresh, turn on matrix access if Bad Line
			case 128+12:
				// Refresh, turn on matrix access if Bad Line, reset raster_x, graphics display starts here
			case 128+13:
				display_state = true;
				SetBALow;
				break;
				
				// Refresh, VCBASE->VCCOUNT, turn on matrix access and reset RC if Bad Line
			case 128+14:
				display_state = true;
				rc = 0;
				SetBALow;
				vc = vc_base;
				break;
				
				// Refresh and matrix access, increment mc_base by 2 if y expansion flipflop is set
			case 128+15:
				display_state = true;
				SetBALow;
				
				for (i=0; i<8; i++)
					if (spr_exp_y & (1 << i))
						mc_base[i] += 2;
				
				ml_index = 0;
				matrix_access();
				break;
				
				// Graphics and matrix access, increment mc_base by 1 if y expansion flipflop is set
				// and check if sprite DMA can be turned off
			case 128+16:
				gfxcharcolor = graphics_access(display_state);
				display_state = true;
				SetBALow;
				
				mask = 1;
				for (i=0; i<8; i++, mask<<=1) {
					if (spr_exp_y & mask)
						mc_base[i]++;
					if ((mc_base[i] & 0x3f) == 0x3f)
						spr_dma_on &= ~mask;
				}
				
				matrix_access();
				break;
				
				// Graphics and matrix access, turn off border in 40 column mode, display window starts here
			case 128+17:
				if (raster_y == dy_stop)
					ud_border_on = true;
				else if(ctrl1 & 0x10 && raster_y == dy_start)
					ud_border_on = false;
				
				if (ctrl2 & 8 && !ud_border_on) 
					border_on = false;
				
				if (ud_border_on)
					draw_border(chunky_ptr, ec_color_long)
				else
				{
					draw_graphics(gfxcharcolor);
					if (border_on)
						draw_border(chunky_ptr, ec_color_long)
				}
				chunky_ptr += 8;
				fore_mask_ptr++;
				gfxcharcolor = graphics_access(display_state);
				display_state = true;
				SetBALow;
				matrix_access();
				break;
				
				// Turn off border in 38 column mode
			case 128+18:
				if (!(ctrl2 & 8) && !ud_border_on)
					border_on = false;
				
				// Falls through
				
				// Graphics and matrix access
			case 128+19: case 128+20: case 128+21: case 128+22: case 128+23: case 128+24:
			case 128+25: case 128+26: case 128+27: case 128+28: case 128+29: case 128+30:
			case 128+31: case 128+32: case 128+33: case 128+34: case 128+35: case 128+36:
			case 128+37: case 128+38: case 128+39: case 128+40: case 128+41: case 128+42:
			case 128+43: case 128+44: case 128+45: case 128+46: case 128+47: case 128+48:
			case 128+49: case 128+50: case 128+51: case 128+52: case 128+53: case 128+54:	// Gnagna...
				if (ud_border_on)
					draw_border(chunky_ptr, ec_color_long)
				else
					draw_graphics(gfxcharcolor);
				chunky_ptr += 8;
				fore_mask_ptr++;
				gfxcharcolor = graphics_access(display_state);
				display_state = true;
				SetBALow;
				matrix_access();
				break;
				
				// Last graphics access, turn off matrix access, turn on sprite DMA if Y coordinate is
				// right and sprite is enabled, handle sprite y expansion, set BA for sprite 0
			case 128+55:
				if (ud_border_on)
					draw_border(chunky_ptr, ec_color_long)
				else
					draw_graphics(gfxcharcolor);
				chunky_ptr += 8;
				fore_mask_ptr++;
				gfxcharcolor = graphics_access(display_state);
				display_state = true;
				
				// Invert y expansion flipflop if bit in MYE is set
				mask = 1;
				for (i=0; i<8; i++, mask<<=1)
					if (mye & mask)
						spr_exp_y ^= mask;
				CheckSpriteDMA;
				
				if (spr_dma_on & 0x01) {	// Don't remove these braces!
					SetBALow;
				} else
					BALow = false;
				break;
				
				// Turn on border in 38 column mode, turn on sprite DMA if Y coordinate is right and
				// sprite is enabled, set BA for sprite 0, display window ends here
			case 128+56:
				if (!(ctrl2 & 8))
					border_on = true;
				
				if (ud_border_on)
					draw_border(chunky_ptr, ec_color_long)
				else
				{
					draw_graphics(gfxcharcolor);
					if (border_on)
						draw_border(chunky_ptr, ec_color_long)
				}
				chunky_ptr += 8;
				display_state = true;
				CheckSpriteDMA;
				
				if (spr_dma_on & 0x01)
					SetBALow;
				break;
				
				// Turn on border in 40 column mode, set BA for sprite 1, paint sprites
			case 128+57:
				if (ctrl2 & 8)
					border_on = true;
				
				// Draw sprites
				if (spr_disp_on && ThePrefs.SpritesOn && !ud_border_on)
					draw_sprites();
				
				// Turn off sprite display if DMA is off
				mask = 1;
				for (i=0; i<8; i++, mask<<=1)
					if ((spr_disp_on & mask) && !(spr_dma_on & mask))
						spr_disp_on &= ~mask;
				
				display_state = true;
				if (spr_dma_on & 0x02)
					SetBALow;
				break;
				
				// Fetch sprite pointer 0, mc_base->mc, turn on sprite display if necessary,
				// turn off display if RC=7, read data of sprite 0
			case 128+58:
				mask = 1;
				for (i=0; i<8; i++, mask<<=1) {
					mc[i] = mc_base[i];
					if ((spr_dma_on & mask) && (raster_y & 0xff) == my[i])
						spr_disp_on |= mask;
				}
				SprPtrAccess(0);
				
				if (rc == 7) {
					vc_base = vc;
				}
				display_state = true;
				rc = (rc + 1) & 7;
				break;
				
				// Set BA for sprite 2, read data of sprite 0
			case 128+59:
				SprDataAccess(0);
				display_state = true;
				if (spr_dma_on & 0x04)
					SetBALow;
				break;
				
				// Fetch sprite pointer 1, reset BA if sprite 1 and 2 off, graphics display ends here
			case 128+60:
				// Increment pointer in chunky buffer
				chunky_line_start += xmod;
				
				SprPtrAccess(1);
				display_state = true;
				if (!(spr_dma_on & 0x06))
					BALow = false;
				break;
				
				// Set BA for sprite 3, read data of sprite 1
			case 128+61:
				SprDataAccess(1);
				display_state = true;
				if (spr_dma_on & 0x08)
					SetBALow;
				break;
				
				// Read sprite pointer 2, reset BA if sprite 2 and 3 off, read data of sprite 2
			case 128+62:
				SprPtrAccess(2);
				display_state = true;
				if (!(spr_dma_on & 0x0c))
					BALow = false;
				break;
				
				// Set BA for sprite 4, read data of sprite 2
			case 128+63:
				SprDataAccess(2);
				display_state = true;
				
				if (raster_y == dy_stop)
					ud_border_on = true;
				else
					if (ctrl1 & 0x10 && raster_y == dy_start)
						ud_border_on = false;
				
				if (spr_dma_on & 0x10)
					SetBALow;
				
				// Last cycle
				if(ThePrefs.SIDOn)
					the_c64->TheSID->EmulateLine();
				break;
				
				
				//-----------------------------------------------------------
				//-----------------------------------------------------------
				// Cycles if bad line is false and draw_this_line is false
				//-----------------------------------------------------------
				//-----------------------------------------------------------
				
				// Fetch sprite pointer 4, reset BA is sprite 4 and 5 off
			case 256+3:
				if (!(spr_dma_on & 0x30))
					BALow = false;
				break;
				
				// Set BA for sprite 6, read data of sprite 4 
			case 256+4:
				if (spr_dma_on & 0x40)
					SetBALow;
				break;
				
				// Fetch sprite pointer 5, reset BA if sprite 5 and 6 off
			case 256+5:
				if (!(spr_dma_on & 0x60))
					BALow = false;
				break;
				
				// Set BA for sprite 7, read data of sprite 5
			case 256+6:
				if (spr_dma_on & 0x80)
					SetBALow;
				break;
				
				// Fetch sprite pointer 6, reset BA if sprite 6 and 7 off
			case 256+7:
				if (!(spr_dma_on & 0xc0))
					BALow = false;
				break;
				
				// Fetch sprite pointer 7, reset BA if sprite 7 off
			case 256+9:
				if (!(spr_dma_on & 0x80))
					BALow = false;
				break;
				
				// Refresh, reset BA
			case 256+11:
				BALow = false;
				break;
				
				// Refresh, VCBASE->VCCOUNT, turn on matrix access and reset RC if Bad Line
			case 256+14:
				vc = vc_base;
				break;
				
				// Refresh and matrix access, increment mc_base by 2 if y expansion flipflop is set
			case 256+15:
				for (i=0; i<8; i++)
					if (spr_exp_y & (1 << i))
						mc_base[i] += 2;
				
				ml_index = 0;
				break;
				
				// Graphics and matrix access, increment mc_base by 1 if y expansion flipflop is set
				// and check if sprite DMA can be turned off
			case 256+16:
				if(display_state)
					vc++;
				
				mask = 1;
				for (i=0; i<8; i++, mask<<=1) {
					if (spr_exp_y & mask)
						mc_base[i]++;
					if ((mc_base[i] & 0x3f) == 0x3f)
						spr_dma_on &= ~mask;
				}
				break;
				
				// Graphics and matrix access, turn off border in 40 column mode, display window starts here
			case 256+17:
				if (raster_y == dy_stop)
					ud_border_on = true;
				else if(ctrl1 & 0x10 && raster_y == dy_start)
					ud_border_on = false;
				
				if (ctrl2 & 8 && !ud_border_on) 
					border_on = false;
				
				if(display_state)
					vc++;
				break;
				
				// Turn off border in 38 column mode
			case 256+18:
				if (!(ctrl2 & 8) && !ud_border_on)
					border_on = false;
				
				// Falls through
				
				// Graphics and matrix access
			case 256+19: case 256+20: case 256+21: case 256+22: case 256+23: case 256+24:
			case 256+25: case 256+26: case 256+27: case 256+28: case 256+29: case 256+30:
			case 256+31: case 256+32: case 256+33: case 256+34: case 256+35: case 256+36:
			case 256+37: case 256+38: case 256+39: case 256+40: case 256+41: case 256+42:
			case 256+43: case 256+44: case 256+45: case 256+46: case 256+47: case 256+48:
			case 256+49: case 256+50: case 256+51: case 256+52: case 256+53: case 256+54:	// Gnagna...
				if(display_state)
					vc++;
				break;
				
				// Last graphics access, turn off matrix access, turn on sprite DMA if Y coordinate is
				// right and sprite is enabled, handle sprite y expansion, set BA for sprite 0
			case 256+55:
				if(display_state)
					vc++;
				
				// Invert y expansion flipflop if bit in MYE is set
				mask = 1;
				for (i=0; i<8; i++, mask<<=1)
					if (mye & mask)
						spr_exp_y ^= mask;
				CheckSpriteDMA;
				
				if (spr_dma_on & 0x01) {	// Don't remove these braces!
					SetBALow;
				} else
					BALow = false;
				break;
				
				// Turn on border in 38 column mode, turn on sprite DMA if Y coordinate is right and
				// sprite is enabled, set BA for sprite 0, display window ends here
			case 256+56:
				if (!(ctrl2 & 8))
					border_on = true;
				
				CheckSpriteDMA;
				
				if (spr_dma_on & 0x01)
					SetBALow;
				break;
				
				// Turn on border in 40 column mode, set BA for sprite 1, paint sprites
			case 256+57:
				if (ctrl2 & 8)
					border_on = true;
				
				// Turn off sprite display if DMA is off
				mask = 1;
				for (i=0; i<8; i++, mask<<=1)
					if ((spr_disp_on & mask) && !(spr_dma_on & mask))
						spr_disp_on &= ~mask;
				
				if (spr_dma_on & 0x02)
					SetBALow;
				break;
				
				// Fetch sprite pointer 0, mc_base->mc, turn on sprite display if necessary,
				// turn off display if RC=7, read data of sprite 0
			case 256+58:
				mask = 1;
				for (i=0; i<8; i++, mask<<=1) {
					mc[i] = mc_base[i];
					if ((spr_dma_on & mask) && (raster_y & 0xff) == my[i])
						spr_disp_on |= mask;
				}
				SprPtrAccess(0);
				
				if (rc == 7) {
					vc_base = vc;
					display_state = false;
				}
				if (display_state)
					rc = (rc + 1) & 7;
				break;
				
				// Set BA for sprite 2, read data of sprite 0
			case 256+59:
				SprDataAccess(0);
				if (spr_dma_on & 0x04)
					SetBALow;
				break;
				
				// Fetch sprite pointer 1, reset BA if sprite 1 and 2 off, graphics display ends here
			case 256+60:
				SprPtrAccess(1);
				if (!(spr_dma_on & 0x06))
					BALow = false;
				break;
				
				// Set BA for sprite 3, read data of sprite 1
			case 256+61:
				SprDataAccess(1);
				if (spr_dma_on & 0x08)
					SetBALow;
				break;
				
				// Read sprite pointer 2, reset BA if sprite 2 and 3 off, read data of sprite 2
			case 256+62:
				SprPtrAccess(2);
				if (!(spr_dma_on & 0x0c))
					BALow = false;
				break;
				
				// Set BA for sprite 4, read data of sprite 2
			case 256+63:
				SprDataAccess(2);
				
				if (raster_y == dy_stop)
					ud_border_on = true;
				else
					if (ctrl1 & 0x10 && raster_y == dy_start)
						ud_border_on = false;
				
				if (spr_dma_on & 0x10)
					SetBALow;
				
				// Last cycle
				if(ThePrefs.SIDOn)
					the_c64->TheSID->EmulateLine();
				break;
				
				//-----------------------------------------------------------
				//-----------------------------------------------------------
				// Cycles if bad line is true and draw_this_line is false
				// (cycles 1 and 2 always same)
				//-----------------------------------------------------------
				//-----------------------------------------------------------
				
				// Fetch sprite pointer 4, reset BA is sprite 4 and 5 off
			case 256+128+3:
				display_state = true;
				if (!(spr_dma_on & 0x30))
					BALow = false;
				break;
				
				// Set BA for sprite 6, read data of sprite 4 
			case 256+128+4:
				display_state = true;
				if (spr_dma_on & 0x40)
					SetBALow;
				break;
				
				// Fetch sprite pointer 5, reset BA if sprite 5 and 6 off
			case 256+128+5:
				display_state = true;
				if (!(spr_dma_on & 0x60))
					BALow = false;
				break;
				
				// Set BA for sprite 7, read data of sprite 5
			case 256+128+6:
				display_state = true;
				if (spr_dma_on & 0x80)
					SetBALow;
				break;
				
				// Fetch sprite pointer 6, reset BA if sprite 6 and 7 off
			case 256+128+7:
				display_state = true;
				if (!(spr_dma_on & 0xc0))
					BALow = false;
				break;
				
				// Read data of sprite 6
			case 256+128+8:
				display_state = true;
				break;
				
				// Fetch sprite pointer 7, reset BA if sprite 7 off
			case 256+128+9:
				display_state = true;
				if (!(spr_dma_on & 0x80))
					BALow = false;
				break;
				
				// Read data of sprite 7
			case 256+128+10:
				display_state = true;
				break;
				
				// Refresh, reset BA
			case 256+128+11:
				display_state = true;
				BALow = false;
				break;
				
				// Refresh, turn on matrix access if Bad Line
			case 256+128+12:
				// Refresh, turn on matrix access if Bad Line, reset raster_x, graphics display starts here
			case 256+128+13:
				display_state = true;
				SetBALow;
				break;
				
				// Refresh, VCBASE->VCCOUNT, turn on matrix access and reset RC if Bad Line
			case 256+128+14:
				display_state = true;
				rc = 0;
				SetBALow;
				vc = vc_base;
				break;
				
				// Refresh and matrix access, increment mc_base by 2 if y expansion flipflop is set
			case 256+128+15:
				display_state = true;
				SetBALow;
				
				for (i=0; i<8; i++)
					if (spr_exp_y & (1 << i))
						mc_base[i] += 2;
				break;
				
				// Graphics and matrix access, increment mc_base by 1 if y expansion flipflop is set
				// and check if sprite DMA can be turned off
			case 256+128+16:
				if(display_state)
					vc++;
				display_state = true;
				SetBALow;
				
				mask = 1;
				for (i=0; i<8; i++, mask<<=1) {
					if (spr_exp_y & mask)
						mc_base[i]++;
					if ((mc_base[i] & 0x3f) == 0x3f)
						spr_dma_on &= ~mask;
				}
				break;
				
				// Graphics and matrix access, turn off border in 40 column mode, display window starts here
			case 256+128+17:
				if (raster_y == dy_stop)
					ud_border_on = true;
				else if(ctrl1 & 0x10 && raster_y == dy_start)
					ud_border_on = false;
				
				if (ctrl2 & 8 && !ud_border_on) 
					border_on = false;
				
				if(display_state)
					vc++;
				display_state = true;
				SetBALow;
				break;
				
				// Turn off border in 38 column mode
			case 256+128+18:
				if (!(ctrl2 & 8) && !ud_border_on)
					border_on = false;
				
				// Falls through
				
				// Graphics and matrix access
			case 256+128+19: case 256+128+20: case 256+128+21: case 256+128+22: case 256+128+23: case 256+128+24:
			case 256+128+25: case 256+128+26: case 256+128+27: case 256+128+28: case 256+128+29: case 256+128+30:
			case 256+128+31: case 256+128+32: case 256+128+33: case 256+128+34: case 256+128+35: case 256+128+36:
			case 256+128+37: case 256+128+38: case 256+128+39: case 256+128+40: case 256+128+41: case 256+128+42:
			case 256+128+43: case 256+128+44: case 256+128+45: case 256+128+46: case 256+128+47: case 256+128+48:
			case 256+128+49: case 256+128+50: case 256+128+51: case 256+128+52: case 256+128+53: case 256+128+54:	// Gnagna...
				if(display_state)
					vc++;
				display_state = true;
				SetBALow;
				break;
				
				// Last graphics access, turn off matrix access, turn on sprite DMA if Y coordinate is
				// right and sprite is enabled, handle sprite y expansion, set BA for sprite 0
			case 256+128+55:
				if(display_state)
					vc++;
				display_state = true;
				
				// Invert y expansion flipflop if bit in MYE is set
				mask = 1;
				for (i=0; i<8; i++, mask<<=1)
					if (mye & mask)
						spr_exp_y ^= mask;
				CheckSpriteDMA;
				
				if (spr_dma_on & 0x01) {	// Don't remove these braces!
					SetBALow;
				} else
					BALow = false;
				break;
				
				// Turn on border in 38 column mode, turn on sprite DMA if Y coordinate is right and
				// sprite is enabled, set BA for sprite 0, display window ends here
			case 256+128+56:
				if (!(ctrl2 & 8))
					border_on = true;
				
				display_state = true;
				CheckSpriteDMA;
				
				if (spr_dma_on & 0x01)
					SetBALow;
				break;
				
				// Turn on border in 40 column mode, set BA for sprite 1, paint sprites
			case 256+128+57:
				if (ctrl2 & 8)
					border_on = true;
				
				// Turn off sprite display if DMA is off
				mask = 1;
				for (i=0; i<8; i++, mask<<=1)
					if ((spr_disp_on & mask) && !(spr_dma_on & mask))
						spr_disp_on &= ~mask;
				
				display_state = true;
				if (spr_dma_on & 0x02)
					SetBALow;
				break;
				
				// Fetch sprite pointer 0, mc_base->mc, turn on sprite display if necessary,
				// turn off display if RC=7, read data of sprite 0
			case 256+128+58:
				mask = 1;
				for (i=0; i<8; i++, mask<<=1) {
					mc[i] = mc_base[i];
					if ((spr_dma_on & mask) && (raster_y & 0xff) == my[i])
						spr_disp_on |= mask;
				}
				SprPtrAccess(0);
				
				if (rc == 7) {
					vc_base = vc;
				}
				display_state = true;
				rc = (rc + 1) & 7;
				break;
				
				// Set BA for sprite 2, read data of sprite 0
			case 256+128+59:
				SprDataAccess(0);
				display_state = true;
				if (spr_dma_on & 0x04)
					SetBALow;
				break;
				
				// Fetch sprite pointer 1, reset BA if sprite 1 and 2 off, graphics display ends here
			case 256+128+60:
				SprPtrAccess(1);
				display_state = true;
				if (!(spr_dma_on & 0x06))
					BALow = false;
				break;
				
				// Set BA for sprite 3, read data of sprite 1
			case 256+128+61:
				SprDataAccess(1);
				display_state = true;
				if (spr_dma_on & 0x08)
					SetBALow;
				break;
				
				// Read sprite pointer 2, reset BA if sprite 2 and 3 off, read data of sprite 2
			case 256+128+62:
				SprPtrAccess(2);
				display_state = true;
				if (!(spr_dma_on & 0x0c))
					BALow = false;
				break;
				
				// Set BA for sprite 4, read data of sprite 2
			case 256+128+63:
				SprDataAccess(2);
				display_state = true;
				
				if (raster_y == dy_stop)
					ud_border_on = true;
				else
					if (ctrl1 & 0x10 && raster_y == dy_start)
						ud_border_on = false;
				
				if (spr_dma_on & 0x10)
					SetBALow;
				
				// Last cycle
				if(ThePrefs.SIDOn)
					the_c64->TheSID->EmulateLine();
				break;
		}
		
		// Next cycle
		++cycle;
		
		if(--the_c64->TheCIA1->CyclesTillActionCnt == 0)
			the_c64->TheCIA1->EmulateCycles();
		
		if(--the_c64->TheCIA2->CyclesTillActionCnt == 0)
			the_c64->TheCIA2->EmulateCycles();
		
		the_c64->TheCPU->EmulateCycle(BALow);
		
		if (ThePrefs.Emul1541Proc) 
		{
			the_c64->TheCPU1541->CountVIATimers(1);
			if (!the_c64->TheCPU1541->Idle)
				the_c64->TheCPU1541->EmulateCycle();
		}
		the_c64->CycleCounter++;
	}
	
	this->spr_dma_on = spr_dma_on;
	this->BALow = BALow;
	this->display_state = display_state;
	
	// First cycle in next line
	cycle = (cycle & 0xf80) | 0x01;
}

#endif

/*
 *  VIC vertical blank: Reset counters and redraw screen
 */
inline void MOS6569::vblank(void)
{
	raster_y = vc_base = 0;
	lp_triggered = false;
	
	if (!(frame_skipped = --skip_counter))
		skip_counter = ThePrefs.SkipFrames;
	
	the_c64->VBlank(!frame_skipped);
	
	// Get bitmap pointer for next frame. This must be done
	// after calling the_c64->VBlank() because the preferences
	// and screen configuration may have been changed there
	chunky_line_start = the_display->BitmapBase();
	xmod = the_display->BitmapXMod();
}


/* The el_* functions in a version that doesn't require as humongous
 a TextColorTable, while still being (hopefully) fastish, for PalmOS.
 
 Originally, TextColorTable contained 8 8-bit pixels for each combination
 of forecolor/backcolor/data (total of 512 kB).
 
 This version contains 4 pixels for foreground and background color ONLY.
 This way, we need only 16 kB, which is acceptable.
 
 Assumptions in the below code: COL80_XSTART must be divisible by 8,
 p points at col80
 */

void MOS6569::el_std_text(uint8 *p, uint8 *q)
{
	uint32 *tct = &TextColorTable[b0c << 8];
	uint32 *lp = (uint32 *)p;
	uint8 *cp = color_line;
	uint8 *mp = matrix_line;
	
	// Loop for 40 characters
	for (int i=0; i<40; i++) {
		uint16 color = cp[i] << 4;
		uint8 data = q[mp[i] << 3];
		
		// First 4 pixels
		*lp++ = tct[color | (data >> 4)];
		// Other 4 pixles
		*lp++ = tct[color | (data & 0xf)];
 	}
}
void MOS6569::el_std_text_spr(uint8 *q, uint8 *r)
{
 	uint8 *mp = matrix_line;
	
 	// Loop for 40 characters
 	for (int i=0; i<40; i++)
		r[i] = q[mp[i] << 3];
}


void MOS6569::el_mc_text(uint8 *p, uint8 *q)
{
	uint32 *tct = &TextColorTable[b0c << 8];
 	uint32 *lp = (uint32 *)p;
 	uint8 *cp = color_line;
 	uint8 *mp = matrix_line;
 	uint16 *mclp = mc_color_lookup;
 	uint16 color;
	uint8 data;
	
 	// Loop for 40 characters
 	for (int i=0; i<40; i++) {
		color = cp[i];
		data = q[mp[i] << 3];
		
		if (color & 8) {
			color = color&7;
			mclp[3] = color | (color << 8);
			*lp++ = (mclp[(data >> 6) & 3]      ) |
					(mclp[(data >> 4) & 3] << 16);
			*lp++ = (mclp[(data >> 2) & 3]      ) |
					(mclp[ data       & 3] << 16);
			
		} else { // Standard mode in multicolor mode
			*lp++ = tct[(color<<4) | (data>>4)];
			*lp++ = tct[(color<<4) | (data & 0xf)];
		}
	}
}
void MOS6569::el_mc_text_spr(uint8 *q, uint8 *r)
{
 	uint8 *cp = color_line;
 	uint8 *mp = matrix_line;
	uint8 data;
	
 	// Loop for 40 characters
 	for (int i=0; i<40; i++) {
		data = q[mp[i] << 3];

		if (cp[i] & 8) {
			r[i] = (data & 0xaa) | ((data & 0xaa) >> 1);
		} else { // Standard mode in multicolor mode
			r[i] = data;
		}
 	}
}


void MOS6569::el_std_bitmap(uint8 *p, uint8 *q)
{
 	uint32 *lp = (uint32 *)p;
 	uint8 *mp = matrix_line;
	
 	// Loop for 40 characters
 	for (int i=0; i<40; i++, q+=8) {
		uint8 data = *q;
		uint8 color = mp[i] & 0xf0;
		uint16 bcolor = (mp[i] & 15) << 8;
		
		*lp++ = TextColorTable[bcolor | color | (data >> 4)];
		*lp++ = TextColorTable[bcolor | color | (data & 0xf)];
 	}
}
void MOS6569::el_std_bitmap_spr(uint8 *q, uint8 *r)
{
 	// Loop for 40 characters
 	for (int i=0; i<40; i++, q+=8) {
		r[i] = *q;
 	}
}


void MOS6569::el_mc_bitmap(uint8 *p, uint8 *q)
{
 	uint16 lookup[4];
 	uint32 *lp = (uint32 *) p;
 	uint8 *cp = color_line;
 	uint8 *mp = matrix_line;
	
 	lookup[0] = mc_color_lookup[0];
	
 	// Loop for 40 characters
 	for (int i=0; i<40; i++, q+=8) {
		uint16 color;
		
		color = mp[i] >> 4;
		lookup[1] = (color << 8) | color;
		color = mp[i] & 0xf;
		lookup[2] = (color << 8) | color;
		color = cp[i];
		lookup[3] = (color << 8) | color;
		
		uint8 data = *q;
		
		*lp++ = (lookup[(data >> 6) & 3]) | (lookup[(data >> 4) & 3] << 16);
		*lp++ = (lookup[(data >> 2) & 3]) |	(lookup[ data       & 3] << 16);
 	}
}
void MOS6569::el_mc_bitmap_spr(uint8 *q, uint8 *r)
{
 	// Loop for 40 characters
 	for (int i=0; i<40; i++, q+=8) {
		uint8 data = *q;
		r[i] = (data & 0xaa) | ((data & 0xaa) >> 1);
 	}
}


void MOS6569::el_ecm_text(uint8 *p, uint8 *q)
{
 	uint32 *lp = (uint32 *)p;
	if ((int)p & 3) {
		int tmp = 4-((int)p&3);
		lp = (uint32 *)(p + tmp);
	}
 	uint8 *cp = color_line;
 	uint8 *mp = matrix_line;
 	uint8 *bcp = &b0c;
	
 	// Loop for 40 characters
 	for (int i=0; i<40; i++) {
		uint8 data = mp[i];
		uint8 color = cp[i] << 4;
		uint16 bcolor = bcp[(data >> 6) & 3] << 8;
		
		data = q[(data & 0x3f) << 3];
		*lp++ = TextColorTable[bcolor | color | (data >> 4)];
		*lp++ = TextColorTable[bcolor | color | (data & 0xf)];
 	}
}
void MOS6569::el_ecm_text_spr(uint8 *q, uint8 *r)
{
 	uint8 *mp = matrix_line;
	
 	// Loop for 40 characters
 	for (int i=0; i<40; i++) {
		//r[i] = mp[i];
		r[i] = q[(mp[i] & 0x3f) << 3]; 
	}
}


void MOS6569::el_std_idle(uint8 *p)
{
 	uint8 data = *get_physical(ctrl1 & 0x40 ? 0x39ff : 0x3fff);
 	uint32 *lp = (uint32 *)p;
 	uint32 pla, plb;
	
 	pla=TextColorTable[(b0c<<8) | (data >> 4)];
 	plb=TextColorTable[(b0c<<8) | (data & 0xf)];
	
 	for (int i=0; i<40; i++) {
		*lp++ = pla;
		*lp++ = plb;
 	}
}
void MOS6569::el_std_idle_spr(uint8 *r)
{
 	uint8 data = *get_physical(ctrl1 & 0x40 ? 0x39ff : 0x3fff);
 	memset(r, data, 40);
}


void MOS6569::el_mc_idle(uint8 *p)
{
 	uint16 data = *get_physical(0x3fff);
 	uint32 *lp = (uint32 *)p;
 	uint16 lookup[4];
	
 	lookup[0] = mc_color_lookup[0];
 	lookup[1] = lookup[2] = lookup[3] = 0;
	
	uint32 conva =  lookup[(data >> 6) & 3] | (lookup[(data >> 4) & 3] << 16);
 	uint32 convb =  lookup[(data >> 2) & 3] | (lookup[data & 3]        << 16);
	
 	for (int i=0; i<40; i++) {
		*lp++ = conva;
		*lp++ = convb;
 	}
}
void MOS6569::el_mc_idle_spr(uint8 *r)
{
 	uint16 data = *get_physical(0x3fff);
	memset(r, data, 40);
}


// Sprites

#define PUT_PIXEL() \
if (q[i]) \
	spr_coll |= q[i] | sbit;\
else { \
	p[i] = col;\
	q[i] = sbit;\
}


void MOS6569::el_sprites(uint8 *chunky_ptr)
{
	int i;
	int snum, sbit;		// Sprite number/bit mask
	int spr_coll=0, gfx_coll=0;
	const int xoffs = (C64DISPLAY_X-DISPLAY_X)/2; // 32 if the screen is 320 wide
	
	// Draw each active sprite
	for (snum=0, sbit=1; snum<8; snum++, sbit<<=1)
		if ((sprite_on & sbit) && mx[snum] < C64DISPLAY_X-32) {
			int spr_mask_pos;	// Sprite bit position in fore_mask_buf
			uint32 sdata, fore_mask;
			
			uint8 *p = chunky_ptr + (mx[snum]-xoffs) + 8;;
			uint8 *q = spr_coll_buf + mx[snum] + 8;
			
			uint8 *sdatap = get_physical(matrix_base[0x3f8 + snum] << 6 | mc[snum]);
			sdata = (*sdatap << 24) | (*(sdatap+1) << 16) | (*(sdatap+2) << 8);
			uint8 color = sc[snum], col;
			
			spr_mask_pos = mx[snum] + 8 - x_scroll;
			
			uint8 *fmbp = fore_mask_buf + (spr_mask_pos >> 3);
			int sshift = spr_mask_pos & 7;
			fore_mask = (((*(fmbp+0) << 24) | (*(fmbp+1) << 16) | (*(fmbp+2) << 8)
						  | (*(fmbp+3))) << sshift) | (*(fmbp+4) >> (8-sshift));
			
			// Don't draw outside the screen buffer!
			uint8 xstart=0, xstop=24, xstop1 = 24;
			if (mxe & sbit) {
				xstop=48;
				xstop1=32;
			}
			// DEBUG
			
			if (mx[snum]+8 < xoffs) xstart=xoffs-mx[snum]-8;
			if (mx[snum]+8-xoffs+xstop > DISPLAY_X) {
				xstop = DISPLAY_X-mx[snum]-8+xoffs;
				if (xstop<xstop1) xstop1=xstop;
			}
			
			if (mxe & sbit) {		// X-expanded
				if (mx[snum] >= C64DISPLAY_X-56)
					continue;
				
				uint32 sdata_l = 0, sdata_r = 0, fore_mask_r;
				fore_mask_r = (((*(fmbp+4) << 24) | (*(fmbp+5) << 16) | (*(fmbp+6) << 8)
								| (*(fmbp+7))) << sshift) | (*(fmbp+8) >> (8-sshift));
				if (mmc & sbit) {	// Multicolor mode
					uint32 plane0_l, plane0_r, plane1_l, plane1_r;
					
					// Expand sprite data
					sdata_l = MultiExpTable[sdata >> 24 & 0xff] << 16 | MultiExpTable[sdata >> 16 & 0xff];
					sdata_r = MultiExpTable[sdata >> 8 & 0xff] << 16;
					
					// Convert sprite chunky pixels to bitplanes
					plane0_l = (sdata_l & 0x55555555) | (sdata_l & 0x55555555) << 1;
					plane1_l = (sdata_l & 0xaaaaaaaa) | (sdata_l & 0xaaaaaaaa) >> 1;
					plane0_r = (sdata_r & 0x55555555) | (sdata_r & 0x55555555) << 1;
					plane1_r = (sdata_r & 0xaaaaaaaa) | (sdata_r & 0xaaaaaaaa) >> 1;
					
					// Collision with graphics?
					if ((fore_mask & (plane0_l | plane1_l)) || (fore_mask_r & (plane0_r | plane1_r))) {
						gfx_coll |= sbit;
						if (mdp & sbit)	{
							plane0_l &= ~fore_mask;	// Mask sprite if in background
							plane1_l &= ~fore_mask;
							plane0_r &= ~fore_mask_r;
							plane1_r &= ~fore_mask_r;
						}
					}
					
					// Paint sprite
					plane0_l<<=xstart; plane1_l<<=xstart;
					for (i=xstart; i<xstop1; i++, plane0_l<<=1, plane1_l<<=1) {
						if (plane1_l & 0x80000000) {
							if (plane0_l & 0x80000000)
								col = mm1;
							else
								col = color;
						} else {
							if (plane0_l & 0x80000000)
								col = mm0;
							else
								continue;
						}
						PUT_PIXEL();
					}
					if (xstart>32) {
						plane0_r<<=xstart-32;
						plane1_r<<=xstart-32;
					}
					for (; i<xstop; i++, plane0_r<<=1, plane1_r<<=1) {
						if (plane1_r & 0x80000000) {
							if (plane0_r & 0x80000000)
								col = mm1;
							else
								col = color;
						} else {
							if (plane0_r & 0x80000000)
								col = mm0;
							else
								continue;
						}
						PUT_PIXEL();
					}
					
				} else {			// Standard mode
					
					// Expand sprite data
					sdata_l = ((uint32)ExpTable[sdata >> 24 & 0xff]) << 16 | ExpTable[sdata >> 16 & 0xff];
					sdata_r = ((uint32)ExpTable[sdata >> 8 & 0xff]) << 16;
					// Collision with graphics?
					if ((fore_mask & sdata_l) || (fore_mask_r & sdata_r)) {
						gfx_coll |= sbit;
						if (mdp & sbit)	{
							sdata_l &= ~fore_mask;	// Mask sprite if in background
							sdata_r &= ~fore_mask_r;
						}
					}
					
					// Paint sprite
					col = color;
					sdata_l<<=xstart;
					for (i=xstart; i<xstop1; i++, sdata_l<<=1)
						if (sdata_l & 0x80000000) {
							PUT_PIXEL();
						}
					if (xstart>32)
						sdata_r<<=xstart-32;
					for (; i<xstop; i++, sdata_r<<=1)
						if (sdata_r & 0x80000000) {
							PUT_PIXEL();
						}
				}
				
			} else					// Unexpanded
				
				if (mmc & sbit) {	// Multicolor mode
					uint32 plane0, plane1;
					
					// Convert sprite chunky pixels to bitplanes
					plane0 = (sdata & 0x55555555) | (sdata & 0x55555555) << 1;
					plane1 = (sdata & 0xaaaaaaaa) | (sdata & 0xaaaaaaaa) >> 1;
					
					// Collision with graphics?
					if (fore_mask & (plane0 | plane1)) {
						gfx_coll |= sbit;
						if (mdp & sbit) {
							plane0 &= ~fore_mask;	// Mask sprite if in background
							plane1 &= ~fore_mask;
						}
					}
					
					// Paint sprite
					plane0<<=xstart; plane1<<=xstart;
					for (i=xstart; i<xstop; i++, plane0<<=1, plane1<<=1) {
						if (plane1 & 0x80000000) {
							if (plane0 & 0x80000000)
								col = mm1;
							else
								col = color;
						} else {
							if (plane0 & 0x80000000)
								col = mm0;
							else
								continue;
						}
						PUT_PIXEL();
					}
					
				} else {			// Standard mode
					
					// Collision with graphics?
					if (fore_mask & sdata) {
						gfx_coll |= sbit;
						if (mdp & sbit)
							sdata &= ~fore_mask;	// Mask sprite if in background
					}
					
					// Paint sprite
					col = color;
					sdata<<=xstart;
					for (i=xstart; i<xstop; i++, sdata<<=1)
						if (sdata & 0x80000000) {
							PUT_PIXEL();
						}
					
				}
		}
	
	//if (ThePrefs.SpriteCollisions) {
		
		// Check sprite-sprite collisions
		if (clx_spr)
			clx_spr |= spr_coll;
		else {
			clx_spr |= spr_coll;
			irq_flag |= 0x04;
			if (irq_mask & 0x04) {
				irq_flag |= 0x80;
				the_cpu->TriggerVICIRQ();
			}
		}
		
		// Check sprite-background collisions
		if (clx_bgr)
			clx_bgr |= gfx_coll;
		else {
			clx_bgr |= gfx_coll;
			irq_flag |= 0x02;
			if (irq_mask & 0x02) {
				irq_flag |= 0x80;
				the_cpu->TriggerVICIRQ();
			}
		}
	//}
}


inline int MOS6569::el_update_mc(int raster)
{
	int j;
	int cycles_used = 0;
	uint8 spron = sprite_on;
	uint8 spren = me;
	uint8 sprye = mye;
	uint8 raster8bit = raster;
	uint16 *mcp = mc;
	uint8 *myp = my;
	
	// Increment sprite data counters
	for (j=1; j != 0x100; j<<=1, mcp++, myp++) {
		
		// Sprite enabled?
		if (spren & j)
			
			// Yes, activate if Y position matches raster counter
			if (*myp == (raster8bit & 0xff)) {
				*mcp = 0;
				spron |= j;
			} else
				goto spr_off;
		else
			spr_off:
			// No, turn sprite off when data counter exceeds 60
			//  and increment counter
			if (*mcp != 63) {
				if (sprye & j) {	// Y expansion
					if (!((*myp ^ raster8bit) & 1)) {
						*mcp += 3;
						cycles_used += 2;
						if (*mcp == 63)
							spron &= ~j;
					}
				} else {
					*mcp += 3;
					cycles_used += 2;
					if (*mcp == 63)
						spron &= ~j;
				}
			}
	}
	
	sprite_on = spron;
	return cycles_used;
}


/*
 *  Emulate one raster line
 */

int MOS6569::EmulateLine(void)
{
	int cycles_left = 63;				// SGC: ThePrefs.NormalCycles;	// Cycles left for CPU
	bool skip_line = false;
	bool is_bad_line = false;
	
	// Get raster counter into local variable for faster access and increment
	uint32 raster = raster_y+1;
	
	// End of screen reached?
	if (raster != TOTAL_RASTERS)
		raster_y = raster;
	else {
		vblank();
		raster = 0;
	}
	
	// Trigger raster IRQ if IRQ line reached
	if (raster == irq_raster)
		raster_irq();
	
	// In line $30, the DEN bit controls if Bad Lines can occur
	if (raster == 0x30)
		bad_lines_enabled = ctrl1 & 0x10;
	
	// Skip frame? Only calculate Bad Lines then
	if (!prefs_border_on && (raster<ROW25_YSTART || raster>=ROW25_YSTOP))
		skip_line=true;
	if (frame_skipped || skip_line) {
		if (raster >= FIRST_DMA_LINE && raster <= LAST_DMA_LINE && ((raster & 7) == y_scroll) && bad_lines_enabled) {
			is_bad_line = true;
			cycles_left = 23;			// SGC: ThePrefs.BadLineCycles;
		}
		goto VIC_nop;
	}
		
	// Within the visible range?
	if (raster >= FIRST_DISP_LINE && raster <= LAST_DISP_LINE) {
		
		// Our output goes here
		uint8 *chunky_ptr = chunky_line_start;
		
		// Set video counter
		vc = vc_base;
		
		// Bad Line condition?
		if (raster >= FIRST_DMA_LINE && raster <= LAST_DMA_LINE && ((raster & 7) == y_scroll) && bad_lines_enabled) {
			
			// Turn on display
			display_state = is_bad_line = true;
			cycles_left = 23;			// SGC: ThePrefs.BadLineCycles;
			rc = 0;
			
			// Read and latch 40 bytes from video matrix and color RAM
			uint32 *mp = (uint32 *) matrix_line;
			uint32 *cp = (uint32 *) color_line;
			uint32 *mbp = (uint32 *) (matrix_base + vc);
			uint32 *crp = (uint32 *) (color_ram + vc);
			for (int i=0; i<10; i++) {
				*mp++ = *mbp++;
				*cp++ = *crp++ & 0x0f0f0f0f;
			}
		}
		
		// Handler upper/lower border
		if (raster == dy_stop)
			border_on = true;
		if (raster == dy_start && (ctrl1 & 0x10)) // Don't turn off border if DEN bit cleared
			border_on = false;
		
		if (!border_on)
		{
			// Draw line
			uint8 *p = chunky_ptr + COL40_XSTART + x_scroll; // Pointer in chunky display buffer
			uint8 *r = fore_mask_buf + (COL40_XSTART >> 3);
			
			if (display_state)
			{
				switch (display_idx) {
					case 0: // Standard text
						//if (x_scroll & 3) {
						//	el_std_text(text_chunky_buf, char_base + rc);
						//	memcpy(p, text_chunky_buf, 8*40);             
						//} else
							el_std_text(p, char_base + rc);
						if(sprite_on)
							el_std_text_spr(char_base + rc, r);
						break;
						
					case 1: // Multicolor text
						if (x_scroll & 3) {
							el_mc_text(text_chunky_buf, char_base + rc);
							memcpy(p, text_chunky_buf, 8*40);
						} else
							el_mc_text(p, char_base + rc);
						if(sprite_on)
							el_mc_text_spr(char_base + rc, r);
						break;
						
					case 2: // Standard bitmap
						if (x_scroll & 3) {
							el_std_bitmap(text_chunky_buf, bitmap_base + (vc << 3) + rc);
							memcpy(p, text_chunky_buf, 8*40);             
						} else
							el_std_bitmap(p, bitmap_base + (vc << 3) + rc);
						if(sprite_on)
							el_std_bitmap_spr(bitmap_base + (vc << 3) + rc, r);
						break;
						
					case 3: // Multicolor bitmap
						if (x_scroll & 3) {
							el_mc_bitmap(text_chunky_buf, bitmap_base + (vc << 3) + rc);
							memcpy(p, text_chunky_buf, 8*40);             
						} else
							el_mc_bitmap(p, bitmap_base + (vc << 3) + rc);
						if(sprite_on)
							el_mc_bitmap_spr(bitmap_base + (vc << 3) + rc, r);
						break;
						
					case 4: // ECM text
						//if (x_scroll & 3) {
						//	el_ecm_text(text_chunky_buf, char_base + rc);
						//	memcpy(p, text_chunky_buf, 8*40);             
						//} else
							el_ecm_text(p, char_base + rc);
						if(sprite_on)
							el_ecm_text_spr(char_base + rc, r);
						break;
						
					default: // Invalid mode (all black)
						memset(p, 0, 320);
						if(sprite_on)
							memset(r, 0, 40);
						break;
				}
	 			
	 			vc += 40;
			} // if (display_state)
			else
			{ // Idle state graphics
				switch (display_idx) {
						
					case 0:  // Standard text
					case 1:  // Multicolor text
					case 4:  // ECM text
						if (x_scroll & 3) {
							el_std_idle(text_chunky_buf);
							memcpy(p, text_chunky_buf, 8*40);             
						} else
							el_std_idle(p);
						if(sprite_on)
							el_std_idle_spr(r);
						break;
						
					case 3:  // Multicolor bitmap
						if (x_scroll & 3) {
							el_mc_idle(text_chunky_buf);
							memcpy(p, text_chunky_buf, 8*40);             
						} else
							el_mc_idle(p);
						if(sprite_on)
							el_mc_idle_spr(r);
						break;
						
					default: // Invalid mode (all black)
						memset(p, 0, 320);
						if(sprite_on)
							memset(r, 0, 40);
						break;
				}
			} // if (display_state)
			
			// Draw sprites
			if (sprite_on /* SGC: && ThePrefs.SpritesOn */) {
				memset(spr_coll_buf, 0x0, sizeof(spr_coll_buf));
				el_sprites(chunky_ptr);
			}
			
			// Handle left/right border
			if (!border_40_col) {
				int limit = (COL38_XSTART & 0xfc)>>2;
				uint32 *p_long = (uint32*)chunky_ptr;
				uint32 l_ec_color_long = ec_color_long;
				do {
					*p_long++ = l_ec_color_long;
				} while (--limit);
				
				p = (uint8*)p_long;
				*p++ = ec;
				*p++ = ec;
				*p++ = ec;
				
				p_long = (uint32*)(chunky_ptr + COL38_XSTOP);
				limit = ((DISPLAY_X - COL38_XSTOP) & 0xfc)>>2;
				do {
					*p_long++ = l_ec_color_long;
				} while (--limit);
				
				p = (uint8*)p_long;
				*p++ = ec;
				*p++ = ec;
				*p++ = ec;
			}
			// SGC: Optimization, since we don't show borders
			/*
			else {
				int limit = COL40_XSTART >> 2;
				uint32 *p_long = (uint32*)chunky_ptr;
				do {
					*p_long++ = ec_color_long;
				} while (--limit);
				
				p_long = (uint32*)(chunky_ptr + COL40_XSTOP);
				limit = (DISPLAY_X - COL40_XSTOP) >> 2;
				
				do {
					*p_long++ = ec_color_long;
				} while (--limit);
			}
			*/
			
			
			/*
			// Handle left/right border
			p = chunky_ptr;
			int16 limit = COL40_XSTART;
			
			if (!border_40_col)
				limit = COL38_XSTART;
			
			for (int i=0; i < limit; i++)
				*p++ = ec;
						
			if (!border_40_col) {
				p = chunky_ptr + COL38_XSTOP;
				limit = DISPLAY_X - COL38_XSTOP;
			} else {
				p = chunky_ptr + COL40_XSTOP;
				limit = DISPLAY_X - COL40_XSTOP;
			}
			
			for (int i=0; i < limit; i++)
				*p++ = ec;
			*/
		} else {
			
			// Display border
			memset(chunky_ptr, ec, DISPLAY_X);
		}
		
		// Increment pointer in chunky buffer
		chunky_line_start += xmod;
		
		// Increment row counter, go to idle state on overflow
		if (rc == 7) {
			display_state = false;
			vc_base = vc;
		} else
			rc++;
		
		if (raster >= FIRST_DMA_LINE-1 && raster <= LAST_DMA_LINE-1 && (((raster+1) & 7) == y_scroll) && bad_lines_enabled)
			rc = 0;
	}
	
VIC_nop:
	// Skip this if all sprites are off
	if (me | sprite_on)
		cycles_left -= el_update_mc(raster);
	
	return cycles_left;
}
