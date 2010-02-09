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
 *  1541t64.cpp - 1541 emulation in .t64/LYNX file
 *
 *  Frodo (C) 1994-1997,2002 Christian Bauer

 *
 * Notes:
 * ------
 *
 *  - If any file is opened, the contents of the file in the
 *    .t64 file are copied into a temporary file which is used
 *    for reading. This is done to insert the load address.
 *  - C64 LYNX archives are also handled by these routines
 *
 * Incompatibilities:
 * ------------------
 *
 *  - Only read accesses possible
 *  - No "raw" directory reading
 *  - No relative/sequential/user files
 *  - Only "I" and "UJ" commands implemented
 */

#include "sysdeps.h"

#include "1541t64.h"
#include "IEC.h"
#include "Prefs.h"


// Access modes
enum {
	FMODE_READ, FMODE_WRITE, FMODE_APPEND
};

// File types
enum {
	FTYPE_PRG, FTYPE_SEQ, FTYPE_USR, FTYPE_REL
};

// Prototypes
static bool match(char *p, char *n);


/*
 *  Constructor: Prepare emulation
 */

T64Drive::T64Drive(IEC *iec, char *filepath) : Drive(iec)
{
	the_file = NULL;
	file_info = NULL;

	Ready = false;
	strcpy(orig_t64_name, filepath);
	for (int i=0; i<16; i++)
		file[i] = NULL;

	// Open .t64 file
	open_close_t64_file(filepath);
	if (the_file != NULL) {
		Reset();
		Ready = true;
	}
}


/*
 *  Destructor
 */

T64Drive::~T64Drive()
{
	// Close .t64 file
	open_close_t64_file("");

	Ready = false;
}


/*
 *  Open/close the .t64/LYNX file
 */

void T64Drive::open_close_t64_file(const char *t64name)
{
	uint8 buf[64];
	bool parsed_ok = false;

	// Close old .t64, if open
	if (the_file != NULL) {
		close_all_channels();
		fclose(the_file);
		the_file = NULL;
		delete[] file_info;
		file_info = NULL;
	}

	// Open new .t64 file
	if (t64name[0]) {
		if ((the_file = fopen(t64name, "rb")) != NULL) {

			// Check file ID
			fread(&buf, 64, 1, the_file);
			if (buf[0] == 0x43 && buf[1] == 0x36 && buf[2] == 0x34) {
				is_lynx = false;
				parsed_ok = parse_t64_file();
			} else if (buf[0x3c] == 0x4c && buf[0x3d] == 0x59 && buf[0x3e] == 0x4e && buf[0x3f] == 0x58) {
				is_lynx = true;
				parsed_ok = parse_lynx_file();
			}

			if (!parsed_ok) {
				fclose(the_file);
				the_file = NULL;
				delete[] file_info;
				file_info = NULL;
				return;
			}
		}
	}
}


/*
 *  Parse .t64 file and construct FileInfo array
 */

bool T64Drive::parse_t64_file(void)
{
	uint8 buf[32];
	uint8 *buf2;
	char *p;
	int max, i, j;

	// Read header and get maximum number of files contained
	fseek(the_file, 32, SEEK_SET);
	fread(&buf, 32, 1, the_file);
	max = (buf[3] << 8) | buf[2];

	memcpy(dir_title, buf+8, 16);

	// Allocate buffer for file records and read them
	buf2 = new uint8[max*32];
	fread(buf2, 32, max, the_file);

	// Determine number of files contained
	for (i=0, num_files=0; i<max; i++)
		if (buf2[i*32] == 1)
			num_files++;

	if (!num_files)
		return false;

	// Construct file information array
	file_info = new FileInfo[num_files];
	for (i=0, j=0; i<max; i++)
		if (buf2[i*32] == 1) {
			memcpy(file_info[j].name, buf2+i*32+16, 16);

			// Strip trailing spaces
			file_info[j].name[16] = 0x20;
			p = file_info[j].name + 16;
			while (*p-- == 0x20) ;
			p[2] = 0;

			file_info[j].type = FTYPE_PRG;
			file_info[j].sa_lo = buf2[i*32+2];
			file_info[j].sa_hi = buf2[i*32+3];
			file_info[j].offset = (buf2[i*32+11] << 24) | (buf2[i*32+10] << 16) | (buf2[i*32+9] << 8) | buf2[i*32+8];
			file_info[j].length = ((buf2[i*32+5] << 8) | buf2[i*32+4]) - ((buf2[i*32+3] << 8) | buf2[i*32+2]);
			j++;
		}

	delete[] buf2;
	return true;
}


/*
 *  Parse LYNX file and construct FileInfo array
 */

