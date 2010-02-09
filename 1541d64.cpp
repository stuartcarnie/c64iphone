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
 *  1541d64.cpp - 1541 emulation in .d64 file
 *
 *  Frodo (C) 1994-1997,2002 Christian Bauer
 *

 *
 * Incompatibilities:
 * ------------------
 *
 *  - Only read accesses possible
 *  - Not all commands implemented
 *  - The .d64 error info is read, but unused
 */

/* 
 * 20081220, Stuart Carnie: Fixes a bug that prevents LOAD"*",8,1 from finding the 
							first non-deleted PRG file in find_file
 *
 */

#include "sysdeps.h"

#include "1541d64.h"
#include "IEC.h"
#include "Prefs.h"
#include "Display.h"

// Channel modes (IRC users listen up :-)
enum {
	CHMOD_FREE,			// Channel free
	CHMOD_COMMAND,		// Command/error channel
	CHMOD_DIRECTORY,	// Reading directory
	CHMOD_FILE,			// Sequential file open
	CHMOD_DIRECT		// Direct buffer access ('#')
};

// Access modes
enum {
	FMODE_READ, FMODE_WRITE, FMODE_APPEND
};

// File types
enum {
	FTYPE_PRG, FTYPE_SEQ, FTYPE_USR, FTYPE_REL
};

// Number of tracks/sectors
const int NUM_TRACKS = 35;
const int NUM_SECTORS = 683;

// Prototypes
static bool match(uint8 *p, uint8 *n);


/*
 *  Constructor: Prepare emulation, open .d64 file
 */

D64Drive::D64Drive(IEC *iec, char *filepath) : Drive(iec)
{
	the_file = NULL;
	ram = NULL;

	Ready = false;
	strcpy(orig_d64_name, filepath);
	for (int i=0; i<=14; i++) {
		chan_mode[i] = CHMOD_FREE;
		chan_buf[i] = NULL;
	}
	chan_mode[15] = CHMOD_COMMAND;

	// Open .d64 file
	open_close_d64_file(filepath);
	if (the_file != NULL) {

		// Allocate 1541 RAM
		ram = new uint8[0x800];
		bam = (BAM *)(ram + 0x700);

		Reset();
		Ready = true;
	}
}


/*
 *  Destructor
 */

D64Drive::~D64Drive()
{
	// Close .d64 file
	open_close_d64_file("");

	delete[] ram;
	Ready = false;
}


/*
 *  Open/close the .d64 file
 */

void D64Drive::open_close_d64_file(const char *d64name)
{
	long size;
	uint8 magic[4];

	// Close old .d64, if open
	if (the_file != NULL) {
		close_all_channels();
		fclose(the_file);
		the_file = NULL;
	}

	// Open new .d64 file
	if (d64name[0]) {
		if ((the_file = fopen(d64name, "rb")) != NULL) {
			// Check length
			fseek(the_file, 0, SEEK_END);
			if ((size = ftell(the_file)) < NUM_SECTORS * 256) {
				fclose(the_file);
				the_file = NULL;
				return;
			}

			// x64 image?
			rewind(the_file);
			fread(&magic, 4, 1, the_file);
			if (magic[0] == 0x43 && magic[1] == 0x15 && magic[2] == 0x41 && magic[3] == 0x64)
				image_header = 64;
			else
				image_header = 0;

			// Preset error info (all sectors no error)
			memset(error_info, 1, NUM_SECTORS);

			// Load sector error info from .d64 file, if present
			if (!image_header && size == NUM_SECTORS * 257) {
				fseek(the_file, NUM_SECTORS * 256, SEEK_SET);
				fread(&error_info, NUM_SECTORS, 1, the_file);
			}
		}
	}
}


/*
 *  Open channel
 */

uint8 D64Drive::Open(int channel, char *filename)
{
	set_error(ERR_OK);

	// Channel 15: execute file name as command
	if (channel == 15) {
		execute_command(filename);
		return ST_OK;
	}

	if (chan_mode[channel] != CHMOD_FREE) {
		set_error(ERR_NOCHANNEL);
		return ST_OK;
	}

	if (filename[0] == '$')
		if (channel)
			return open_file_ts(channel, 18, 0);
		else
			return open_directory(filename+1);

	if (filename[0] == '#')
		return open_direct(channel, filename);

	return open_file(channel, filename);
}


