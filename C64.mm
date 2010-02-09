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
 *  C64.cpp - Put the pieces together
 *
 *  Frodo (C) 1994-1997,2002 Christian Bauer
 */

#include "sysdeps.h"

#include "C64.h"
#include "CPUC64.h"
#include "CPU1541.h"
#include "VIC.h"
#include "SID.h"
#include "CIA.h"
#include "IEC.h"
#include "1541job.h"
#include "Display.h"
#include "Prefs.h"
#include "Keyboard.h"
#include "JoyStick.h"
#include <sys/time.h>
#include "frodo_lua.h"

const double FRAME_TIMER = 1 / (double)SCREEN_FREQ;
double C64::time_start = CFAbsoluteTimeGetCurrent();

/*
 *  Constructor: Allocate objects and memory
 */

C64::C64()
{
	int i,j;
	uint8 *p;
	
	// The thread is not yet running
	thread_running = false;
	quit_thyself = false;
	have_a_break = false;
	in_pause_loop = false;
	
	// System-dependent things
	c64_ctor1();
	
	// Allocate virtual keyboard
	TheKeyboard = new Keyboard();
	
	TheJoyStick = &gTheJoystick;
	
	// Open display
	TheDisplay = new C64Display(this);
	
	// Allocate RAM/ROM memory
	RAM = new uint8[0x10000];
	Basic = new uint8[0x2000];
	Kernal = new uint8[0x2000];
	Char = new uint8[0x1000];
	Color = new uint8[0x0400];
	RAM1541 = new uint8[0x0800];
	ROM1541 = new uint8[0x4000];
	IO_Ram = new uint8[0x1000];
	
	// Create the chips
	TheCPU = new MOS6510(this, RAM, Basic, Kernal, Char, Color, IO_Ram);
	
	TheJob1541 = new Job1541(RAM1541);
	TheCPU1541 = new MOS6502_1541(this, TheJob1541, TheDisplay, RAM1541, ROM1541);
	
	TheVIC = TheCPU->TheVIC = new MOS6569(this, TheDisplay, TheCPU, RAM, Char, Color);
	TheSID = TheCPU->TheSID = new MOS6581(this);
	TheCIA1 = TheCPU->TheCIA1 = new MOS6526_1(TheCPU, TheVIC);
	TheCIA2 = TheCPU->TheCIA2 = TheCPU1541->TheCIA2 = new MOS6526_2(TheCPU, TheVIC, TheCPU1541);
	TheIEC = TheCPU->TheIEC = new IEC(TheDisplay);
	
	// Initialize RAM with powerup pattern
	for (i=0, p=RAM; i<512; i++) {
		for (j=0; j<64; j++)
			*p++ = 0;
		for (j=0; j<64; j++)
			*p++ = 0xff;
	}
	
	// Initialize color RAM with random values
	for (i=0, p=Color; i<1024; i++)
	{
		*p++ = Random() & 0x0f;
	}
	// Clear 1541 RAM
	memset(RAM1541, 0, 0x800);
	
	CycleCounter = 0;
	
	SwitchToSC = false;
	SwitchToStandard = false;
	
	LUA = NULL;
}


/*
 *  Destructor: Delete all objects
 */

C64::~C64()
{
	TheCPU->ClearTraps();
	if (LUA) {
		lua_closeFrodo(LUA);
	}
	
	delete TheJob1541;
	delete TheIEC;
	delete TheCIA2;
	delete TheCIA1;
	delete TheSID;
	delete TheVIC;
	delete TheCPU1541;
	delete TheCPU;
	delete TheDisplay;
	delete TheKeyboard;
	delete TheJoyStick;
	
	delete[] RAM;
	delete[] Basic;
	delete[] Kernal;
	delete[] Char;
	delete[] Color;
	delete[] RAM1541;
	delete[] ROM1541;
	delete[] IO_Ram;
}


/*
 *  Reset C64
 */

void C64::Reset(void)
{
	// clear existing traps
	TheCPU->ClearTraps();

	TheCPU->AsyncReset();
	TheCPU1541->AsyncReset();
	TheSID->Reset();
	TheCIA1->Reset();
	TheCIA2->Reset();
	TheIEC->Reset();
}

bool auto_booting = false;

trap_result_t C64::auto_boot(MOS6510 *TheCPU, void *d) {
	TheCPU->the_c64->TheKeyboard->QueueKeyEvent(KeyCode_SHIFT_RUNSTOP, KeyStateDown);
	TheCPU->the_c64->TheKeyboard->QueueKeyEvent(Keyboard::HoldKey);
	TheCPU->the_c64->TheKeyboard->QueueKeyEvent(KeyCode_SHIFT_RUNSTOP, KeyStateUp);
	return TRAP_REPLACE_AND_REDO;
}

trap_result_t C64::intercept_ready_handler(MOS6510 *TheCPU, void *d) {
	if (auto_booting) return TRAP_REDO;
	
	TheCPU->the_c64->installStartupRoutine();
	TheCPU->AsyncReset();
	return TRAP_REDO;
}

// Resets the C64 and auto-boots the currently loaded disk image
void C64::ResetAndAutoboot() {
	// re-enables standard boot sequence
	Kernal[0x039b] = 0x22;
	Kernal[0x039c] = 0xe4;

	Reset();
	installAutoBootHandler();
}

