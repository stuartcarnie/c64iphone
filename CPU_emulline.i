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
 *  CPU_emulline.i - 6510/6502 emulation core (body of
 *                   EmulateLine() function, the same for
 *                   both 6510 and 6502)
 *
 *  Frodo (C) 1994-1997,2002 Christian Bauer
 */


/*
 *  Addressing mode macros
 */

#if 1
#define read_u16_imm()	*((uint16*)pc), pc+=2
#else
#define read_u16_imm()	((*(pc+1)) << 8) | *pc, pc+=2
#endif

// Read immediate operand
#define read_byte_imm() (*pc++)

// Read zeropage operand address
#define read_adr_zero() ((uint16)read_byte_imm())

// Read zeropage x-indexed operand address
#define read_adr_zero_x() ((read_byte_imm() + x) & 0xff)

// Read zeropage y-indexed operand address
#define read_adr_zero_y() ((read_byte_imm() + y) & 0xff)

// Read absolute operand address (uses adr!)
//#define	read_adr_abs() (adr = ((*(pc+1)) << 8) | *pc, pc+=2, adr)
#define	read_adr_abs() (adr = read_u16_imm(), adr)

// Read absolute x-indexed operand address
#define read_adr_abs_x() (read_adr_abs() + x)

// Read absolute y-indexed operand address
#define read_adr_abs_y() (read_adr_abs() + y)

// Read indexed indirect operand address
#define read_adr_ind_x() (read_zp_word(read_byte_imm() + x))

// Read indirect indexed operand address
#define read_adr_ind_y() (read_zp_word(read_byte_imm()) + y)

// Read zeropage operand
#define read_byte_zero() read_zp(read_adr_zero())

// Read zeropage x-indexed operand
#define read_byte_zero_x() read_zp(read_adr_zero_x())

// Read zeropage y-indexed operand
#define read_byte_zero_y() read_zp(read_adr_zero_y())

// Read absolute operand
//#define read_byte_abs() (adr = ((*(pc+1)) << 8) | *pc, pc+=2, read_byte(adr))
#define read_byte_abs() (adr = read_u16_imm(), read_byte(adr))

#if PRECISE_CPU_CYCLES
// Acount for cyles due to crossing page boundaries
#define page_plus(exp, reg) \
	(adr = exp, page_cycles = (adr & 0xff) + reg >= 0x100, adr + reg)

// Read absolute x-indexed operand
//#define read_byte_abs_x() (adr = ((*(pc+1)) << 8) | *pc, pc+=2, read_byte(page_plus(adr, x)))
#define read_byte_abs_x() (adr = read_u16_imm(), read_byte(page_plus(adr, x)))

// Read absolute x-indexed operand
#define read_byte_abs_y() read_byte(page_plus(read_adr_abs(), y))

// Read indirect y-indexed operand
#define read_byte_ind_y() read_byte(page_plus(read_zp_word(read_byte_imm()), y))

#else

// Read absolute x-indexed operand
//#define read_byte_abs_x() (adr = ((*(pc+1)) << 8) | *pc, pc+=2, read_byte(adr + x))
#define read_byte_abs_x() (adr = read_u16_imm(), read_byte(adr + x))

// Read absolute x-indexed operand
//#define read_byte_abs_y() (adr = ((*(pc+1)) << 8) | *pc, pc+=2, read_byte(adr + y))
#define read_byte_abs_y() (adr = read_u16_imm(), read_byte(adr + y))

// Read indirect y-indexed operand
#define read_byte_ind_y() read_byte(read_adr_ind_y())
#endif

// Read indexed indirect operand
#define read_byte_ind_x() read_byte(read_adr_ind_x())


/*
 *  Set N and Z flags according to byte
 */

#define set_nz(x) (z_flag = n_flag = (x))



/*
 * End of opcode, decrement cycles left
 */

#define ENDOP(cyc) last_cycles = cyc; break;


	// Main opcode fetch/execute loop
