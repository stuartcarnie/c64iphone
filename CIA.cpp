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
 *  CIA.cpp - 6526 emulation
 *
 *  Frodo (C) 1994-1997,2002 Christian Bauer
 *

 *
 * Notes:
 * ------
 *
 *  - The EmulateLine() function is called for every emulated raster
 *    line. It counts down the timers and triggers interrupts if
 *    necessary.
 *  - The TOD clocks are counted by CountTOD() during the VBlank, so
 *    the input frequency is 50Hz
 *  - The fields KeyMatrix and RevMatrix contain one bit for each
 *    key on the C64 keyboard (0: key pressed, 1: key released).
 *    KeyMatrix is used for normal keyboard polling (PRA->PRB),
 *    RevMatrix for reversed polling (PRB->PRA).
 *
 * Incompatibilities:
 * ------------------
 *
 *  - The TOD clock should not be stopped on a read access, but
 *    latched
 *  - The SDR interrupt is faked
 */

#include "sysdeps.h"

#include "CIA.h"
#include "CPUC64.h"
#include "CPU1541.h"
#include "VIC.h"
#include "Prefs.h"


/*
 *  Constructors
 */

MOS6526::MOS6526(MOS6510 *CPU) : the_cpu(CPU) {}
MOS6526_1::MOS6526_1(MOS6510 *CPU, MOS6569 *VIC) : MOS6526(CPU), the_vic(VIC) { type=1; }
MOS6526_2::MOS6526_2(MOS6510 *CPU, MOS6569 *VIC, MOS6502_1541 *CPU1541) :
	MOS6526(CPU), the_vic(VIC), the_cpu_1541(CPU1541) { type=2; }


/*
 *  Switch from standard emulation to single cycle emulation
 */
void MOS6526::SwitchToSC(void)
{
  ta_irq_next_cycle = false;
  tb_irq_next_cycle = false;
  has_new_cra = false;
  has_new_crb = false;
  ta_state = ta_cnt_phi2 ? T_COUNT : T_STOP;
  tb_state = (tb_cnt_phi2 || tb_cnt_ta) ? T_COUNT : T_STOP;
  CyclesTillAction = 1;
  CyclesTillActionCnt = 1;
}


/*
 *  Switch from single cycle emulation to standard emulation
 */
void MOS6526::SwitchToStandard(void)
{
  UpdateTATB(false);
  
  if(has_new_cra)
  {
		cra = new_cra & 0xef;
		if (new_cra & 0x10) // Force load
			ta = latcha;
  }
  
  if(has_new_crb)    
  {
		crb = new_crb & 0xef;
		if (new_crb & 0x10) // Force load
			tb = latchb;
  }
  
  if(ta_irq_next_cycle)
		TriggerInterrupt(1);
  
  if(tb_irq_next_cycle)
		TriggerInterrupt(2);
}


/*
 *  Reset the CIA
 */

void MOS6526::Reset(void)
{
	pra = prb = ddra = ddrb = 0;

	ta = tb = 0xffff;
	latcha = latchb = 1;

	tod_10ths = tod_sec = tod_min = tod_hr = 0;
	alm_10ths = alm_sec = alm_min = alm_hr = 0;

	sdr = icr = cra = crb = int_mask = 0;

	tod_halt = ta_cnt_phi2 = tb_cnt_phi2 = tb_cnt_ta = false;
	tod_divider = 0;

	ta_irq_next_cycle = tb_irq_next_cycle = false;
	ta_state = tb_state = T_STOP;
	CyclesTillAction = 1;
	CyclesTillAction = 1;
}

void MOS6526_1::Reset(void)
{
	MOS6526::Reset();

	// Clear keyboard matrix and joystick states
	for (int i=0; i<8; i++)
		KeyMatrix[i] = RevMatrix[i] = 0xff;

	Joystick1 = Joystick2 = 0xff;
	prev_lp = 0x10;
}

void MOS6526_2::Reset(void)
{
	MOS6526::Reset();

	// VA14/15 = 0
	the_vic->ChangedVA(0);

	// IEC
	IECLines = 0xd0;
}


/*
 *  Get CIA state
 */