void C64::installAutoBootHandler() {
	static trap_t trap = { NULL, false, 0xE5CD, 0xA5, 0xC6, 0x85, (trap_handler_t)&C64::auto_boot, NULL, NULL };
	installLuaScript();
	TheCPU->InstallTrap(&trap);
}

void C64::installReadyHandler() {
	static trap_t trap = { NULL, false, 0xA47D, 0x20, 0x90, 0xFF, (trap_handler_t)&C64::intercept_ready_handler, NULL, NULL };
	TheCPU->InstallTrap(&trap);
}

void C64::installLuaScript() {
	TheCPU->ClearTraps();

	// run lua script
	if (LUA) {
		lua_closeFrodo(LUA);
		LUA = NULL;
	}
	
	if (ThePrefs.LuaScriptPath[0] != '\0') {
		LUA = lua_openFrodo(ThePrefs.LuaScriptPath);
	}
}	

/*
 *  NMI C64
 */

void C64::NMI(void)
{
	TheCPU->AsyncNMI();
}


/*
 *  The preferences have changed. prefs is a pointer to the new
 *   preferences, ThePrefs still holds the previous ones.
 *   The emulation must be in the paused state!
 */

void C64::NewPrefs(Prefs *prefs)
{
	PatchKernal(prefs->FastReset, prefs->Emul1541Proc);
	TheIEC->NewPrefs(prefs);
	TheJob1541->NewPrefs(prefs);
	TheSID->NewPrefs(prefs);
	TheVIC->NewPrefs(prefs);
	
	if(!ThePrefs.SingleCycleEmulation && prefs->SingleCycleEmulation)
	{
		// Single cycle emulation switched on
		SwitchToSC = true;
	}
	
	if(ThePrefs.SingleCycleEmulation && !prefs->SingleCycleEmulation)
	{
		// Single cycle emulation switched off
		SwitchToStandard = true;
	}
	// Reset 1541 processor if turned on
	if (!ThePrefs.Emul1541Proc && prefs->Emul1541Proc)
	{
		TheCPU1541->AsyncReset();
	}
}

/* this patch changes the startup message to 
   *** COMMODORE 64 EXPERIENCE ***
   ...
 */
const unsigned char kernal_patch1[] = {
	0x20,0x41,0x56,0x41,0x49,0x4c,0x41,0x42,
	0x4c,0x45,0x20,0x42,0x59,0x54,0x45,0x53,
	0x20,0x0d,0x00,0x93,0x0d,0x20,0x20,0x20,
	0x20,0x2a,0x2a,0x2a,0x20,0x43,0x4f,0x4d,
	0x4d,0x4f,0x44,0x4f,0x52,0x45,0x20,0x36,
	0x34,0x20,0x45,0x58,0x50,0x45,0x52,0x49,
	0x45,0x4e,0x43,0x45,0x20,0x2a,0x2a,0x2a,
	0x0d,0x0d,0x20,0x36,0x34,0x4b,0x20,0x52,
	0x41,0x4d,0x20,0x53,0x59,0x53,0x54,0x45,
	0x4d,0x20,0x20,0x00
};

const int kernal_patch1_size = sizeof(kernal_patch1) / sizeof(kernal_patch1[0]);

/* this is a patch to remove BASIC commands, leaving
 * LIST, RUN and SYS
 */
const unsigned char basic_patch1[] = {
	0x01,0x01,0xc4,0x01,0x01,0xd2,0x01,0x01,
	0x01,0xd4,0x01,0x01,0x01,0xc1,0x01,0x01,
	0x01,0x01,0x01,0xa3,0x01,0x01,0x01,0x01,
	0xd4,0x01,0x01,0xcd,0x01,0x01,0x01,0xc4,
	0x01,0x01,0xd4,0x01,0x01,0x01,0xcf,0x52,
	0x55,0xce,0x01,0xc6,0x01,0x01,0x01,0x01,
	0x01,0x01,0xc5,0x01,0x01,0x01,0x01,0xc2,
	0x01,0x01,0x01,0x01,0x01,0xce,0x01,0x01,
	0xcd,0x01,0x01,0x01,0xd0,0x01,0xce,0x01,
	0x01,0x01,0xd4,0x4c,0x4f,0x41,0xc4,0x01,
	0x01,0x01,0xc5,0x01,0x01,0x01,0x01,0x01,
	0xd9,0x01,0x01,0xc6,0x01,0x01,0x01,0xc5,
	0x01,0x01,0x01,0x01,0x01,0xa3,0x01,0x01,
	0x01,0x01,0xd4,0x01,0x01,0x01,0xd4,0x01,
	0x01,0x01,0xd4,0x01,0x01,0xd2,0x01,0x01,
	0xc4,0x53,0x59,0xd3,0x01,0x01,0x01,0xce,
	0x01,0x01,0x01,0x01,0xc5,0x01,0x01,0xd4,
	0x01,0x01,0xd7,0x01,0x01,0x01,0xa8,0x01,
	0xcf,0x01,0xce,0x01,0x01,0x01,0xa8,0x01,
	0x01,0x01,0xce,0x01,0x01,0xd4,0x01,0x01,
	0x01,0xd0,0xab,0xad,0xaa,0xaf,0xde,0x01,
	0x01,0xc4,0x01,0xd2,0xbe,0xbd,0xbc,0x01,
	0x01,0xce,0x01,0x01,0xd4,0x01,0x01,0xd3,
	0x01,0x01,0xd2,0x01,0x01,0xc5,0x01,0x01,
	0xd3,0x01,0x01,0xd2,0x01,0x01,0xc4,0x01,
	0x01,0xc7,0x01,0x01,0xd0,0x01,0x01,0xd3,
	0x01,0x01,0xce,0x01,0x01,0xce,0x01,0x01,
	0xce,0x01,0x01,0x01,0xcb,0x01,0x01,0xce,
	0x01,0x01,0x01,0xa4,0x01,0x01,0xcc,0x01,
	0x01,0xc3,0x01,0x01,0x01,0xa4,0x01,0x01,
	0x01,0x01,0xa4,0x01,0x01,0x01,0x01,0x01,
	0xa4,0x01,0x01,0x01,0xa4,0x01,0xcf,0x00
};

