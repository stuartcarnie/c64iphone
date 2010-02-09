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
 *  CPUC64.cpp - 6510 (C64) emulation (line based)
 *
 *  Frodo (C) 1994-1997,2002 Christian Bauer
 *
 *
 * Notes:
 * ------
 *
 *  - The EmulateLine() function is called for every emulated
 *    raster line. It has a cycle counter that is decremented
 *    by every executed opcode and if the counter goes below
 *    zero, the function returns.
 *  - Memory configurations:
 *     $01  $a000-$bfff  $d000-$dfff  $e000-$ffff
 *     -----------------------------------------------
 *      0       RAM          RAM          RAM
 *      1       RAM       Char ROM        RAM
 *      2       RAM       Char ROM    Kernal ROM
 *      3    Basic ROM    Char ROM    Kernal ROM
 *      4       RAM          RAM          RAM
 *      5       RAM          I/O          RAM
 *      6       RAM          I/O      Kernal ROM
 *      7    Basic ROM       I/O      Kernal ROM
 *  - All memory accesses are done with the read_byte() and
 *    write_byte() functions which also do the memory address
 *    decoding. The read_zp() and write_zp() functions allow
 *    faster access to the zero page, the pop_byte() and
 *    push_byte() macros for the stack.
 *  - If a write occurs to addresses 0 or 1, new_config is
 *    called to check whether the memory configuration has
 *    changed
 *  - The PC is either emulated with a 16 bit address or a
 *    direct memory pointer (for faster access), depending on
 *    the PC_IS_POINTER #define. In the latter case, a second
 *    pointer, pc_base, is kept to allow recalculating the
 *    16 bit 6510 PC if it has to be pushed on the stack.
 *  - The possible interrupt sources are:
 *      INT_VICIRQ: I flag is checked, jump to ($fffe)
 *      INT_CIAIRQ: I flag is checked, jump to ($fffe)
 *      INT_NMI: Jump to ($fffa)
 *      INT_RESET: Jump to ($fffc)
 *  - Interrupts are not checked before every opcode but only
 *    at certain times:
 *      On entering EmulateLine()
 *      On CLI
 *      On PLP if the I flag was cleared
 *      On RTI if the I flag was cleared
 *  - The z_flag variable has the inverse meaning of the
 *    6510 Z flag
 *  - Only the highest bit of the n_flag variable is used
 *  - The $f2 opcode that would normally crash the 6510 is
 *    used to implement emulator-specific functions, mainly
 *    those for the IEC routines
 *
 * Incompatibilities:
 * ------------------
 *
 *  - If PC_IS_POINTER is set, neither branches accross memory
 *    areas nor jumps to I/O space are possible
 *  - Extra cycles for crossing page boundaries are not
 *    accounted for
 *  - The cassette sense line is always closed
 */

#include "sysdeps.h"

#include "CPUC64.h"
#include "CPU_common.h"
#include "C64.h"
#include "VIC.h"
#include "SID.h"
#include "CIA.h"
#include "IEC.h"
#include "Display.h"
#include "Version.h"
#include "CPU1541.h"


enum {
	INT_RESET = 3
};

/*
 *  6510 constructor: Initialize registers
 */

MOS6510::MOS6510(C64 *c64, uint8 *Ram, uint8 *Basic, uint8 *Kernal, uint8 *Char, uint8 *Color, uint8 *IO_Ram)
 : the_c64(c64), ram(Ram), basic_rom(Basic), kernal_rom(Kernal), char_rom(Char), color_ram(Color), io_ram(IO_Ram), halt(false)
{
	first_trap = NULL;
	
	a = x = y = 0;
	sp = 0xff;
	n_flag = z_flag = 0;
	v_flag = d_flag = c_flag = false;
	i_flag = true;
	dfff_byte = 0x55;

	first_irq_cycle = first_nmi_cycle = 0;

	borrowed_cycles = 0;

  for(int i=0; i<16; ++i)
    mem_ptr[i] = ram + (i << 12);
}


/*
 *  Switch from standard emulation to single cycle emulation
 */