/*
 *  Open file
 */

uint8 D64Drive::open_file(int channel, char *filename)
{
	char plainname[256];
	int filemode = FMODE_READ;
	int filetype = FTYPE_PRG;
	int track, sector;

	convert_filename(filename, plainname, &filemode, &filetype);

	// Channel 0 is READ PRG, channel 1 is WRITE PRG
	if (!channel) {
		filemode = FMODE_READ;
		filetype = FTYPE_PRG;
	}
	if (channel == 1) {
		filemode = FMODE_WRITE;
		filetype = FTYPE_PRG;
	}

	// Allow only read accesses
	if (filemode != FMODE_READ) {
		set_error(ERR_WRITEPROTECT);
		return ST_OK;
	}

	// Find file in directory and open it
	if (find_file(plainname, &track, &sector))
		return open_file_ts(channel, track, sector);
	else
		set_error(ERR_FILENOTFOUND);

	return ST_OK;
}


/*
 *  Analyze file name, get access mode and type
 */

void D64Drive::convert_filename(char *srcname, char *destname, int *filemode, int *filetype)
{
	char *p;

	// Search for ':', p points to first character after ':'
	if ((p = strchr(srcname, ':')) != NULL)
		p++;
	else
		p = srcname;

	// Remaining string -> destname
	strncpy(destname, p, NAMEBUF_LENGTH);

	// Search for ','
	p = destname;
	while (*p && (*p != ',')) p++;

	// Look for mode parameters seperated by ','
	p = destname;
	while ((p = strchr(p, ',')) != NULL) {

		// Cut string after the first ','
		*p++ = 0;

		switch (*p) {
			case 'P':
				*filetype = FTYPE_PRG;
				break;
			case 'S':
				*filetype = FTYPE_SEQ;
				break;
			case 'U':
				*filetype = FTYPE_USR;
				break;
			case 'L':
				*filetype = FTYPE_REL;
				break;
			case 'R':
				*filemode = FMODE_READ;
				break;
			case 'W':
				*filemode = FMODE_WRITE;
				break;
			case 'A':
				*filemode = FMODE_APPEND;
				break;
		}
	}
}


/*
 *  Search file in directory, find first track and sector
 *  false: not found, true: found
 */

bool D64Drive::find_file(char *filename, int *track, int *sector)
{
	int i, j;
	uint8 *p, *q;
	DirEntry *de;

	// Scan all directory blocks
	dir.next_track = bam->dir_track;
	dir.next_sector = bam->dir_sector;

	while (dir.next_track) {
		if (!read_sector(dir.next_track, dir.next_sector, (uint8 *) &dir.next_track))
			return false;

		// Scan all 8 entries of a block
		for (j=0; j<8; j++) {
			de = &dir.entry[j];
			*track = de->track;
			*sector = de->sector;

			// Stuart Carnie: resolve
			if (de->type & 0x07) {
				p = (uint8 *)filename;
				q = de->name;
				for (i=0; i<16 && *p; i++, p++, q++) {
					if (*p == '*')	// Wildcard '*' matches all following characters
						return true;
					if (*p != *q) {
						if (*p != '?') goto next_entry;	// Wildcard '?' matches single character
						if (*q == 0xa0) goto next_entry;
					}
				}

				if (i == 16 || *q == 0xa0)
					return true;
			}
next_entry: ;
		}
	}

	return false;
}


/*
 *  Open file given track/sector of first block
 */

uint8 D64Drive::open_file_ts(int channel, int track, int sector)
{
	chan_buf[channel] = new uint8[256];
	chan_mode[channel] = CHMOD_FILE;

	// On the next call to Read, the first block will be read
	chan_buf[channel][0] = track;
	chan_buf[channel][1] = sector;
	buf_len[channel] = 0;

	return ST_OK;
}


/*
 *  Prepare directory as BASIC program (channel 0)
 */

const char type_char_1[] = "DSPUREERSELQGRL?";
const char type_char_2[] = "EERSELQGRL??????";
const char type_char_3[] = "LQGRL???????????";

