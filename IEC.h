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

/*
 *  IEC.h - IEC bus routines, 1541 emulation (DOS level)
 *
 *  Frodo (C) 1994-1997,2002 Christian Bauer
 */

#ifndef _IEC_H
#define _IEC_H


// Maximum length of file names
const int NAMEBUF_LENGTH = 256;


// C64 status codes
enum {
	ST_OK = 0,				// No error
	ST_READ_TIMEOUT	= 0x02,	// Timeout on reading
	ST_TIMEOUT = 0x03,		// Timeout
	ST_EOF = 0x40,			// End of file
	ST_NOTPRESENT = 0x80	// Device not present
};


// 1541 error codes
enum {
	ERR_OK,				// 00 OK
	ERR_WRITEERROR,		// 25 WRITE ERROR
	ERR_WRITEPROTECT,	// 26 WRITE PROTECT ON
	ERR_SYNTAX30,		// 30 SYNTAX ERROR (unknown command)
	ERR_SYNTAX33,		// 33 SYNTAX ERROR (wildcards on writing)
	ERR_WRITEFILEOPEN,	// 60 WRITE FILE OPEN
	ERR_FILENOTOPEN,	// 61 FILE NOT OPEN
	ERR_FILENOTFOUND,	// 62 FILE NOT FOUND
	ERR_ILLEGALTS,		// 67 ILLEGAL TRACK OR SECTOR
	ERR_NOCHANNEL,		// 70 NO CHANNEL
	ERR_STARTUP,		// 73 Power-up message
	ERR_NOTREADY		// 74 DRIVE NOT READY
};


// IEC command codes
enum {
	CMD_DATA = 0x60,	// Data transfer
	CMD_CLOSE = 0xe0,	// Close channel
	CMD_OPEN = 0xf0		// Open channel
};


// IEC ATN codes
enum {
	ATN_LISTEN = 0x20,
	ATN_UNLISTEN = 0x30,
	ATN_TALK = 0x40,
	ATN_UNTALK = 0x50
};


// Drive LED states
enum {
	DRVLED_OFF,		// Inactive, LED off
	DRVLED_ON,		// Active, LED on
	DRVLED_ERROR	// Error, blink LED
};


class Drive;
class C64Display;
class Prefs;

// Class for complete IEC bus system with drives 8..11
class IEC {
public:
	IEC(C64Display *display);
	~IEC();

	void Reset(void);
	void NewPrefs(Prefs *prefs);
	void RomChanged(int number);
	void UpdateLEDs(void);

	uint8 Out(uint8 byte, bool eoi);
	uint8 OutATN(uint8 byte);
	uint8 OutSec(uint8 byte);
	uint8 In(uint8 *byte);
	void SetATN(void);
	void RelATN(void);
	void Turnaround(void);
	void Release(void);

private:
	uint8 listen(int device);
	uint8 talk(int device);
	uint8 unlisten(void);
	uint8 untalk(void);
	uint8 sec_listen(void);
	uint8 sec_talk(void);
	uint8 open_out(uint8 byte, bool eoi);
	uint8 data_out(uint8 byte, bool eoi);
	uint8 data_in(uint8 *byte);

	C64Display *the_display;	// Pointer to display object (for drive LEDs)

	char name_buf[NAMEBUF_LENGTH];	// Buffer for file names and command strings
	char *name_ptr;			// Pointer for reception of file name
	int name_len;			// Received length of file name

	Drive *drive;		// 1 drive (8)

	Drive *listener;		// Pointer to active listener
	Drive *talker;			// Pointer to active talker

	bool listener_active;	// Listener selected, listener_data is valid
	bool talker_active;		// Talker selected, talker_data is valid
	bool listening;			// Last ATN was listen (to decide between sec_listen/sec_talk)

	uint8 received_cmd;		// Received command code ($x0)
	uint8 sec_addr;			// Received secondary address ($0x)
};


// Abstract superclass for individual drives
class Drive {
public:
	Drive(IEC *iec);
	virtual ~Drive() {}

	virtual uint8 Open(int channel, char *filename)=0;
	virtual uint8 Close(int channel)=0;
	virtual uint8 Read(int channel, uint8 *byte)=0;
	virtual uint8 Write(int channel, uint8 byte, bool eoi)=0;
	virtual void Reset(void)=0;

	int LED;			// Drive LED state
	bool Ready;			// Drive is ready for operation

protected:
	void set_error(int error);

	const char *error_ptr;	// Pointer within error message	
	int error_len;		// Remaining length of error message

private:
	IEC *the_iec;		// Pointer to IEC object
};

#endif