void MOS6526::GetState(MOS6526State *cs)
{
	cs->pra = pra;
	cs->prb = prb;
	cs->ddra = ddra;
	cs->ddrb = ddrb;

	cs->ta_lo = ta & 0xff;
	cs->ta_hi = ta >> 8;
	cs->tb_lo = tb & 0xff;
	cs->tb_hi = tb >> 8;
	cs->latcha = latcha;
	cs->latchb = latchb;
	cs->cra = cra;
	cs->crb = crb;

	cs->tod_10ths = tod_10ths;
	cs->tod_sec = tod_sec;
	cs->tod_min = tod_min;
	cs->tod_hr = tod_hr;
	cs->alm_10ths = alm_10ths;
	cs->alm_sec = alm_sec;
	cs->alm_min = alm_min;
	cs->alm_hr = alm_hr;

	cs->sdr = sdr;

	cs->int_data = icr;
	cs->int_mask = int_mask;

  cs->CyclesTillAction = CyclesTillAction;
  cs->CyclesTillActionCnt = CyclesTillActionCnt;

  cs->has_new_cra = has_new_cra;
  cs->has_new_crb = has_new_crb;
  cs->new_cra = new_cra;
  cs->new_crb = new_crb;
  cs->ta_irq_next_cycle = ta_irq_next_cycle;
  cs->tb_irq_next_cycle = tb_irq_next_cycle;
	cs->ta_state = ta_state;
	cs->tb_state = tb_state;
	
	cs->ta_cnt_phi2 = ta_cnt_phi2;
	cs->tb_cnt_phi2 = tb_cnt_phi2;
	cs->tb_cnt_ta = tb_cnt_ta;

  cs->more_info = GetMoreInfo();
}


/*
 *  Restore CIA state
 */

void MOS6526::SetState(MOS6526State *cs)
{
	pra = cs->pra;
	prb = cs->prb;
	ddra = cs->ddra;
	ddrb = cs->ddrb;

	ta = (cs->ta_hi << 8) | cs->ta_lo;
	tb = (cs->tb_hi << 8) | cs->tb_lo;
	latcha = cs->latcha;
	latchb = cs->latchb;
	cra = cs->cra;
	crb = cs->crb;

	tod_10ths = cs->tod_10ths;
	tod_sec = cs->tod_sec;
	tod_min = cs->tod_min;
	tod_hr = cs->tod_hr;
	alm_10ths = cs->alm_10ths;
	alm_sec = cs->alm_sec;
	alm_min = cs->alm_min;
	alm_hr = cs->alm_hr;

	sdr = cs->sdr;

	icr = cs->int_data;
	int_mask = cs->int_mask;

	tod_halt = false;

  CyclesTillAction = cs->CyclesTillAction;
  CyclesTillActionCnt = cs->CyclesTillActionCnt;

  has_new_cra = cs->has_new_cra;
  has_new_crb = cs->has_new_crb;
  new_cra = cs->new_cra;
  new_crb = cs->new_crb;
  ta_irq_next_cycle = cs->ta_irq_next_cycle;
  tb_irq_next_cycle = cs->tb_irq_next_cycle;
	ta_state = cs->ta_state;
	tb_state = cs->tb_state;

	ta_cnt_phi2 = cs->ta_cnt_phi2;
	tb_cnt_phi2 = cs->tb_cnt_phi2;
	tb_cnt_ta = cs->tb_cnt_ta;

  SetMoreInfo(cs->more_info);
}


/*
 *  Read from register (CIA 1)
 */
void MOS6526_1::UpdateDataPorts(void)
{
	uint8 ret = pra | ~ddra;
	uint8 tst = (prb | ~ddrb) & Joystick1;
	if (!(tst & 0x01)) ret &= RevMatrix[0];	// AND all active columns
	if (!(tst & 0x02)) ret &= RevMatrix[1];
	if (!(tst & 0x04)) ret &= RevMatrix[2];
	if (!(tst & 0x08)) ret &= RevMatrix[3];
	if (!(tst & 0x10)) ret &= RevMatrix[4];
	if (!(tst & 0x20)) ret &= RevMatrix[5];
	if (!(tst & 0x40)) ret &= RevMatrix[6];
	if (!(tst & 0x80)) ret &= RevMatrix[7];
	dataport1 = ret & Joystick2;

	ret = ~ddrb;
	tst = (pra | ~ddra) & Joystick2;
	if (!(tst & 0x01)) ret &= KeyMatrix[0];	// AND all active rows
	if (!(tst & 0x02)) ret &= KeyMatrix[1];
	if (!(tst & 0x04)) ret &= KeyMatrix[2];
	if (!(tst & 0x08)) ret &= KeyMatrix[3];
	if (!(tst & 0x10)) ret &= KeyMatrix[4];
	if (!(tst & 0x20)) ret &= KeyMatrix[5];
	if (!(tst & 0x40)) ret &= KeyMatrix[6];
	if (!(tst & 0x80)) ret &= KeyMatrix[7];
	dataport2 = (ret | (prb & ddrb)) & Joystick1;
}