// Return true if name 'n' matches pattern 'p'
static bool match(uint8 *p, uint8 *n)
{
	if (!*p)		// Null pattern matches everything
		return true;

	do {
		if (*p == '*')	// Wildcard '*' matches all following characters
			return true;
		if ((*p != *n) && (*p != '?'))	// Wildcard '?' matches single character
			return false;
		p++; n++;
	} while (*p);

	return *n == 0xa0;
}

uint8 D64Drive::open_directory(char *pattern)
{
	int i, j, n, m;
	uint8 *p, *q;
	DirEntry *de;
	uint8 c;
	char *tmppat;

	// Special treatment for "$0"
	if (pattern[0] == '0' && pattern[1] == 0)
		pattern += 1;

	// Skip everything before the ':' in the pattern
	if ((tmppat = strchr(pattern, ':')) != NULL)
		pattern = tmppat + 1;

	p = buf_ptr[0] = chan_buf[0] = new uint8[8192];
	chan_mode[0] = CHMOD_DIRECTORY;

	// Create directory title
	*p++ = 0x01;	// Load address $0401 (from PET days :-)
	*p++ = 0x04;
	*p++ = 0x01;	// Dummy line link
	*p++ = 0x01;
	*p++ = 0;		// Drive number (0) as line number
	*p++ = 0;
	*p++ = 0x12;	// RVS ON
	*p++ = '\"';

	q = bam->disk_name;
	for (i=0; i<23; i++) {
		if ((c = *q++) == 0xa0)
			*p++ = ' ';		// Replace 0xa0 by space
		else
			*p++ = c;
	}
	*(p-7) = '\"';
	*p++ = 0;

	// Scan all directory blocks
	dir.next_track = bam->dir_track;
	dir.next_sector = bam->dir_sector;

	while (dir.next_track) {
		if (!read_sector(dir.next_track, dir.next_sector, (uint8 *) &dir.next_track))
			return ST_OK;

		// Scan all 8 entries of a block
		for (j=0; j<8; j++) {
			de = &dir.entry[j];

			if (de->type && match((uint8 *)pattern, de->name)) {
				*p++ = 0x01; // Dummy line link
				*p++ = 0x01;

				*p++ = de->num_blocks_l; // Line number
				*p++ = de->num_blocks_h;

				*p++ = ' ';
				n = (de->num_blocks_h << 8) + de->num_blocks_l;
				if (n<10) *p++ = ' ';
				if (n<100) *p++ = ' ';

				*p++ = '\"';
				q = de->name;
				m = 0;
				for (i=0; i<16; i++) {
					if ((c = *q++) == 0xa0) {
						if (m)
							*p++ = ' ';		// Replace all 0xa0 by spaces
						else
							m = *p++ = '\"';	// But the first by a '"'
					} else
						*p++ = c;
				}
				if (m)
					*p++ = ' ';
				else
					*p++ = '\"';			// No 0xa0, then append a space

				if (de->type & 0x80)
					*p++ = ' ';
				else
					*p++ = '*';

				*p++ = type_char_1[de->type & 0x0f];
				*p++ = type_char_2[de->type & 0x0f];
				*p++ = type_char_3[de->type & 0x0f];

				if (de->type & 0x40)
					*p++ = '<';
				else
					*p++ = ' ';

				*p++ = ' ';
				if (n >= 10) *p++ = ' ';
				if (n >= 100) *p++ = ' ';
				*p++ = 0;
			}
		}
	}

	// Final line
	q = p;
	for (i=0; i<29; i++)
		*q++ = ' ';

	n = 0;
	for (i=0; i<35; i++)
		n += bam->bitmap[i*4];

	*p++ = 0x01;		// Dummy line link
	*p++ = 0x01;
	*p++ = n & 0xff;	// Number of free blocks as line number
	*p++ = (n >> 8) & 0xff;

	*p++ = 'B';
	*p++ = 'L';
	*p++ = 'O';
	*p++ = 'C';
	*p++ = 'K';
	*p++ = 'S';
	*p++ = ' ';
	*p++ = 'F';
	*p++ = 'R';
	*p++ = 'E';
	*p++ = 'E';
	*p++ = '.';

	p = q;
	*p++ = 0;
	*p++ = 0;
	*p++ = 0;

	buf_len[0] = p - chan_buf[0];

	return ST_OK;
}


/*
 *  Open channel for direct buffer access
 */