void MOS6510::SwitchToSC(void)
{
  pcSC = pc - pc_base;
  first_irq_cycle = 0;
  first_nmi_cycle = 0;
  state = 0;
  ddr = ram[0];
  pr = ram[1];
	ram[1] = (ddr & pr) | (~ddr & 0x17);
}


/*
 *  Switch from single cycle emulation to standard emulation
 */
void MOS6510::SwitchToStandard(void)
{
#if SINGLE_CYCLE
  borrowed_cycles = 0;
  while(state)
  {
    EmulateCycle(false);
    ++borrowed_cycles;
  }
  jump(pcSC);
  ram[0] = ddr;
  ram[1] = pr;
#endif
}


/*
 *  Reset CPU asynchronously
 */
void MOS6510::ClearIRQ(void)
{
	// Clear all interrupt lines
	interrupt.intr_any = 0;
}

void MOS6510::AsyncReset(void)
{
	interrupt.intr[INT_RESET] = true;
}


/*
 *  Raise NMI asynchronously (Restore key)
 */

void MOS6510::AsyncNMI(void)
{
	if (!nmi_state)
		interrupt.intr[INT_NMI] = true;
}

#pragma mark Trap Handling

void MOS6510::ClearTraps() {
	for(trap_t *trap = first_trap; trap; trap = trap->next_trap) {
		poke(trap->addr, trap->org[0], trap->forceRam);
		if (trap->trap_release)
			trap->trap_release(trap);
	}
	first_trap = NULL;
}

int MOS6510::InstallTrap(trap_t *trap) {
	/*
	for(int i = sizeof(trap->org) / sizeof(trap->org[0]); i-- > 0;) {
		
		if(peek(trap->addr + i) != trap->org[i])
			return -1;
	}
	 */
#if !defined(_DISTRIBUTION)
	printf("WARNING: disabled check in InstallTrap and added following line\n");
#endif
	
	poke(trap->addr, 0x00, trap->forceRam);
	trap->next_trap = first_trap;
	first_trap = trap;
	return 0;
}

/*
 * Trap handlers, which are checked when a BRK instruction is executed
 * Currently only implemented for line-base CPU emulation
 */

trap_result2_t* MOS6510::trap(void) {
	static trap_result2_t result;
	int currentPC = (pc - pc_base) - 1;
	for(trap_t *trap = first_trap; trap != NULL; trap = trap->next_trap) {
		if(trap->addr == currentPC) {
			result.result = trap->handler(this, trap->data);
			result.trap = trap;
			return &result;
		}
	}
	
	result.result = TRAP_DO_BREAK;
	return &result;
}

uint8 MOS6510::peek(uint16 adr, bool forceram)
{
	if (adr < 0xa000 || forceram)
		return ram[adr];
	else
		switch (adr >> 12) {
			case 0xa:
			case 0xb:
				return basic_rom[adr & 0x1fff];
			case 0xc:
				return ram[adr];
			case 0xd:
				return char_rom[adr & 0x0fff];
			case 0xe:
			case 0xf:
				return kernal_rom[adr & 0x1fff];
			default:	// Can't happen
				return 0;
		}
}

void MOS6510::poke(uint16 adr, uint8 byte, bool forceram) {
	if (adr < 0xa000 || forceram)
		ram[adr] = byte;
	else
		switch (adr >> 12) {
			case 0xa:
			case 0xb:
				basic_rom[adr & 0x1fff] = byte;
			case 0xc:
				ram[adr] = byte;
			case 0xd:
				ram[adr] = byte;
			case 0xe:
			case 0xf:
				kernal_rom[adr & 0x1fff] = byte;
		}
}


/*
 *  Get 6510 register state
 */

