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

#include "SIDRenderer.h"

#if defined(USE_AUDIO_UNIT)

#include "AudioUnitQueueManager.h"

#define checkStatus(status)

#define kOutputBus 0
#define kInputBus 1


CAudioUnitQueueManager::CAudioUnitQueueManager(SIDRenderer *renderer, float sampleFrequency, SoundChannels channels):_renderer(renderer)
{
	OSStatus status;

	// Describe audio component
    AudioComponentDescription desc;
    desc.componentType = kAudioUnitType_Output;
    desc.componentSubType = kAudioUnitSubType_RemoteIO;
    desc.componentFlags = 0;
    desc.componentFlagsMask = 0;
	desc.componentManufacturer = kAudioUnitManufacturer_Apple;
	
    // Get component
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &desc);
	
	// Get audio units
    status = AudioComponentInstanceNew(inputComponent, &_audioUnit);
    checkStatus(status);
	
	// Enable IO for playback
	UInt32 flag = 0;
	status = AudioUnitSetProperty(_audioUnit, 
								  kAudioOutputUnitProperty_EnableIO, 
								  kAudioUnitScope_Input, 
								  kInputBus,
								  &flag, 
								  sizeof(flag));
	
	flag = 1;
    status = AudioUnitSetProperty(_audioUnit, 
								  kAudioOutputUnitProperty_EnableIO, 
								  kAudioUnitScope_Output, 
								  kOutputBus, 
								  &flag, 
								  sizeof(flag));
	checkStatus(status);
	
	// Describe format
	_audioFormat.mSampleRate		= sampleFrequency;
	_audioFormat.mFormatID			= kAudioFormatLinearPCM;
	_audioFormat.mFormatFlags		= kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
	//_audioFormat.mFormatFlags		= kLinearPCMFormatFlagsAreAllClear;
	_audioFormat.mFramesPerPacket	= 1;
	_audioFormat.mChannelsPerFrame	= channels;
	_audioFormat.mBitsPerChannel	= 16;
	_audioFormat.mBytesPerPacket	= 2 * channels;
	_audioFormat.mBytesPerFrame		= 2 * channels;
	
	// Apply format
	status = AudioUnitSetProperty(_audioUnit, 
								  kAudioUnitProperty_StreamFormat, 
								  kAudioUnitScope_Output, 
								  kInputBus,							
								  &_audioFormat, 
								  sizeof(_audioFormat));
	checkStatus(status);
	
	status = AudioUnitSetProperty(_audioUnit, 
								  kAudioUnitProperty_StreamFormat, 
								  kAudioUnitScope_Input, 
								  kOutputBus, 
								  &_audioFormat, 
								  sizeof(_audioFormat));
	checkStatus(status);
	
	AURenderCallbackStruct callbackStruct;
    // Set output callback
	callbackStruct.inputProc = CAudioUnitQueueManager::playbackCallback;
	callbackStruct.inputProcRefCon = this;
	status = AudioUnitSetProperty(_audioUnit, 
								  kAudioUnitProperty_SetRenderCallback, 
								  kAudioUnitScope_Global, 
								  kOutputBus,
								  &callbackStruct, 
								  sizeof(callbackStruct));
	checkStatus(status);
}

CAudioUnitQueueManager::~CAudioUnitQueueManager() {
}

OSStatus CAudioUnitQueueManager::playbackCallback(void *inRefCon, 
								 AudioUnitRenderActionFlags *ioActionFlags, 
								 const AudioTimeStamp *inTimeStamp, 
								 UInt32 inBusNumber, 
								 UInt32 inNumberFrames, 
								 AudioBufferList *ioData) {    
	CAudioUnitQueueManager *THIS = (CAudioUnitQueueManager*)inRefCon;
	THIS->_renderer->fill_buffer((uint8*)ioData->mBuffers[0].mData, (uint32*)&ioData->mBuffers[0].mDataByteSize);
	if (!ioData->mBuffers[0].mDataByteSize)
		*ioActionFlags |= kAudioUnitRenderAction_OutputIsSilence;
	return noErr;
	
}

void CAudioUnitQueueManager::start() {
	// Initialise
	OSStatus status = AudioUnitInitialize(_audioUnit);
	checkStatus(status);
	status = AudioOutputUnitStart(_audioUnit);
}

void CAudioUnitQueueManager::stop() {
	OSStatus status = AudioOutputUnitStop(_audioUnit);
	AudioUnitUninitialize(_audioUnit);
}

void CAudioUnitQueueManager::pause() {
	OSStatus status = AudioOutputUnitStop(_audioUnit);
}

void CAudioUnitQueueManager::resume() {
	OSStatus status = AudioOutputUnitStart(_audioUnit);
}

#endif