uint8 D64Drive::open_direct(int channel, char *filename)
{
	int buf = -1;

	if (filename[1] == 0)
		buf = alloc_buffer(-1);
	else
		if ((filename[1] >= '0') && (filename[1] <= '3') && (filename[2] == 0))
			buf = alloc_buffer(filename[1] - '0');

	if (buf == -1) {
		set_error(ERR_NOCHANNEL);
		return ST_OK;
	}

	// The buffers are in the 1541 RAM at $300 and are 256 bytes each
	chan_buf[channel] = buf_ptr[channel] = ram + 0x300 + (buf << 8);
	chan_mode[channel] = CHMOD_DIRECT;
	chan_buf_num[channel] = buf;

	// Store actual buffer number in buffer
	*chan_buf[channel] = buf + '0';
	buf_len[channel] = 1;

	return ST_OK;
}


/*
 *  Close channel
 */

uint8 D64Drive::Close(int channel)
{
	if (channel == 15) {
		close_all_channels();
		return ST_OK;
	}

	switch (chan_mode[channel]) {
		case CHMOD_FREE:
			break;
 
		case CHMOD_DIRECT:
			free_buffer(chan_buf_num[channel]);
			chan_buf[channel] = NULL;
			chan_mode[channel] = CHMOD_FREE;
			break;

		default:
			delete[] chan_buf[channel];
			chan_buf[channel] = NULL;
			chan_mode[channel] = CHMOD_FREE;
			break;
	}

	return ST_OK;
}


/*
 *  Close all channels
 */

void D64Drive::close_all_channels()
{
	for (int i=0; i<15; i++)
		Close(i);

	cmd_len = 0;
}


/*
 *  Read from channel
 */

uint8 D64Drive::Read(int channel, uint8 *byte)
{
	switch (chan_mode[channel]) {
		case CHMOD_COMMAND:
			*byte = *error_ptr++;
			if (--error_len)
				return ST_OK;
			else {
				set_error(ERR_OK);
				return ST_EOF;
			}
			break;

		case CHMOD_FILE:
			// Read next block if necessary
			if (chan_buf[channel][0] && !buf_len[channel]) {
				if (!read_sector(chan_buf[channel][0], chan_buf[channel][1], chan_buf[channel]))
					return ST_READ_TIMEOUT;
				buf_ptr[channel] = chan_buf[channel] + 2;

				// Determine block length
				buf_len[channel] = chan_buf[channel][0] ? 254 : (uint8)chan_buf[channel][1]-1;
			}

			if (buf_len[channel] > 0) {
				*byte = *buf_ptr[channel]++;
				if (!--buf_len[channel] && !chan_buf[channel][0])
					return ST_EOF;
				else
					return ST_OK;
			} else
				return ST_READ_TIMEOUT;
			break;

		case CHMOD_DIRECTORY:
		case CHMOD_DIRECT:
			if (buf_len[channel] > 0) {
				*byte = *buf_ptr[channel]++;
				if (--buf_len[channel])
					return ST_OK;
				else
					return ST_EOF;
			} else
				return ST_READ_TIMEOUT;
			break;
	}
	return ST_READ_TIMEOUT;
}


/*
 *  Write byte to channel
 */

uint8 D64Drive::Write(int channel, uint8 byte, bool eoi)
{
	switch (chan_mode[channel]) {
		case CHMOD_FREE:
			set_error(ERR_FILENOTOPEN);
			break;

		case CHMOD_COMMAND:
			// Collect characters and execute command on EOI
			if (cmd_len >= 40)
				return ST_TIMEOUT;

			cmd_buffer[cmd_len++] = byte;

			if (eoi) {
				cmd_buffer[cmd_len++] = 0;
				cmd_len = 0;
				execute_command(cmd_buffer);
			}
			return ST_OK;

		case CHMOD_DIRECTORY:
			set_error(ERR_WRITEFILEOPEN);
			break;
	}
	return ST_TIMEOUT;
}


/*
 *  Execute command string
 */