uint8 MOS6526_1::ReadRegister(uint16 adr)
{
	switch (adr) {
		case 0x00: return dataport1;
		case 0x01: return dataport2;
		case 0x02: return ddra;
		case 0x03: return ddrb;
		case 0x04: 
		  if(ThePrefs.SingleCycleEmulation)
		    UpdateTATB(false); 
		  return ta;
		case 0x05: 
		  if(ThePrefs.SingleCycleEmulation)
		    UpdateTATB(false); 
		  return ta >> 8;
		case 0x06:
		  if(ThePrefs.SingleCycleEmulation)
		    UpdateTATB(false); 
		  return tb;
		case 0x07: 
		  if(ThePrefs.SingleCycleEmulation)
		    UpdateTATB(false); 
		  return tb >> 8;
		case 0x08: tod_halt = false; return tod_10ths;
		case 0x09: return tod_sec;
		case 0x0a: return tod_min;
		case 0x0b: tod_halt = true; return tod_hr;
		case 0x0c: return sdr;
		case 0x0d: {
			uint8 ret = icr;		// Read and clear ICR
			icr = 0;
			the_cpu->ClearCIAIRQ();	// Clear IRQ
			return ret;
		}
		case 0x0e: return cra;
		case 0x0f: return crb;
	}
	return 0;	// Can't happen
}


/*
 *  Read from register (CIA 2)
 */

uint8 MOS6526_2::ReadRegister(uint16 adr)
{
	switch (adr) {
		case 0x00:
			return (pra | ~ddra) & 0x3f
				| IECLines & the_cpu_1541->IECLines;
		case 0x01: return prb | ~ddrb;
		case 0x02: return ddra;
		case 0x03: return ddrb;
		case 0x04: 
		  if(ThePrefs.SingleCycleEmulation)
		    UpdateTATB(false); 
		  return ta;
		case 0x05: 
		  if(ThePrefs.SingleCycleEmulation)
		    UpdateTATB(false); 
		  return ta >> 8;
		case 0x06: 
		  if(ThePrefs.SingleCycleEmulation)
		    UpdateTATB(false); 
		  return tb;
		case 0x07: 
		  if(ThePrefs.SingleCycleEmulation)
		    UpdateTATB(false); 
		  return tb >> 8;
		case 0x08: tod_halt = false; return tod_10ths;
		case 0x09: return tod_sec;
		case 0x0a: return tod_min;
		case 0x0b: tod_halt = true; return tod_hr;
		case 0x0c: return sdr;
		case 0x0d: {
			uint8 ret = icr;		// Read and clear ICR
			icr = 0;
			the_cpu->ClearNMI();	// Clear NMI
			return ret;
		}
		case 0x0e: return cra;
		case 0x0f: return crb;
	}
	return 0;	// Can't happen
}


/*
 *  Write to register (CIA 1)
 */

// Write to port B, check for lightpen interrupt
inline void MOS6526_1::check_lp(void)
{
	if ((prb | ~ddrb) & 0x10 != prev_lp)
		the_vic->TriggerLightpen();
	prev_lp = (prb | ~ddrb) & 0x10;
}

