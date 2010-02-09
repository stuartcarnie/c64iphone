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

#if 1
/*
 *  SID.cpp - 6581 emulation
 *
 *  Frodo (C) 1994-1997,2002 Christian Bauer
 *

 *
 * Incompatibilities:
 * ------------------
 *
 *  - Lots of empirically determined constants in the filter calculations
 *  - Voice 3 cannot be muted
 */

#include "sysdeps.h"
#include <math.h>

#include "SID.h"
#include "Prefs.h"

#include "Display.h"
#include "VIC.h"

#ifdef USE_FIXPOINT_MATHS
#include "FixPoint.i"
#endif

/*
 *  Constructor
 */

MOS6581::MOS6581(C64 *c64) : the_c64(c64)
{
	the_renderer = NULL;
	for (int i=0; i<32; i++)
		regs[i] = 0;

	// Open the renderer
	open_close_renderer(SIDTYPE_NONE, ThePrefs.SIDType);
}


/*
 *  Destructor
 */

MOS6581::~MOS6581()
{
	// Close the renderer
	open_close_renderer(ThePrefs.SIDType, SIDTYPE_NONE);
}


/*
 *  Reset the SID
 */

void MOS6581::Reset(void)
{
	assert(the_renderer != NULL);
	
	for (int i=0; i<32; i++)
		regs[i] = 0;
	last_sid_byte = 0;

	the_renderer->Reset();
}


/*
 *  Preferences may have changed
 */

void MOS6581::NewPrefs(Prefs *prefs)
{
	assert(the_renderer != NULL);
	
	open_close_renderer(ThePrefs.SIDType, prefs->SIDType);
	the_renderer->NewPrefs(prefs);
}


/*
 *  Pause sound output
 */

void MOS6581::PauseSound(void)
{
	assert(the_renderer != NULL);
	the_renderer->Pause();
}


/*
 *  Resume sound output
 */

void MOS6581::ResumeSound(void)
{
	assert(the_renderer != NULL);
	the_renderer->Resume();
}


/*
 *  Get SID state
 */

void MOS6581::GetState(MOS6581State *ss)
{
	ss->freq_lo_1 = regs[0];
	ss->freq_hi_1 = regs[1];
	ss->pw_lo_1 = regs[2];
	ss->pw_hi_1 = regs[3];
	ss->ctrl_1 = regs[4];
	ss->AD_1 = regs[5];
	ss->SR_1 = regs[6];

	ss->freq_lo_2 = regs[7];
	ss->freq_hi_2 = regs[8];
	ss->pw_lo_2 = regs[9];
	ss->pw_hi_2 = regs[10];
	ss->ctrl_2 = regs[11];
	ss->AD_2 = regs[12];
	ss->SR_2 = regs[13];

	ss->freq_lo_3 = regs[14];
	ss->freq_hi_3 = regs[15];
	ss->pw_lo_3 = regs[16];
	ss->pw_hi_3 = regs[17];
	ss->ctrl_3 = regs[18];
	ss->AD_3 = regs[19];
	ss->SR_3 = regs[20];

	ss->fc_lo = regs[21];
	ss->fc_hi = regs[22];
	ss->res_filt = regs[23];
	ss->mode_vol = regs[24];

	ss->pot_x = 0xff;
	ss->pot_y = 0xff;
	ss->osc_3 = 0;
	ss->env_3 = 0;
}


/*
 *  Restore SID state
 */

void MOS6581::SetState(MOS6581State *ss)
{
	regs[0] = ss->freq_lo_1;
	regs[1] = ss->freq_hi_1;
	regs[2] = ss->pw_lo_1;
	regs[3] = ss->pw_hi_1;
	regs[4] = ss->ctrl_1;
	regs[5] = ss->AD_1;
	regs[6] = ss->SR_1;

	regs[7] = ss->freq_lo_2;
	regs[8] = ss->freq_hi_2;
	regs[9] = ss->pw_lo_2;
	regs[10] = ss->pw_hi_2;
	regs[11] = ss->ctrl_2;
	regs[12] = ss->AD_2;
	regs[13] = ss->SR_2;

	regs[14] = ss->freq_lo_3;
	regs[15] = ss->freq_hi_3;
	regs[16] = ss->pw_lo_3;
	regs[17] = ss->pw_hi_3;
	regs[18] = ss->ctrl_3;
	regs[19] = ss->AD_3;
	regs[20] = ss->SR_3;

	regs[21] = ss->fc_lo;
	regs[22] = ss->fc_hi;
	regs[23] = ss->res_filt;
	regs[24] = ss->mode_vol;

	// Stuff the new register values into the renderer
	if (the_renderer != NULL)
		for (int i=0; i<25; i++)
			the_renderer->WriteRegister(i, regs[i]);
}

//#import "DigitalRenderer.h"
#ifdef USE_FASTSID
#import "FastDigitalRenderer.h"
#else
#import "DigitalRenderer.h"
#endif


/*
 *  Open/close the renderer, according to old and new prefs
 */

void MOS6581::open_close_renderer(int old_type, int new_type)
{
	if (old_type == new_type)
		return;

	// Delete the old renderer
	delete the_renderer;

	// Create new renderer
	if (new_type == SIDTYPE_DIGITAL)
		the_renderer = new RENDERER_TYPE();
	else
		the_renderer = NULL;

	// Stuff the current register values into the new renderer
	if (the_renderer != NULL)
		for (int i=0; i<25; i++)
			the_renderer->WriteRegister(i, regs[i]);
}

#endif