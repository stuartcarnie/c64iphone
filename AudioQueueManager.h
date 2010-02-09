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
#import <AudioToolbox/AudioToolbox.h>
#import "RingQ.h"

const int kNumberBuffers = 4;

enum SoundChannels {
	MonoSound	= 1,
	StereoSound	= 2
};

class CAudioQueueManager {
public:
							CAudioQueueManager(float sampleFrequency, int sampleBufferSize, SoundChannels channels);
							~CAudioQueueManager();
	
	void					start();
	void					stop();
	void					pause();
	void					resume();
	
	inline int				bytesPerFrame() { return _bytesPerFrame; }
	inline int				sampleFrameCount() { return _sampleFrameCount; }
	inline SoundChannels	channels() { return (SoundChannels)_dataFormat.mChannelsPerFrame; }
	inline float			frequency() { return _sampleFrequency; }
	inline long				remainingSamples() { return _samplesInQueue; }
	inline long				remainingMilliseconds() { return (long)((double)remainingSamples() / _sampleFrequency * 1000); }
	
	short*					getNextBuffer();
	void					queueBuffer(short* buffer);

	
private:
	static void				HandleOutputBuffer (void *aqData, AudioQueueRef inAQ, AudioQueueBufferRef outBuffer);
	void					_HandleOutputBuffer(AudioQueueBufferRef outBuffer);
	void					setupQueue();
	void					shutdownQueue();
	void					execute();
	
	AudioStreamBasicDescription	_dataFormat;
	AudioQueueRef			_queue;
	AudioQueueBufferRef		_buffers[kNumberBuffers];
	
	bool					_isRunning;
	short					_samples;
	int						_bytesPerFrame;
	int						_framesPerBuffer;
	int						_bytesPerQueueBuffer;
	int						_sampleFrameCount;	// number of samples in a buffer
	float					_sampleFrequency;
	volatile int			_samplesInQueue;
	pthread_t				_soundThread;
	SoundBuffer				_soundQBuffer;
	CFRunLoopRef			_runLoop;
	bool					_autoDelete;
	
	typedef void*			(*ThreadRoutine)(void* inParameter);
	
	//	Implementation
protected:
	static void*			Entry(CAudioQueueManager* inAudioQueueManager);
		
};