void MOS6510::GetState(MOS6510State *s)
{
	s->a = a;
	s->x = x;
	s->y = y;

	s->p = 0x20 | (n_flag & 0x80);
	if (v_flag) s->p |= 0x40;
	if (d_flag) s->p |= 0x08;
	if (i_flag) s->p |= 0x04;
	if (!z_flag) s->p |= 0x02;
	if (c_flag) s->p |= 0x01;
	
  if(ThePrefs.SingleCycleEmulation)
  {
  	s->ddr = ddr;
  	s->pr = pr;
  }
  else
  {
  	s->ddr = ram[0];
  	s->pr = ram[1];// & 0x3f;
  }

  s->ar = ar;
  s->ar2 = ar2;
  s->state = state;
  s->op = op;
  s->rdbuf = rdbuf;

  s->basic_in = basic_in;
  s->kernal_in = kernal_in;
  s->char_in = char_in;
  s->io_in = io_in;

  if(ThePrefs.SingleCycleEmulation)
	  s->pc = pcSC;
  else
	  s->pc = pc - pc_base;

	s->sp = sp | 0x0100;

	s->intr[INT_VICIRQ] = interrupt.intr[INT_VICIRQ];
	s->intr[INT_CIAIRQ] = interrupt.intr[INT_CIAIRQ];
	s->intr[INT_NMI] = interrupt.intr[INT_NMI];
	s->intr[INT_RESET] = interrupt.intr[INT_RESET];
	s->nmi_state = nmi_state;
	s->dfff_byte = dfff_byte;
}


/*
 *  Restore 6510 state
 */

void MOS6510::SetState(MOS6510State *s)
{
	a = s->a;
	x = s->x;
	y = s->y;
	
	n_flag = s->p & 0x80;
	v_flag = s->p & 0x40;
	d_flag = s->p & 0x08;
	i_flag = s->p & 0x04;
	z_flag = !(s->p & 0x02);
	c_flag = s->p & 0x01;
	
	if(ThePrefs.SingleCycleEmulation)
	{
		ddr = s->ddr;
		pr = s->pr;
	}
	else
	{
		ram[0] = s->ddr;
		ram[1] = s->pr;
	}
	new_config();
	ar = s->ar;
	ar2 = s->ar2;
	state = s->state;
	op = s->op;
	rdbuf = s->rdbuf;
	
	basic_in = s->basic_in;
	kernal_in = s->kernal_in;
	char_in = s->char_in;
	io_in = s->io_in;
	
	if(ThePrefs.SingleCycleEmulation)
		pcSC = s->pc;
	else {
		jump(s->pc);
	}
    
	sp = s->sp & 0xff;
	
	interrupt.intr[INT_VICIRQ] = s->intr[INT_VICIRQ];
	interrupt.intr[INT_CIAIRQ] = s->intr[INT_CIAIRQ];
	interrupt.intr[INT_NMI] = s->intr[INT_NMI];
	interrupt.intr[INT_RESET] = s->intr[INT_RESET];
	nmi_state = s->nmi_state;
	dfff_byte = s->dfff_byte;
}


/*
 *  Memory configuration has probably changed
 */

void MOS6510::new_config(void)
{
	uint8 port;
	if(ThePrefs.SingleCycleEmulation)
		port = ~ddr | pr;
	else
		port = ~ram[0] | ram[1];
	
	basic_in = (port & 3) == 3;
	kernal_in = port & 2;
	char_in = (port & 3) && !(port & 4);
	io_in = (port & 3) && (port & 4);
	
	mem_ptr[0xa] = basic_in ? basic_rom : ram + 0xa000;
	mem_ptr[0xb] = basic_in ? basic_rom + 0x1000 : ram + 0xb000;
	mem_ptr[0xd] = char_in ? char_rom : ram + 0xd000;
	mem_ptr[0xe] = kernal_in ? kernal_rom : ram + 0xe000;
	mem_ptr[0xf] = kernal_in ? kernal_rom + 0x1000 : ram + 0xf000;
}


/*
 *  Read a byte from the CPU's address space
 */

