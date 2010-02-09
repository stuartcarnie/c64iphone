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
 *  VIC.h - 6569R5 emulation (line based)
 *
 *  Frodo (C) 1994-1997,2002 Christian Bauer
 */

#ifndef _VIC_H
#define _VIC_H


// Define this if you want global variables instead of member variables
extern "C" {
	//void draw_border(void *, uint32);
	//void memset8(void*, uint32);
}

#define draw_border(ptr, val) { *(uint32*)ptr = (uint32)val; *((uint32*)ptr+1) = (uint32)val; }


// Total number of raster lines (PAL)
const unsigned TOTAL_RASTERS = 0x138;

// Screen refresh frequency (PAL)
const unsigned SCREEN_FREQ = 50;


class MOS6510;
class C64Display;
class C64;
struct MOS6569State;
class Prefs;


class MOS6569 {
public:
	MOS6569(C64 *c64, C64Display *disp, MOS6510 *CPU, uint8 *RAM, uint8 *Char, uint8 *Color);

	uint8 ReadRegister(uint16 adr);
	void WriteRegister(uint16 adr, uint8 byte);
#if SINGLE_CYCLE
	void WriteRegisterSC(uint16 adr, uint8 byte);
	void EmulateLineSC(void);
#endif
	int EmulateLine(void);
	void NewPrefs(Prefs *newPrefs);
	void ChangedVA(uint16 new_va);	// CIA VA14/15 has changed
	void TriggerLightpen(void);		// Trigger lightpen interrupt
	void GetState(MOS6569State *vd);
	void SetState(MOS6569State *vd);
	void SwitchToSC(void);
	void SwitchToStandard(void);

private:
	void vblank(void);
	void raster_irq(void);

	uint16 mx[8];				// VIC registers
	uint8 my[8];
	uint8 mx8;
	uint8 ctrl1, ctrl2;
	uint8 lpx, lpy;
	uint8 me, mxe, mye, mdp, mmc;
	uint8 vbase;
	uint8 irq_flag, irq_mask;
	uint8 clx_spr, clx_bgr;
	uint8 ec, b0c, b1c, b2c, b3c, mm0, mm1;
	uint8 sc[8];

	uint8 *ram, *char_rom, *color_ram; // Pointers to RAM and ROM
	C64 *the_c64;				// Pointer to C64
	C64Display *the_display;	// Pointer to C64Display
	MOS6510 *the_cpu;			// Pointer to 6510

	uint8 ec_color, b0c_color, b1c_color,
	      b2c_color, b3c_color;	// Indices for exterior/background colors
	uint8 mm0_color, mm1_color;	// Indices for MOB multicolors
	uint8 spr_color[8];			// Indices for MOB colors

	uint32 ec_color_long;		// ec_color expanded to 32 bits

	uint8 matrix_line[40];		// Buffer for video line, read in Bad Lines
	uint8 color_line[40];		// Buffer for color line, read in Bad Lines

	uint8 *chunky_line_start;	// Pointer to start of current line in bitmap buffer
	int xmod;					// Number of bytes per row

	uint16 raster_y;				// Current raster line
	uint16 irq_raster;			// Interrupt raster line
	uint16 dy_start;				// Comparison values for border logic
	uint16 dy_stop;
	uint16 rc;					// Row counter
	uint16 vc;					// Video counter
	uint16 vc_base;				// Video counter base
	uint16 x_scroll;				// X scroll value
	uint16 y_scroll;				// Y scroll value
	uint16 cia_vabase;			// CIA VA14/15 video base

	uint16 mc[8];				// Sprite data counters

	int display_idx;			// Index of current display mode
	int skip_counter;			// Counter for frame-skipping

	long pad0;	// Keep buffers long-aligned
	uint8 spr_coll_buf[0x180];	// Buffer for sprite-sprite collisions and priorities
	uint8 fore_mask_buf[0x180/8];	// Foreground mask for sprite-graphics collisions and priorities
	uint8 text_chunky_buf[40*8];	// Line graphics buffer

	bool display_state;			// true: Display state, false: Idle state
	bool border_on;				// Flag: Upper/lower border on (Frodo SC: Main border flipflop)
	bool frame_skipped;			// Flag: Frame is being skipped
	uint8 bad_lines_enabled;	// Flag: Bad Lines enabled for this frame
	bool lp_triggered;			// Flag: Lightpen was triggered in this frame

  // Only used in single cycle emulation (start)
	void matrix_access(void);
	uint32 graphics_access_ds(void);
	void draw_graphics(uint32 gfxcharcolor);
	void draw_sprites(void);
	void SprDataAccess23(uint8 spr_dma_on, uint8 num);
  
	uint16 cycle;					// Current cycle in line (1..63)

	uint8 *chunky_ptr;			// Pointer in chunky bitmap buffer (this is where out output goes)
	uint8 *fore_mask_ptr;		// Pointer in fore_mask_buf

	uint16 matrix_baseSC;			// Video matrix base
	uint16 char_baseSC;			// Character generator base
	uint16 bitmap_baseSC;			// Bitmap base
	uint8 *mem_ptr[4];
	void init_mem_ptr(void);

