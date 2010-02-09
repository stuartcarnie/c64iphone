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

#include "DigitalRenderer.h"

#include "Prefs.h"

#include "VIC.h"
#include "debug.h"

/*
 *  Resonance frequency polynomials
 */

#define CALC_RESONANCE_LP(f) (227.755\
				- 1.7635 * f\
				- 0.0176385 * f * f\
				+ 0.00333484 * f * f * f\
				- 9.05683E-6 * f * f * f * f)

#define CALC_RESONANCE_HP(f) (366.374\
				- 14.0052 * f\
				+ 0.603212 * f * f\
				- 0.000880196 * f * f * f)


/*
 *  Random number generator for noise waveform
 */

static inline uint8 sid_random(void)
{
	static uint32 seed = 1;
	seed = seed * 1103515245 + 12345;
	return seed >> 16;
}


/**
 **  Renderer for digital SID emulation (SIDTYPE_DIGITAL)
 **/

// SID waveforms (some of them :-)
enum {
	WAVE_NONE,
	WAVE_TRI,
	WAVE_SAW,
	WAVE_TRISAW,
	WAVE_RECT,
	WAVE_TRIRECT,
	WAVE_SAWRECT,
	WAVE_TRISAWRECT,
	WAVE_NOISE
};

// Filter types
enum {
	FILT_NONE,
	FILT_LP,
	FILT_BP,
	FILT_LPBP,
	FILT_HP,
	FILT_NOTCH,
	FILT_HPBP,
	FILT_ALL
};

#if AUDIO_DRIVER == AD_AUDIO_UNIT
# import "AudioUnitQueueManager.h"
#elif AUDIO_DRIVER == AD_AUDIO_QUEUE
# import "AudioQueueManager.h"
#elif AUDIO_DRIVER == AD_OPENAL

#endif


#include "DigitalRenderer_samples.i"

/*
 *  Constructor
 */

DigitalRenderer::DigitalRenderer()
{
	// Link voices together
	voice[0].mod_by = &voice[2];
	voice[1].mod_by = &voice[0];
	voice[2].mod_by = &voice[1];
	voice[0].mod_to = &voice[1];
	voice[1].mod_to = &voice[2];
	voice[2].mod_to = &voice[0];
	
	// Calculate triangle table
	for (int i=0; i<0x1000; i++) {
		TriTable[i] = (i << 4) | (i >> 8);
		TriTable[0x1fff-i] = (i << 4) | (i >> 8);
	}
	
#ifdef PRECOMPUTE_RESONANCE
#ifdef USE_FIXPOINT_MATHS
	// slow floating point doesn't matter much on startup!
	for (int i=0; i<256; i++) {
		resonanceLP[i] = FixNo(CALC_RESONANCE_LP(i));
		resonanceHP[i] = FixNo(CALC_RESONANCE_HP(i));
	}
	// Pre-compute the quotient. No problem since int-part is small enough
	sidquot = (int32)((((double)SID_FREQ)*65536) / SAMPLE_FREQ);
	// compute lookup table for sin and cos
	InitFixSinTab();
#else
	for (int i=0; i<256; i++) {
		resonanceLP[i] = CALC_RESONANCE_LP(i);
		resonanceHP[i] = CALC_RESONANCE_HP(i);
	}
#endif
#endif
	
	Reset();
	
	// System specific initialization
	init_sound();
}


/*
 *  Reset emulation
 */

