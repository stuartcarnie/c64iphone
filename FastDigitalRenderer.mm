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



#include <CoreFoundation/CoreFoundation.h>

#include "FastDigitalRenderer.h"

#include "Prefs.h"

#include "VIC.h"
#include "debug.h"

/*
 *  Random number generator for noise waveform
 */

static inline uint8 sid_random(void) {
	static uint32 seed = 1;
	seed = seed * 1103515245 + 12345;
	return seed >> 16;
}


# import "AudioQueueManager.h"

#import "fastsid.i"

/*
 *  Constructor
 */

FastDigitalRenderer::FastDigitalRenderer() {
	_fastSID = new sound_t();
	bzero(_fastSID, sizeof(sound_t));
	_fastSID->sample_buf = sample_buf;
	fastsid_init(_fastSID, SAMPLE_FREQ, SID_FREQ);
	Reset();
	
	// System specific initialization
	init_sound();
}


/*
 *  Reset emulation
 */

void FastDigitalRenderer::Reset(void) {
	fastsid_reset(_fastSID);

	volume = 0;
	sample_in_ptr = 0;
	memset(sample_buf, 0, SAMPLE_BUF_SIZE);
}


/*
 *  Write to register
 */

void FastDigitalRenderer::WriteRegister(uint16 adr, uint8 byte) {
	fastsid_store(_fastSID, adr, byte);
	
	if (adr == 24)
		volume = byte & 0xf;
}


/*
 *  Preferences may have changed
 */

void FastDigitalRenderer::NewPrefs(Prefs *prefs) {
	_fastSID->emulatefilter = prefs->SIDFilters;
	fastsid_init(_fastSID, SAMPLE_FREQ, SID_FREQ);
}


void FastDigitalRenderer::init_sound() {
	//sid_filters = ThePrefs.SIDFilters;
	
	_audioQueue = new CAudioQueueManager(SAMPLE_FREQ, FRAGMENT_SIZE, MonoSound);
	_audioQueue->start();
	
	if (!ThePrefs.SIDOn)
		Pause();
	
	ready = true;
}

FastDigitalRenderer::~FastDigitalRenderer() {
	if (_audioQueue) {
		// default is to auto-delete
		_audioQueue->stop();
	}
}

void FastDigitalRenderer::VBlank() {
	// Convert latency preferences from milliseconds to frags.
	int lead_hiwater = ThePrefs.LatencyMax;
	int lead_lowater = ThePrefs.LatencyMin;
	
	long remainingMilliseconds = _audioQueue->remainingMilliseconds();
	if (remainingMilliseconds > lead_hiwater)
		return;
	
	// Calculate one frag.
	short* buffer = _audioQueue->getNextBuffer();
	if (!buffer)
		return;
	
	fastsid_calculate_samples(_fastSID, buffer, FRAGMENT_SIZE, sample_in_ptr);
	//calc_buffer(buffer, FRAGMENT_SIZE);
	_audioQueue->queueBuffer(buffer);
	
	int neededMilliseconds = lead_lowater - _audioQueue->remainingMilliseconds();
	// If we're getting too far behind the audio add an extra frag.
	if (neededMilliseconds > 0) {
		const int millisecondsPerFragment = (float)FRAGMENT_SIZE / (float)SAMPLE_FREQ * 1000.0;
		int neededFragments = neededMilliseconds / millisecondsPerFragment;
		
		while (neededFragments--) {
			short* buffer = _audioQueue->getNextBuffer();
			if (buffer) {
				fastsid_calculate_samples(_fastSID, buffer, FRAGMENT_SIZE, sample_in_ptr);
				_audioQueue->queueBuffer(buffer);
			} else
				break;
		}
	}
}

void FastDigitalRenderer::Pause() {
	_audioQueue->pause();
}

void FastDigitalRenderer::Resume() {
	if (ThePrefs.SIDOn)
		_audioQueue->resume();
}