const int patch1_size = sizeof(basic_patch1) / sizeof(basic_patch1[0]);

const unsigned char boot_message[] = {
	0x20, 0x44, 0xE5, 0xA9, 0x73, 0xA0, 0xE4, 0x20,
	0x1E, 0xAB, 0xAD, 0x37, 0x00, 0x38, 0xED, 0x2B,
	0x00, 0xAA, 0xAD, 0x38, 0x00, 0xED, 0x2C, 0x00,
	0x20, 0xCD, 0xBD, 0xA9, 0x60, 0xA0, 0xE4, 0x20,
	0x1E, 0xAB, 0xA9, 0x00, 0xA0, 0xC1, 0x20, 0x1E,
	0xAB, 0xA9, 0x00, 0x85, 0xD3, 0x85, 0xCA, 0x85,
	0xCC, 0xA9, 0x0A, 0x85, 0xD6, 0x85, 0xC9, 0x58,
	0xEA, 0x4C, 0x38, 0xC0,
};

const int boot_message_size = sizeof(boot_message) / sizeof(boot_message[0]);

void C64::installStartupRoutine() {
	// add our startup routine
	for (int i=0xc000, j=0; j<boot_message_size; i++, j++) {
		RAM[i] = boot_message[j];
	}
	
	const char* MANOMIO_MESSAGE = 
	//0123456789012345678901234567890123456789
	"\r\r\r\r"
	"   **** COMMODORE 64 FOR IPHONE ****\r\r"
	"            BY MANOMIO LLC\r\r"
	"READY.\r";
	const char* p = MANOMIO_MESSAGE;
	int len = strlen(MANOMIO_MESSAGE);
	for (int i=0xc100, j=0; j <= len; j++, i++) {
		RAM[i] = p[j];
	}
	
	Kernal[0x039b] = 0x00;
	Kernal[0x039c] = 0xc0;
}

/*
 *  Patch kernal IEC routines
 */

void C64::PatchKernal(bool fast_reset, bool emul_1541_proc)
{
	if (fast_reset) {
		Kernal[0x1d84] = 0xa0;
		Kernal[0x1d85] = 0x00;
	} else {
		Kernal[0x1d84] = orig_kernal_1d84;
		Kernal[0x1d85] = orig_kernal_1d85;
	}
	
	if (emul_1541_proc) {
		Kernal[0x0d40] = 0x78;
		Kernal[0x0d41] = 0x20;
		Kernal[0x0d23] = 0x78;
		Kernal[0x0d24] = 0x20;
		Kernal[0x0d36] = 0x78;
		Kernal[0x0d37] = 0x20;
		Kernal[0x0e13] = 0x78;
		Kernal[0x0e14] = 0xa9;
		Kernal[0x0def] = 0x78;
		Kernal[0x0df0] = 0x20;
		Kernal[0x0dbe] = 0xad;
		Kernal[0x0dbf] = 0x00;
		Kernal[0x0dcc] = 0x78;
		Kernal[0x0dcd] = 0x20;
		Kernal[0x0e03] = 0x20;
		Kernal[0x0e04] = 0xbe;
	} else {
		Kernal[0x0d40] = 0xf2;	// IECOut
		Kernal[0x0d41] = 0x00;
		Kernal[0x0d23] = 0xf2;	// IECOutATN
		Kernal[0x0d24] = 0x01;
		Kernal[0x0d36] = 0xf2;	// IECOutSec
		Kernal[0x0d37] = 0x02;
		Kernal[0x0e13] = 0xf2;	// IECIn
		Kernal[0x0e14] = 0x03;
		Kernal[0x0def] = 0xf2;	// IECSetATN
		Kernal[0x0df0] = 0x04;
		Kernal[0x0dbe] = 0xf2;	// IECRelATN
		Kernal[0x0dbf] = 0x05;
		Kernal[0x0dcc] = 0xf2;	// IECTurnaround
		Kernal[0x0dcd] = 0x06;
		Kernal[0x0e03] = 0xf2;	// IECRelease
		Kernal[0x0e04] = 0x07;
	}
	
	// 1541
	ROM1541[0x2ae4] = 0xea;		// Don't check ROM checksum
	ROM1541[0x2ae5] = 0xea;
	ROM1541[0x2ae8] = 0xea;
	ROM1541[0x2ae9] = 0xea;
	ROM1541[0x2c9b] = 0xf2;		// DOS idle loop
	ROM1541[0x2c9c] = 0x00;
	ROM1541[0x3594] = 0x20;		// Write sector
	ROM1541[0x3595] = 0xf2;
	ROM1541[0x3596] = 0xf5;
	ROM1541[0x3597] = 0xf2;
	ROM1541[0x3598] = 0x01;
	ROM1541[0x3b0c] = 0xf2;		// Format track
	ROM1541[0x3b0d] = 0x02;
	
	//return;
	// disable STOP key in basic, to prevent disks / tapes from loading
	// CMP #$80 (replaces CMP #$7F, which tests STOP key)
	// $80 is just a dummy value
	Kernal[0x16f0]	= 0x80;	
	
	Basic[0x059d]		= 0xFF;	// disable ? (PRINT) command
	Basic[0x05a5]		= 0xFF;	// disable ability to enter line numbers
	
	// remove basic commands
	for (int i=0x9e, j=0; i < 0x9e + 0x100; i++, j++) {
		Basic[i] = basic_patch1[j];
	}
	
	// update BASIC startup message
	for (int i=0x460, j=0; i < 0x460+0x4c; i++, j++) {
		Kernal[i] = kernal_patch1[j];
	}
	
	installStartupRoutine();
}