#if PRECISE_CPU_CYCLES
	if (cycles_left != 1)
		cycles_left -= borrowed_cycles;
	int page_cycles = 0;
	for (;;) {
		if (last_cycles) {
			last_cycles += page_cycles;
			page_cycles = 0;
#if PRECISE_CIA_CYCLES && !defined(IS_CPU_1541)
			TheCIA1->EmulateLine(last_cycles);
			TheCIA2->EmulateLine(last_cycles);
#endif
		}
		if ((cycles_left -= last_cycles) < 0) {
			borrowed_cycles = -cycles_left;
			break;
		}
#else
	while ((cycles_left -= last_cycles) >= 0) {
#endif
		uint8 _opcode = read_byte_imm();
		
redo_trap:
		switch (_opcode) {


		// Load group
		case 0xa9:	// LDA #imm
			set_nz(a = read_byte_imm());
			ENDOP(2);

		case 0xa5:	// LDA zero
			set_nz(a = read_byte_zero());
			ENDOP(3);

		case 0xb5:	// LDA zero,X
			set_nz(a = read_byte_zero_x());
			ENDOP(4);

		case 0xad:	// LDA abs
			set_nz(a = read_byte_abs());
			ENDOP(4);

		case 0xbd:	// LDA abs,X
			set_nz(a = read_byte_abs_x());
			ENDOP(4);

		case 0xb9:	// LDA abs,Y
			set_nz(a = read_byte_abs_y());
			ENDOP(4);

		case 0xa1:	// LDA (ind,X)
			set_nz(a = read_byte_ind_x());
			ENDOP(6);
		
		case 0xb1:	// LDA (ind),Y
			set_nz(a = read_byte_ind_y());
			ENDOP(5);

		case 0xa2:	// LDX #imm
			set_nz(x = read_byte_imm());
			ENDOP(2);

		case 0xa6:	// LDX zero
			set_nz(x = read_byte_zero());
			ENDOP(3);

		case 0xb6:	// LDX zero,Y
			set_nz(x = read_byte_zero_y());
			ENDOP(4);

		case 0xae:	// LDX abs
			set_nz(x = read_byte_abs());
			ENDOP(4);

		case 0xbe:	// LDX abs,Y
			set_nz(x = read_byte_abs_y());
			ENDOP(4);

		case 0xa0:	// LDY #imm
			set_nz(y = read_byte_imm());
			ENDOP(2);

		case 0xa4:	// LDY zero
			set_nz(y = read_byte_zero());
			ENDOP(3);

		case 0xb4:	// LDY zero,X
			set_nz(y = read_byte_zero_x());
			ENDOP(4);

		case 0xac:	// LDY abs
			set_nz(y = read_byte_abs());
			ENDOP(4);

		case 0xbc:	// LDY abs,X
			set_nz(y = read_byte_abs_x());
			ENDOP(4);

		// Store group
		case 0x85:	// STA zero
			write_zp(read_adr_zero(), a);
			ENDOP(3);

		case 0x95:	// STA zero,X
			write_zp(read_adr_zero_x(), a);
			ENDOP(4);

		case 0x8d:	// STA abs
			write_byte(read_adr_abs(), a);
			ENDOP(4);

		case 0x9d:	// STA abs,X
			write_byte(read_adr_abs_x(), a);
			ENDOP(5);

		case 0x99:	// STA abs,Y
			write_byte(read_adr_abs_y(), a);
			ENDOP(5);

		case 0x81:	// STA (ind,X)
			write_byte(read_adr_ind_x(), a);
			ENDOP(6);

		case 0x91:	// STA (ind),Y
			write_byte(read_adr_ind_y(), a);
			ENDOP(6);

		case 0x86:	// STX zero
			write_zp(read_adr_zero(), x);
			ENDOP(3);

		case 0x96:	// STX zero,Y
			write_zp(read_adr_zero_y(), x);
			ENDOP(4);

		case 0x8e:	// STX abs
			write_byte(read_adr_abs(), x);
			ENDOP(4);

		case 0x84:	// STY zero
			write_zp(read_adr_zero(), y);
			ENDOP(3);

		case 0x94:	// STY zero,X
			write_zp(read_adr_zero_x(), y);
			ENDOP(4);

		case 0x8c:	// STY abs
			write_byte(read_adr_abs(), y);
			ENDOP(4);


		// Transfer group
		case 0xaa:	// TAX
			set_nz(x = a);
			ENDOP(2);

		case 0x8a:	// TXA
			set_nz(a = x);
			ENDOP(2);

		case 0xa8:	// TAY
			set_nz(y = a);
			ENDOP(2);

		case 0x98:	// TYA
			set_nz(a = y);
			ENDOP(2);

		case 0xba:	// TSX
			set_nz(x = sp);
			ENDOP(2);

		case 0x9a:	// TXS
			sp = x;
			ENDOP(2);


		// Arithmetic group
#define DoAdc(x) \
  tmp = (x); \
	if (!d_flag) { \
		uint16 tmp16 = a + tmp + (c_flag ? 1 : 0); \
		c_flag = tmp16 > 0xff; \
		v_flag = !((a ^ tmp) & 0x80) && ((a ^ tmp16) & 0x80); \
		z_flag = n_flag = a = tmp16; \
  } else { do_adc_bcd(tmp); }

#define DoSbc(x) \
	tmp = (x); \
	if (!d_flag) { \
		uint16 tmp2 = a - tmp - (c_flag ? 0 : 1); \
		c_flag = tmp2 < 0x100; \
		v_flag = ((a ^ tmp2) & 0x80) && ((a ^ tmp) & 0x80); \
		z_flag = n_flag = a = tmp2; \
	} else { do_sbc_bcd(tmp); }

		case 0x69:	// ADC #imm
			DoAdc(read_byte_imm());
			ENDOP(2);

		case 0x65:	// ADC zero
			DoAdc(read_byte_zero());
			ENDOP(3);

		case 0x75:	// ADC zero,X
			DoAdc(read_byte_zero_x());
			ENDOP(4);

		case 0x6d:	// ADC abs
			DoAdc(read_byte_abs());
			ENDOP(4);

		case 0x7d:	// ADC abs,X
			DoAdc(read_byte_abs_x());
			ENDOP(4);

		case 0x79:	// ADC abs,Y
			DoAdc(read_byte_abs_y());
			ENDOP(4);

		case 0x61:	// ADC (ind,X)
			DoAdc(read_byte_ind_x());
			ENDOP(6);

		case 0x71:	// ADC (ind),Y
			DoAdc(read_byte_ind_y());
			ENDOP(5);

		case 0xe9:	// SBC #imm
		case 0xeb:	// Undocumented opcode
			DoSbc(read_byte_imm());
			ENDOP(2);

		case 0xe5:	// SBC zero
			DoSbc(read_byte_zero());
			ENDOP(3);

		case 0xf5:	// SBC zero,X
			DoSbc(read_byte_zero_x());
			ENDOP(4);

		case 0xed:	// SBC abs
			DoSbc(read_byte_abs());
			ENDOP(4);

		case 0xfd:	// SBC abs,X
			DoSbc(read_byte_abs_x());
			ENDOP(4);

		case 0xf9:	// SBC abs,Y
			DoSbc(read_byte_abs_y());
			ENDOP(4);

		case 0xe1:	// SBC (ind,X)
			DoSbc(read_byte_ind_x());
			ENDOP(6);

		case 0xf1:	// SBC (ind),Y
			DoSbc(read_byte_ind_y());
			ENDOP(5);


		// Increment/decrement group
		case 0xe8:	// INX
			set_nz(++x);
			ENDOP(2);

		case 0xca:	// DEX
			set_nz(--x);
			ENDOP(2);

		case 0xc8:	// INY
			set_nz(++y);
			ENDOP(2);

		case 0x88:	// DEY
			set_nz(--y);
			ENDOP(2);

		case 0xe6:	// INC zero
			adr = read_adr_zero();
			write_zp(adr, set_nz(read_zp(adr) + 1));
			ENDOP(5);

		case 0xf6:	// INC zero,X
			adr = read_adr_zero_x();
			write_zp(adr, set_nz(read_zp(adr) + 1));
			ENDOP(6);

		case 0xee:	// INC abs
			adr = read_adr_abs();
			write_byte(adr, set_nz(read_byte(adr) + 1));
			ENDOP(6);

		case 0xfe:	// INC abs,X
			adr = read_adr_abs_x();
			write_byte(adr, set_nz(read_byte(adr) + 1));
			ENDOP(7);

		case 0xc6:	// DEC zero
			adr = read_adr_zero();
			write_zp(adr, set_nz(read_zp(adr) - 1));
			ENDOP(5);

		case 0xd6:	// DEC zero,X
			adr = read_adr_zero_x();
			write_zp(adr, set_nz(read_zp(adr) - 1));
			ENDOP(6);

		case 0xce:	// DEC abs
			adr = read_adr_abs();
			write_byte(adr, set_nz(read_byte(adr) - 1));
			ENDOP(6);

		case 0xde:	// DEC abs,X
			adr = read_adr_abs_x();
			write_byte(adr, set_nz(read_byte(adr) - 1));
			ENDOP(7);


		// Logic group
		case 0x29:	// AND #imm
			set_nz(a &= read_byte_imm());
			ENDOP(2);

		case 0x25:	// AND zero
			set_nz(a &= read_byte_zero());
			ENDOP(3);

		case 0x35:	// AND zero,X
			set_nz(a &= read_byte_zero_x());
			ENDOP(4);

		case 0x2d:	// AND abs
			set_nz(a &= read_byte_abs());
			ENDOP(4);

		case 0x3d:	// AND abs,X
			set_nz(a &= read_byte_abs_x());
			ENDOP(4);

		case 0x39:	// AND abs,Y
			set_nz(a &= read_byte_abs_y());
			ENDOP(4);

		case 0x21:	// AND (ind,X)
			set_nz(a &= read_byte_ind_x());
			ENDOP(6);

		case 0x31:	// AND (ind),Y
			set_nz(a &= read_byte_ind_y());
			ENDOP(5);

		case 0x09:	// ORA #imm
			set_nz(a |= read_byte_imm());
			ENDOP(2);

		case 0x05:	// ORA zero
			set_nz(a |= read_byte_zero());
			ENDOP(3);

		case 0x15:	// ORA zero,X
			set_nz(a |= read_byte_zero_x());
			ENDOP(4);

		case 0x0d:	// ORA abs
			set_nz(a |= read_byte_abs());
			ENDOP(4);

		case 0x1d:	// ORA abs,X
			set_nz(a |= read_byte_abs_x());
			ENDOP(4);

		case 0x19:	// ORA abs,Y
			set_nz(a |= read_byte_abs_y());
			ENDOP(4);

		case 0x01:	// ORA (ind,X)
			set_nz(a |= read_byte_ind_x());
			ENDOP(6);

		case 0x11:	// ORA (ind),Y
			set_nz(a |= read_byte_ind_y());
			ENDOP(5);

		case 0x49:	// EOR #imm
			set_nz(a ^= read_byte_imm());
			ENDOP(2);

		case 0x45:	// EOR zero
			set_nz(a ^= read_byte_zero());
			ENDOP(3);

		case 0x55:	// EOR zero,X
			set_nz(a ^= read_byte_zero_x());
			ENDOP(4);

		case 0x4d:	// EOR abs
			set_nz(a ^= read_byte_abs());
			ENDOP(4);

		case 0x5d:	// EOR abs,X
			set_nz(a ^= read_byte_abs_x());
			ENDOP(4);

		case 0x59:	// EOR abs,Y
			set_nz(a ^= read_byte_abs_y());
			ENDOP(4);

		case 0x41:	// EOR (ind,X)
			set_nz(a ^= read_byte_ind_x());
			ENDOP(6);

		case 0x51:	// EOR (ind),Y
			set_nz(a ^= read_byte_ind_y());
			ENDOP(5);


		// Compare group
		case 0xc9:	// CMP #imm
			set_nz(adr = a - read_byte_imm());
			c_flag = adr < 0x100;
			ENDOP(2);

		case 0xc5:	// CMP zero
			set_nz(adr = a - read_byte_zero());
			c_flag = adr < 0x100;
			ENDOP(3);

		case 0xd5:	// CMP zero,X
			set_nz(adr = a - read_byte_zero_x());
			c_flag = adr < 0x100;
			ENDOP(4);

		case 0xcd:	// CMP abs
			set_nz(adr = a - read_byte_abs());
			c_flag = adr < 0x100;
			ENDOP(4);

		case 0xdd:	// CMP abs,X
			set_nz(adr = a - read_byte_abs_x());
			c_flag = adr < 0x100;
			ENDOP(4);

		case 0xd9:	// CMP abs,Y
			set_nz(adr = a - read_byte_abs_y());
			c_flag = adr < 0x100;
			ENDOP(4);

		case 0xc1:	// CMP (ind,X)
			set_nz(adr = a - read_byte_ind_x());
			c_flag = adr < 0x100;
			ENDOP(6);

		case 0xd1:	// CMP (ind),Y
			set_nz(adr = a - read_byte_ind_y());
			c_flag = adr < 0x100;
			ENDOP(5);

		case 0xe0:	// CPX #imm
			set_nz(adr = x - read_byte_imm());
			c_flag = adr < 0x100;
			ENDOP(2);

		case 0xe4:	// CPX zero
			set_nz(adr = x - read_byte_zero());
			c_flag = adr < 0x100;
			ENDOP(3);

		case 0xec:	// CPX abs
			set_nz(adr = x - read_byte_abs());
			c_flag = adr < 0x100;
			ENDOP(4);

		case 0xc0:	// CPY #imm
			set_nz(adr = y - read_byte_imm());
			c_flag = adr < 0x100;
			ENDOP(2);

		case 0xc4:	// CPY zero
			set_nz(adr = y - read_byte_zero());
			c_flag = adr < 0x100;
			ENDOP(3);

		case 0xcc:	// CPY abs
			set_nz(adr = y - read_byte_abs());
			c_flag = adr < 0x100;
			ENDOP(4);


		// Bit-test group
		case 0x24:	// BIT zero
			z_flag = a & (tmp = read_byte_zero());
			n_flag = tmp;
			v_flag = tmp & 0x40;
			ENDOP(3);

		case 0x2c:	// BIT abs
			z_flag = a & (tmp = read_byte_abs());
			n_flag = tmp;
			v_flag = tmp & 0x40;
			ENDOP(4);


		// Shift/rotate group
		case 0x0a:	// ASL A
			c_flag = a & 0x80;
			set_nz(a <<= 1);
			ENDOP(2);

		case 0x06:	// ASL zero
			tmp = read_zp(adr = read_adr_zero());
			c_flag = tmp & 0x80;
			write_zp(adr, set_nz(tmp << 1));
			ENDOP(5);

		case 0x16:	// ASL zero,X
			tmp = read_zp(adr = read_adr_zero_x());
			c_flag = tmp & 0x80;
			write_zp(adr, set_nz(tmp << 1));
			ENDOP(6);

		case 0x0e:	// ASL abs
			tmp = read_byte(adr = read_adr_abs());
			c_flag = tmp & 0x80;
			write_byte(adr, set_nz(tmp << 1));
			ENDOP(6);

		case 0x1e:	// ASL abs,X
			tmp = read_byte(adr = read_adr_abs_x());
			c_flag = tmp & 0x80;
			write_byte(adr, set_nz(tmp << 1));
			ENDOP(7);

		case 0x4a:	// LSR A
			c_flag = a & 0x01;
			set_nz(a >>= 1);
			ENDOP(2);

		case 0x46:	// LSR zero
			tmp = read_zp(adr = read_adr_zero());
			c_flag = tmp & 0x01;
			write_zp(adr, set_nz(tmp >> 1));
			ENDOP(5);

		case 0x56:	// LSR zero,X
			tmp = read_zp(adr = read_adr_zero_x());
			c_flag = tmp & 0x01;
			write_zp(adr, set_nz(tmp >> 1));
			ENDOP(6);

		case 0x4e:	// LSR abs
			tmp = read_byte(adr = read_adr_abs());
			c_flag = tmp & 0x01;
			write_byte(adr, set_nz(tmp >> 1));
			ENDOP(6);

		case 0x5e:	// LSR abs,X
			tmp = read_byte(adr = read_adr_abs_x());
			c_flag = tmp & 0x01;
			write_byte(adr, set_nz(tmp >> 1));
			ENDOP(7);

		case 0x2a:	// ROL A
			tmp = a & 0x80;
			set_nz(a = c_flag ? (a << 1) | 0x01 : a << 1);
			c_flag = tmp;
			ENDOP(2);

		case 0x26:	// ROL zero
			tmp = read_zp(adr = read_adr_zero());
			write_zp(adr, set_nz(c_flag ? (tmp << 1) | 0x01 : tmp << 1));
			c_flag = tmp & 0x80;
			ENDOP(5);

		case 0x36:	// ROL zero,X
			tmp = read_zp(adr = read_adr_zero_x());
			write_zp(adr, set_nz(c_flag ? (tmp << 1) | 0x01 : tmp << 1));
			c_flag = tmp & 0x80;
			ENDOP(6);

		case 0x2e:	// ROL abs
			tmp = read_byte(adr = read_adr_abs());
			write_byte(adr, set_nz(c_flag ? (tmp << 1) | 0x01 : tmp << 1));
			c_flag = tmp & 0x80;
			ENDOP(6);

		case 0x3e:	// ROL abs,X
			tmp = read_byte(adr = read_adr_abs_x());
			write_byte(adr, set_nz(c_flag ? (tmp << 1) | 0x01 : tmp << 1));
			c_flag = tmp & 0x80;
			ENDOP(7);

		case 0x6a:	// ROR A
			tmp = a & 0x01;
			set_nz(a = (c_flag ? (a >> 1) | 0x80 : a >> 1));
			c_flag = tmp;
			ENDOP(2);

		case 0x66:	// ROR zero
			tmp = read_zp(adr = read_adr_zero());
			write_zp(adr, set_nz(c_flag ? (tmp >> 1) | 0x80 : tmp >> 1));
			c_flag = tmp & 0x01;
			ENDOP(5);

		case 0x76:	// ROR zero,X
			tmp = read_zp(adr = read_adr_zero_x());
			write_zp(adr, set_nz(c_flag ? (tmp >> 1) | 0x80 : tmp >> 1));
			c_flag = tmp & 0x01;
			ENDOP(6);

		case 0x6e:	// ROR abs
			tmp = read_byte(adr = read_adr_abs());
			write_byte(adr, set_nz(c_flag ? (tmp >> 1) | 0x80 : tmp >> 1));
			c_flag = tmp & 0x01;
			ENDOP(6);

		case 0x7e:	// ROR abs,X
			tmp = read_byte(adr = read_adr_abs_x());
			write_byte(adr, set_nz(c_flag ? (tmp >> 1) | 0x80 : tmp >> 1));
			c_flag = tmp & 0x01;
			ENDOP(7);


		// Stack group
		case 0x48:	// PHA
			push_byte(a);
			ENDOP(3);

		case 0x68:	// PLA
			set_nz(a = pop_byte());
			ENDOP(4);

		case 0x08:	// PHP
			push_flags(true);
			ENDOP(3);

		case 0x28:	// PLP
			pop_flags();
			if (interrupt.intr_any && !i_flag)
				goto handle_int;
			ENDOP(4);


		// Jump/branch group
		case 0x4c:	// JMP abs
			jump(read_adr_abs());
			ENDOP(3);

		case 0x6c:	// JMP (ind)
			adr = read_adr_abs();
			jump(read_byte(adr) | (read_byte((adr + 1) & 0xff | adr & 0xff00) << 8));
			ENDOP(5);

		case 0x20:	// JSR abs
			push_byte((pc-pc_base+1) >> 8); push_byte(pc-pc_base+1);
			jump(read_adr_abs());
			ENDOP(6);

		case 0x60:	// RTS
			adr = pop_byte();	// Split because of pop_byte ++sp side-effect
			jump((adr | pop_byte() << 8) + 1);
			ENDOP(6);

		case 0x40:	// RTI
			pop_flags();
			adr = pop_byte();	// Split because of pop_byte ++sp side-effect
			jump(adr | pop_byte() << 8);
			if (interrupt.intr_any && !i_flag)
				goto handle_int;
			ENDOP(6);

		case 0x00:	// BRK
#ifndef IS_CPU_1541
			{
				trap_result2_t *res = trap();
				switch (res->result) {
					case TRAP_REDO:
						_opcode = res->trap->org[0];
						goto redo_trap;
						
					case TRAP_REPLACE_AND_REDO:
						_opcode = res->trap->org[0];
						*(pc - 1) = _opcode;
						goto redo_trap;
						
					case TRAP_DO_BREAK:
						// regular BRK code
						push_byte((pc+1-pc_base) >> 8); push_byte(pc+1-pc_base);
						push_flags(true);
						i_flag = true;
						jump(read_word(0xfffe));
						ENDOP(7);						
				}
			}
			break;
#else
			// regular BRK code
			push_byte((pc+1-pc_base) >> 8); push_byte(pc+1-pc_base);
			push_flags(true);
			i_flag = true;
			jump(read_word(0xfffe));
			ENDOP(7);
#endif

#if PRECISE_CPU_CYCLES
#define Branch(flag) \
	if (flag) { \
		uint8 *old_pc = pc; \
		pc += (int8)*pc + 1; \
		if (((pc-pc_base) ^ (old_pc - pc_base)) & 0xff00) { \
			ENDOP(4); \
		} else { \
			ENDOP(3); \
		} \
	} else { \
		pc++; \
		ENDOP(2); \
	}
#else
#define Branch(flag) \
	if (flag) { \
		pc += (int8)*pc + 1; \
		ENDOP(3); \
	} else { \
		pc++; \
		ENDOP(2); \
	}
#endif

		case 0xb0:	// BCS rel
			Branch(c_flag);

		case 0x90:	// BCC rel
			Branch(!c_flag);

		case 0xf0:	// BEQ rel
			Branch(!z_flag);

		case 0xd0:	// BNE rel
			Branch(z_flag);

		case 0x70:	// BVS rel
#ifndef IS_CPU_1541
			Branch(v_flag);
#else
			Branch((via2_pcr & 0x0e) == 0x0e ? 1 : v_flag);	// GCR byte ready flag
#endif

		case 0x50:	// BVC rel
#ifndef IS_CPU_1541
			Branch(!v_flag);
#else
			Branch(!((via2_pcr & 0x0e) == 0x0e) ? 0 : v_flag);	// GCR byte ready flag
#endif

		case 0x30:	// BMI rel
			Branch(n_flag & 0x80);

		case 0x10:	// BPL rel
			Branch(!(n_flag & 0x80));


		// Flags group
		case 0x38:	// SEC
			c_flag = true;
			ENDOP(2);

		case 0x18:	// CLC
			c_flag = false;
			ENDOP(2);

		case 0xf8:	// SED
			d_flag = true;
			ENDOP(2);

		case 0xd8:	// CLD
			d_flag = false;
			ENDOP(2);

		case 0x78:	// SEI
			i_flag = true;
			ENDOP(2);

		case 0x58:	// CLI
			i_flag = false;
			if (interrupt.intr_any)
				goto handle_int;
			ENDOP(2);

		case 0xb8:	// CLV
			v_flag = false;
			ENDOP(2);


		// NOP group
		case 0xea:	// NOP
			ENDOP(2);


/*
 * Undocumented opcodes start here
 */

		// NOP group
		case 0x1a:	// NOP
		case 0x3a:
		case 0x5a:
		case 0x7a:
		case 0xda:
		case 0xfa:
			ENDOP(2);

		case 0x80:	// NOP #imm
		case 0x82:
		case 0x89:
		case 0xc2:
		case 0xe2:
			pc++;
			ENDOP(2);

		case 0x04:	// NOP zero
		case 0x44:
		case 0x64:
			pc++;
			ENDOP(3);

		case 0x14:	// NOP zero,X
		case 0x34:
		case 0x54:
		case 0x74:
		case 0xd4:
		case 0xf4:
			pc++;
			ENDOP(4);

		case 0x0c:	// NOP abs
			pc+=2;
			ENDOP(4);

		case 0x1c:	// NOP abs,X
		case 0x3c:
		case 0x5c:
		case 0x7c:
		case 0xdc:
		case 0xfc:
#if PRECISE_CPU_CYCLES
			read_byte_abs_x();
#else
			pc+=2;
#endif
			ENDOP(4);


		// Load A/X group
		case 0xa7:	// LAX zero
			set_nz(a = x = read_byte_zero());
			ENDOP(3);

		case 0xb7:	// LAX zero,Y
			set_nz(a = x = read_byte_zero_y());
			ENDOP(4);

		case 0xaf:	// LAX abs
			set_nz(a = x = read_byte_abs());
			ENDOP(4);

		case 0xbf:	// LAX abs,Y
			set_nz(a = x = read_byte_abs_y());
			ENDOP(4);

		case 0xa3:	// LAX (ind,X)
			set_nz(a = x = read_byte_ind_x());
			ENDOP(6);

		case 0xb3:	// LAX (ind),Y
			set_nz(a = x = read_byte_ind_y());
			ENDOP(5);


		// Store A/X group
		case 0x87:	// SAX zero
			write_byte(read_adr_zero(), a & x);
			ENDOP(3);

		case 0x97:	// SAX zero,Y
			write_byte(read_adr_zero_y(), a & x);
			ENDOP(4);

		case 0x8f:	// SAX abs
			write_byte(read_adr_abs(), a & x);
			ENDOP(4);

		case 0x83:	// SAX (ind,X)
			write_byte(read_adr_ind_x(), a & x);
			ENDOP(6);


		// ASL/ORA group
#define ShiftLeftOr \
	c_flag = tmp & 0x80; \
	tmp <<= 1; \
	set_nz(a |= tmp);

		case 0x07:	// SLO zero
			tmp = read_zp(adr = read_adr_zero());
			ShiftLeftOr;
			write_zp(adr, tmp);
			ENDOP(5);

		case 0x17:	// SLO zero,X
			tmp = read_zp(adr = read_adr_zero_x());
			ShiftLeftOr;
			write_zp(adr, tmp);
			ENDOP(6);

		case 0x0f:	// SLO abs
			tmp = read_byte(adr = read_adr_abs());
			ShiftLeftOr;
			write_byte(adr, tmp);
			ENDOP(6);

		case 0x1f:	// SLO abs,X
			tmp = read_byte(adr = read_adr_abs_x());
			ShiftLeftOr;
			write_byte(adr, tmp);
			ENDOP(7);

		case 0x1b:	// SLO abs,Y
			tmp = read_byte(adr = read_adr_abs_y());
			ShiftLeftOr;
			write_byte(adr, tmp);
			ENDOP(7);

		case 0x03:	// SLO (ind,X)
			tmp = read_byte(adr = read_adr_ind_x());
			ShiftLeftOr;
			write_byte(adr, tmp);
			ENDOP(8);

		case 0x13:	// SLO (ind),Y
			tmp = read_byte(adr = read_adr_ind_y());
			ShiftLeftOr;
			write_byte(adr, tmp);
			ENDOP(8);


		// ROL/AND group
		case 0x27:	// RLA zero
			tmp = read_zp(adr = read_adr_zero());
	    set_nz(a &= (c_flag ? (tmp << 1) | 0x01 : tmp << 1));
			write_zp(adr, (c_flag ? (tmp << 1) | 0x01 : tmp << 1));
	    c_flag = tmp & 0x80;
			ENDOP(5);

		case 0x37:	// RLA zero,X
			tmp = read_zp(adr = read_adr_zero_x());
    	set_nz(a &= (c_flag ? (tmp << 1) | 0x01 : tmp << 1));
			write_zp(adr, (c_flag ? (tmp << 1) | 0x01 : tmp << 1));
    	c_flag = tmp & 0x80;
			ENDOP(6);

		case 0x2f:	// RLA abs
			tmp = read_byte(adr = read_adr_abs());
    	set_nz(a &= (c_flag ? (tmp << 1) | 0x01 : tmp << 1));
			write_byte(adr, (c_flag ? (tmp << 1) | 0x01 : tmp << 1));
    	c_flag = tmp & 0x80;
			ENDOP(6);

		case 0x3f:	// RLA abs,X
			tmp = read_byte(adr = read_adr_abs_x());
    	set_nz(a &= (c_flag ? (tmp << 1) | 0x01 : tmp << 1));
			write_byte(adr, (c_flag ? (tmp << 1) | 0x01 : tmp << 1));
    	c_flag = tmp & 0x80;
			ENDOP(7);

		case 0x3b:	// RLA abs,Y
			tmp = read_byte(adr = read_adr_abs_y());
    	set_nz(a &= (c_flag ? (tmp << 1) | 0x01 : tmp << 1));
			write_byte(adr, (c_flag ? (tmp << 1) | 0x01 : tmp << 1));
    	c_flag = tmp & 0x80;
			ENDOP(7);

		case 0x23:	// RLA (ind,X)
			tmp = read_byte(adr = read_adr_ind_x());
    	set_nz(a &= (c_flag ? (tmp << 1) | 0x01 : tmp << 1));
			write_byte(adr, (c_flag ? (tmp << 1) | 0x01 : tmp << 1));
    	c_flag = tmp & 0x80;
			ENDOP(8);

		case 0x33:	// RLA (ind),Y
			tmp = read_byte(adr = read_adr_ind_y());
    	set_nz(a &= (c_flag ? (tmp << 1) | 0x01 : tmp << 1));
			write_byte(adr, (c_flag ? (tmp << 1) | 0x01 : tmp << 1));
    	c_flag = tmp & 0x80;
			ENDOP(8);


		// LSR/EOR group
#define ShiftRightEor \
	c_flag = tmp & 0x01; \
	tmp >>= 1; \
	set_nz(a ^= tmp);

		case 0x47:	// SRE zero
			tmp = read_zp(adr = read_adr_zero());
			ShiftRightEor;
			write_zp(adr, tmp);
			ENDOP(5);

		case 0x57:	// SRE zero,X
			tmp = read_zp(adr = read_adr_zero_x());
			ShiftRightEor;
			write_zp(adr, tmp);
			ENDOP(6);

		case 0x4f:	// SRE abs
			tmp = read_byte(adr = read_adr_abs());
			ShiftRightEor;
			write_byte(adr, tmp);
			ENDOP(6);

		case 0x5f:	// SRE abs,X
			tmp = read_byte(adr = read_adr_abs_x());
			ShiftRightEor;
			write_byte(adr, tmp);
			ENDOP(7);

		case 0x5b:	// SRE abs,Y
			tmp = read_byte(adr = read_adr_abs_y());
			ShiftRightEor;
			write_byte(adr, tmp);
			ENDOP(7);

		case 0x43:	// SRE (ind,X)
			tmp = read_byte(adr = read_adr_ind_x());
			ShiftRightEor;
			write_byte(adr, tmp);
			ENDOP(8);

		case 0x53:	// SRE (ind),Y
			tmp = read_byte(adr = read_adr_ind_y());
			ShiftRightEor;
			write_byte(adr, tmp);
			ENDOP(8);


		// ROR/ADC group
#define RoRightAdc \
	{ uint8 tmp2 = tmp & 0x01; \
	tmp = c_flag ? (tmp >> 1) | 0x80 : tmp >> 1; \
	c_flag = tmp2; \
	DoAdc(tmp); }

		case 0x67:	// RRA zero
			tmp = read_zp(adr = read_adr_zero());
			RoRightAdc
			write_zp(adr, tmp);
			ENDOP(5);

		case 0x77:	// RRA zero,X
			tmp = read_zp(adr = read_adr_zero_x());
			RoRightAdc
			write_zp(adr, tmp);
			ENDOP(6);

		case 0x6f:	// RRA abs
			tmp = read_byte(adr = read_adr_abs());
			RoRightAdc
			write_byte(adr, tmp);
			ENDOP(6);

		case 0x7f:	// RRA abs,X
			tmp = read_byte(adr = read_adr_abs_x());
			RoRightAdc
			write_byte(adr, tmp);
			ENDOP(7);

		case 0x7b:	// RRA abs,Y
			tmp = read_byte(adr = read_adr_abs_y());
			RoRightAdc
			write_byte(adr, tmp);
			ENDOP(7);

		case 0x63:	// RRA (ind,X)
			tmp = read_byte(adr = read_adr_ind_x());
			RoRightAdc
			write_byte(adr, tmp);
			ENDOP(8);

		case 0x73:	// RRA (ind),Y
			tmp = read_byte(adr = read_adr_ind_y());
			RoRightAdc
			write_byte(adr, tmp);
			ENDOP(8);


		// DEC/CMP group
#define DecCompare \
	set_nz(adr = a - tmp); \
	c_flag = adr < 0x100;

		case 0xc7:	// DCP zero
			tmp = read_zp(adr = read_adr_zero()) - 1;
			write_zp(adr, tmp);
			DecCompare;
			ENDOP(5);

		case 0xd7:	// DCP zero,X
			tmp = read_zp(adr = read_adr_zero_x()) - 1;
			write_zp(adr, tmp);
			DecCompare;
			ENDOP(6);

		case 0xcf:	// DCP abs
			tmp = read_byte(adr = read_adr_abs()) - 1;
			write_byte(adr, tmp);
			DecCompare;
			ENDOP(6);

		case 0xdf:	// DCP abs,X
			tmp = read_byte(adr = read_adr_abs_x()) - 1;
			write_byte(adr, tmp);
			DecCompare;
			ENDOP(7);

		case 0xdb:	// DCP abs,Y
			tmp = read_byte(adr = read_adr_abs_y()) - 1;
			write_byte(adr, tmp);
			DecCompare;
			ENDOP(7);

		case 0xc3:	// DCP (ind,X)
			tmp = read_byte(adr = read_adr_ind_x()) - 1;
			write_byte(adr, tmp);
			DecCompare;
			ENDOP(8);

		case 0xd3:	// DCP (ind),Y
			tmp = read_byte(adr = read_adr_ind_y()) - 1;
			write_byte(adr, tmp);
			DecCompare;
			ENDOP(8);


		// INC/SBC group
		case 0xe7:	// ISB zero
			tmp = read_zp(adr = read_adr_zero()) + 1;
			DoSbc(tmp);
			write_zp(adr, tmp);
			ENDOP(5);

		case 0xf7:	// ISB zero,X
			tmp = read_zp(adr = read_adr_zero_x()) + 1;
			DoSbc(tmp);
			write_zp(adr, tmp);
			ENDOP(6);

		case 0xef:	// ISB abs
			tmp = read_byte(adr = read_adr_abs()) + 1;
			DoSbc(tmp);
			write_byte(adr, tmp);
			ENDOP(6);

		case 0xff:	// ISB abs,X
			tmp = read_byte(adr = read_adr_abs_x()) + 1;
			DoSbc(tmp);
			write_byte(adr, tmp);
			ENDOP(7);

		case 0xfb:	// ISB abs,Y
			tmp = read_byte(adr = read_adr_abs_y()) + 1;
			DoSbc(tmp);
			write_byte(adr, tmp);
			ENDOP(7);

		case 0xe3:	// ISB (ind,X)
			tmp = read_byte(adr = read_adr_ind_x()) + 1;
			DoSbc(tmp);
			write_byte(adr, tmp);
			ENDOP(8);

		case 0xf3:	// ISB (ind),Y
			tmp = read_byte(adr = read_adr_ind_y()) + 1;
			DoSbc(tmp);
			write_byte(adr, tmp);
			ENDOP(8);


		// Complex functions
		case 0x0b:	// ANC #imm
		case 0x2b:
			set_nz(a &= read_byte_imm());
			c_flag = n_flag & 0x80;
			ENDOP(2);

		case 0x4b:	// ASR #imm
			a &= read_byte_imm();
			c_flag = a & 0x01;
			set_nz(a >>= 1);
			ENDOP(2);

		case 0x6b:	// ARR #imm
			tmp = read_byte_imm() & a;
			a = (c_flag ? (tmp >> 1) | 0x80 : tmp >> 1);
			if (!d_flag) {
				set_nz(a);
				c_flag = a & 0x40;
				v_flag = (a & 0x40) ^ ((a & 0x20) << 1);
			} else {
				n_flag = c_flag ? 0x80 : 0;
				z_flag = a;
				v_flag = (tmp ^ a) & 0x40;
				if ((tmp & 0x0f) + (tmp & 0x01) > 5)
					a = a & 0xf0 | (a + 6) & 0x0f;
				if (c_flag = ((tmp + (tmp & 0x10)) & 0x1f0) > 0x50)
					a += 0x60;
			}
			ENDOP(2);

		case 0x8b:	// ANE #imm
			set_nz(a = read_byte_imm() & x & (a | 0xee));
			ENDOP(2);

		case 0x93:	// SHA (ind),Y
			tmp = read_zp(pc[0] + 1);
			write_byte(read_adr_ind_y(), a & x & (tmp+1));
			ENDOP(6);

		case 0x9b:	// SHS abs,Y
			tmp = pc[1];
			write_byte(read_adr_abs_y(), a & x & (tmp+1));
			sp = a & x;
			ENDOP(5);

		case 0x9c:	// SHY abs,X
			tmp = pc[1];
			write_byte(read_adr_abs_x(), y & (tmp+1));
			ENDOP(5);

		case 0x9e:	// SHX abs,Y
			tmp = pc[1];
			write_byte(read_adr_abs_y(), x & (tmp+1));
			ENDOP(5);

		case 0x9f:	// SHA abs,Y
			tmp = pc[1];
			write_byte(read_adr_abs_y(), a & x & (tmp+1));
			ENDOP(5);

		case 0xab:	// LXA #imm
			set_nz(a = x = (a | 0xee) & read_byte_imm());
			ENDOP(2);

		case 0xbb:	// LAS abs,Y
			set_nz(a = x = sp = read_byte_abs_y() & sp);
			ENDOP(4);

		case 0xcb:	// SBX #imm
			x &= a;
			adr = x - read_byte_imm();
			c_flag = adr < 0x100;
			set_nz(x = adr);
			ENDOP(2);

		case 0x02:
		case 0x12:
		case 0x22:
		case 0x32:
		case 0x42:
		case 0x52:
		case 0x62:
		case 0x72:
		case 0x92:
		case 0xb2:
		case 0xd2:
			illegal_op(*(pc-1), pc-pc_base-1);
			break;