uint8 MOS6510::read_byte(uint16 adr)
{
	if (adr < 0xa000)
		return ram[adr];
	else
  	switch (adr >> 12) {
  		case 0xa:
  		case 0xb:
  			if (basic_in)
  				return basic_rom[adr & 0x1fff];
  			else
  				return ram[adr];
  		case 0xc:
  			return ram[adr];
  		case 0xd:
  			if (io_in)
  				switch ((adr >> 8) & 0x0f) {
  					case 0x0:	// VIC
  					case 0x1:
  					case 0x2:
  					case 0x3:
  						return TheVIC->ReadRegister(adr & 0x3f);
  					case 0x4:	// SID
  					case 0x5:
  					case 0x6:
  					case 0x7:
  						return TheSID->ReadRegister(adr & 0x1f);
  					case 0x8:	// Color RAM
  					case 0x9:
  					case 0xa:
  					case 0xb:
						  return color_ram[adr & 0x03ff] & 0x0f | the_c64->Random() & 0xf0;
  					case 0xc:	// CIA 1
  						return TheCIA1->ReadRegister(adr & 0x0f);
  					case 0xd:	// CIA 2
  						return TheCIA2->ReadRegister(adr & 0x0f);
  					case 0xe:	// REU/Open I/O
  					case 0xf:
  						if (adr < 0xdfff)
  							return the_c64->Random();
  						else
  						{
          			dfff_byte = ~dfff_byte;
          			return dfff_byte;
              }
  				}
  			else if (char_in)
  				return char_rom[adr & 0x0fff];
  			else
  				return ram[adr];
  		case 0xe:
  		case 0xf:
  			if (kernal_in)
  				return kernal_rom[adr & 0x1fff];
  			else
  				return ram[adr];
  		default:	// Can't happen
  			return 0;
  	}
}


uint8 MOS6510::read_byte_io(uint16 adr)
{
	switch ((adr >> 8) & 0x0f) {
		case 0x0:	// VIC
		case 0x1:
		case 0x2:
		case 0x3:
			return TheVIC->ReadRegister(adr & 0x3f);
		case 0x4:	// SID
		case 0x5:
		case 0x6:
		case 0x7:
			return TheSID->ReadRegister(adr & 0x1f);
		case 0x8:	// Color RAM
		case 0x9:
		case 0xa:
		case 0xb:
		  return color_ram[adr & 0x03ff] & 0x0f | the_c64->Random() & 0xf0;
		case 0xc:	// CIA 1
			return TheCIA1->ReadRegister(adr & 0x0f);
		case 0xd:	// CIA 2
			return TheCIA2->ReadRegister(adr & 0x0f);
		case 0xe:	// REU/Open I/O
		case 0xf:
			if (adr < 0xdfff)
				return the_c64->Random();
			else
			{
  			dfff_byte = ~dfff_byte;
  			return dfff_byte;
      }
	}
	return 0; // Keep the compiler happy
}


/*
 *  Read a word (little-endian) from the CPU's address space
 */

uint16 MOS6510::read_word(uint16 adr)
{
	return read_byte(adr) | (read_byte(adr+1) << 8);
}


/*
 *  Reset CPU
 */

void MOS6510::Reset(void)
{
	// Delete 'CBM80' if present
	if (ram[0x8004] == 0xc3 && ram[0x8005] == 0xc2 && ram[0x8006] == 0xcd
	 && ram[0x8007] == 0x38 && ram[0x8008] == 0x30)
		ram[0x8004] = 0;

	// Initialize extra 6510 registers and memory configuration
	ddr = pr = 0;
	ram[0] = ram[1] = 0;
	new_config();

	// Clear all interrupt lines
	interrupt.intr_any = 0;
	nmi_state = false;

	// Read reset vector
  if(ThePrefs.SingleCycleEmulation)
  {
  	pcSC = read_word(0xfffc);
  	state = 0;
  }
  else
  {
  	jump(read_word(0xfffc));
  }
}


/*
 *  Illegal opcode encountered
 */

void MOS6510::illegal_op(uint8 op, uint16 at)
{
	char illop_msg[80];
	
	sprintf(illop_msg, "6510: Illegal opcode %02x at %04x.", op, at);
	if (ShowRequester(illop_msg, "Reset 6510", "Reset C64"))
		the_c64->ResetAndAutoboot();
	Reset();
}


//************************************************************
// Start of normal emulation (no single cycle)
//************************************************************