void DigitalRenderer::Reset(void)
{
	volume = 0;
	v3_mute = false;
	
	for (int v=0; v<3; v++) {
		voice[v].wave = WAVE_NONE;
		voice[v].eg_state = EG_IDLE;
		voice[v].count = voice[v].add = 0;
		voice[v].freq = voice[v].pw = 0;
		voice[v].eg_level = voice[v].s_level = 0;
		voice[v].a_add = voice[v].d_sub = voice[v].r_sub = EGTable[0];
		voice[v].gate = voice[v].ring = voice[v].test = false;
		voice[v].filter = voice[v].sync = false;
	}
	
	f_type = FILT_NONE;
	f_freq = f_res = 0;
#ifdef USE_FIXPOINT_MATHS
	f_ampl = FixNo(1);
	d1 = d2 = g1 = g2 = 0;
	xn1 = xn2 = yn1 = yn2 = 0;
#else
	f_ampl = 1.0;
	d1 = d2 = g1 = g2 = 0.0;
	xn1 = xn2 = yn1 = yn2 = 0.0;
#endif
	
	sample_in_ptr = 0;
	memset(sample_buf, 0, SAMPLE_BUF_SIZE);
}


/*
 *  Write to register
 */

void DigitalRenderer::WriteRegister(uint16 adr, uint8 byte)
{
	if (!ready)
		return;
	
	int v = adr/7;	// Voice number
	DRVoice* pv = &voice[v];
	
	switch (adr) {
		case 0:
		case 7:
		case 14:
			pv->freq = (pv->freq & 0xff00) | byte;
#ifdef USE_FIXPOINT_MATHS
			pv->add = sidquot.imul((int)pv->freq);
#else
			pv->add = (uint32)((float)pv->freq * SID_FREQ / SAMPLE_FREQ);
#endif
			break;
			
		case 1:
		case 8:
		case 15:
			pv->freq = (pv->freq & 0xff) | (byte << 8);
#ifdef USE_FIXPOINT_MATHS
			pv->add = sidquot.imul((int)pv->freq);
#else
			pv->add = (uint32)((float)pv->freq * SID_FREQ / SAMPLE_FREQ);
#endif
			break;
			
		case 2:
		case 9:
		case 16:
			pv->pw = (pv->pw & 0x0f00) | byte;
			break;
			
		case 3:
		case 10:
		case 17:
			pv->pw = (pv->pw & 0xff) | ((byte & 0xf) << 8);
			break;
			
		case 4:
		case 11:
		case 18:
			pv->wave = (byte >> 4) & 0xf;
			if ((byte & 1) != pv->gate)
				if (byte & 1)	// Gate turned on
					pv->eg_state = EG_ATTACK;
				else			// Gate turned off
					if (pv->eg_state != EG_IDLE)
						pv->eg_state = EG_RELEASE;
			pv->gate = byte & 1;
			pv->mod_by->sync = byte & 2;
			pv->ring = byte & 4;
			if ((pv->test = byte & 8))
				pv->count = 0;
			break;
			
		case 5:
		case 12:
		case 19:
			pv->a_add = EGTable[byte >> 4];
			pv->d_sub = EGTable[byte & 0xf];
			break;
			
		case 6:
		case 13:
		case 20:
			pv->s_level = (byte >> 4) * 0x111111;
			pv->r_sub = EGTable[byte & 0xf];
			break;
			
		case 22:
			if (byte != f_freq) {
				f_freq = byte;
				if (sid_filters)
					calc_filter();
			}
			break;
			
		case 23:
			voice[0].filter = byte & 1;
			voice[1].filter = byte & 2;
			voice[2].filter = byte & 4;
			if ((byte >> 4) != f_res) {
				f_res = byte >> 4;
				if (sid_filters)
					calc_filter();
			}
			break;
			
		case 24:
			volume = byte & 0xf;
			v3_mute = byte & 0x80;
			if (((byte >> 4) & 7) != f_type) {
				f_type = (byte >> 4) & 7;
#ifdef USE_FIXPOINT_MATHS
				xn1 = xn2 = yn1 = yn2 = 0;
#else
				xn1 = xn2 = yn1 = yn2 = 0.0;
#endif
				if (sid_filters)
					calc_filter();
			}
			break;
	}
}


/*
 *  Preferences may have changed
 */