/*
 *  Save CPU state to snapshot
 *
 *  number of bytes written to p2 (p1 always 0x9000)
 */

uint32 C64::SaveCPUState(uint8 *p1, uint8 *p2)
{
	MOS6510State *state = (MOS6510State *) (((UInt32) p2+0x8000+0x403) & 0xfffffffc);
	TheCPU->GetState(state);
	
	memcpy(p1, RAM, 0x8000);
	memcpy(p1+0x8000, IO_Ram, 0x1000);
	memcpy(p2, RAM + 0x8000, 0x8000);
	memcpy(p2+0x8000, Color, 0x400);
	
	// p1 now contains 36k of memory
	// p2 contains other 32k, then Color and CPU state
	
	return ((UInt32) state + sizeof(MOS6510State) - (UInt32) p2);
}


/*
 *  Load CPU state from snapshot
 */

uint16 C64::LoadCPUState(uint8 *p1, uint8 *p2)
{
	MOS6510State *state = (MOS6510State *) (((UInt32) p2+0x8000+0x403) & 0xfffffffc);
	
	memcpy(RAM, p1, 0x8000);
	memcpy(IO_Ram, p1+0x8000, 0x1000);
	memcpy(RAM + 0x8000, p2, 0x8000);
	memcpy(Color, p2+0x8000, 0x400);
	TheCPU->SetState(state);
	
	return ((UInt32) state + sizeof(MOS6510State) - (UInt32) p2);
}

uint16 C64::LoadCPUStateOld(uint8 *p1, uint8 *p2)
{
	MOS6510State state;
	MOS6510StateOld *stateOld = (MOS6510StateOld *) (((UInt32) p2+0x8000+0x403) & 0xfffffffc);
	
	state.ar = 0;
	state.ar2 = 0;			// Address registers
	state.state = 0;
	state.op = 0;		// Current state and opcode
	state.rdbuf = 0;			// Data buffer for RMW instructions
	
	state.a = stateOld->a;
	state.x = stateOld->x;
	state.y = stateOld->y;
	state.p = stateOld->p;			// Processor flags
	state.ddr = stateOld->ddr;
	state.pr = stateOld->pr;		// Port
	state.pc = stateOld->pc;
	state.sp = stateOld->sp;
	state.intr[0] = stateOld->intr[0];		// Interrupt state
	state.intr[1] = stateOld->intr[1];
	state.intr[2] = stateOld->intr[2];
	state.intr[3] = stateOld->intr[3];
	state.nmi_state = stateOld->nmi_state;	
	state.dfff_byte = stateOld->dfff_byte;
	state.basic_in = stateOld->basic_in;
	state.kernal_in = stateOld->kernal_in;
	state.char_in = stateOld->char_in;
	state.io_in = stateOld->io_in;
	
	memcpy(RAM, p1, 0x8000);
	memcpy(IO_Ram, p1+0x8000, 0x1000);
	memcpy(RAM + 0x8000, p2, 0x8000);
	memcpy(Color, p2+0x8000, 0x400);
	TheCPU->SetState(&state);
	
	return ((UInt32) stateOld + sizeof(MOS6510StateOld) - (UInt32) p2);
}


/*
 *  Save 1541 state to snapshot
 *
 *  number of bytes written to p
 */

uint32 C64::Save1541State(uint8 *p)
{
	MOS6502State *state =  (MOS6502State *) ((UInt32) (p+0x803) & 0xfffffffc);
	TheCPU1541->GetState(state);
	
	memcpy(p, RAM1541, 0x800);
	
	return ((UInt32) state + sizeof(MOS6502State) - (UInt32) p);
}


/*
 *  Load 1541 state from snapshot
 */

uint16 C64::Load1541State(uint8 *p)
{
	MOS6502State *state = (MOS6502State *) ((UInt32) (p+0x803) & 0xfffffffc);
	
	memcpy(RAM1541, p, 0x800);
	TheCPU1541->SetState(state);
	
	return ((UInt32) state + sizeof(MOS6502State) - (UInt32) p);
}

uint16 C64::Load1541StateOld(uint8 *p)
{
	MOS6502State state;
	MOS6502StateOld *stateOld = (MOS6502StateOld *) ((UInt32) (p+0x803) & 0xfffffffc);
	
	memcpy(&state, stateOld, sizeof(MOS6502StateOld));
	state.ar = 0;
	state.ar2 = 0;
	state.state = 0;
	state.op = 0;
	state.rdbuf = 0;
	
	memcpy(RAM1541, p, 0x800);
	TheCPU1541->SetState(&state);
	
	return ((UInt32) stateOld + sizeof(MOS6502StateOld) - (UInt32) p);
}