void D64Drive::execute_command(char *command)
{
	uint16 adr;
	int len;

	switch (command[0]) {
		case 'B':
			if (command[1] != '-')
				set_error(ERR_SYNTAX30);
			else
				switch (command[2]) {
					case 'R':
						block_read_cmd(&command[3]);
						break;

					case 'P':
						buffer_ptr_cmd(&command[3]);
						break;

					case 'A':
					case 'F':
					case 'W':
						set_error(ERR_WRITEPROTECT);
						break;
						
					case 'E':
						ShowRequester("An unsupported disk command was executed.  Enable full 1541 emulation and restart the program.", "Ok");

					default:
						set_error(ERR_SYNTAX30);
						break;
				}
			break;

		case 'M':
			if (command[1] != '-')
				set_error(ERR_SYNTAX30);
			else
				switch (command[2]) {
					case 'R':
						adr = ((uint8)command[4] << 8) | ((uint8)command[3]);
						error_ptr = (char *)(ram + (adr & 0x07ff));
						if (!(error_len = (uint8)command[5]))
							error_len = 1;
						break;

					case 'W':
						adr = ((uint8)command[4] << 8) | ((uint8)command[3]);
						len = (uint8)command[5];
						for (int i=0; i<len; i++)
							ram[adr+i] = (uint8)command[i+6];
						break;
						
					case 'E':
						ShowRequester("An unsupported disk command was executed.  Enable full 1541 emulation and restart the program.", "Ok");

					default:
						set_error(ERR_SYNTAX30);
				}
			break;

		case 'I':
			close_all_channels();
			read_sector(18, 0, (uint8 *)bam);
			set_error(ERR_OK);
			break;

		case 'U':
			switch (command[1] & 0x0f) {
				case 1:		// U1/UA: Block-Read
					block_read_cmd(&command[2]);
					break;

				case 2:		// U2/UB: Block-Write
					set_error(ERR_WRITEPROTECT);
					break;
					
				case 3:
				case 4:
				case 5:
				case 6:
				case 7:
				case 8:
					set_error(ERR_SYNTAX30);
					ShowRequester("An unsupported disk command was executed.  Enable full 1541 emulation and restart the program.", "Ok");
					break;
					
				case 10:	// U:/UJ: Reset
					Reset();
					break;

				default:
					set_error(ERR_SYNTAX30);
					break;
			}
			break;

		case 'G':
			if (command[1] != ':')
				set_error(ERR_SYNTAX30);
			else
				chd64_cmd(&command[2]);
			break;

		case 'C':
		case 'N':
		case 'R':
		case 'S':
		case 'V':
			set_error(ERR_WRITEPROTECT);
			break;

		default:
			set_error(ERR_SYNTAX30);
			break;
	}
}


/*
 *  Execute B-R command
 */

void D64Drive::block_read_cmd(char *command)
{
	int channel, drvnum, track, sector;

	if (parse_bcmd(command, &channel, &drvnum, &track, &sector)) {
		if (chan_mode[channel] == CHMOD_DIRECT) {
			read_sector(track, sector, buf_ptr[channel] = chan_buf[channel]);
			buf_len[channel] = 256;
			set_error(ERR_OK);
		} else
			set_error(ERR_NOCHANNEL);
	} else
		set_error(ERR_SYNTAX30);
}


/*
 *  Execute B-P command
 */

void D64Drive::buffer_ptr_cmd(char *command)
{
	int channel, pointer, i;

	if (parse_bcmd(command, &channel, &pointer, &i, &i)) {
		if (chan_mode[channel] == CHMOD_DIRECT) {
			buf_ptr[channel] = chan_buf[channel] + pointer;
			buf_len[channel] = 256 - pointer;
			set_error(ERR_OK);
		} else
			set_error(ERR_NOCHANNEL);
	} else
		set_error(ERR_SYNTAX30);
}


/*
 *  Parse block command parameters
 *  true: OK, false: error
 */