void DigitalRenderer::NewPrefs(Prefs *prefs)
{
	sid_filters = prefs->SIDFilters;
	calc_filter();
}


/*
 *  Calculate IIR filter coefficients
 */

void DigitalRenderer::calc_filter(void)
{
#ifdef USE_FIXPOINT_MATHS
	FixPoint fr, arg;
	
	if (f_type == FILT_ALL)
	{
		d1 = 0; d2 = 0; g1 = 0; g2 = 0; f_ampl = FixNo(1); return;
	}
	else if (f_type == FILT_NONE)
	{
		d1 = 0; d2 = 0; g1 = 0; g2 = 0; f_ampl = 0; return;
	}
#else
	float fr, arg;
	
	// Check for some trivial cases
	if (f_type == FILT_ALL) {
		d1 = 0.0; d2 = 0.0;
		g1 = 0.0; g2 = 0.0;
		f_ampl = 1.0;
		return;
	} else if (f_type == FILT_NONE) {
		d1 = 0.0; d2 = 0.0;
		g1 = 0.0; g2 = 0.0;
		f_ampl = 0.0;
		return;
	}
#endif
	
	// Calculate resonance frequency
	if (f_type == FILT_LP || f_type == FILT_LPBP)
#ifdef PRECOMPUTE_RESONANCE
		fr = resonanceLP[f_freq];
#else
	fr = CALC_RESONANCE_LP(f_freq);
#endif
	else
#ifdef PRECOMPUTE_RESONANCE
		fr = resonanceHP[f_freq];
#else
	fr = CALC_RESONANCE_HP(f_freq);
#endif
	
#ifdef USE_FIXPOINT_MATHS
	// explanations see below.
	arg = fr / (SAMPLE_FREQ >> 1);
	if (arg > FixNo(0.99)) {arg = FixNo(0.99);}
	if (arg < FixNo(0.01)) {arg = FixNo(0.01);}
	
	g2 = FixNo(0.55) + FixNo(1.2) * arg * (arg - 1) + FixNo(0.0133333333) * f_res;
	g1 = FixNo(-2) * g2.sqrt() * fixcos(arg);
	
	if (f_type == FILT_LPBP || f_type == FILT_HPBP) {g2 += FixNo(0.1);}
	
	if (g1.abs() >= g2 + 1)
	{
		if (g1 > 0) {g1 = g2 + FixNo(0.99);}
		else {g1 = -(g2 + FixNo(0.99));}
	}
	
	switch (f_type)
	{
		case FILT_LPBP:
		case FILT_LP:
			d1 = FixNo(2); d2 = FixNo(1); f_ampl = FixNo(0.25) * (1 + g1 + g2); break;
		case FILT_HPBP:
		case FILT_HP:
			d1 = FixNo(-2); d2 = FixNo(1); f_ampl = FixNo(0.25) * (1 - g1 + g2); break;
		case FILT_BP:
			d1 = 0; d2 = FixNo(-1);
			f_ampl = FixNo(0.25) * (1 + g1 + g2) * (1 + fixcos(arg)) / fixsin(arg);
			break;
		case FILT_NOTCH:
			d1 = FixNo(-2) * fixcos(arg); d2 = FixNo(1);
			f_ampl = FixNo(0.25) * (1 + g1 + g2) * (1 + fixcos(arg)) / fixsin(arg);
			break;
		default: break;
	}
	
#else
	
	// Limit to <1/2 sample frequency, avoid div by 0 in case FILT_BP below
	arg = fr / (float)(SAMPLE_FREQ >> 1);
	if (arg > 0.99)
		arg = 0.99;
	if (arg < 0.01)
		arg = 0.01;
	
	// Calculate poles (resonance frequency and resonance)
	g2 = 0.55 + 1.2 * arg * arg - 1.2 * arg + (float)f_res * 0.0133333333;
	g1 = -2.0 * sqrt(g2) * cos(M_PI * arg);
	
	// Increase resonance if LP/HP combined with BP
	if (f_type == FILT_LPBP || f_type == FILT_HPBP)
		g2 += 0.1;
	
	// Stabilize filter
	if (fabs(g1) >= g2 + 1.0)
		if (g1 > 0.0)
			g1 = g2 + 0.99;
		else
			g1 = -(g2 + 0.99);
	
	// Calculate roots (filter characteristic) and input attenuation
	switch (f_type) {
			
		case FILT_LPBP:
		case FILT_LP:
			d1 = 2.0; d2 = 1.0;
			f_ampl = 0.25 * (1.0 + g1 + g2);
			break;
			
		case FILT_HPBP:
		case FILT_HP:
			d1 = -2.0; d2 = 1.0;
			f_ampl = 0.25 * (1.0 - g1 + g2);
			break;
			
		case FILT_BP:
			d1 = 0.0; d2 = -1.0;
			f_ampl = 0.25 * (1.0 + g1 + g2) * (1 + cos(M_PI * arg)) / sin(M_PI * arg);
			break;
			
		case FILT_NOTCH:
			d1 = -2.0 * cos(M_PI * arg); d2 = 1.0;
			f_ampl = 0.25 * (1.0 + g1 + g2) * (1 + cos(M_PI * arg)) / (sin(M_PI * arg));
			break;
			
		default:
			break;
	}
#endif
}


