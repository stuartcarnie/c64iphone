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

#import "SIDRenderer.h"
#import "sysdeps.h"
#include "Display.h"

class CAudioQueueManager;

const uint32	SAMPLE_FREQ = 22050;	// Sample output frequency in Hz
const uint32	SID_FREQ = 985248;		// SID frequency in Hz
const uint32	CALC_FREQ = 50;			// Frequency at which calc_buffer is called in Hz (should be 50Hz)
const uint32	SID_CYCLES = SID_FREQ/SAMPLE_FREQ;	// # of SID clocks per sample frame
const int		SAMPLE_BUF_SIZE = 0x138*2;// Size of buffer for sampled voice (double buffered)

const int		FRAGMENT_SIZE = SAMPLE_FREQ / CALC_FREQ;

typedef struct sound_s sound_t;

// Renderer class
class FastDigitalRenderer {
public:
	FastDigitalRenderer();
	~FastDigitalRenderer();
	
	void Reset(void);
	inline void EmulateLine(void) {
		sample_buf[sample_in_ptr] = volume;
		sample_in_ptr++;
		if (sample_in_ptr == SAMPLE_BUF_SIZE)
			sample_in_ptr = 0;
	}
	
	void VBlank(void);
	void WriteRegister(uint16 adr, uint8 byte);
	void NewPrefs(Prefs *prefs);
	void Pause(void);
	void Resume(void);
	
private:
	
	void init_sound();
	
	CAudioQueueManager		*_audioQueue;
	sound_t					*_fastSID;
	bool					ready;
	uint8					sample_buf[SAMPLE_BUF_SIZE];	// Buffer for sampled voice
	int						sample_in_ptr;					// Index in sample_buf for writing
	uint8					volume;
	
};