bool D64Drive::parse_bcmd(char *cmd, int *arg1, int *arg2, int *arg3, int *arg4)
{
	int i;

	if (*cmd == ':') cmd++;

	// Read four parameters separated by space, cursor right or comma
	while (*cmd == ' ' || *cmd == 0x1d || *cmd == 0x2c) cmd++;
	if (!*cmd) return false;

	i = 0;
	while (*cmd >= 0x30 && *cmd < 0x40) {
		i *= 10;
		i += *cmd++ & 0x0f;
	}
	*arg1 = i & 0xff;

	while (*cmd == ' ' || *cmd == 0x1d || *cmd == 0x2c) cmd++;
	if (!*cmd) return false;

	i = 0;
	while (*cmd >= 0x30 && *cmd < 0x40) {
		i *= 10;
		i += *cmd++ & 0x0f;
	}
	*arg2 = i & 0xff;

	while (*cmd == ' ' || *cmd == 0x1d || *cmd == 0x2c) cmd++;
	if (!*cmd) return false;

	i = 0;
	while (*cmd >= 0x30 && *cmd < 0x40) {
		i *= 10;
		i += *cmd++ & 0x0f;
	}
	*arg3 = i & 0xff;

	while (*cmd == ' ' || *cmd == 0x1d || *cmd == 0x2c) cmd++;
	if (!*cmd) return false;

	i = 0;
	while (*cmd >= 0x30 && *cmd < 0x40) {
		i *= 10;
		i += *cmd++ & 0x0f;
	}
	*arg4 = i & 0xff;

	return true;
}


/*
 *  Execute 'G' command
 */

void D64Drive::chd64_cmd(char *d64name)
{
	char str[NAMEBUF_LENGTH];
	char *p = str;

	// Convert .d64 file name
	for (int i=0; i<NAMEBUF_LENGTH && (*p++ = conv_from_64(*d64name++)); i++) ;

	close_all_channels();

	// G:. resets the .d64 file name to its original setting
	if (str[0] == '.' && str[1] == 0)
		open_close_d64_file(orig_d64_name);
	else
		open_close_d64_file(str);

	// Read BAM
	read_sector(18, 0, (uint8 *)bam);
}


/*
 *  Reset drive
 */

void D64Drive::Reset(void)
{
	close_all_channels();

	read_sector(18, 0, (uint8 *)bam);

	cmd_len = 0;
	for (int i=0; i<4; i++)
		buf_free[i] = true;

	set_error(ERR_STARTUP);
}


/*
 *  Allocate floppy buffer
 *   -> Desired buffer number or -1
 *   <- Allocated buffer number or -1
 */

int D64Drive::alloc_buffer(int want)
{
	if (want == -1) {
		for (want=3; want>=0; want--)
			if (buf_free[want]) {
				buf_free[want] = false;
				return want;
			}
		return -1;
	}

	if (want < 4)
		if (buf_free[want]) {
			buf_free[want] = false;
			return want;
		} else
			return -1;
	else
		return -1;
}


/*
 *  Free floppy buffer
 */

void D64Drive::free_buffer(int buf)
{
	buf_free[buf] = true;
}


/*
 *  Read sector (256 bytes)
 *  true: success, false: error
 */

bool D64Drive::read_sector(int track, int sector, uint8 *buffer)
{
	int offset;

	// Convert track/sector to byte offset in file
	if ((offset = offset_from_ts(track, sector)) < 0) {
		set_error(ERR_ILLEGALTS);
		return false;
	}

	if (the_file == NULL) {
		set_error(ERR_NOTREADY);
		return false;
	}

	fseek(the_file, offset + image_header, SEEK_SET);
	fread(buffer, 256, 1, the_file);
	return true;
}


/*
 *  Convert track/sector to offset
 */

const int num_sectors[41] = {
	0,
	21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,21,
	19,19,19,19,19,19,19,
	18,18,18,18,18,18,
	17,17,17,17,17,
	17,17,17,17,17		// Tracks 36..40
};

const int sector_offset[41] = {
	0,
	0,21,42,63,84,105,126,147,168,189,210,231,252,273,294,315,336,
	357,376,395,414,433,452,471,
	490,508,526,544,562,580,
	598,615,632,649,666,
	683,700,717,734,751	// Tracks 36..40
};

int D64Drive::offset_from_ts(int track, int sector)
{
	if ((track < 1) || (track > NUM_TRACKS) ||
		(sector < 0) || (sector >= num_sectors[track]))
		return -1;

	return (sector_offset[track] + sector) << 8;
}


/*
 *  Conversion PETSCII->ASCII
 */

uint8 D64Drive::conv_from_64(uint8 c)
{
	if ((c >= 'A') && (c <= 'Z') || (c >= 'a') && (c <= 'z'))
		return c ^ 0x20;
	if ((c >= 0xc1) && (c <= 0xda))
		return c ^ 0x80;
	return c;
}