	bool is_bad_line;			// Flag: Current line is bad line
	bool draw_this_line;		// Flag: This line is drawn on the screen
	bool ud_border_on;			// Flag: Upper/lower border on
	bool vblanking;				// Flag: VBlank in next cycle
	bool prefs_border_on;		// Flag: Stores ThePrefs.BordersOn
	
	uint8 spr_exp_y;			// 8 sprite y expansion flipflops
	uint8 spr_dma_on;			// 8 flags: Sprite DMA active
	uint8 spr_disp_on;			// 8 flags: Sprite display active
	uint16 spr_ptr[8];			// Sprite data pointers
	uint16 mc_base[8];			// Sprite data counter bases

	uint16 raster_x;			// Current raster x position

	uint16 ml_index;				// Index in matrix/color_line[]
	uint8 spr_data[8][4];		// Sprite data read

	bool BALow;
	uint32 first_ba_cycle;		// Cycle when BA first went low
	// Only used in single cycle emulation (end)

	// Only used in standard emulation (start)
	uint8 *get_physical(uint16 adr);
	void make_mc_table(void);

	void el_std_text(uint8 *p, uint8 *q);
	void el_std_text_spr(uint8 *q, uint8 *r);
	void el_mc_text(uint8 *p, uint8 *q);
	void el_mc_text_spr(uint8 *q, uint8 *r);
	void el_std_bitmap(uint8 *p, uint8 *q);
	void el_std_bitmap_spr(uint8 *q, uint8 *r);
	void el_mc_bitmap(uint8 *p, uint8 *q);
	void el_mc_bitmap_spr(uint8 *q, uint8 *r);
	void el_ecm_text(uint8 *p, uint8 *q);
	void el_ecm_text_spr(uint8 *q, uint8 *r);
	void el_std_idle(uint8 *p);
	void el_std_idle_spr(uint8 *r);
	void el_mc_idle(uint8 *p);
	void el_mc_idle_spr(uint8 *r);

	void el_sprites(uint8 *chunky_ptr);
	int el_update_mc(int raster);

	uint16 mc_color_lookup[4];

	bool border_40_col;			// Flag: 40 column border
	uint8 sprite_on;			// 8 flags: Sprite display/DMA active

	uint8 *matrix_base;			// Video matrix base
	uint8 *char_base;			// Character generator base
	uint8 *bitmap_base;			// Bitmap base
	// Only used in standard emulation (end)

};

/*
 *  Read from VIC register
 */

inline uint8 MOS6569::ReadRegister(uint16 adr)
{
	switch (adr) {
		case 0x00: case 0x02: case 0x04: case 0x06:
		case 0x08: case 0x0a: case 0x0c: case 0x0e:
			return mx[adr >> 1];
			
		case 0x01: case 0x03: case 0x05: case 0x07:
		case 0x09: case 0x0b: case 0x0d: case 0x0f:
			return my[adr >> 1];
			
		case 0x10:	// Sprite X position MSB
			return mx8;
			
		case 0x11:	// Control register 1
			return (ctrl1 & 0x7f) | ((raster_y & 0x100) >> 1);
			
		case 0x12:	// Raster counter
			return raster_y;
			
		case 0x13:	// Light pen X
			return lpx;
			
		case 0x14:	// Light pen Y
			return lpy;
			
		case 0x15:	// Sprite enable
			return me;
			
		case 0x16:	// Control register 2
			return ctrl2 | 0xc0;
			
		case 0x17:	// Sprite Y expansion
			return mye;
			
		case 0x18:	// Memory pointers
			return vbase | 0x01;
			
		case 0x19:	// IRQ flags
			return irq_flag | 0x70;
			
		case 0x1a:	// IRQ mask
			return irq_mask | 0xf0;
			
		case 0x1b:	// Sprite data priority
			return mdp;
			
		case 0x1c:	// Sprite multicolor
			return mmc;
			
		case 0x1d:	// Sprite X expansion
			return mxe;
			
		case 0x1e:{	// Sprite-sprite collision
			uint8 ret = clx_spr;
			clx_spr = 0;	// Read and clear
			return ret;
		}
			
		case 0x1f:{	// Sprite-background collision
			uint8 ret = clx_bgr;
			clx_bgr = 0;	// Read and clear
			return ret;
		}
			
		case 0x20: return ec | 0xf0;
		case 0x21: return b0c | 0xf0;
		case 0x22: return b1c | 0xf0;
		case 0x23: return b2c | 0xf0;
		case 0x24: return b3c | 0xf0;
		case 0x25: return mm0 | 0xf0;
		case 0x26: return mm1 | 0xf0;
			
		case 0x27: case 0x28: case 0x29: case 0x2a:
		case 0x2b: case 0x2c: case 0x2d: case 0x2e:
			return sc[adr - 0x27] | 0xf0;
			
		default:
			return 0xff;
	}
}



