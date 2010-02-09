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

#import <pthread.h>
#import <CoreFoundation/CoreFoundation.h>
#import <AudioUnit/AudioUnit.h>
#import <AudioToolbox/AudioToolbox.h>

const int kNumberBuffers = 4;

enum SoundChannels {
	MonoSound	= 1,
	StereoSound	= 2
};

class SIDRenderer;

class CAudioUnitQueueManager {
public:
	CAudioUnitQueueManager(SIDRenderer *renderer, float sampleFrequency, SoundChannels channels);
	~CAudioUnitQueueManager();
	
	void						start();
	void						stop();
		
	void						pause();
	void						resume();
	
private:
	static OSStatus				playbackCallback(void *inRefCon, 
												 AudioUnitRenderActionFlags *ioActionFlags, 
												 const AudioTimeStamp *inTimeStamp, 
												 UInt32 inBusNumber, 
												 UInt32 inNumberFrames, 
												 AudioBufferList *ioData);
	
private:
	AudioStreamBasicDescription	_audioFormat;
	AudioUnit					_audioUnit;
	SIDRenderer					*_renderer;
};