/*
 Frodo, Commodore 64 emulator for the iPhone
 Copyright (C) 2007-2010 Stuart Carnie
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

void DigitalRenderer::init_sound() {
	sid_filters = ThePrefs.SIDFilters;

	_audioQueue = new CAudioUnitQueueManager(this, SAMPLE_FREQ, MonoSound);
	_audioQueue->start();
	if (!ThePrefs.SIDOn)
		Pause();
	
	ready = true;
#if AUDIO_UNIT_MODE == AUDIO_MODE_BIP_BUFFER
	_soundBuffer.AllocateBuffer(SOUND_BUFFER_SIZE);
#elif AUDIO_UNIT_MODE == AUDIO_MODE_RING_Q
	_soundQBuffer.AllocateBuffers(16, FRAGMENT_SIZE);
#endif
}

DigitalRenderer::~DigitalRenderer() {
	if (_audioQueue) {
		// default is to auto-delete
		_audioQueue->stop();
	}
}

#if AUDIO_UNIT_MODE == AUDIO_MODE_BIP_BUFFER

pthread_mutex_t g_lock = PTHREAD_MUTEX_INITIALIZER;

void DigitalRenderer::VBlank() {
	pthread_mutex_lock(&g_lock);
	
	int committed = _soundBuffer.GetCommittedSize();
	int reserved;
	int16* buffer = (int16*)_soundBuffer.Reserve(FRAGMENT_SIZE*4, reserved);
	if (buffer) {
		calc_buffer(buffer, reserved>>1);
		_soundBuffer.Commit(reserved);
	}
	
	pthread_mutex_unlock(&g_lock);
}

void DigitalRenderer::fill_buffer(uint8* buffer, uint32* size) {
	pthread_mutex_lock(&g_lock);
	
	int sizeInBytes;
	uint8* sound = _soundBuffer.GetContiguousBlock(sizeInBytes);
	if (*size > sizeInBytes) {
		*size = sizeInBytes;
		if (!sizeInBytes) {
			goto cleanup;
		}
	}
	
	memcpy(buffer, sound, *size);
	_soundBuffer.DecommitBlock(*size);
	
cleanup:
	pthread_mutex_unlock(&g_lock);
}

#elif AUDIO_UNIT_MODE == AUDIO_MODE_RING_Q

void DigitalRenderer::VBlank() {
	int16* buffer = _soundQBuffer.DequeueFreeBuffer();
	if (buffer) {
		calc_buffer(buffer, FRAGMENT_SIZE);
		_soundQBuffer.EnqueueSoundBuffer(buffer);
	}
	
	int queuedFragments = 16 - _soundQBuffer.FreeCount();
	int missing = 8 - queuedFragments;
	
	while (missing-- > 0) {
		buffer = _soundQBuffer.DequeueFreeBuffer();
		if (buffer) {
			calc_buffer(buffer, FRAGMENT_SIZE);
			_soundQBuffer.EnqueueSoundBuffer(buffer);
		}
	}
}

#define SOUND_LOGGING

void DigitalRenderer::fill_buffer(uint8* buffer, uint32* size) {
	uint32 filled			= 0;
	int16 *sound			= NULL;
	do {
		sound = _soundQBuffer.DequeueSoundBuffer();
		if (sound) {
			memcpy(buffer, sound, FRAGMENT_SIZE_IN_BYTES);
			_soundQBuffer.EnqueueFreeBuffer(sound);
			filled += FRAGMENT_SIZE_IN_BYTES;
			buffer += FRAGMENT_SIZE_IN_BYTES;
		}
	} while (sound && filled < *size);
	
#ifdef SOUND_LOGGING
	int missing = (*size - filled) >> 1;
	if (missing) {
		NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
		NSLog([NSString stringWithFormat:@"Warning: buffer needed %d bytes, supplied with %d bytes", *size, filled]);
		[pool release];
	}
#endif
	
	*size = filled;
}

#elif AUDIO_UNIT_MODE == AUDIO_MODE_DIRECT

void DigitalRenderer::VBlank() {
}

void DigitalRenderer::fill_buffer(uint8* buffer, uint32* size) {
	calc_buffer((int16*)buffer, *size >> 1);
}

#endif

void DigitalRenderer::Pause() {
	_audioQueue->pause();
}

void DigitalRenderer::Resume() {
	if (ThePrefs.SIDOn)
		_audioQueue->resume();
}