/*
 *  Write a byte to the CPU's address space
 */
void MOS6510::write_byte(uint16 adr, uint8 byte)
{
	if (adr < 0xd000 || !io_in || adr >= 0xe000) {
		ram[adr] = byte;
		if (adr < 2)
			new_config();
	} else  {
		io_ram[adr & 0x0fff] = byte;		
		switch ((adr >> 8) & 0x0f) {
			case 0x0:	// VIC
			case 0x1:
			case 0x2:
			case 0x3:
				TheVIC->WriteRegister(adr & 0x3f, byte);
				return;
			case 0x4:	// SID
			case 0x5:
			case 0x6:
			case 0x7:
				TheSID->WriteRegister(adr & 0x1f, byte);
				return;
			case 0x8:	// Color RAM
			case 0x9:
			case 0xa:
			case 0xb:
				color_ram[adr & 0x03ff] = byte & 0x0f;
				return;
			case 0xc:	// CIA 1
				TheCIA1->WriteRegister(adr & 0x0f, byte);
				return;
			case 0xd:	// CIA 2
				TheCIA2->WriteRegister(adr & 0x0f, byte);
				return;
			case 0xe:	// REU/Open I/O
			case 0xf:
				return;
		}
	}
}

/*
 *  Read a byte from the zeropage
 */
#define read_zp(adr) ram[adr]

/*
 *  Read a word (little-endian) from the zeropage
 */
inline uint16 MOS6510::read_zp_word(uint16 adr)
{
	// !! zeropage word addressing wraps around !!
	return ram[adr & 0xff] | (ram[(adr+1) & 0xff] << 8);
}

/*
 *  Write a byte to the zeropage
 */
inline void MOS6510::write_zp(uint16 adr, uint8 byte)
{
	ram[adr] = byte;

	// Check if memory configuration may have changed.
	if (adr < 2)
		new_config();
}

/*
 *  Jump to address
 */
void MOS6510::jump(uint16 adr)
{
	if (adr < 0xa000) {
		pc = ram + adr;
		pc_base = ram;
	} else
		switch (adr >> 12) {
			case 0xa:
			case 0xb:
				if (basic_in) {
					pc = basic_rom + (adr & 0x1fff);
					pc_base = basic_rom - 0xa000;
				} else {
					pc = ram + adr;
					pc_base = ram;
				}
				break;
			case 0xc:
				pc = ram + adr;
				pc_base = ram;
				break;
			case 0xd:
				if (io_in) {
					pc = io_ram + (adr & 0x0fff);
					pc_base = io_ram - 0xd000;
				}
				else if (char_in) {
					pc = char_rom + (adr & 0x0fff);
					pc_base = char_rom - 0xd000;
				} else {
					pc = ram + adr;
					pc_base = ram;
				}
				break;
			case 0xe:
			case 0xf:
				if (kernal_in) {
					pc = kernal_rom + (adr & 0x1fff);
					pc_base = kernal_rom - 0xe000;
				} else {
					pc = ram + adr;
					pc_base = ram;
				}
				break;
		}
}

/*
 *  Adc instruction
 */
void MOS6510::do_adc_bcd(uint8 byte)
{
	uint16 al, ah;

	// Decimal mode
	al = (a & 0x0f) + (byte & 0x0f) + (c_flag ? 1 : 0);		// Calculate lower nybble
	if (al > 9) al += 6;									// BCD fixup for lower nybble

	ah = (a >> 4) + (byte >> 4);							// Calculate upper nybble
	if (al > 0x0f) ah++;

	z_flag = a + byte + (c_flag ? 1 : 0);					// Set flags
	n_flag = ah << 4;	// Only highest bit used
	v_flag = (((ah << 4) ^ a) & 0x80) && !((a ^ byte) & 0x80);

	if (ah > 9) ah += 6;									// BCD fixup for upper nybble
	c_flag = ah > 0x0f;										// Set carry flag
	a = (ah << 4) | (al & 0x0f);							// Compose result
}

/*
 * Sbc instruction
 */
