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

#if AUDIO_DRIVER == AD_AUDIO_UNIT
class CAudioUnitQueueManager;

#define AUDIO_MODE_RING_Q		1
#define AUDIO_MODE_BIP_BUFFER	2
#define AUDIO_MODE_DIRECT		3

#define AUDIO_UNIT_MODE			AUDIO_MODE_RING_Q

#if AUDIO_UNIT_MODE == AUDIO_MODE_BIP_BUFFER
# import "BipBuffer.h"
#elif AUDIO_UNIT_MODE == AUDIO_MODE_RING_Q
# import "RingQ.h"
#endif

#elif AUDIO_DRIVER == AD_AUDIO_QUEUE
class CAudioQueueManager;
#elif AUDIO_DRIVER == AD_OPENAL
#include <AudioToolbox/AudioToolbox.h>
#include <OpenAL/al.h>
#include <OpenAL/alc.h>

#endif

#if AUDIO_DRIVER == AD_AUDIO_UNIT

#elif AUDIO_DRIVER == AD_AUDIO_QUEUE

#elif AUDIO_DRIVER == AD_OPENAL

#endif

// EG states
enum {
	EG_IDLE,
	EG_ATTACK,
	EG_DECAY,
	EG_RELEASE
};

// Structure for one voice
struct DRVoice {
	int		wave;			// Selected waveform
	int		eg_state;		// Current state of EG
	DRVoice *mod_by;	// Voice that modulates this one
	DRVoice *mod_to;	// Voice that is modulated by this one
	
	uint32	count;		// Counter for waveform generator, 8.16 fixed
	uint32	add;			// Added to counter in every frame
	
	uint16	freq;		// SID frequency value
	uint16	pw;			// SID pulse-width value
	
	uint32	a_add;		// EG parameters
	uint32	d_sub;
	uint32	s_level;
	uint32	r_sub;
	uint32	eg_level;	// Current EG level, 8.16 fixed
	
	uint32	noise;		// Last noise generator output value

	bool	gate;			// EG gate bit
	bool	ring;			// Ring modulation bit
	bool	test;			// Test bit
	bool	filter;		// Flag: Voice filtered

	// The following bit is set for the modulating
	// voice, not for the modulated one (as the SID bits)
	bool	sync;			// Sync modulation bit
};

const uint32 SAMPLE_FREQ = 22050;	// Sample output frequency in Hz
const uint32 SID_FREQ = 985248;		// SID frequency in Hz
const uint32 CALC_FREQ = 50;			// Frequency at which calc_buffer is called in Hz (should be 50Hz)
const uint32 SID_CYCLES = SID_FREQ/SAMPLE_FREQ;	// # of SID clocks per sample frame
const int SAMPLE_BUF_SIZE = 0x138*2;// Size of buffer for sampled voice (double buffered)

#if AUDIO_DRIVER == AD_AUDIO_UNIT
const int		FRAGMENT_SIZE = 512;
const int		FRAGMENT_SIZE_IN_BYTES = FRAGMENT_SIZE << 1;
const int		SOUND_BUFFER_SIZE = 16384;
#elif AUDIO_DRIVER == AD_AUDIO_QUEUE
const int		FRAGMENT_SIZE = SAMPLE_FREQ / CALC_FREQ;
#elif AUDIO_DRIVER == AD_OPENAL
const int		kNumberOpenAlBuffers = 8;
//const int		FRAGMENT_SIZE = SAMPLE_FREQ / CALC_FREQ;
const int		FRAGMENT_SIZE = 1024;
const ALfloat	SAMPLE_RATE = 44100.0;
#endif

// Renderer class
class DigitalRenderer {
public:
	DigitalRenderer();
	~DigitalRenderer();
	
	void Reset(void);
	inline void EmulateLine(void) {
		sample_buf[sample_in_ptr] = volume;
		sample_in_ptr++;
		if (sample_in_ptr == SAMPLE_BUF_SIZE)
			sample_in_ptr = 0;
	}
	
#if AUDIO_DRIVER == AD_AUDIO_UNIT
	void fill_buffer(uint8* buffer, uint32* size);
#endif
	void VBlank(void);
	void WriteRegister(uint16 adr, uint8 byte);
	void NewPrefs(Prefs *prefs);
	void Pause(void);
	void Resume(void);
	
private:
	void init_sound(void);
	void calc_filter(void);
	void calc_buffer(int16 *buf, long count);
	
	bool ready;						// Flag: Renderer has initialized and is ready
	uint8 volume;					// Master volume
	bool v3_mute;					// Voice 3 muted
	bool sid_filters;

public:
	static uint16 TriTable[0x1000*2];	// Tables for certain waveforms
	static const uint16 TriSawTable[0x100];
	static const uint16 TriRectTable[0x100];

#ifdef EMUL_MOS8580
	static const uint16 SawRectTable[0x100];
	static const uint16 TriSawRectTable[0x100];
#endif
	
	static const uint32 EGTable[16];	// Increment/decrement values for all A/D/R settings
	static const uint8 EGDRShift[256]; // For exponential approximation of D/R
	
private:
	static const int16 SampleTab[16]; // Table for sampled voice
	
	DRVoice voice[3];				// Data for 3 voices
	
	uint8 f_type;					// Filter type
	uint8 f_freq;					// SID filter frequency (upper 8 bits)
	uint8 f_res;					// Filter resonance (0..15)
#ifdef USE_FIXPOINT_MATHS
	FixPoint f_ampl;
	FixPoint d1, d2, g1, g2;
	int32 xn1, xn2, yn1, yn2;		// can become very large
	FixPoint sidquot;
#ifdef PRECOMPUTE_RESONANCE
	FixPoint resonanceLP[256];
	FixPoint resonanceHP[256];
#endif
#else
	float f_ampl;					// IIR filter input attenuation
	float d1, d2, g1, g2;			// IIR filter coefficients
	float xn1, xn2, yn1, yn2;		// IIR filter previous input/output signal
	
#ifdef PRECOMPUTE_RESONANCE
	float resonanceLP[256];			// shortcut for calc_filter
	float resonanceHP[256];
#endif
#endif
	
	uint8 sample_buf[SAMPLE_BUF_SIZE];	// Buffer for sampled voice
	int sample_in_ptr;					// Index in sample_buf for writing

#if AUDIO_DRIVER == AD_AUDIO_UNIT
	CAudioUnitQueueManager	*_audioQueue;

# if AUDIO_UNIT_MODE == AUDIO_MODE_BIP_BUFFER
	Mutex					_soundBufferLock;
	BipBuffer				_soundBuffer;
# elif AUDIO_UNIT_MODE == AUDIO_MODE_RING_Q
	SoundBuffer				_soundQBuffer;
# endif
	
#elif AUDIO_DRIVER == AD_AUDIO_QUEUE
	CAudioQueueManager		*_audioQueue;
#elif AUDIO_DRIVER == AD_OPENAL
	ALCcontext*								mContext;
	ALCdevice*								mDevice;
	ALuint									mSourceID;
	ALuint									mBufferIDs[kNumberOpenAlBuffers];
	int16									mSampleData[kNumberOpenAlBuffers][FRAGMENT_SIZE];
#endif
};
