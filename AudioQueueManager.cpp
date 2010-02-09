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

#include "AudioQueueManager.h"
#include "RingQ.h"
#include <libkern/OSAtomic.h>

const int kMinimumBufferSize = 2048;

CAudioQueueManager::CAudioQueueManager(float sampleFrequency, int sampleFrameCount, SoundChannels channels)
:_sampleFrequency(sampleFrequency), _sampleFrameCount(sampleFrameCount), _samplesInQueue(0), _runLoop(NULL), _soundThread(NULL),
_autoDelete(true), _isRunning(false)
{
	_dataFormat.mSampleRate = sampleFrequency;
	_dataFormat.mFormatID = kAudioFormatLinearPCM;
	_dataFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
	_dataFormat.mBytesPerPacket = 2 * channels;
	_dataFormat.mBytesPerFrame = 2 * channels;
	_dataFormat.mFramesPerPacket = 1;
	_dataFormat.mChannelsPerFrame = channels;
	_dataFormat.mBitsPerChannel = 16;
	
	_soundQBuffer.AllocateBuffers(16, _sampleFrameCount);
	
	_bytesPerQueueBuffer = _bytesPerFrame = _sampleFrameCount * _dataFormat.mBytesPerFrame;
	if (_bytesPerFrame < kMinimumBufferSize) {
		_framesPerBuffer = kMinimumBufferSize / _bytesPerFrame;
		if (kMinimumBufferSize % _bytesPerFrame != 0)
			_framesPerBuffer++;
			
		_bytesPerFrame = _framesPerBuffer * _bytesPerFrame;
	} else
		_framesPerBuffer = 1;
}

CAudioQueueManager::~CAudioQueueManager() {
	
}

void CAudioQueueManager::start() {
	if (_soundThread != NULL) {
		printf("Thread is already running");
		return;
	}
	
	pthread_attr_t theThreadAttributes;
	
	OSStatus result = pthread_attr_init(&theThreadAttributes);
	result = pthread_attr_setdetachstate(&theThreadAttributes, PTHREAD_CREATE_DETACHED);
	result = pthread_create(&_soundThread, &theThreadAttributes, (ThreadRoutine)CAudioQueueManager::Entry, this);
	pthread_attr_destroy(&theThreadAttributes);
}

void CAudioQueueManager::stop() {
	if (_soundThread == NULL) {
		return;
	}
	CFRunLoopStop(_runLoop);
}

void* CAudioQueueManager::Entry(CAudioQueueManager* inAudioQueueManager) {
	inAudioQueueManager->execute();
	return NULL;
}

void CAudioQueueManager::execute() {
	setupQueue();
	_runLoop = CFRunLoopGetCurrent();
	
	CFRunLoopRun();
	
	shutdownQueue();
	
	_soundThread = NULL;
	if (_autoDelete)
		delete this;
}

void CAudioQueueManager::setupQueue() {
	OSStatus res = AudioQueueNewOutput(&_dataFormat, HandleOutputBuffer, this, CFRunLoopGetCurrent(), kCFRunLoopCommonModes, 0, &_queue);
	for (int i = 0; i < kNumberBuffers; i++) {
		res = AudioQueueAllocateBuffer(_queue, _bytesPerFrame, &_buffers[i]);
		HandleOutputBuffer(this, _queue, _buffers[i]);
	}
	
	res = AudioQueueStart(_queue, NULL);
	_isRunning = true;
}

void CAudioQueueManager::shutdownQueue() {
	if (_isRunning) {
		_isRunning = false;
		AudioQueueDispose(_queue, TRUE);
	}
}

short* CAudioQueueManager::getNextBuffer() {
	return _soundQBuffer.DequeueFreeBuffer();
}

void CAudioQueueManager::queueBuffer(short* buffer) {
	_soundQBuffer.EnqueueSoundBuffer(buffer);
	OSAtomicAdd32(_sampleFrameCount, &_samplesInQueue);
}

void CAudioQueueManager::pause() {
	if (!_isRunning)
		return;
	
	AudioQueuePause(_queue);
	_isRunning = false;
}

void CAudioQueueManager::resume() {
	if (_isRunning)
		return;
	
	AudioQueueStart(_queue, NULL);
	_isRunning = true;
}

void CAudioQueueManager::HandleOutputBuffer (void *aqData, AudioQueueRef inAQ, AudioQueueBufferRef outBuffer) {
	CAudioQueueManager *aq = (CAudioQueueManager*)aqData;
	aq->_HandleOutputBuffer(outBuffer);
}

void CAudioQueueManager::_HandleOutputBuffer(AudioQueueBufferRef outBuffer) {
	if (!_isRunning || _soundQBuffer.SoundCount() == 0) {
		outBuffer->mAudioDataByteSize = outBuffer->mAudioDataBytesCapacity;
	} else {
		
		int neededFrames = _framesPerBuffer;
		unsigned char* buf = (unsigned char*)outBuffer->mAudioData;
		int bytesInBuffer = 0;

		for ( ; _soundQBuffer.SoundCount() && neededFrames; neededFrames--) {
			short* buffer = _soundQBuffer.DequeueSoundBuffer();
			memcpy(buf, buffer, _bytesPerQueueBuffer);
			_soundQBuffer.EnqueueFreeBuffer(buffer);
			OSAtomicAdd32(-_sampleFrameCount, &_samplesInQueue);
			buf += _bytesPerQueueBuffer;
			bytesInBuffer += _bytesPerQueueBuffer;
		}
		
		outBuffer->mAudioDataByteSize = bytesInBuffer;	
	}
	
	OSStatus res = AudioQueueEnqueueBuffer(_queue, outBuffer, 0, NULL);
	if (res != 0)
		throw "Unable to enqueue buffer";
}