void MOS6510::do_sbc_bcd(uint8 byte)
{
	uint16 tmp = a - byte - (c_flag ? 0 : 1);
	uint16 al, ah;

	// Decimal mode
	al = (a & 0x0f) - (byte & 0x0f) - (c_flag ? 0 : 1);		// Calculate lower nybble
	ah = (a >> 4) - (byte >> 4);							// Calculate upper nybble
	if (al & 0x10) {
		al -= 6;											// BCD fixup for lower nybble
		ah--;
	}
	if (ah & 0x10) ah -= 6;									// BCD fixup for upper nybble

	c_flag = tmp < 0x100;									// Set flags
	v_flag = ((a ^ tmp) & 0x80) && ((a ^ byte) & 0x80);
	z_flag = n_flag = tmp;

	a = (ah << 4) | (al & 0x0f); // Compose result
}

/*
 *  Jump to illegal address space (PC_IS_POINTER only)
 */
void MOS6510::illegal_jump(uint16 at, uint16 to)
{
	char illop_msg[80];
	
	sprintf(illop_msg, "6510: Jump to I/O space at %04x to %04x.", at, to);
	if (ShowRequester(illop_msg, "Reset 6510", "Reset C64"))
		the_c64->Reset();
	Reset();
	
}


/*
 *  Stack macros
 */

// Pop a byte from the stack
#define pop_byte() ram[(++sp) | 0x0100]

// Push a byte onto the stack
#define push_byte(byte) (ram[(sp--) & 0xff | 0x0100] = (byte))

// Pop processor flags from the stack
#define pop_flags() \
	n_flag = tmp = pop_byte(); \
	v_flag = tmp & 0x40; \
	d_flag = tmp & 0x08; \
	i_flag = tmp & 0x04; \
	z_flag = !(tmp & 0x02); \
	c_flag = tmp & 0x01;

// Push processor flags onto the stack
#define push_flags(b_flag) \
	tmp = 0x20 | (n_flag & 0x80); \
	if (v_flag) tmp |= 0x40; \
	if (b_flag) tmp |= 0x10; \
	if (d_flag) tmp |= 0x08; \
	if (i_flag) tmp |= 0x04; \
	if (!z_flag) tmp |= 0x02; \
	if (c_flag) tmp |= 0x01; \
	push_byte(tmp);


/*
 *  Emulate cycles_left worth of 6510 instructions
 *  Returns number of cycles of last instruction
 */

int MOS6510::EmulateLine(int cycles_left)
{
	uint8 tmp;
	uint16 adr;		// Used by read_adr_abs()!
	int last_cycles = 0;
	
	//if (halt) {
	//	return 0;
	//}
	
	// Any pending interrupts?
	if (interrupt.intr_any) {
handle_int:
		if (interrupt.intr[INT_NMI]) {
			interrupt.intr[INT_NMI] = false;	// Simulate an edge-triggered input
			push_byte((pc-pc_base) >> 8); push_byte(pc-pc_base);
			push_flags(false);
			i_flag = true;
			jump(read_word(0xfffa));
			last_cycles = 7;

		} else if ((interrupt.intr[INT_VICIRQ] || interrupt.intr[INT_CIAIRQ]) && !i_flag) {
			push_byte((pc-pc_base) >> 8); push_byte(pc-pc_base);
			push_flags(false);
			i_flag = true;
			jump(read_word(0xfffe));
			last_cycles = 7;
		}

		else if (interrupt.intr[INT_RESET])
			Reset();
	}

#include "CPU_emulline.i"

		// Extension opcode
		case 0xf2:
			if ((pc-pc_base) < 0xe000) {
				illegal_op(0xf2, pc-pc_base-1);
				break;
			}
			switch (read_byte_imm()) {
				case 0x00:
					ram[0x90] |= TheIEC->Out(ram[0x95], ram[0xa3] & 0x80);
					c_flag = false;
					jump(0xedac);
					break;
				case 0x01:
					ram[0x90] |= TheIEC->OutATN(ram[0x95]);
					c_flag = false;
					jump(0xedac);
					break;
				case 0x02:
					ram[0x90] |= TheIEC->OutSec(ram[0x95]);
					c_flag = false;
					jump(0xedac);
					break;
				case 0x03:
					ram[0x90] |= TheIEC->In(&a);
					set_nz(a);
					c_flag = false;
					jump(0xedac);
					break;
				case 0x04:
					TheIEC->SetATN();
					jump(0xedfb);
					break;
				case 0x05:
					TheIEC->RelATN();
					jump(0xedac);
					break;
				case 0x06:
					TheIEC->Turnaround();
					jump(0xedac);
					break;
				case 0x07:
					TheIEC->Release();
					jump(0xedac);
					break;
				default:
					illegal_op(0xf2, pc-pc_base-1);
					break;
			}
			break;
		}
	}

	return last_cycles;
}

