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
 *  CIA.h - 6526 emulation
 *
 *  Frodo (C) 1994-1997,2002 Christian Bauer
 */

#ifndef _CIA_H
#define _CIA_H

#include "Prefs.h"


class MOS6510;
class MOS6502_1541;
class MOS6569;
struct MOS6526State;


// Timer states
enum {
	T_STOP,
	T_WAIT_THEN_COUNT,
	T_LOAD_THEN_STOP,
	T_LOAD_THEN_COUNT,
	T_LOAD_THEN_WAIT_THEN_COUNT,
	T_COUNT,
	T_COUNT_THEN_STOP,
};


class MOS6526 {
public:
	MOS6526(MOS6510 *CPU);

	void Reset(void);
	void GetState(MOS6526State *cs);
	void SetState(MOS6526State *cs);
	void EmulateCycles(void);
	void UpdateTATB(bool ResetCyclesTillAction);
	
	// an optimization which will avoid calling EmulateLine
	inline bool NeedToEmulateLine() { return ta_cnt_phi2 || tb_cnt_phi2; }
	
	void EmulateLine(int cycles);
	void CountTOD(void);
	void TriggerInterrupt(int bit);
	uint8 GetMoreInfo(void);
	void SetMoreInfo(uint8 value);
  void SwitchToSC(void);
  void SwitchToStandard(void);
  
	uint16 CyclesTillActionCnt;

protected:
	uint16 CyclesTillAction;
	MOS6510 *the_cpu;	// Pointer to 6510
	uint8 type;

	uint8 pra, prb, ddra, ddrb;

	uint16 ta, tb, latcha, latchb;

	uint8 tod_10ths, tod_sec, tod_min, tod_hr;
	uint8 alm_10ths, alm_sec, alm_min, alm_hr;

	uint8 sdr, icr, cra, crb;
	uint8 int_mask;

	int tod_divider;	// TOD frequency divider

	bool tod_halt,		// Flag: TOD halted
		 ta_cnt_phi2,	// Flag: Timer A is counting Phi 2
		 tb_cnt_phi2,	// Flag: Timer B is counting Phi 2
     tb_cnt_ta;		// Flag: Timer B is counting underflows of Timer A

	bool ta_irq_next_cycle,		// Flag: Trigger TA IRQ in next cycle
		 tb_irq_next_cycle,		// Flag: Trigger TB IRQ in next cycle
		 has_new_cra,			// Flag: New value for CRA pending
		 has_new_crb;			// Flag: New value for CRB pending
	char ta_state, tb_state;	// Timer A/B states
	uint8 new_cra, new_crb;		// New values for CRA/CRB
};


class MOS6526_1 : public MOS6526 {
public:
	MOS6526_1(MOS6510 *CPU, MOS6569 *VIC);

	void Reset(void);
	uint8 ReadRegister(uint16 adr);
	void WriteRegister(uint16 adr, uint8 byte);
	void TriggerInterrupt(int bit);
	uint8 GetMoreInfo(void);
	void SetMoreInfo(uint8 value);

	uint8 KeyMatrix[8];	// C64 keyboard matrix, 1 bit/key (0: key down, 1: key up)
	uint8 RevMatrix[8];	// Reversed keyboard matrix

	uint8 Joystick1;	// Joystick 1 AND value
	uint8 Joystick2;	// Joystick 2 AND value

	void UpdateDataPorts();
	
private:
	void check_lp(void);

	MOS6569 *the_vic;

	uint8 prev_lp;		// Previous state of LP line (bit 4)
	uint8 dataport1;
	uint8 dataport2;
};


class MOS6526_2 : public MOS6526{
public:
	MOS6526_2(MOS6510 *CPU, MOS6569 *VIC, MOS6502_1541 *CPU1541);

	void Reset(void);
	uint8 ReadRegister(uint16 adr);
	void WriteRegister(uint16 adr, uint8 byte);
	void TriggerInterrupt(int bit);
	uint8 GetMoreInfo(void);
	void SetMoreInfo(uint8 value);

	uint8 IECLines;		// State of IEC lines (bit 7 - DATA, bit 6 - CLK, bit 4 - ATN)

private:
	MOS6569 *the_vic;
	MOS6502_1541 *the_cpu_1541;
};


// CIA state
struct MOS6526State {
	uint8 pra;
	uint8 ddra;
	uint8 prb;
	uint8 ddrb;
	uint8 ta_lo;
	uint8 ta_hi;
	uint8 tb_lo;
	uint8 tb_hi;
	uint8 tod_10ths;
	uint8 tod_sec;
	uint8 tod_min;
	uint8 tod_hr;
	uint8 sdr;
	uint8 int_data;		// Pending interrupts
	uint8 cra;
	uint8 crb;
						// Additional registers
	uint16 latcha;		// Timer latches
	uint16 latchb;
	uint8 alm_10ths;	// Alarm time
	uint8 alm_sec;
	uint8 alm_min;
	uint8 alm_hr;
	uint8 int_mask;		// Enabled interrupts
	
	uint8 more_info; // prev_lp in CIA1; IECLines in CIA2

	uint16 CyclesTillAction;
	uint16 CyclesTillActionCnt;

  uint8 has_new_cra;
  uint8 has_new_crb;
  uint8 new_cra;
  uint8 new_crb;
  uint8 ta_irq_next_cycle;
  uint8 tb_irq_next_cycle;
	uint8 ta_state;
	uint8 tb_state;
	
	uint8 ta_cnt_phi2;
	uint8 tb_cnt_phi2;
	uint8 tb_cnt_ta;
};

struct MOS6526StateOld {
	uint8 pra;
	uint8 ddra;
	uint8 prb;
	uint8 ddrb;
	uint8 ta_lo;
	uint8 ta_hi;
	uint8 tb_lo;
	uint8 tb_hi;
	uint8 tod_10ths;
	uint8 tod_sec;
	uint8 tod_min;
	uint8 tod_hr;
	uint8 sdr;
	uint8 int_data;		// Pending interrupts
	uint8 cra;
	uint8 crb;
						// Additional registers
	uint16 latcha;		// Timer latches
	uint16 latchb;
	uint8 alm_10ths;	// Alarm time
	uint8 alm_sec;
	uint8 alm_min;
	uint8 alm_hr;
	uint8 int_mask;		// Enabled interrupts
	
	uint8 more_info; // prev_lp in CIA1; IECLines in CIA2
};

#endif