/*
 *  Fill one audio buffer with calculated SID sound
 */

void DigitalRenderer::calc_buffer(int16 *buf, long count)
{
	// Get filter coefficients, so the emulator won't change
	// them in the middle of our calculations
#ifdef USE_FIXPOINT_MATHS
	FixPoint cf_ampl = f_ampl;
	FixPoint cd1 = d1, cd2 = d2, cg1 = g1, cg2 = g2;
#else
	float cf_ampl = f_ampl;
	float cd1 = d1, cd2 = d2, cg1 = g1, cg2 = g2;
#endif
	
	// Index in sample_buf for reading, 16.16 fixed
	uint32 sample_count = (sample_in_ptr + SAMPLE_BUF_SIZE/2) << 16;
	
	//count >>= 1;	// 16 bit mono output, count is in bytes
	while (count--) {
		int32 sum_output;
		int32 sum_output_filter = 0;
		
		// Get current master volume from sample buffer,
		// calculate sampled voice
		uint8 master_volume = sample_buf[(sample_count >> 16) % SAMPLE_BUF_SIZE];
		sample_count += ((0x138 * 50) << 16) / SAMPLE_FREQ;
		sum_output = SampleTab[master_volume] << 8;
		
		// Loop for all three voices
		for (int j=0; j<3; j++) {
			DRVoice *v = &voice[j];
			
			// Envelope generators
			uint16 envelope;
			
			switch (v->eg_state) {
				case EG_ATTACK:
					v->eg_level += v->a_add;
					if (v->eg_level > 0xffffff) {
						v->eg_level = 0xffffff;
						v->eg_state = EG_DECAY;
					}
					break;
				case EG_DECAY:
					if (v->eg_level <= v->s_level || v->eg_level > 0xffffff)
						v->eg_level = v->s_level;
					else {
						v->eg_level -= v->d_sub >> EGDRShift[v->eg_level >> 16];
						if (v->eg_level <= v->s_level || v->eg_level > 0xffffff)
							v->eg_level = v->s_level;
					}
					break;
				case EG_RELEASE:
					v->eg_level -= v->r_sub >> EGDRShift[v->eg_level >> 16];
					if (v->eg_level > 0xffffff) {
						v->eg_level = 0;
						v->eg_state = EG_IDLE;
					}
					break;
				//case EG_IDLE:
				//	v->eg_level = 0;
				//	break;
			}
			 
			envelope = (v->eg_level * master_volume) >> 20;
			
			if (j==2 && v3_mute)
				continue;
			
			// Waveform generator
			uint16 output;
			
			if (!v->test)
				v->count += v->add;
			
			if (v->sync && (v->count > 0x1000000))
				v->mod_to->count = 0;
			
			v->count &= 0xffffff;
			
			switch (v->wave) {
				case WAVE_TRI:
					if (v->ring)
						output = TriTable[(v->count ^ (v->mod_by->count & 0x800000)) >> 11];
					else
						output = TriTable[v->count >> 11];
					break;
				case WAVE_SAW:
					output = v->count >> 8;
					break;
				case WAVE_RECT:
					if (v->count > (uint32)(v->pw << 12))
						output = 0xffff;
					else
						output = 0;
					break;
				case WAVE_TRISAW:
					output = TriSawTable[v->count >> 16];
					break;
				case WAVE_TRIRECT:
					if (v->count > (uint32)(v->pw << 12))
						output = TriRectTable[v->count >> 16];
					else
						output = 0;
					break;
				case WAVE_SAWRECT:
					if (v->count > (uint32)(v->pw << 12))
#ifdef EMUL_MOS8580
						output = SawRectTable[v->count >> 16];
#else
						output = (v->count >> 16) & 0x7F == 0x7F ? 0x7878 : 0x0000;
#endif
					else
						output = 0;
					break;
				case WAVE_TRISAWRECT:
#ifdef EMUL_MOS8580
					if (v->count > (uint32)(v->pw << 12))
						output = TriSawRectTable[v->count >> 16];
					else
#endif
						output = 0;
					break;
				case WAVE_NOISE:
					if (v->count > 0x100000) {
						output = v->noise = sid_random() << 8;
						v->count &= 0xfffff;
					} else
						output = v->noise;
					break;
				default:
					output = 0x8000;
					break;
			}
			if (v->filter)
				sum_output_filter += (int16)(output ^ 0x8000) * envelope;
			else
				sum_output += (int16)(output ^ 0x8000) * envelope;
		}
		
		// Filter
		if (sid_filters) {
#ifdef USE_FIXPOINT_MATHS
			int32 xn = cf_ampl.imul(sum_output_filter);
			int32 yn = xn+cd1.imul(xn1)+cd2.imul(xn2)-cg1.imul(yn1)-cg2.imul(yn2);
			yn2 = yn1; yn1 = yn; xn2 = xn1; xn1 = xn;
			sum_output_filter = yn;
#else
			float xn = (float)sum_output_filter * cf_ampl;
			float yn = xn + cd1 * xn1 + cd2 * xn2 - cg1 * yn1 - cg2 * yn2;
			yn2 = yn1; yn1 = yn; xn2 = xn1; xn1 = xn;
			sum_output_filter = (int32)yn;
#endif
		}
		
		// Write to buffer
		*buf++ = (sum_output + sum_output_filter) >> 10;
	}
}