#if SINGLE_CYCLE

//************************************************************
// End of normal emulation (no single cycle)
//************************************************************

#undef pop_flags
#undef push_flags
#undef Branch

//************************************************************
// Start of single cycle emulation
//************************************************************

/*
 *  Write a byte to the CPU's address space
 */
inline void MOS6510::write_byteSC(uint16 adr, uint8 byte)
{
	if (adr < 0xd000) {
		if (adr >= 2)
			ram[adr] = byte;
		else if (adr == 0) {
			ddr = byte;
			ram[0] = ddr;
			new_config();
		} else {
			pr = byte;
			ram[1] = (ddr & pr) | (~ddr & 0x17);
			new_config();
		}
	} else if(!io_in || adr >= 0xe000) {
		ram[adr] = byte;
  } else {
		io_ram[adr & 0x0fff] = byte; // required only to switch back to standard emulation
		switch ((adr >> 8) & 0x0f) {
			case 0x0:	// VIC
			case 0x1:
			case 0x2:
			case 0x3:
				TheVIC->WriteRegisterSC(adr & 0x3f, byte);
				return;
			case 0x4:	// SID
			case 0x5:
			case 0x6:
			case 0x7:
				TheSID->WriteRegister(adr & 0x1f, byte);
				return;
			case 0x8:	// Color RAM
			case 0x9:
			case 0xa:
			case 0xb:
				color_ram[adr & 0x03ff] = byte & 0x0f;
				return;
			case 0xc:	// CIA 1
				TheCIA1->WriteRegister(adr & 0x0f, byte);
				return;
			case 0xd:	// CIA 2
				TheCIA2->WriteRegister(adr & 0x0f, byte);
				return;
			case 0xe:	// REU/Open I/O
			case 0xf:
				return;
		}
	}
}

/*
 *  Adc instruction
 */
inline void MOS6510::do_adc(uint8 byte)
{
	if (!d_flag) {
		uint16 tmp;

		// Binary mode
		tmp = a + byte + (c_flag ? 1 : 0);
		c_flag = tmp > 0xff;
		v_flag = !((a ^ byte) & 0x80) && ((a ^ tmp) & 0x80);
		z_flag = n_flag = a = tmp;

	} else {
		uint16 al, ah;

		// Decimal mode
		al = (a & 0x0f) + (byte & 0x0f) + (c_flag ? 1 : 0);		// Calculate lower nybble
		if (al > 9) al += 6;									// BCD fixup for lower nybble

		ah = (a >> 4) + (byte >> 4);							// Calculate upper nybble
		if (al > 0x0f) ah++;

		z_flag = a + byte + (c_flag ? 1 : 0);					// Set flags
		n_flag = ah << 4;	// Only highest bit used
		v_flag = (((ah << 4) ^ a) & 0x80) && !((a ^ byte) & 0x80);

		if (ah > 9) ah += 6;									// BCD fixup for upper nybble
		c_flag = ah > 0x0f;										// Set carry flag
		a = (ah << 4) | (al & 0x0f);							// Compose result
	}
}

/*
 * Sbc instruction
 */