/*
 *  Save VIC state to snapshot
 */

uint16 C64::SaveVICState(uint8 *p)
{
	MOS6569State *state = (MOS6569State *) (((UInt32) p+3) & 0xfffffffc);
	TheVIC->GetState(state);
	return ((UInt32) state + sizeof(MOS6569State) - (UInt32) p);
}


/*
 *  Load VIC state from snapshot
 */

uint16 C64::LoadVICState(uint8 *p)
{
	MOS6569State *state = (MOS6569State *) (((UInt32) p+3) & 0xfffffffc);
	
	TheVIC->SetState(state);
	return ((UInt32) state + sizeof(MOS6569State) - (UInt32) p);
}

uint16 C64::LoadVICStateOld(uint8 *p)
{
	int i;
	MOS6569State state;
	MOS6569StateOld *stateOld = (MOS6569StateOld *) (((UInt32) p+3) & 0xfffffffc);
	
	state.m0x = stateOld->m0x;
	state.m0y = stateOld->m0y;
	state.m1x = stateOld->m1x;
	state.m1y = stateOld->m1y;
	state.m2x = stateOld->m2x;
	state.m2y = stateOld->m2y;
	state.m3x = stateOld->m3x;
	state.m3y = stateOld->m3y;
	state.m4x = stateOld->m4x;
	state.m4y = stateOld->m4y;
	state.m5x = stateOld->m5x;
	state.m5y = stateOld->m5y;
	state.m6x = stateOld->m6x;
	state.m6y = stateOld->m6y;
	state.m7x = stateOld->m7x;
	state.m7y = stateOld->m7y;
	state.mx8 = stateOld->mx8;
	if(state.mx8 & 0x01) state.m0x += 256;
	if(state.mx8 & 0x02) state.m1x += 256;
	if(state.mx8 & 0x04) state.m2x += 256;
	if(state.mx8 & 0x08) state.m3x += 256;
	if(state.mx8 & 0x10) state.m4x += 256;
	if(state.mx8 & 0x20) state.m5x += 256;
	if(state.mx8 & 0x40) state.m6x += 256;
	if(state.mx8 & 0x80) state.m7x += 256;
	
	state.ctrl1 = stateOld->ctrl1;
	state.raster_y = stateOld->raster;
	state.lpx = stateOld->lpx;
	state.lpy = stateOld->lpy;
	state.me = stateOld->me;
	state.ctrl2 = stateOld->ctrl2;
	state.mye = stateOld->mye;
	state.vbase = stateOld->vbase;
	state.irq_flag = stateOld->irq_flag;
	state.irq_mask = stateOld->irq_mask;
	state.mdp = stateOld->mdp;
	state.mmc = stateOld->mmc;
	state.mxe = stateOld->mxe;
	state.clx_spr = stateOld->mm;
	state.clx_bgr = stateOld->md;
	
	state.ec = stateOld->ec;
	state.b0c = stateOld->b0c;
	state.b1c = stateOld->b1c;
	state.b2c = stateOld->b2c;
	state.b3c = stateOld->b3c;
	state.mm0 = stateOld->mm0;
	state.mm1 = stateOld->mm1;
	state.m0c = stateOld->m0c;
	state.m1c = stateOld->m1c;
	state.m2c = stateOld->m2c;
	state.m3c = stateOld->m3c;
	state.m4c = stateOld->m4c;
	state.m5c = stateOld->m5c;
	state.m6c = stateOld->m6c;
	state.m7c = stateOld->m7c;
	
	state.irq_raster = stateOld->irq_raster;		// IRQ raster line
	state.vc = stateOld->vc;				// Video counter
	state.vc_base = stateOld->vc_base;			// Video counter base
	state.rc = stateOld->rc;				// Row counter
	state.spr_dma = stateOld->spr_dma;			// 8 Flags: Sprite DMA active
	state.spr_disp = stateOld->spr_disp;			// 8 Flags: Sprite display active
	for(i=0; i<8; ++i)
		state.mc[i] = stateOld->mc[i];			// Sprite data counters
	for(i=0; i<8; ++i)
		state.mc_base[i] = stateOld->mc_base[i];		// Sprite data counter bases
	state.display_state = stateOld->display_state;		// true: Display state, false: Idle state
	state.bad_line = stateOld->bad_line;			// Flag: Bad Line state
	state.bad_line_enable = stateOld->bad_line_enable;	// Flag: Bad Lines enabled for this frame
	state.lp_triggered = stateOld->lp_triggered;		// Flag: Lightpen was triggered in this frame
	state.border_on = stateOld->border_on;			// Flag: Upper/lower border on (Frodo SC: Main border flipflop)
	state.frame_skipped = stateOld->frame_skipped;
	state.draw_this_line = false;
	
	state.bank_base = stateOld->bank_base;		// VIC bank base address
	state.matrix_base = stateOld->matrix_base;		// Video matrix base
	state.char_base = stateOld->char_base;		// Character generator base
	state.bitmap_base = stateOld->bitmap_base;		// Bitmap base
	
	state.spr_exp_y = ~state.mye;
	state.first_ba_cycle = 0;
	for(i=0; i<8; ++i)
		state.sprite_base[i] = 0;	// Sprite bases
	state.cycle = 0x102;				// Current cycle in line (1..63)
	state.raster_x = (UInt16) (0xfffc + 8 * 53);		// Current raster x position
	state.ml_index = 0;			// Index in matrix/color_line[]
	state.ud_border_on = true;		// Flag: Upper/lower border on
	
	TheVIC->SetState(&state);
	return ((UInt32) stateOld + sizeof(MOS6569StateOld) - (UInt32) p);
}