void MOS6526_1::WriteRegister(uint16 adr, uint8 byte)
{
	switch (adr) {
		case 0x0: 
			pra = byte; 
			UpdateDataPorts(); 
			break;
			
		case 0x1:
			prb = byte;
			UpdateDataPorts();
			check_lp();
			break;
			
		case 0x2: 
			ddra = byte; 
			UpdateDataPorts(); 
			break;
			
		case 0x3:
			ddrb = byte;
			UpdateDataPorts();
			check_lp();
			break;

		case 0x4: latcha = (latcha & 0xff00) | byte; break;
		case 0x5:
			latcha = (latcha & 0xff) | (byte << 8);
			if (!(cra & 1))	// Reload timer if stopped
				ta = latcha;
			break;

		case 0x6: latchb = (latchb & 0xff00) | byte; break;
		case 0x7:
			latchb = (latchb & 0xff) | (byte << 8);
			if (!(crb & 1))	// Reload timer if stopped
				tb = latchb;
			break;

		case 0x8:
			if (crb & 0x80)
				alm_10ths = byte & 0x0f;
			else
				tod_10ths = byte & 0x0f;
			break;
		case 0x9:
			if (crb & 0x80)
				alm_sec = byte & 0x7f;
			else
				tod_sec = byte & 0x7f;
			break;
		case 0xa:
			if (crb & 0x80)
				alm_min = byte & 0x7f;
			else
				tod_min = byte & 0x7f;
			break;
		case 0xb:
			if (crb & 0x80)
				alm_hr = byte & 0x9f;
			else
				tod_hr = byte & 0x9f;
			break;

		case 0xc:
			sdr = byte;
			TriggerInterrupt(8);	// Fake SDR interrupt for programs that need it
			break;

		case 0xd:
      if(ThePrefs.SingleCycleEmulation)
			{
  			if (byte & 0x80)
  				int_mask |= byte & 0x7f;
  			else
  				int_mask &= ~byte;
  			if (icr & int_mask & 0x1f) { // Trigger IRQ if pending
  				icr |= 0x80;
  				the_cpu->TriggerCIAIRQ();
  			}
      }
      else
      {
  			if (ThePrefs.CIAIRQHack)	// Hack for addressing modes that read from the address
  				icr = 0;
  			if (byte & 0x80) {
  				int_mask |= byte & 0x7f;
  				if (icr & int_mask & 0x1f) { // Trigger IRQ if pending
  					icr |= 0x80;
  					the_cpu->TriggerCIAIRQ();
  				}
  			} else
  				int_mask &= ~byte;
      }
			break;

		case 0xe:
      if(ThePrefs.SingleCycleEmulation)
      {
        UpdateTATB(true);
  			has_new_cra = true;		// Delay write by 1 cycle
  			new_cra = byte;
  			ta_cnt_phi2 = ((byte & 0x20) == 0x00);
      }
      else
      {
  			cra = byte & 0xef;
  			if (byte & 0x10) // Force load
  				ta = latcha;
  			ta_cnt_phi2 = ((byte & 0x21) == 0x01);
      }
			break;

		case 0xf:
      if(ThePrefs.SingleCycleEmulation)
      {
        UpdateTATB(true);
  			has_new_crb = true;		// Delay write by 1 cycle
  			new_crb = byte;
  			tb_cnt_phi2 = ((byte & 0x60) == 0x00);
  			tb_cnt_ta = ((byte & 0x60) == 0x40);
      }
      else
      {
  			crb = byte & 0xef;
  			if (byte & 0x10) // Force load
  				tb = latchb;
  			tb_cnt_phi2 = ((byte & 0x61) == 0x01);
  			tb_cnt_ta = ((byte & 0x61) == 0x41);
      }
			break;
	}
}


/*
 *  Write to register (CIA 2)
 */

