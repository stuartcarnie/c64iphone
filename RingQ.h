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


typedef short		*q_element;

struct tagRingQ {
	q_element *first;				/* start of buffer */ 
    q_element *in;					/* next available slot */ 
    q_element *out;					/* first element in queue */ 
    q_element *limit;				/* last slot + 1 */ 
	int size;
	
	inline int enqueue(q_element new_element) {
		q_element *next; 
		next = in + 1; 
		if (next == limit)			/* buffer wrap? */ 
			next = first; 
		if (next == out)			/* buffer full? */ 
			return ENOMEM; 
		*in = new_element; 
		in = next; 
		return 0; 
	}
	
	inline q_element dequeue() {
		q_element result; 
		q_element *next = out; 
		if (in == next)				/* buffer empty? */ 
			return NULL;				/* not a Q_element */ 
		result = *next++; 
		if (next == limit)			/* buffer wrap? */ 
			next = first; 
		out = next; 
		return result; 
	}
	
	inline int count() {
		int count = in - out;
		if (count < 0)
			count = size + count;
		return count;
	}
	
	inline void Allocate(int count) {
		size = count;
		count++;
		buffers = new q_element[count];
		first = in = out = &buffers[0];
		limit = &buffers[count];
	}
	
	tagRingQ() {
		first = in = out = limit = NULL;
		buffers = NULL;
	}
	
	~tagRingQ() {
		if (!buffers)
			delete [] buffers;
	}
	
	q_element* buffers;
};

class SoundBuffer {
public:
	void AllocateBuffers(int count, int size) {
		_freeList.Allocate(count);
		_soundList.Allocate(count);
		do {
			_freeList.enqueue(new short[size]);
		} while (--count);
	}
	
	inline int FreeCount() {
		return _freeList.count();
	}
	
	inline int SoundCount() {
		return _soundList.count();
	}
	
	inline q_element DequeueFreeBuffer() {
		return _freeList.dequeue();
	}
	
	inline int EnqueueSoundBuffer(q_element item) {
		return _soundList.enqueue(item);
	}
	
	inline q_element DequeueSoundBuffer() {
		return _soundList.dequeue();
	}
	
	inline int EnqueueFreeBuffer(q_element item) {
		return _freeList.enqueue(item);
	}
	
private:
	tagRingQ	_freeList;
	tagRingQ	_soundList;
};