#if AUDIO_DRIVER == AD_AUDIO_UNIT
# include "DigitalRenderer_audiounit.i"
#elif AUDIO_DRIVER == AD_AUDIO_QUEUE
# include "DigitalRenderer_audioqueue.i"
#elif AUDIO_DRIVER == AD_OPENAL

#define AssertNoOALError(inMessage, inHandler)					\
			if((result = alGetError()) != AL_NO_ERROR)			\
			{													\
				printf("%s: %x\n", inMessage, (int)result);		\
				goto inHandler;									\
			}


// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
typedef ALvoid	AL_APIENTRY	(*alBufferDataStaticProcPtr) (const ALint bid, ALenum format, ALvoid* data, ALsizei size, ALsizei freq);
ALvoid  alBufferDataStaticProc(const ALint bid, ALenum format, ALvoid* data, ALsizei size, ALsizei freq)
{
	static	alBufferDataStaticProcPtr	proc = NULL;
    
    if (proc == NULL) {
        proc = (alBufferDataStaticProcPtr) alcGetProcAddress(NULL, (const ALCchar*) "alBufferDataStatic");
    }
    
    if (proc)
        proc(bid, format, data, size, freq);
	
    return;
}

// ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
typedef ALvoid	AL_APIENTRY	(*alcMacOSXMixerOutputRateProcPtr) (const ALdouble value);
ALvoid  alcMacOSXMixerOutputRateProc(const ALdouble value)
{
	static	alcMacOSXMixerOutputRateProcPtr	proc = NULL;
    
    if (proc == NULL) {
        proc = (alcMacOSXMixerOutputRateProcPtr) alcGetProcAddress(NULL, (const ALCchar*) "alcMacOSXMixerOutputRate");
    }
    
    if (proc)
        proc(value);
	
    return;
}