void MOS6526_2::WriteRegister(uint16 adr, uint8 byte)
{
  uint8 old_lines;

	switch (adr) {
		case 0x0:{
			pra = byte;
			if(ThePrefs.SingleCycleEmulation)
			{
				the_vic->ChangedVA(~(pra | ~ddra) & 3);
				old_lines = IECLines;
				IECLines = (~byte << 2) & 0x80	// DATA
					| (~byte << 2) & 0x40		// CLK
					| (~byte << 1) & 0x10;		// ATN
			}
			else
			{
				byte = ~pra & ddra;
				the_vic->ChangedVA(byte & 3);
				old_lines = IECLines;
				IECLines = (byte << 2) & 0x80	// DATA
					| (byte << 2) & 0x40		// CLK
					| (byte << 1) & 0x10;		// ATN
			}

			if ((IECLines ^ old_lines) & 0x10) {	// ATN changed
				the_cpu_1541->NewATNState();
				if (old_lines & 0x10)				// ATN 1->0
					the_cpu_1541->IECInterrupt();
			}
			break;
		}
		case 0x1: prb = byte; break;

		case 0x2:
			ddra = byte;
			the_vic->ChangedVA(~(pra | ~ddra) & 3);
			break;
		case 0x3: ddrb = byte; break;

		case 0x4: latcha = (latcha & 0xff00) | byte; break;
		case 0x5:
			latcha = (latcha & 0xff) | (byte << 8);
			if (!(cra & 1))	// Reload timer if stopped
				ta = latcha;
			break;

		case 0x6: latchb = (latchb & 0xff00) | byte; break;
		case 0x7:
			latchb = (latchb & 0xff) | (byte << 8);
			if (!(crb & 1))	// Reload timer if stopped
				tb = latchb;
			break;

		case 0x8:
			if (crb & 0x80)
				alm_10ths = byte & 0x0f;
			else
				tod_10ths = byte & 0x0f;
			break;
		case 0x9:
			if (crb & 0x80)
				alm_sec = byte & 0x7f;
			else
				tod_sec = byte & 0x7f;
			break;
		case 0xa:
			if (crb & 0x80)
				alm_min = byte & 0x7f;
			else
				tod_min = byte & 0x7f;
			break;
		case 0xb:
			if (crb & 0x80)
				alm_hr = byte & 0x9f;
			else
				tod_hr = byte & 0x9f;
			break;

		case 0xc:
			sdr = byte;
			TriggerInterrupt(8);	// Fake SDR interrupt for programs that need it
			break;

		case 0xd:
			if(ThePrefs.SingleCycleEmulation)
			{
				if (byte & 0x80)
					int_mask |= byte & 0x7f;
				else
					int_mask &= ~byte;
				if (icr & int_mask & 0x1f) { // Trigger NMI if pending
					icr |= 0x80;
					the_cpu->TriggerNMI();
				}
			}
			else
			{
				if (ThePrefs.CIAIRQHack)
					icr = 0;
				if (byte & 0x80) {
					int_mask |= byte & 0x7f;
					if (icr & int_mask & 0x1f) { // Trigger NMI if pending
						icr |= 0x80;
						the_cpu->TriggerNMI();
					}
				} else
					int_mask &= ~byte;
			}
			break;

		case 0xe:
			if(ThePrefs.SingleCycleEmulation)
			{
				UpdateTATB(true);
				has_new_cra = true;		// Delay write by 1 cycle
				new_cra = byte;
				ta_cnt_phi2 = ((byte & 0x20) == 0x00);
			}
			else
			{
				cra = byte & 0xef;
				if (byte & 0x10) // Force load
					ta = latcha;
				ta_cnt_phi2 = ((byte & 0x21) == 0x01);
			}
			break;

		case 0xf:
			if(ThePrefs.SingleCycleEmulation)
			{
				UpdateTATB(true);
				has_new_crb = true;		// Delay write by 1 cycle
				new_crb = byte;
				tb_cnt_phi2 = ((byte & 0x60) == 0x00);
				tb_cnt_ta = ((byte & 0x60) == 0x40);
			}
			else
			{
				crb = byte & 0xef;
				if (byte & 0x10) // Force load
					tb = latchb;
				tb_cnt_phi2 = ((byte & 0x61) == 0x01);
				tb_cnt_ta = ((byte & 0x61) == 0x41);
			}
			break;
	}
}


inline void MOS6526::UpdateTATB(bool ResetCyclesTillAction)
{
  uint16 ElapsedCycles = CyclesTillAction - CyclesTillActionCnt;

  if(ElapsedCycles > 0)
  {
    // Check, if we have to update ta
    if(ta_cnt_phi2 && ta_state == T_COUNT && ta > 0)
      ta = ta - ElapsedCycles;
    
    // Check, if we have to update tb
    if(tb_cnt_phi2 && tb_state == T_COUNT && tb > 0)
      tb = tb - ElapsedCycles;
  }

  if(ResetCyclesTillAction)
  {
    // Called from WriteRegister -> next action after one cycle
    CyclesTillAction = 1;
    CyclesTillActionCnt = 1;
  }
  else
    CyclesTillAction = CyclesTillActionCnt;
}


