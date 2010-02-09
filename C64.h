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
 *  C64.h - Put the pieces together
 *
 *  Frodo (C) 1994-1997,2002 Christian Bauer
 */

#ifndef _C64_H
#define _C64_H

#include "frodo_types.h"
#include <CoreFoundation/CFDate.h>
#include "Prefs.h"

#if !defined(_DISTRIBUTION)
#define NPERFORMANCE_COUNTERS
#define NPROFILE_VBLANK
#endif

class C64Display;
class MOS6510;
class MOS6569;
class MOS6581;
class MOS6526_1;
class MOS6526_2;
class IEC;
class MOS6502_1541;
class Job1541;
class CmdPipe;
class Keyboard;
class CTouchStick;
class CJoyStick;
struct lua_State;

class C64 {
public:
	C64();
	~C64();

	void Run(bool autoBoot);
	void Quit(void);
	void Pause(void);
	void Resume(void);
	void Reset(void);
	
	void ResetAndAutoboot();
	
	bool InPauseLoop() {
		return in_pause_loop;
	}
	
	bool IsEmulatorRunning() {
		return thread_running;
	}
	
	void NMI(void);
	void VBlank(bool draw_frame);
	void NewPrefs(Prefs *prefs);
	void PatchKernal(bool fast_reset, bool emul_1541_proc);
	
	void SaveSnapshot(uint8 *block1, uint8 *block2);
	bool LoadSnapshot(uint8 *block1, uint8 *block2);
	uint32 SaveCPUState(uint8 *p1, uint8 *p2);
	uint32 Save1541State(uint8 *p);
	uint16 Save1541JobState(uint8 *p);
	uint16 SaveVICState(uint8 *p);
	uint16 SaveSIDState(uint8 *p);
	uint16 SaveCIAState(uint8 *p);
	uint16 LoadCPUState(uint8 *p1, uint8 *p2);
	uint16 Load1541State(uint8 *p);
	uint16 Load1541JobState(uint8 *p);
	uint16 LoadVICState(uint8 *p);
	uint16 LoadSIDState(uint8 *p);
	uint16 LoadCIAState(uint8 *p);
	
	uint16 LoadCPUStateOld(uint8 *p1, uint8 *p2);
	uint16 Load1541StateOld(uint8 *p);
	uint16 LoadVICStateOld(uint8 *p);
	uint16 LoadCIAStateOld(uint8 *p);
	
	inline uint32 getNow() {
		double now = CFAbsoluteTimeGetCurrent();
		now = now - time_start;
		return (uint32)(now * 1000000UL);
	};
	
#ifdef PERFORMANCE_COUNTERS
	inline double getAverageSpeed() {
		return average_speed;
	}
#endif

	uint8 *RAM;
	uint8 *Basic, *Kernal, *Char, *Color;		// C64
	uint8 *IO_Ram; // Simulate RAM if jmp $dxxxx occurs
	uint8 *RAM1541, *ROM1541;	// 1541

	C64Display *TheDisplay;
	Keyboard *TheKeyboard;		// virtual keyboard to push events
	CJoyStick *TheJoyStick;

	MOS6510 *TheCPU;			// C64
	MOS6569 *TheVIC;
	MOS6581 *TheSID;
	MOS6526_1 *TheCIA1;
	MOS6526_2 *TheCIA2;
	IEC *TheIEC;

	MOS6502_1541 *TheCPU1541;	// 1541
	Job1541 *TheJob1541;

	uint32 CycleCounter;
		
#pragma mark Private Members
private:
	static trap_result_t auto_boot(MOS6510 *TheCPU, void *d);
	static trap_result_t intercept_ready_handler(MOS6510 *TheCPU, void *d);
	
	void installAutoBootHandler();
	void installReadyHandler();
	void installStartupRoutine();
	
	void installLuaScript();
	
	void c64_ctor1(void);
	uint8 poll_joystick(int port);
	void thread_func(void);

	bool thread_running;	// Emulation thread is running
	bool quit_thyself;		// Emulation thread shall quit
	bool have_a_break;		// Emulation thread shall pause
	bool in_pause_loop;

	int joy_minx, joy_maxx, joy_miny, joy_maxy; // For dynamic joystick calibration

	uint8 orig_kernal_1d84,	// Original contents of kernal locations $1d84 and $1d85
		  orig_kernal_1d85;	// (for undoing the Fast Reset patch)
	
	uint32 tv_start, time_last;
	double speed_index;
	static double time_start;
	
	lua_State *LUA;

#ifdef PERFORMANCE_COUNTERS
	double		average_speed, total_speed;
	int			frames;
#endif
	
public:
	CmdPipe *gui;
	uint8 Random();
	void SeedRandom(uint32);
private:
	uint32 seed;
	bool SwitchToSC;
	bool SwitchToStandard;
};


#endif