/*
 *  Save SID state to snapshot
 */

uint16 C64::SaveSIDState(uint8 *p)
{
	MOS6581State *state = (MOS6581State *) (((UInt32) p+3) & 0xfffffffc);
	TheSID->GetState(state);
	return ((UInt32) state + sizeof(MOS6581State) - (UInt32) p);
}


/*
 *  Load SID state from snapshot
 */

uint16 C64::LoadSIDState(uint8 *p)
{
	MOS6581State *state = (MOS6581State *) (((UInt32) p+3) & 0xfffffffc);
	
	TheSID->SetState(state);
	return ((UInt32) state + sizeof(MOS6581State) - (UInt32) p);
}


/*
 *  Save CIA states to snapshot
 */

uint16 C64::SaveCIAState(uint8 *p)
{
	MOS6526State *state = (MOS6526State *) (((UInt32) p+3) & 0xfffffffc);
	TheCIA1->GetState(state);
	state = (MOS6526State *) (((UInt32) state + sizeof(MOS6526State) + 3) & 0xfffffffc);
	TheCIA2->GetState(state);
	
	return ((UInt32) state + sizeof(MOS6526State) - (UInt32) p);
}


/*
 *  Load CIA states from snapshot
 */

uint16 C64::LoadCIAState(uint8 *p)
{
	MOS6526State *state = (MOS6526State *) (((UInt32) p+3) & 0xfffffffc);
	
	TheCIA1->SetState(state);
	state = (MOS6526State *) (((UInt32) state + sizeof(MOS6526State) + 3) & 0xfffffffc);
	TheCIA2->SetState(state);
	
	return ((UInt32) state + sizeof(MOS6526State) - (UInt32) p);
}

uint16 C64::LoadCIAStateOld(uint8 *p)
{
	MOS6526State state;
	MOS6526StateOld *stateOld = (MOS6526StateOld *) (((UInt32) p+3) & 0xfffffffc);
	
	memcpy(&state, stateOld, sizeof(MOS6526StateOld));
	
	state.CyclesTillAction = 1;
	state.CyclesTillActionCnt = 1;
	state.has_new_cra = false;
	state.has_new_crb = false;
	state.new_cra = 0;
	state.new_crb = 0;
	state.ta_irq_next_cycle = false;
	state.tb_irq_next_cycle = false;
	state.ta_cnt_phi2 = ((state.cra & 0x20) == 0x00);
	state.tb_cnt_phi2 = ((state.crb & 0x60) == 0x00);
	state.tb_cnt_ta = ((state.crb & 0x60) == 0x40);
	state.ta_state = state.ta_cnt_phi2 ? T_COUNT : T_STOP;
	state.tb_state = (state.tb_cnt_phi2 || state.tb_cnt_ta) ? T_COUNT : T_STOP;
	
	TheCIA1->SetState(&state);
	
	// Same for CIA2
	stateOld = (MOS6526StateOld *) (((UInt32) stateOld + sizeof(MOS6526StateOld) + 3) & 0xfffffffc);
	memcpy(&state, stateOld, sizeof(MOS6526StateOld));
	
	state.CyclesTillAction = 1;
	state.CyclesTillActionCnt = 1;
	state.has_new_cra = false;
	state.has_new_crb = false;
	state.new_cra = 0;
	state.new_crb = 0;
	state.ta_irq_next_cycle = false;
	state.tb_irq_next_cycle = false;
	state.ta_cnt_phi2 = ((state.cra & 0x20) == 0x00);
	state.tb_cnt_phi2 = ((state.crb & 0x60) == 0x00);
	state.tb_cnt_ta = ((state.crb & 0x60) == 0x40);
	state.ta_state = state.ta_cnt_phi2 ? T_COUNT : T_STOP;
	state.tb_state = (state.tb_cnt_phi2 || state.tb_cnt_ta) ? T_COUNT : T_STOP;
	
	TheCIA2->SetState(&state);
	
	return ((UInt32) stateOld + sizeof(MOS6526StateOld) - (UInt32) p);
}


/*
 *  Save 1541 GCR state to snapshot
 */

uint16 C64::Save1541JobState(uint8 *p)
{
	Job1541State *state = (Job1541State *) (((UInt32) p+3) & 0xfffffffc);
	TheJob1541->GetState(state);
	return ((UInt32) state + sizeof(Job1541State) - (UInt32) p);
}


/*
 *  Load 1541 GCR state from snapshot
 */

uint16 C64::Load1541JobState(uint8 *p)
{
	Job1541State *state = (Job1541State *) (((UInt32) p+3) & 0xfffffffc);
	
	TheJob1541->SetState(state);
	return ((UInt32) state + sizeof(Job1541State) - (UInt32) p);
}

#define SNAPSHOT_1541 1


/*
 *  Save snapshot (emulation must be paused and in VBlank)
 *
 */