void DigitalRenderer::init_sound() {
	sid_filters = ThePrefs.SIDFilters;
	
	OSStatus result = noErr;
	mDevice = alcOpenDevice(NULL);
	AssertNoOALError("Error opening output device", end)
	
	alcMacOSXMixerOutputRateProc(SAMPLE_RATE);
	
	if (!ThePrefs.SIDOn)
		Pause();

	// Create an OpenAL Context
	mContext = alcCreateContext(mDevice, NULL);
	AssertNoOALError("Error creating OpenAL context", end)
	
	alcMakeContextCurrent(mContext);
	AssertNoOALError("Error setting current OpenAL context", end)
	
	alGenSources(1, &mSourceID);
	alGenBuffers(kNumberOpenAlBuffers, mBufferIDs);
	AssertNoOALError("Error generating OpenAL buffers", end)
	
	for(int i = 0; i < kNumberOpenAlBuffers; i++) {
		alBufferDataStaticProc(mBufferIDs[i], AL_FORMAT_MONO16, mSampleData[i], FRAGMENT_SIZE, SAMPLE_RATE);
		AssertNoOALError("Error attaching data to buffer\n", end);
	}
	
	alSourceQueueBuffers(mSourceID, kNumberOpenAlBuffers, mBufferIDs);
	AssertNoOALError("Error queueing buffers", end)
	
	alSourcePlay(mSourceID);
	AssertNoOALError("Error starting effect playback", end)
end:
	ready = true;
}

DigitalRenderer::~DigitalRenderer() {
	if (mContext) alcDestroyContext(mContext);
	if (mDevice) alcCloseDevice(mDevice);	
}

void DigitalRenderer::VBlank() {
	ALint state;
	alGetSourcei(mSourceID, AL_SOURCE_STATE, &state);
	bool playing = state == AL_PLAYING;
	if (!playing)
		Resume();
	
	ALint samplePos;
	alGetSourcei(mSourceID, AL_SAMPLE_OFFSET, &samplePos);
	
	ALint numBuffersProcessed = 0;
	alGetSourcei(mSourceID, AL_BUFFERS_PROCESSED, &numBuffersProcessed);
	if (!numBuffersProcessed)
		return;
	
	ALuint tmpBuffers[numBuffersProcessed];
	alSourceUnqueueBuffers(mSourceID, numBuffersProcessed, tmpBuffers);
	int numBuffersToQueue = numBuffersProcessed;
	while (numBuffersProcessed--) {
		int i = kNumberOpenAlBuffers - 1;
		for (i = 0; i < kNumberOpenAlBuffers; i++)
			if (mBufferIDs[i] == tmpBuffers[numBuffersProcessed]) break;
		
		calc_buffer(mSampleData[i], FRAGMENT_SIZE);
	}
	alSourceQueueBuffers(mSourceID, numBuffersToQueue, tmpBuffers);
}

void DigitalRenderer::Pause() {
	alSourcePause(mSourceID);
}

void DigitalRenderer::Resume() {
	if (ThePrefs.SIDOn)
		alSourcePlay(mSourceID);
}

#endif