// VIC state
struct MOS6569State {
	uint16 m0x;				// Sprite coordinates
	uint16 m1x;
	uint16 m2x;
	uint16 m3x;
	uint16 m4x;
	uint16 m5x;
	uint16 m6x;
	uint16 m7x;
	uint8 m0y;
	uint8 m1y;
	uint8 m2y;
	uint8 m3y;
	uint8 m4y;
	uint8 m5y;
	uint8 m6y;
	uint8 m7y;
	uint8 mx8;

	uint8 ctrl1;			// Control registers
	uint16 raster_y;
	uint8 lpx;
	uint8 lpy;
	uint8 me;
	uint8 ctrl2;
	uint8 mye;
	uint8 vbase;
	uint8 irq_flag;
	uint8 irq_mask;
	uint8 mdp;
	uint8 mmc;
	uint8 mxe;
	uint8 clx_spr;
	uint8 clx_bgr;

	uint8 ec;				// Color registers
	uint8 b0c;
	uint8 b1c;
	uint8 b2c;
	uint8 b3c;
	uint8 mm0;
	uint8 mm1;
	uint8 m0c;
	uint8 m1c;
	uint8 m2c;
	uint8 m3c;
	uint8 m4c;
	uint8 m5c;
	uint8 m6c;
	uint8 m7c;
							// Additional registers
	uint8 pad0;
	uint16 irq_raster;		// IRQ raster line
	uint16 vc;				// Video counter
	uint16 vc_base;			// Video counter base
	uint16 rc;				// Row counter
	uint8 spr_dma;			// 8 Flags: Sprite DMA active
	uint8 spr_disp;			// 8 Flags: Sprite display active
	uint16 mc[8];			// Sprite data counters
	uint16 mc_base[8];		// Sprite data counter bases
	bool display_state;		// true: Display state, false: Idle state
	bool bad_line;			// Flag: Bad Line state
	uint8 bad_line_enable;	// Flag: Bad Lines enabled for this frame
	bool lp_triggered;		// Flag: Lightpen was triggered in this frame
	bool border_on;			// Flag: Upper/lower border on (Frodo SC: Main border flipflop)
  bool frame_skipped;
  bool draw_this_line;
  
	uint16 bank_base;		// VIC bank base address
	uint16 matrix_base;		// Video matrix base
	uint16 char_base;		// Character generator base
	uint16 bitmap_base;		// Bitmap base

  // Only used in FRODO_SC:
  uint8 spr_exp_y;
	uint32 first_ba_cycle;
	uint16 sprite_base[8];	// Sprite bases
	uint16 cycle;				// Current cycle in line (1..63)
	uint16 raster_x;		// Current raster x position
	uint16 ml_index;			// Index in matrix/color_line[]
	bool ud_border_on;		// Flag: Upper/lower border on
};

struct MOS6569StateOld {
	uint8 m0x;				// Sprite coordinates
	uint8 m0y;
	uint8 m1x;
	uint8 m1y;
	uint8 m2x;
	uint8 m2y;
	uint8 m3x;
	uint8 m3y;
	uint8 m4x;
	uint8 m4y;
	uint8 m5x;
	uint8 m5y;
	uint8 m6x;
	uint8 m6y;
	uint8 m7x;
	uint8 m7y;
	uint8 mx8;

	uint8 ctrl1;			// Control registers
	uint8 raster;
	uint8 lpx;
	uint8 lpy;
	uint8 me;
	uint8 ctrl2;
	uint8 mye;
	uint8 vbase;
	uint8 irq_flag;
	uint8 irq_mask;
	uint8 mdp;
	uint8 mmc;
	uint8 mxe;
	uint8 mm;
	uint8 md;

	uint8 ec;				// Color registers
	uint8 b0c;
	uint8 b1c;
	uint8 b2c;
	uint8 b3c;
	uint8 mm0;
	uint8 mm1;
	uint8 m0c;
	uint8 m1c;
	uint8 m2c;
	uint8 m3c;
	uint8 m4c;
	uint8 m5c;
	uint8 m6c;
	uint8 m7c;
							// Additional registers
	uint16 irq_raster;		// IRQ raster line
	uint16 vc;				// Video counter
	uint16 vc_base;			// Video counter base
	uint8 rc;				// Row counter
	uint8 spr_dma;			// 8 Flags: Sprite DMA active
	uint8 spr_disp;			// 8 Flags: Sprite display active
	uint8 mc[8];			// Sprite data counters
	uint8 mc_base[8];		// Sprite data counter bases
	bool display_state;		// true: Display state, false: Idle state
	bool bad_line;			// Flag: Bad Line state
	bool bad_line_enable;	// Flag: Bad Lines enabled for this frame
	bool lp_triggered;		// Flag: Lightpen was triggered in this frame
	bool border_on;			// Flag: Upper/lower border on (Frodo SC: Main border flipflop)
  bool frame_skipped;
  
	uint16 bank_base;		// VIC bank base address
	uint16 matrix_base;		// Video matrix base
	uint16 char_base;		// Character generator base
	uint16 bitmap_base;		// Bitmap base
};

#endif