void C64::SaveSnapshot(uint8 *block1, uint8 *block2)
{
	uint8 *p1, *p2;
	uint8 flags;
	
	p1=block1;
	// SNAPSHOT_HEADER
	*p1++='F'; *p1++='r'; *p1++='o'; *p1++='d'; *p1++='o'; *p1++='S'; 
	*p1++='n'; *p1++='a'; *p1++='p'; *p1++='s'; *p1++='h'; *p1++='o'; 
	*p1++='t'; *p1++='\n';
	*p1++=SNAPSHOT_VERSION;	// Version number
	flags = 0;
	if (ThePrefs.Emul1541Proc)
		flags |= SNAPSHOT_1541;
	*p1++=flags;
	p1+=SaveVICState(p1);
	p1+=SaveSIDState(p1);
	p1+=SaveCIAState(p1);
	
	p2=block2;
	
	p2+=SaveCPUState(p1, p2);
	p1+=0x9000;
	
	if (ThePrefs.Emul1541Proc) 
	{
		//memcpy(p2, ThePrefs.DrivePath, 256);
		memset(p2, 0, 256); // After load of snapshot, we don't have a disk attached
		p2+=256;
		
		p2+=Save1541State(p2);
		p2+=Save1541JobState(p2);
	}
}


/*
 *  Load snapshot (emulation must be paused and in VBlank)
 */

bool C64::LoadSnapshot(uint8 *block1, uint8 *block2)
{
	// must clear snapshots before loading any state.
	TheCPU->ClearTraps();
	
	uint8 *p1, *p2;
	unsigned char Header[14];
	uint8 flags;
	uint8 *vicptr;	// Pointer to VIC data
	bool bOldSnapshot = false;
	
	p1=Header;
	*p1++='F'; *p1++='r'; *p1++='o'; *p1++='d'; *p1++='o'; *p1++='S'; 
	*p1++='n'; *p1++='a'; *p1++='p'; *p1++='s'; *p1++='h'; *p1++='o';
	*p1++='t'; *p1++='\n';
	
	if (memcmp(Header, block1, sizeof(Header))) 
	{
		memcpy(Header, block1, sizeof(Header)-1);
		Header[sizeof(Header)-1]='\0';
		//ShowRequester(REQ_BAD_SNAPSHOT, (uint32)Header,0,0,0);
		return false;
	}
	p1=block1+sizeof(Header);
	
	if (*p1 != SNAPSHOT_VERSION) 
	{
		//ShowRequester(REQ_BAD_SNAPSHOT_VERSION, *p1,0,0,0);
		return false;
	}
	p1++;
	flags = *p1++;
	vicptr = p1;
	p2=block2;
		p1+=LoadVICState(p1);
		p1+=LoadSIDState(p1);
		p1+=LoadCIAState(p1);
		p2+=LoadCPUState(p1, p2);
	p1+=0x9000;
	
	if ((flags & SNAPSHOT_1541) != 0) 
	{
		// First switch on emulation
		Prefs &TheNewPrefs = ThePrefs;
		//memcpy(TheNewPrefs.DrivePath, p2, 256);
		memset(TheNewPrefs.DrivePath, 0, 256); // No information about disk
		p2+=256;
		TheNewPrefs.Emul1541Proc = true;
		NewPrefs(&TheNewPrefs);
		ThePrefs = TheNewPrefs;
		
		// Then read the context
		if(bOldSnapshot)
		{
			p2+=Load1541StateOld(p2);
			p2+=Load1541JobState(p2);
		}
		else
		{
			p2+=Load1541State(p2);
			p2+=Load1541JobState(p2);
		}
	} 
	else if (ThePrefs.Emul1541Proc) 
	{	// No emulation in snapshot, but currently active?
		Prefs &TheNewPrefs = ThePrefs;
		TheNewPrefs.Emul1541Proc = false;
		NewPrefs(&TheNewPrefs);
		ThePrefs = TheNewPrefs;
	}
	
	p1=vicptr;
	if(bOldSnapshot)
		p1+=LoadVICStateOld(p1);	// Load VIC data twice in SL (is REALLY necessary sometimes!)
	else
		p1+=LoadVICState(p1);	// Load VIC data twice in SL (is REALLY necessary sometimes!)
	
	installLuaScript();
	
	return true;
}


/*
 *  Constructor, system-dependent things
 */

#if defined(PROFILE_VBLANK)

static int frameCount = 0;
struct timeval lastupdate;

#endif

void C64::c64_ctor1(void) {
	tv_start = time_last = getNow();
#if defined(PROFILE_VBLANK)
	gettimeofday(&lastupdate, NULL);
#endif
}

/*
 *  Start emulation
 */
void C64::Run(bool autoBoot)
{
	// Reset chips
	TheCPU->Reset();
	TheSID->Reset();
	TheCIA1->Reset();
	TheCIA2->Reset();
	TheCPU1541->Reset();
	
	// Patch kernal IEC routines
	orig_kernal_1d84 = Kernal[0x1d84];
	orig_kernal_1d85 = Kernal[0x1d85];
	PatchKernal(ThePrefs.FastReset, ThePrefs.Emul1541Proc);
		
	// Start the CPU thread
	thread_running = true;
	quit_thyself = false;
	have_a_break = false;
	
	if (autoBoot) {
		// re-enables standard boot sequence to load game
		Kernal[0x039b] = 0x22;
		Kernal[0x039c] = 0xe4;
		
		installAutoBootHandler();
	}
	
	thread_func();
}


/*
 *  Stop emulation
 */
void C64::Quit() {
	quit_thyself = true;
	thread_running = false;
}



/*
 *  Pause emulation
 */
void C64::Pause() {
	TheSID->PauseSound();
	have_a_break = true;
}

void C64::Resume() {
	have_a_break = false;
	TheSID->ResumeSound();
}