void MOS6526::EmulateCycles(void)
{
	bool ta_underflow = false;

	// Trigger pending interrupts
	if (ta_irq_next_cycle) 
	{
		ta_irq_next_cycle = false;
		TriggerInterrupt(1);
	}
	if (tb_irq_next_cycle) 
	{
		tb_irq_next_cycle = false;
		TriggerInterrupt(2);
	}

	// Timer A state machine
	switch (ta_state) 
	{
		case T_WAIT_THEN_COUNT:
			ta_state = T_COUNT;		// fall through
		case T_STOP:
			goto ta_idle;
		case T_LOAD_THEN_STOP:
			ta_state = T_STOP;
			ta = latcha;			// Reload timer
			goto ta_idle;
		case T_LOAD_THEN_COUNT:
			ta_state = T_COUNT;
			ta = latcha;			// Reload timer
			goto ta_idle;
		case T_LOAD_THEN_WAIT_THEN_COUNT:
			ta_state = T_WAIT_THEN_COUNT;
			if (ta == 1)
				goto ta_interrupt;	// Interrupt if timer == 1
			else 
			{
				ta = latcha;		// Reload timer
				goto ta_idle;
			}
		case T_COUNT:
			goto ta_count;
		case T_COUNT_THEN_STOP:
			ta_state = T_STOP;
			goto ta_count;
	}

	// Count timer A
ta_count:
	if (ta_cnt_phi2)
	{
  	if(ta > 0)
  	  ta = ta - (CyclesTillAction - CyclesTillActionCnt);
		if (!ta)
		{				// underflow?
			if (ta_state != T_STOP) 
			{
ta_interrupt:
				ta = latcha;			// Reload timer
				ta_irq_next_cycle = true; // Trigger interrupt in next cycle
				icr |= 1;				// But set ICR bit now

				if (cra & 8) {			// One-shot?
					cra &= 0xfe;		// Yes, stop timer
					new_cra &= 0xfe;
					ta_state = T_LOAD_THEN_STOP;	// Reload in next cycle
				} else
					ta_state = T_LOAD_THEN_COUNT;	// No, delay one cycle (and reload)
			}
			ta_underflow = true;
		}
  }

	// Delayed write to CRA?
ta_idle:
	if (has_new_cra) 
	{
		switch (ta_state) 
		{
			case T_STOP:
			case T_LOAD_THEN_STOP:
				if (new_cra & 1) {		// Timer started, wasn't running
					if (new_cra & 0x10)	// Force load
						ta_state = T_LOAD_THEN_WAIT_THEN_COUNT;
					else				// No force load
						ta_state = T_WAIT_THEN_COUNT;
				} else {				// Timer stopped, was already stopped
					if (new_cra & 0x10)	// Force load
						ta_state = T_LOAD_THEN_STOP;
				}
				break;
			case T_COUNT:
				if (new_cra & 1) {		// Timer started, was already running
					if (new_cra & 0x10)	// Force load
						ta_state = T_LOAD_THEN_WAIT_THEN_COUNT;
				} else {				// Timer stopped, was running
					if (new_cra & 0x10)	// Force load
						ta_state = T_LOAD_THEN_STOP;
					else				// No force load
						ta_state = T_COUNT_THEN_STOP;
				}
				break;
			case T_LOAD_THEN_COUNT:
			case T_WAIT_THEN_COUNT:
				if (new_cra & 1) {
					if (new_cra & 8) {		// One-shot?
						new_cra &= 0xfe;	// Yes, stop timer
						ta_state = T_STOP;
					} else if (new_cra & 0x10)	// Force load
						ta_state = T_LOAD_THEN_WAIT_THEN_COUNT;
				} else {
					ta_state = T_STOP;
				}
				break;
		}
		cra = new_cra & 0xef;
		has_new_cra = false;
	}

	// Timer B state machine
	switch (tb_state) 
	{
		case T_WAIT_THEN_COUNT:
			tb_state = T_COUNT;		// fall through
		case T_STOP:
			goto tb_idle;
		case T_LOAD_THEN_STOP:
			tb_state = T_STOP;
			tb = latchb;			// Reload timer
			goto tb_idle;
		case T_LOAD_THEN_COUNT:
			tb_state = T_COUNT;
			tb = latchb;			// Reload timer
			goto tb_idle;
		case T_LOAD_THEN_WAIT_THEN_COUNT:
			tb_state = T_WAIT_THEN_COUNT;
			if (tb == 1)
				goto tb_interrupt;	// Interrupt if timer == 1
			else {
				tb = latchb;		// Reload timer
				goto tb_idle;
			}
		case T_COUNT:
			goto tb_count;
		case T_COUNT_THEN_STOP:
			tb_state = T_STOP;
			goto tb_count;
	}

	// Count timer B
tb_count:
	if (tb_cnt_phi2 || (tb_cnt_ta && ta_underflow))
	{
    if(tb > 0)
    {
      if(tb_cnt_phi2)
        tb = tb - (CyclesTillAction - CyclesTillActionCnt);
      else
        --tb;
    }
		if (!tb) 
		{				// underflow?
			if (tb_state != T_STOP) 
			{
tb_interrupt:
				tb = latchb;			// Reload timer
				tb_irq_next_cycle = true; // Trigger interrupt in next cycle
				icr |= 2;				// But set ICR bit now

				if (crb & 8) {			// One-shot?
					crb &= 0xfe;		// Yes, stop timer
					new_crb &= 0xfe;
					tb_state = T_LOAD_THEN_STOP;	// Reload in next cycle
				} else
					tb_state = T_LOAD_THEN_COUNT;	// No, delay one cycle (and reload)
			}
		}
  }

	// Delayed write to CRB?
tb_idle:
	if (has_new_crb) 
	{
		switch (tb_state) 
		{
			case T_STOP:
			case T_LOAD_THEN_STOP:
				if (new_crb & 1) {		// Timer started, wasn't running
					if (new_crb & 0x10)	// Force load
						tb_state = T_LOAD_THEN_WAIT_THEN_COUNT;
					else				// No force load
						tb_state = T_WAIT_THEN_COUNT;
				} else {				// Timer stopped, was already stopped
					if (new_crb & 0x10)	// Force load
						tb_state = T_LOAD_THEN_STOP;
				}
				break;
			case T_COUNT:
				if (new_crb & 1) {		// Timer started, was already running
					if (new_crb & 0x10)	// Force load
						tb_state = T_LOAD_THEN_WAIT_THEN_COUNT;
				} else {				// Timer stopped, was running
					if (new_crb & 0x10)	// Force load
						tb_state = T_LOAD_THEN_STOP;
					else				// No force load
						tb_state = T_COUNT_THEN_STOP;
				}
				break;
			case T_LOAD_THEN_COUNT:
			case T_WAIT_THEN_COUNT:
				if (new_crb & 1) {
					if (new_crb & 8) {		// One-shot?
						new_crb &= 0xfe;	// Yes, stop timer
						tb_state = T_STOP;
					} else if (new_crb & 0x10)	// Force load
						tb_state = T_LOAD_THEN_WAIT_THEN_COUNT;
				} else {
					tb_state = T_STOP;
				}
				break;
		}
		crb = new_crb & 0xef;
		has_new_crb = false;
	}

  // Calculate cycles till next action
  CyclesTillAction = 65535;

  if(ta_state == T_COUNT)
  {
    if(ta_cnt_phi2 && ta > 0)
      CyclesTillAction = ta;
    else
      CyclesTillAction = 1;
  } 

  if((ta_state != T_COUNT && ta_state != T_STOP)
  || (tb_state != T_COUNT && tb_state != T_STOP)
  || ta_irq_next_cycle || tb_irq_next_cycle)
    CyclesTillAction = 1;

  if(tb_state == T_COUNT)
  {
    if(tb_cnt_phi2 && tb > 0)
    {
      if(tb < CyclesTillAction)
        CyclesTillAction = tb;
    }
    else
      CyclesTillAction = 1;
  } 

  //CyclesTillAction = 1;
  CyclesTillActionCnt = CyclesTillAction;
}


