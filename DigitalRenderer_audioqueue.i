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
	
	_audioQueue = new CAudioQueueManager(SAMPLE_FREQ, FRAGMENT_SIZE, MonoSound);
	_audioQueue->start();
	
	if (!ThePrefs.SIDOn)
		Pause();
	
	ready = true;
}

DigitalRenderer::~DigitalRenderer() {
	if (_audioQueue) {
		// default is to auto-delete
		_audioQueue->stop();
	}
}

void DigitalRenderer::VBlank() {
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
	
	calc_buffer(buffer, FRAGMENT_SIZE);
	_audioQueue->queueBuffer(buffer);
	
	int neededMilliseconds = lead_lowater - _audioQueue->remainingMilliseconds();
	// If we're getting too far behind the audio add an extra frag.
	if (neededMilliseconds > 0) {
		const int millisecondsPerFragment = (float)FRAGMENT_SIZE / (float)SAMPLE_FREQ * 1000.0;
		int neededFragments = neededMilliseconds / millisecondsPerFragment;
		
		while (neededFragments--) {
			short* buffer = _audioQueue->getNextBuffer();
			if (buffer) {
				calc_buffer(buffer, FRAGMENT_SIZE);
				_audioQueue->queueBuffer(buffer);
			} else
				break;
		}
	}
}

void DigitalRenderer::Pause() {
	_audioQueue->pause();
}

void DigitalRenderer::Resume() {
	if (ThePrefs.SIDOn)
		_audioQueue->resume();
}