/*
 *  Vertical blank: Poll keyboard and joysticks, update window
 */

void C64::VBlank(bool draw_frame)
{
	// requirement for snapshots
	if (have_a_break) {
		in_pause_loop = true;
		while (have_a_break) {
			usleep(200);
		}
		in_pause_loop = false;
	}
	
	// Poll keyboard
	TheDisplay->PollKeyboard(TheCIA1->KeyMatrix, TheCIA1->RevMatrix);
	
	// Poll joysticks
	if (ThePrefs.JoystickSwap)
		TheCIA1->Joystick2 = poll_joystick(0);
	else
		TheCIA1->Joystick1 = poll_joystick(0);
	
	TheCIA1->UpdateDataPorts();
	
	if(ThePrefs.SIDOn)
		TheSID->VBlank();
	
	// Count TOD clocks
	TheCIA1->CountTOD();
	TheCIA2->CountTOD();
	
#if defined(PROFILE_VBLANK)
	timeval currentTime;
	gettimeofday(&currentTime, NULL);
	timersub(&currentTime, &lastupdate, &currentTime);
	frameCount++;
	if (currentTime.tv_sec >= 1) {
		NSLog(@"blanks / sec: %d", frameCount);
		frameCount = 0;
		gettimeofday(&lastupdate, nil);
	}
	
#endif
	
	if (draw_frame) {
		TheDisplay->Update();
		const double kTimePerFrame = 20000;
		uint32 now = getNow();
		
		double elapsed_time = now - tv_start;
		speed_index = (double)kTimePerFrame / (elapsed_time + 1) * ThePrefs.SkipFrames * 100;
		if ((speed_index > 100) && ThePrefs.LimitSpeed) {
			speed_index = 100;
			usleep((unsigned long)(ThePrefs.SkipFrames * kTimePerFrame - elapsed_time));
		}	

#ifdef PERFORMANCE_COUNTERS
		uint32 perf_elapsed = now - time_last;
		if (perf_elapsed >= 2 * 1000000) {
			time_last = now;
			average_speed = total_speed / frames;
			total_speed = 0;
			frames = 0;
		}
		
		frames++;
		total_speed += speed_index;
#endif	
		
		tv_start = getNow();
	}
}


/*
 *  Poll joystick port, return CIA mask
 */
uint8 C64::poll_joystick(int port)
{
	uint8 j = 0xff;
	switch (TheJoyStick->dPadState()) {
		case DPadUp: j = 0xfe; break;
		case DPadUpRight: j = 0xf7 & 0xfe; break;
		case DPadRight: j = 0xf7; break;
		case DPadDownRight: j = 0xfd & 0xf7; break;
		case DPadDown: j = 0xfd; break;
		case DPadDownLeft: j = 0xfd & 0xfb; break;
		case DPadLeft: j = 0xfb; break;
		case DPadUpLeft: j = 0xfe & 0xfb; break;
	}
	
	if (TheJoyStick->buttonOneState() == FireButtonDown)
		j &= 0xef;
	
	return j;
}


/*
 * The emulation's main loop
 */
void C64::thread_func(void)
{
	while (!quit_thyself) 
	{	
#if SINGLE_CYCLE
		if(ThePrefs.SingleCycleEmulation)
		{
  			TheVIC->EmulateLineSC();
		}
		else
#endif
		{
	  		// The order of calls is important here
	  		int cycles = TheVIC->EmulateLine();
	  		if(ThePrefs.SIDOn) {
				TheSID->EmulateLine();
			}
#if !PRECISE_CIA_CYCLES
			if(TheCIA1->NeedToEmulateLine())
				TheCIA1->EmulateLine(ThePrefs.CIACycles);
			
			if (TheCIA2->NeedToEmulateLine())
				TheCIA2->EmulateLine(ThePrefs.CIACycles);
#endif
	  		if (ThePrefs.Emul1541Proc) 
	  		{
	  			int cycles_1541 = ThePrefs.FloppyCycles;
	  			TheCPU1541->CountVIATimers(cycles_1541);
				
	  			if (!TheCPU1541->Idle) 
	  			{
	  				TheCPU1541->EmulateLine(cycles_1541, cycles); // EmulateLine of CPUC64 called in there
	  			} 
	  			else
	  				TheCPU->EmulateLine(cycles);
	  		} 
	  		else 
	  		{
	  			// 1541 processor disabled, only emulate 6510
	  			TheCPU->EmulateLine(cycles);
	  		}
		}

#if SINGLE_CYCLE
		if(SwitchToSC)
		{
			// Single cycle emulation switched on
			SwitchToSC = false;
			TheCIA1->SwitchToSC();
			TheCIA2->SwitchToSC();
			TheVIC->SwitchToSC();
			TheCPU->SwitchToSC();
			if(ThePrefs.Emul1541Proc)
				TheCPU1541->SwitchToSC();
		}
		
		if(SwitchToStandard)
		{
			// Single cycle emulation switched off
			SwitchToStandard = false;
			TheCIA1->SwitchToStandard();
			TheCIA2->SwitchToStandard();
			TheVIC->SwitchToStandard();
			TheCPU->SwitchToStandard();
			if(ThePrefs.Emul1541Proc)
				TheCPU1541->SwitchToStandard();
		}
#endif
	}
}
uint8 C64::Random(void)
{
	seed = seed * 1103515245L + 12345;
	return (seed >> 16)&0xff;
}

void C64::SeedRandom(uint32 s)
{
	seed=s;
}