/*
 *  Count CIA TOD clock (called during VBlank)
 */

void MOS6526::CountTOD(void)
{
	uint8 lo, hi;

	// Decrement frequency divider
	if (tod_divider)
		tod_divider--;
	else {

		// Reload divider according to 50/60 Hz flag
		if (cra & 0x80)
			tod_divider = 4;
		else
			tod_divider = 5;

		// 1/10 seconds
		tod_10ths++;
		if (tod_10ths > 9) {
			tod_10ths = 0;

			// Seconds
			lo = (tod_sec & 0x0f) + 1;
			hi = tod_sec >> 4;
			if (lo > 9) {
				lo = 0;
				hi++;
			}
			if (hi > 5) {
				tod_sec = 0;

				// Minutes
				lo = (tod_min & 0x0f) + 1;
				hi = tod_min >> 4;
				if (lo > 9) {
					lo = 0;
					hi++;
				}
				if (hi > 5) {
					tod_min = 0;

					// Hours
					lo = (tod_hr & 0x0f) + 1;
					hi = (tod_hr >> 4) & 1;
					tod_hr &= 0x80;		// Keep AM/PM flag
					if (lo > 9) {
						lo = 0;
						hi++;
					}
					tod_hr |= (hi << 4) | lo;
					if ((tod_hr & 0x1f) > 0x11)
						tod_hr = tod_hr & 0x80 ^ 0x80;
				} else
					tod_min = (hi << 4) | lo;
			} else
				tod_sec = (hi << 4) | lo;
		}

		// Alarm time reached? Trigger interrupt if enabled
		if (tod_10ths == alm_10ths && tod_sec == alm_sec &&
			tod_min == alm_min && tod_hr == alm_hr)
			TriggerInterrupt(4);
	}
}