inline void MOS6510::do_sbc(uint8 byte)
{
	uint16 tmp = a - byte - (c_flag ? 0 : 1);

	if (!d_flag) {

		// Binary mode
		c_flag = tmp < 0x100;
		v_flag = ((a ^ tmp) & 0x80) && ((a ^ byte) & 0x80);
		z_flag = n_flag = a = tmp;

	} else {
		uint16 al, ah;

		// Decimal mode
		al = (a & 0x0f) - (byte & 0x0f) - (c_flag ? 0 : 1);	// Calculate lower nybble
		ah = (a >> 4) - (byte >> 4);							// Calculate upper nybble
		if (al & 0x10) {
			al -= 6;											// BCD fixup for lower nybble
			ah--;
		}
		if (ah & 0x10) ah -= 6;									// BCD fixup for upper nybble

		c_flag = tmp < 0x100;									// Set flags
		v_flag = ((a ^ tmp) & 0x80) && ((a ^ byte) & 0x80);
		z_flag = n_flag = tmp;

		a = (ah << 4) | (al & 0x0f);							// Compose result
	}
}

/*
 *  Emulate one 6510 clock cycle
 */

// Read byte from memory
#define read_to(adr, to) \
	if (BALow) \
		return; \
  to = (((adr) & 0xf000) == 0xd000 && io_in) ? read_byte_io(adr) : mem_ptr[(adr) >> 12][(adr) & 0x0fff]
  
// Read byte from memory, throw away result
#define read_idle(adr) \
	if (BALow) \
		return; \
	if(((adr) & 0xf000) == 0xd000 && io_in) \
	  read_byte_io(adr);

void MOS6510::EmulateCycle(bool BALow)
{
	uint8 data;

	switch (state) {

		// Opcode fetch (cycle 0)
		case 0:
    	// Any pending interrupts in state 0 (opcode fetch)?
    	if (interrupt.intr_any) 
    	{
    		if (interrupt.intr[INT_RESET])
    		{
    			Reset();
      	  EmulateCycle(BALow);
      	  break;
        }
    		else if (interrupt.intr[INT_NMI] && (the_c64->CycleCounter-first_nmi_cycle >= 2)) 
    		{
    			interrupt.intr[INT_NMI] = false;	// Simulate an edge-triggered input
    			state = 0x0010;
      	  EmulateCycle(BALow);
      	  break;
    		} 
    		else if ((interrupt.intr[INT_VICIRQ] || interrupt.intr[INT_CIAIRQ]) && (the_c64->CycleCounter-first_irq_cycle >= 2) && !i_flag)
    		{
    			state = 0x0008;
      	  EmulateCycle(BALow);
      	  break;
        }
    	}

#define write_byte write_byteSC
#include "CPU_emulcycle.i"
#undef write_byte

		// Extension opcode
		case O_EXT:
			if (pcSC < 0xe000) {
				illegal_op(0xf2, pcSC-1);
				break;
			}
			switch (read_byte(pcSC++)) {
				case 0x00:
					ram[0x90] |= TheIEC->Out(ram[0x95], ram[0xa3] & 0x80);
					c_flag = false;
					pcSC = 0xedac;
					Last;
				case 0x01:
					ram[0x90] |= TheIEC->OutATN(ram[0x95]);
					c_flag = false;
					pcSC = 0xedac;
					Last;
				case 0x02:
					ram[0x90] |= TheIEC->OutSec(ram[0x95]);
					c_flag = false;
					pcSC = 0xedac;
					Last;
				case 0x03:
					ram[0x90] |= TheIEC->In(&a);
					set_nz(a);
					c_flag = false;
					pcSC = 0xedac;
					Last;
				case 0x04:
					TheIEC->SetATN();
					pcSC = 0xedfb;
					Last;
				case 0x05:
					TheIEC->RelATN();
					pcSC = 0xedac;
					Last;
				case 0x06:
					TheIEC->Turnaround();
					pcSC = 0xedac;
					Last;
				case 0x07:
					TheIEC->Release();
					pcSC = 0xedac;
					Last;
				default:
					illegal_op(0xf2, pcSC-1);
					break;
			}
			break;

		default:
			illegal_op(op, pcSC-1);
			break;
	}
}

//************************************************************
// End of single cycle emulation
//************************************************************
#endif