bool T64Drive::parse_lynx_file(void)
{
	uint8 *p;
	int dir_blocks, cur_offset, num_blocks, last_block, i;
	char type_char;

	// Dummy directory title
	strcpy(dir_title, "LYNX ARCHIVE    ");

	// Read header and get number of directory blocks and files contained
	fseek(the_file, 0x60, SEEK_SET);
	fscanf(the_file, "%d", &dir_blocks);
	while (fgetc(the_file) != 0x0d)
		if (feof(the_file))
			return false;
	fscanf(the_file, "%d\015", &num_files);

	// Construct file information array
	file_info = new FileInfo[num_files];
	cur_offset = dir_blocks * 254;
	for (i=0; i<num_files; i++) {

		// Read file name
		fread(file_info[i].name, 16, 1, the_file);

		// Strip trailing shift-spaces
		file_info[i].name[16] = 0xa0;
		p = (uint8 *)file_info[i].name + 16;
		while (*p-- == 0xa0) ;
		p[2] = 0;

		// Read file length and type
		fscanf(the_file, "\015%d\015%c\015%d\015", &num_blocks, &type_char, &last_block);

		switch (type_char) {
			case 'S':
				file_info[i].type = FTYPE_SEQ;
				break;
			case 'U':
				file_info[i].type = FTYPE_USR;
				break;
			case 'R':
				file_info[i].type = FTYPE_REL;
				break;
			default:
				file_info[i].type = FTYPE_PRG;
				break;
		}
		file_info[i].sa_lo = 0;	// Only used for .t64 files
		file_info[i].sa_hi = 0;
		file_info[i].offset = cur_offset;
		file_info[i].length = (num_blocks-1) * 254 + last_block;

		cur_offset += num_blocks * 254;
	}

	return true;
}


/*
 *  Open channel
 */

uint8 T64Drive::Open(int channel, char *filename)
{
	set_error(ERR_OK);

	// Channel 15: Execute file name as command
	if (channel == 15) {
		execute_command(filename);
		return ST_OK;
	}

	// Close previous file if still open
	if (file[channel]) {
		fclose(file[channel]);
		file[channel] = NULL;
	}

	if (filename[0] == '#') {
		set_error(ERR_NOCHANNEL);
		return ST_OK;
	}

	if (the_file == NULL) {
		set_error(ERR_NOTREADY);
		return ST_OK;
	}

	if (filename[0] == '$')
		return open_directory(channel, filename+1);

	return open_file(channel, filename);
}


/*
 *  Open file
 */

uint8 T64Drive::open_file(int channel, char *filename)
{
	char plainname[NAMEBUF_LENGTH];
	int filemode = FMODE_READ;
	int filetype = FTYPE_PRG;
	int num;

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

	// Find file
	if (find_first_file(plainname, filetype, &num)) {

		// Open temporary file
		if ((file[channel] = tmpfile()) != NULL) {

			// Write load address (.t64 only)
			if (!is_lynx) {
				fwrite(&file_info[num].sa_lo, 1, 1, file[channel]);
				fwrite(&file_info[num].sa_hi, 1, 1, file[channel]);
			}

			// Copy file contents from .t64 file to temp file
			uint8 *buf = new uint8[file_info[num].length];
			fseek(the_file, file_info[num].offset, SEEK_SET);
			fread(buf, file_info[num].length, 1, the_file);
			fwrite(buf, file_info[num].length, 1, file[channel]);
			rewind(file[channel]);
			delete[] buf;

			if (filemode == FMODE_READ)	// Read and buffer first byte
				read_char[channel] = fgetc(file[channel]);
		}
	} else
		set_error(ERR_FILENOTFOUND);

	return ST_OK;
}


/*
 *  Analyze file name, get access mode and type
 */

void T64Drive::convert_filename(char *srcname, char *destname, int *filemode, int *filetype)
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
 *  Find first file matching wildcard pattern
 */

// Return true if name 'n' matches pattern 'p'
static bool match(char *p, char *n)
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

	return !(*n);
}

bool T64Drive::find_first_file(char *name, int type, int *num)
{
	for (int i=0; i<num_files; i++)
		if (match(name, file_info[i].name) && type == file_info[i].type) {
			*num = i;
			return true;
		}

	return false;
}


/*
 *  Open directory, create temporary file
 */