void MOS6526::TriggerInterrupt(int bit)
{
	if (type==1)
		((MOS6526_1 *) this)->TriggerInterrupt(bit);
	else if (type==2)
		((MOS6526_2 *) this)->TriggerInterrupt(bit);
}

// Handle additional information for each CIA on GetState/SetState
uint8 MOS6526::GetMoreInfo()
{
	if (type==1)
		return ((MOS6526_1 *) this)->GetMoreInfo();
	else if (type==2)
		return ((MOS6526_2 *) this)->GetMoreInfo();
	return 0; // Keep the compiler happy
}
void MOS6526::SetMoreInfo(uint8 value)
{
	if (type==1)
		((MOS6526_1 *) this)->SetMoreInfo(value);
	else if (type==2)
		((MOS6526_2 *) this)->SetMoreInfo(value);
}

uint8 MOS6526_1::GetMoreInfo()
{
  return prev_lp;
}
void MOS6526_1::SetMoreInfo(uint8 value)
{
  prev_lp = value;
}
uint8 MOS6526_2::GetMoreInfo()
{
  return IECLines;
}
void MOS6526_2::SetMoreInfo(uint8 value)
{
  IECLines = value;
}


/*
 *  Trigger IRQ (CIA 1)
 */

void MOS6526_1::TriggerInterrupt(int bit)
{
	icr |= bit;
	if (int_mask & bit) {
		icr |= 0x80;
		the_cpu->TriggerCIAIRQ();
	}
}


/*
 *  Trigger NMI (CIA 2)
 */

void MOS6526_2::TriggerInterrupt(int bit)
{
	icr |= bit;
	if (int_mask & bit) {
		icr |= 0x80;
		the_cpu->TriggerNMI();
	}
}


void MOS6526::EmulateLine(int cycles)
{
	unsigned long tmp;

	// Timer A
	if (ta_cnt_phi2) {
		ta = tmp = ta - cycles;		// Decrement timer

		if (tmp > 0xffff) {			// Underflow?
			ta = latcha;			// Reload timer

			if (cra & 8) {			// One-shot?
				cra &= 0xfe;
				ta_cnt_phi2 = false;
			}
			TriggerInterrupt(1);
			if (tb_cnt_ta) {		// Timer B counting underflows of Timer A?
				tb = tmp = tb - 1;	// tmp = --tb doesn't work
				if (tmp > 0xffff) goto tb_underflow;
			}
		}
	}

	// Timer B
	if (tb_cnt_phi2) {
		tb = tmp = tb - cycles;		// Decrement timer

		if (tmp > 0xffff) {			// Underflow?
tb_underflow:
			tb = latchb;

			if (crb & 8) {			// One-shot?
				crb &= 0xfe;
				tb_cnt_phi2 = false;
				tb_cnt_ta = false;
			}
			TriggerInterrupt(2);
		}
	}
}

