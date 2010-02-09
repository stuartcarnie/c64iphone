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
 *  CPUC64.h - 6510 (C64) emulation (line based)
 *
 *  Frodo (C) 1994-1997,2002 Christian Bauer
 */

#ifndef _CPU_C64_H
#define _CPU_C64_H

#include "C64.h"


// Interrupt types
enum {
	INT_VICIRQ,
	INT_CIAIRQ,
	INT_NMI
	// INT_RESET (private)
};

class MOS6569;
class MOS6581;
class MOS6526_1;
class MOS6526_2;
class IEC;
struct MOS6510State;


// 6510 emulation (C64)
class MOS6510 {
private:
	uint8 n_flag, z_flag;
	bool v_flag, d_flag, i_flag, c_flag;
	uint8 a, x, y, sp;

	uint8 *pc, *pc_base;
	uint16 pcSC;
	
public:
	MOS6510(C64 *c64, uint8 *Ram, uint8 *Basic, uint8 *Kernal, uint8 *Char, uint8 *Color, uint8 *IO_Ram);
	
#if SINGLE_CYCLE
	void EmulateCycle(bool BALow);			// Emulate one clock cycle
#endif
	
	int EmulateLine(int cycles_left);	// Emulate until cycles_left underflows
	void Reset(void);
	void ClearIRQ(void);
	void AsyncReset(void);				// Reset the CPU asynchronously
	void AsyncNMI(void);				// Raise NMI asynchronously (NMI pulse)
	void GetState(MOS6510State *s);
	void SetState(MOS6510State *s);
	
	void TriggerVICIRQ(void);
	void ClearVICIRQ(void);
	void TriggerCIAIRQ(void);
	void ClearCIAIRQ(void);
	void TriggerNMI(void);
	void ClearNMI(void);
	void SwitchToSC(void);
	void SwitchToStandard(void);
	
	int InstallTrap(trap_t *trap);
	void ClearTraps();
	
	int ExtConfig;	// Memory configuration for ExtRead/WriteByte (0..7)
	
	MOS6569 *TheVIC;	// Pointer to VIC
	MOS6581 *TheSID;	// Pointer to SID
	MOS6526_1 *TheCIA1;	// Pointer to CIA 1
	MOS6526_2 *TheCIA2;	// Pointer to CIA 2
	IEC *TheIEC;		// Pointer to drive array
	
	C64 *the_c64;		// Pointer to C64 object
	
	bool halt;
	
private:
	// trap handling
	trap_result2_t* trap();
	uint8 peek(uint16 adr, bool forceram);				// for trap handler
	void poke(uint16 adr, uint8 byte, bool forceram);	// for trap handler
	
	uint8 read_byte(uint16 adr);
	uint8 read_byte_io(uint16 adr);
	uint16 read_word(uint16 adr);
	void write_byte(uint16 adr, uint8 byte);
#if SINGLE_CYCLE
	void write_byteSC(uint16 adr, uint8 byte);
#endif
	
	uint16 read_zp_word(uint16 adr);
	void write_zp(uint16 adr, uint8 byte);
	
	void new_config(void);
	void jump(uint16 adr);
	void illegal_op(uint8 op, uint16 at);
	void illegal_jump(uint16 at, uint16 to);
	
	void do_adc(uint8 byte);
	void do_sbc(uint8 byte);
	void do_adc_bcd(uint8 byte);
	void do_sbc_bcd(uint8 byte);
	
	trap_t *first_trap;
	
	uint8 *ram;			// Pointer to main RAM
	uint8 *basic_rom, *kernal_rom, *char_rom, *color_ram; // Pointers to ROMs and color RAM
	uint8 *io_ram;
	
	union {				// Pending interrupts
		uint8 intr[4];	// Index: See definitions above
		unsigned long intr_any;
	} interrupt;
	bool nmi_state;		// State of NMI line
		
	uint32 first_irq_cycle, first_nmi_cycle;
	
	uint8 state, op;		// Current state and opcode
	uint16 ar, ar2;			// Address registers
	uint8 rdbuf;			// Data buffer for RMW instructions
	uint8 ddr, pr;			// Processor port
	
	int	borrowed_cycles;	// Borrowed cycles from next line
	
	bool basic_in, kernal_in, char_in, io_in;
	uint8 dfff_byte;
	
	uint8 *mem_ptr[16];
};

// 6510 state
struct MOS6510State {
	uint16 ar, ar2;			// Address registers
	uint8 state, op;		// Current state and opcode
	uint8 rdbuf;			// Data buffer for RMW instructions
	
	uint8 a, x, y;
	uint8 p;			// Processor flags
	uint8 ddr, pr;		// Port
	uint16 pc, sp;
	uint8 intr[4];		// Interrupt state
	bool nmi_state;	
	uint8 dfff_byte;
	bool basic_in, kernal_in, char_in, io_in;
};


struct MOS6510StateOld {
	uint8 a, x, y;
	uint8 p;			// Processor flags
	uint8 ddr, pr;		// Port
	uint16 pc, sp;
	uint8 intr[4];		// Interrupt state
	bool nmi_state;	
	uint8 dfff_byte;
	bool instruction_complete;
	bool basic_in, kernal_in, char_in, io_in;
};


inline void MOS6510::TriggerVICIRQ(void)
{
	if (!(interrupt.intr[INT_VICIRQ] || interrupt.intr[INT_CIAIRQ]))
		first_irq_cycle = the_c64->CycleCounter;
	interrupt.intr[INT_VICIRQ] = true;
}

inline void MOS6510::TriggerCIAIRQ(void)
{
	if (!(interrupt.intr[INT_VICIRQ] || interrupt.intr[INT_CIAIRQ]))
		first_irq_cycle = the_c64->CycleCounter;
	interrupt.intr[INT_CIAIRQ] = true;
}

inline void MOS6510::TriggerNMI(void)
{
	if (!nmi_state) {
		nmi_state = true;
		interrupt.intr[INT_NMI] = true;
		first_nmi_cycle = the_c64->CycleCounter;
	}
}

inline void MOS6510::ClearVICIRQ(void)
{
	interrupt.intr[INT_VICIRQ] = false;
}

inline void MOS6510::ClearCIAIRQ(void)
{
	interrupt.intr[INT_CIAIRQ] = false;
}

inline void MOS6510::ClearNMI(void)
{
	nmi_state = false;
}

#endif