uint8 T64Drive::open_directory(int channel, char *filename)
{
	char buf[] = "\001\004\001\001\0\0\022\042                \042 00 2A";
	char str[NAMEBUF_LENGTH];
	char pattern[NAMEBUF_LENGTH];
	char *p, *q;
	int i, num;
	int filemode;
	int filetype;

	// Special treatment for "$0"
	if (strlen(filename) == 1 && filename[0] == '0')
		filename += 1;

	// Convert filename ('$' already stripped), filemode/type are ignored
	convert_filename(filename, pattern, &filemode, &filetype);

	// Create temporary file
	if ((file[channel] = tmpfile()) == NULL)
		return ST_OK;

	// Create directory title
	p = &buf[8];
	for (i=0; i<16 && dir_title[i]; i++)
		*p++ = dir_title[i];
	fwrite(buf, 1, 32, file[channel]);

	// Create and write one line for every directory entry
	for (num=0; num<num_files; num++) {

		// Include only files matching the pattern
		if (match(pattern, file_info[num].name)) {

			// Clear line with spaces and terminate with null byte
			memset(buf, ' ', 31);
			buf[31] = 0;

			p = buf;
			*p++ = 0x01;	// Dummy line link
			*p++ = 0x01;

			// Calculate size in blocks (254 bytes each)
			i = (file_info[num].length + 254) / 254;
			*p++ = i & 0xff;
			*p++ = (i >> 8) & 0xff;

			p++;
			if (i < 10) p++;	// Less than 10: add one space
			if (i < 100) p++;	// Less than 100: add another space

			// Convert and insert file name
			strcpy(str, file_info[num].name);
			*p++ = '\"';
			q = p;
			for (i=0; i<16 && str[i]; i++)
				*q++ = str[i];
			*q++ = '\"';
			p += 18;

			// File type
			switch (file_info[num].type) {
				case FTYPE_PRG:
					*p++ = 'P';
					*p++ = 'R';
					*p++ = 'G';
					break;
				case FTYPE_SEQ:
					*p++ = 'S';
					*p++ = 'E';
					*p++ = 'Q';
					break;
				case FTYPE_USR:
					*p++ = 'U';
					*p++ = 'S';
					*p++ = 'R';
					break;
				case FTYPE_REL:
					*p++ = 'R';
					*p++ = 'E';
					*p++ = 'L';
					break;
				default:
					*p++ = '?';
					*p++ = '?';
					*p++ = '?';
					break;
			}

			// Write line
			fwrite(buf, 1, 32, file[channel]);
		}
	}

	// Final line
	fwrite("\001\001\0\0BLOCKS FREE.             \0\0", 1, 32, file[channel]);

	// Rewind file for reading and read first byte
	rewind(file[channel]);
	read_char[channel] = fgetc(file[channel]);

	return ST_OK;
}


/*
 *  Close channel
 */

uint8 T64Drive::Close(int channel)
{
	if (channel == 15) {
		close_all_channels();
		return ST_OK;
	}

	if (file[channel]) {
		fclose(file[channel]);
		file[channel] = NULL;
	}

	return ST_OK;
}


/*
 *  Close all channels
 */

void T64Drive::close_all_channels(void)
{
	for (int i=0; i<15; i++)
		Close(i);

	cmd_len = 0;
}


/*
 *  Read from channel
 */

uint8 T64Drive::Read(int channel, uint8 *byte)
{
	int c;

	// Channel 15: Error channel
	if (channel == 15) {
		*byte = *error_ptr++;

		if (*byte != '\r')
			return ST_OK;
		else {	// End of message
			set_error(ERR_OK);
			return ST_EOF;
		}
	}

	if (!file[channel]) return ST_READ_TIMEOUT;

	// Get char from buffer and read next
	*byte = read_char[channel];
	c = fgetc(file[channel]);
	if (c == EOF)
		return ST_EOF;
	else {
		read_char[channel] = c;
		return ST_OK;
	}
}


/*
 *  Write to channel
 */

uint8 T64Drive::Write(int channel, uint8 byte, bool eoi)
{
	// Channel 15: Collect chars and execute command on EOI
	if (channel == 15) {
		if (cmd_len >= 40)
			return ST_TIMEOUT;
		
		cmd_buffer[cmd_len++] = byte;

		if (eoi) {
			cmd_buffer[cmd_len] = 0;
			cmd_len = 0;
			execute_command(cmd_buffer);
		}
		return ST_OK;
	}

	if (!file[channel])
		set_error(ERR_FILENOTOPEN);
	else
		set_error(ERR_WRITEPROTECT);

	return ST_TIMEOUT;
}


/*
 *  Execute command string
 */

void T64Drive::execute_command(char *command)
{
	switch (command[0]) {
		case 'I':
			close_all_channels();
			set_error(ERR_OK);
			break;

		case 'U':
			if ((command[1] & 0x0f) == 0x0a) {
				Reset();
			} else
				set_error(ERR_SYNTAX30);
			break;

		case 'G':
			if (command[1] != ':')
				set_error(ERR_SYNTAX30);
			else
				cht64_cmd(&command[2]);
			break;

		default:
			set_error(ERR_SYNTAX30);
	}
}


/*
 *  Execute 'G' command
 */

void T64Drive::cht64_cmd(char *t64name)
{
	char str[NAMEBUF_LENGTH];
	char *p = str;

	// Convert .t64 file name
	for (int i=0; i<NAMEBUF_LENGTH && (*p++ = conv_from_64(*t64name++)); i++) ;

	close_all_channels();

	// G:. resets the .t64 file name to its original setting
	if (str[0] == '.' && str[1] == 0)
		open_close_t64_file(orig_t64_name);
	else
		open_close_t64_file(str);

	if (the_file == NULL)
		set_error(ERR_NOTREADY);
}


/*
 *  Reset drive
 */

void T64Drive::Reset(void)
{
	close_all_channels();
	cmd_len = 0;	
	set_error(ERR_STARTUP);
}


/*
 *  Conversion PETSCII->ASCII
 */

uint8 T64Drive::conv_from_64(uint8 c)
{
	if ((c >= 'A') && (c <= 'Z') || (c >= 'a') && (c <= 'z'))
		return c ^ 0x20;
	if ((c >= 0xc1) && (c <= 0xda))
		return c ^ 0x80;
	return c;
}
