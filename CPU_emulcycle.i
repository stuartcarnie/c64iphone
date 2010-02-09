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
 *  CPU_emulcycle.i - SC 6510/6502 emulation core (body of
 *                    EmulateCycle() function, the same for
 *                    both 6510 and 6502)
 *
 *  Frodo (C) 1994-1997,2002 Christian Bauer
 */


/*
 *  Stack macros
 */

// Pop processor flags from the stack
#define pop_flags() \
	read_to(sp | 0x100, data); \
	n_flag = data; \
	v_flag = data & 0x40; \
	d_flag = data & 0x08; \
	i_flag = data & 0x04; \
	z_flag = !(data & 0x02); \
	c_flag = data & 0x01;

// Push processor flags onto the stack
#define push_flags(b_flag) \
	data = 0x20 | (n_flag & 0x80); \
	if (v_flag) data |= 0x40; \
	if (b_flag) data |= 0x10; \
	if (d_flag) data |= 0x08; \
	if (i_flag) data |= 0x04; \
	if (!z_flag) data |= 0x02; \
	if (c_flag) data |= 0x01; \
	write_byte(sp-- | 0x100, data);


/*
 *  Other macros
 */

// Branch (cycle 1)
#define Branch(flag) \
		read_to(pcSC, data);  \
		pcSC++; \
		if (flag) { \
			ar = pcSC + (int8)data; \
			if ((ar >> 8) != (pcSC >> 8)) { \
				if (data & 0x80) \
					state = O_BRANCH_BP; \
				else \
					state = O_BRANCH_FP; \
			} else \
				state = O_BRANCH_NP; \
		} else \
			state = 0; \
		break;

// Set N and Z flags according to byte
#define set_nz(x) (z_flag = n_flag = (x))

// Address fetch of RMW instruction done, now read and write operand
#define DoRMW state = RMW_DO_IT; break;

// Operand fetch done, now execute opcode
#define Execute state = OpTab[op]; break;

// Last cycle of opcode
#define Last state = 0; break;


/*
 *  EmulCycle() function
 */

  		// Opcode fetch (cycle 0)
	  	//case 0:
			read_to(pcSC, op);
			pcSC++;
			state = ModeTab[op];
			break;


		// IRQ
		case 0x0008:
			read_idle(pcSC);
			state = 0x0009;
			break;
		case 0x0009:
			read_idle(pcSC);
			state = 0x000a;
			break;
		case 0x000a:
			write_byte(sp-- | 0x100, pcSC >> 8);
			state = 0x000b;
			break;
		case 0x000b:
			write_byte(sp-- | 0x100, pcSC);
			state = 0x000c;
			break;
		case 0x000c:
			push_flags(false);
			i_flag = true;
			state = 0x000d;
			break;
		case 0x000d:
			read_to(0xfffe, pcSC);
			state = 0x000e;
			break;
		case 0x000e:
			read_to(0xffff, data);
			pcSC |= data << 8;
			Last;


		// NMI
		case 0x0010:
			read_idle(pcSC);
			state = 0x0011;
			break;
		case 0x0011:
			read_idle(pcSC);
			state = 0x0012;
			break;
		case 0x0012:
			write_byte(sp-- | 0x100, pcSC >> 8);
			state = 0x0013;
			break;
		case 0x0013:
			write_byte(sp-- | 0x100, pcSC);
			state = 0x0014;
			break;
		case 0x0014:
			push_flags(false);
			i_flag = true;
			state = 0x0015;
			break;
		case 0x0015:
			read_to(0xfffa, pcSC);
			state = 0x0016;
			break;
		case 0x0016:
			read_to(0xfffb, data);
			pcSC |= data << 8;
			Last;


		// Addressing modes: Fetch effective address, no extra cycles (-> ar)
		case A_ZERO:
			read_to(pcSC, ar);
			pcSC++;
			Execute;

		case A_ZEROX:
			read_to(pcSC, ar);
			pcSC++;
			state = A_ZEROX1;
			break;
		case A_ZEROX1:
			read_idle(ar);
			ar = (ar + x) & 0xff;
			Execute;

		case A_ZEROY:
			read_to(pcSC, ar);
			pcSC++;
			state = A_ZEROY1;
			break;
		case A_ZEROY1:
			read_idle(ar);
			ar = (ar + y) & 0xff;
			Execute;

		case A_ABS:
			read_to(pcSC, ar);
			pcSC++;
			state = A_ABS1;
			break;
		case A_ABS1:
			read_to(pcSC, data);
			pcSC++;
			ar = ar | (data << 8);
			Execute;

		case A_ABSX:
			read_to(pcSC, ar);
			pcSC++;
			state = A_ABSX1;
			break;
		case A_ABSX1:
			read_to(pcSC, ar2);	// Note: Some undocumented opcodes rely on the value of ar2
			pcSC++;
			if (ar+x < 0x100)
				state = A_ABSX2;
			else
				state = A_ABSX3;
			ar = (ar + x) & 0xff | (ar2 << 8);
			break;
		case A_ABSX2:	// No page crossed
			read_idle(ar);
			Execute;
		case A_ABSX3:	// Page crossed
			read_idle(ar);
			ar += 0x100;
			Execute;

		case A_ABSY:
			read_to(pcSC, ar);
			pcSC++;
			state = A_ABSY1;
			break;
		case A_ABSY1:
			read_to(pcSC, ar2);	// Note: Some undocumented opcodes rely on the value of ar2
			pcSC++;
			if (ar+y < 0x100)
				state = A_ABSY2;
			else
				state = A_ABSY3;
			ar = (ar + y) & 0xff | (ar2 << 8);
			break;
		case A_ABSY2:	// No page crossed
			read_idle(ar);
			Execute;
		case A_ABSY3:	// Page crossed
			read_idle(ar);
			ar += 0x100;
			Execute;

		case A_INDX:
			read_to(pcSC, ar2);
			pcSC++;
			state = A_INDX1;
			break;
		case A_INDX1:
			read_idle(ar2);
			ar2 = (ar2 + x) & 0xff;
			state = A_INDX2;
			break;
		case A_INDX2:
			read_to(ar2, ar);
			state = A_INDX3;
			break;
		case A_INDX3:
			read_to((ar2 + 1) & 0xff, data);
			ar = ar | (data << 8);
			Execute;

		case A_INDY:
			read_to(pcSC, ar2);
			pcSC++;
			state = A_INDY1;
			break;
		case A_INDY1:
			read_to(ar2, ar);
			state = A_INDY2;
			break;
		case A_INDY2:
			read_to((ar2 + 1) & 0xff, ar2);	// Note: Some undocumented opcodes rely on the value of ar2
			if (ar+y < 0x100)
				state = A_INDY3;
			else
				state = A_INDY4;
			ar = (ar + y) & 0xff | (ar2 << 8);
			break;
		case A_INDY3:	// No page crossed
			read_idle(ar);
			Execute;
		case A_INDY4:	// Page crossed
			read_idle(ar);
			ar += 0x100;
			Execute;


		// Addressing modes: Fetch effective address, extra cycle on page crossing (-> ar)
		case AE_ABSX:
			read_to(pcSC, ar);
			pcSC++;
			state = AE_ABSX1;
			break;
		case AE_ABSX1:
			read_to(pcSC, data);
			pcSC++;
			if (ar+x < 0x100) {
				ar = (ar + x) & 0xff | (data << 8);
				Execute;
			} else {
				ar = (ar + x) & 0xff | (data << 8);
				state = AE_ABSX2;
			}
			break;
		case AE_ABSX2:	// Page crossed
			read_idle(ar);
			ar += 0x100;
			Execute;

		case AE_ABSY:
			read_to(pcSC, ar);
			pcSC++;
			state = AE_ABSY1;
			break;
		case AE_ABSY1:
			read_to(pcSC, data);
			pcSC++;
			if (ar+y < 0x100) {
				ar = (ar + y) & 0xff | (data << 8);
				Execute;
			} else {
				ar = (ar + y) & 0xff | (data << 8);
				state = AE_ABSY2;
			}
			break;
		case AE_ABSY2:	// Page crossed
			read_idle(ar);
			ar += 0x100;
			Execute;

		case AE_INDY:
			read_to(pcSC, ar2);
			pcSC++;
			state = AE_INDY1;
			break;
		case AE_INDY1:
			read_to(ar2, ar);
			state = AE_INDY2;
			break;
		case AE_INDY2:
			read_to((ar2 + 1) & 0xff, data);
			if (ar+y < 0x100) {
				ar = (ar + y) & 0xff | (data << 8);
				Execute;
			} else {
				ar = (ar + y) & 0xff | (data << 8);
				state = AE_INDY3;
			}
			break;
		case AE_INDY3:	// Page crossed
			read_idle(ar);
			ar += 0x100;
			Execute;


		// Addressing modes: Read operand, write it back, no extra cycles (-> ar, rdbuf)
		case M_ZERO:
			read_to(pcSC, ar);
			pcSC++;
			DoRMW;

		case M_ZEROX:
			read_to(pcSC, ar);
			pcSC++;
			state = M_ZEROX1;
			break;
		case M_ZEROX1:
			read_idle(ar);
			ar = (ar + x) & 0xff;
			DoRMW;

		case M_ZEROY:
			read_to(pcSC, ar);
			pcSC++;
			state = M_ZEROY1;
			break;
		case M_ZEROY1:
			read_idle(ar);
			ar = (ar + y) & 0xff;
			DoRMW;

		case M_ABS:
			read_to(pcSC, ar);
			pcSC++;
			state = M_ABS1;
			break;
		case M_ABS1:
			read_to(pcSC, data);
			pcSC++;
			ar = ar | (data << 8);
			DoRMW;

		case M_ABSX:
			read_to(pcSC, ar);
			pcSC++;
			state = M_ABSX1;
			break;
		case M_ABSX1:
			read_to(pcSC, data);
			pcSC++;
			if (ar+x < 0x100)
				state = M_ABSX2;
			else
				state = M_ABSX3;
			ar = (ar + x) & 0xff | (data << 8);
			break;
		case M_ABSX2:	// No page crossed
			read_idle(ar);
			DoRMW;
		case M_ABSX3:	// Page crossed
			read_idle(ar);
			ar += 0x100;
			DoRMW;

		case M_ABSY:
			read_to(pcSC, ar);
			pcSC++;
			state = M_ABSY1;
			break;
		case M_ABSY1:
			read_to(pcSC, data);
			pcSC++;
			if (ar+y < 0x100)
				state = M_ABSY2;
			else
				state = M_ABSY3;
			ar = (ar + y) & 0xff | (data << 8);
			break;
		case M_ABSY2:	// No page crossed
			read_idle(ar);
			DoRMW;
		case M_ABSY3:	// Page crossed
			read_idle(ar);
			ar += 0x100;
			DoRMW;

		case M_INDX:
			read_to(pcSC, ar2);
			pcSC++;
			state = M_INDX1;
			break;
		case M_INDX1:
			read_idle(ar2);
			ar2 = (ar2 + x) & 0xff;
			state = M_INDX2;
			break;
		case M_INDX2:
			read_to(ar2, ar);
			state = M_INDX3;
			break;
		case M_INDX3:
			read_to((ar2 + 1) & 0xff, data);
			ar = ar | (data << 8);
			DoRMW;

		case M_INDY:
			read_to(pcSC, ar2);
			pcSC++;
			state = M_INDY1;
			break;
		case M_INDY1:
			read_to(ar2, ar);
			state = M_INDY2;
			break;
		case M_INDY2:
			read_to((ar2 + 1) & 0xff, data);
			if (ar+y < 0x100)
				state = M_INDY3;
			else
				state = M_INDY4;
			ar = (ar + y) & 0xff | (data << 8);
			break;
		case M_INDY3:	// No page crossed
			read_idle(ar);
			DoRMW;
		case M_INDY4:	// Page crossed
			read_idle(ar);
			ar += 0x100;
			DoRMW;

		case RMW_DO_IT:
			read_to(ar, rdbuf);
			state = RMW_DO_IT1;
			break;
		case RMW_DO_IT1:
			write_byte(ar, rdbuf);
			Execute;


		// Load group
		case O_LDA:
			read_to(ar, data);
			set_nz(a = data);
			Last;
		case O_LDA_I:
			read_to(pcSC, data);
			pcSC++;
			set_nz(a = data);
			Last;

		case O_LDX:
			read_to(ar, data);
			set_nz(x = data);
			Last;
		case O_LDX_I:
			read_to(pcSC, data);
			pcSC++;
			set_nz(x = data);
			Last;

		case O_LDY:
			read_to(ar, data);
			set_nz(y = data);
			Last;
		case O_LDY_I:
			read_to(pcSC, data);
			pcSC++;
			set_nz(y = data);
			Last;


		// Store group
		case O_STA:
			write_byte(ar, a);
			Last;

		case O_STX:
			write_byte(ar, x);
			Last;

		case O_STY:
			write_byte(ar, y);
			Last;


		// Transfer group
		case O_TAX:
			read_idle(pcSC);
			set_nz(x = a);
			Last;

		case O_TXA:
			read_idle(pcSC);
			set_nz(a = x);
			Last;

		case O_TAY:
			read_idle(pcSC);
			set_nz(y = a);
			Last;

		case O_TYA:
			read_idle(pcSC);
			set_nz(a = y);
			Last;

		case O_TSX:
			read_idle(pcSC);
			set_nz(x = sp);
			Last;

		case O_TXS:
			read_idle(pcSC);
			sp = x;
			Last;


		// Arithmetic group
		case O_ADC:
			read_to(ar, data);
			do_adc(data);
			Last;
		case O_ADC_I:
			read_to(pcSC, data);
			pcSC++;
			do_adc(data);
			Last;

		case O_SBC:
			read_to(ar, data);
			do_sbc(data);
			Last;
		case O_SBC_I:
			read_to(pcSC, data);
			pcSC++;
			do_sbc(data);
			Last;


		// Increment/decrement group
		case O_INX:
			read_idle(pcSC);
			set_nz(++x);
			Last;

		case O_DEX:
			read_idle(pcSC);
			set_nz(--x);
			Last;

		case O_INY:
			read_idle(pcSC);
			set_nz(++y);
			Last;

		case O_DEY:
			read_idle(pcSC);
			set_nz(--y);
			Last;

		case O_INC:
			write_byte(ar, set_nz(rdbuf + 1));
			Last;

		case O_DEC:
			write_byte(ar, set_nz(rdbuf - 1));
			Last;


		// Logic group
		case O_AND:
			read_to(ar, data);
			set_nz(a &= data);
			Last;
		case O_AND_I:
			read_to(pcSC, data);
			pcSC++;
			set_nz(a &= data);
			Last;

		case O_ORA:
			read_to(ar, data);
			set_nz(a |= data);
			Last;
		case O_ORA_I:
			read_to(pcSC, data);
			pcSC++;
			set_nz(a |= data);
			Last;

		case O_EOR:
			read_to(ar, data);
			set_nz(a ^= data);
			Last;
		case O_EOR_I:
			read_to(pcSC, data);
			pcSC++;
			set_nz(a ^= data);
			Last;

		// Compare group
		case O_CMP:
			read_to(ar, data);
			set_nz(ar = a - data);
			c_flag = ar < 0x100;
			Last;
		case O_CMP_I:
			read_to(pcSC, data);
			pcSC++;
			set_nz(ar = a - data);
			c_flag = ar < 0x100;
			Last;

		case O_CPX:
			read_to(ar, data);
			set_nz(ar = x - data);
			c_flag = ar < 0x100;
			Last;
		case O_CPX_I:
			read_to(pcSC, data);
			pcSC++;
			set_nz(ar = x - data);
			c_flag = ar < 0x100;
			Last;

		case O_CPY:
			read_to(ar, data);
			set_nz(ar = y - data);
			c_flag = ar < 0x100;
			Last;
		case O_CPY_I:
			read_to(pcSC, data);
			pcSC++;
			set_nz(ar = y - data);
			c_flag = ar < 0x100;
			Last;


		// Bit-test group
		case O_BIT:
			read_to(ar, data);
			z_flag = a & data;
			n_flag = data;
			v_flag = data & 0x40;
			Last;


		// Shift/rotate group
		case O_ASL:
			c_flag = rdbuf & 0x80;
			write_byte(ar, set_nz(rdbuf << 1));
			Last;
		case O_ASL_A:
			read_idle(pcSC);
			c_flag = a & 0x80;
			set_nz(a <<= 1);
			Last;

		case O_LSR:
			c_flag = rdbuf & 0x01;
			write_byte(ar, set_nz(rdbuf >> 1));
			Last;
		case O_LSR_A:
			read_idle(pcSC);
			c_flag = a & 0x01;
			set_nz(a >>= 1);
			Last;

		case O_ROL:
			write_byte(ar, set_nz(c_flag ? (rdbuf << 1) | 0x01 : rdbuf << 1));
			c_flag = rdbuf & 0x80;
			Last;
		case O_ROL_A:
			read_idle(pcSC);
			data = a & 0x80;
			set_nz(a = c_flag ? (a << 1) | 0x01 : a << 1);
			c_flag = data;
			Last;

		case O_ROR:
			write_byte(ar, set_nz(c_flag ? (rdbuf >> 1) | 0x80 : rdbuf >> 1));
			c_flag = rdbuf & 0x01;
			Last;
		case O_ROR_A:
			read_idle(pcSC);
			data = a & 0x01;
			set_nz(a = (c_flag ? (a >> 1) | 0x80 : a >> 1));
			c_flag = data;
			Last;


		// Stack group
		case O_PHA:
			read_idle(pcSC);
			state = O_PHA1;
			break;
		case O_PHA1:
			write_byte(sp-- | 0x100, a);
			Last;

		case O_PLA:
			read_idle(pcSC);
			state = O_PLA1;
			break;
		case O_PLA1:
			read_idle(sp | 0x100);
			sp++;
			state = O_PLA2;
			break;
		case O_PLA2:
			read_to(sp | 0x100, data);
			set_nz(a = data);
			Last;

		case O_PHP:
			read_idle(pcSC);
			state = O_PHP1;
			break;
		case O_PHP1:
			push_flags(true);
			Last;

		case O_PLP:
			read_idle(pcSC);
			state = O_PLP1;
			break;
		case O_PLP1:
			read_idle(sp | 0x100);
			sp++;
			state = O_PLP2;
			break;
		case O_PLP2:
			pop_flags();
			Last;


		// Jump/branch group
		case O_JMP:
			read_to(pcSC, ar);
			pcSC++;
			state = O_JMP1;
			break;
		case O_JMP1:
			read_to(pcSC, data);
			pcSC = (data << 8) | ar;
			Last;

		case O_JMP_I:
			read_to(ar, pcSC);
			state = O_JMP_I1;
			break;
		case O_JMP_I1:
			read_to((ar + 1) & 0xff | ar & 0xff00, data);
			pcSC |= data << 8;
			Last;

		case O_JSR:
			read_to(pcSC, ar);
			pcSC++;
			state = O_JSR1;
			break;
		case O_JSR1:
			read_idle(sp | 0x100);
			state = O_JSR2;
			break;
		case O_JSR2:
			write_byte(sp-- | 0x100, pcSC >> 8);
			state = O_JSR3;
			break;
		case O_JSR3:
			write_byte(sp-- | 0x100, pcSC);
			state = O_JSR4;
			break;
		case O_JSR4:
			read_to(pcSC, data);
			pcSC++;
			pcSC = ar | (data << 8);
			Last;

		case O_RTS:
			read_idle(pcSC);
			state = O_RTS1;
			break;
		case O_RTS1:
			read_idle(sp | 0x100);
			sp++;
			state = O_RTS2;
			break;
		case O_RTS2:
			read_to(sp | 0x100, pcSC);
			sp++;
			state = O_RTS3;
			break;
		case O_RTS3:
			read_to(sp | 0x100, data);
			pcSC |= data << 8;
			state = O_RTS4;
			break;
		case O_RTS4:
			read_idle(pcSC);
			pcSC++;
			Last;

		case O_RTI:
			read_idle(pcSC);
			state = O_RTI1;
			break;
		case O_RTI1:
			read_idle(sp | 0x100);
			sp++;
			state = O_RTI2;
			break;
		case O_RTI2:
			pop_flags();
			sp++;
			state = O_RTI3;
			break;
		case O_RTI3:
			read_to(sp | 0x100, pcSC);
			sp++;
			state = O_RTI4;
			break;
		case O_RTI4:
			read_to(sp | 0x100, data);
			pcSC |= data << 8;
			Last;

		case O_BRK:
			read_idle(pcSC);
			pcSC++;
			state = O_BRK1;
			break;
		case O_BRK1:
			write_byte(sp-- | 0x100, pcSC >> 8);
			state = O_BRK2;
			break;
		case O_BRK2:
			write_byte(sp-- | 0x100, pcSC);
			state = O_BRK3;
			break;
		case O_BRK3:
			push_flags(true);
			i_flag = true;
#ifndef IS_CPU_1541
			if (interrupt.intr[INT_NMI]) {			// BRK interrupted by NMI?
				interrupt.intr[INT_NMI] = false;	// Simulate an edge-triggered input
				state = 0x0015;						// Jump to NMI sequence
				break;
			}
#endif
			state = O_BRK4;
			break;
		case O_BRK4:
#ifndef IS_CPU_1541
			first_nmi_cycle++;		// Delay NMI
#endif
			read_to(0xfffe, pcSC);
			state = O_BRK5;
			break;
		case O_BRK5:
			read_to(0xffff, data);
			pcSC |= data << 8;
			Last;

		case O_BCS:
			Branch(c_flag);

		case O_BCC:
			Branch(!c_flag);

		case O_BEQ:
			Branch(!z_flag);

		case O_BNE:
			Branch(z_flag);

		case O_BVS:
#ifndef IS_CPU_1541
			Branch(v_flag);
#else
			Branch((via2_pcr & 0x0e) == 0x0e ? 1 : v_flag);	// GCR byte ready flag
#endif

		case O_BVC:
#ifndef IS_CPU_1541
			Branch(!v_flag);
#else
			Branch(!((via2_pcr & 0x0e) == 0x0e) ? 0 : v_flag);	// GCR byte ready flag
#endif

		case O_BMI:
			Branch(n_flag & 0x80);

		case O_BPL:
			Branch(!(n_flag & 0x80));

		case O_BRANCH_NP:	// No page crossed
			first_irq_cycle++;	// Delay IRQ
#ifndef IS_CPU_1541
			first_nmi_cycle++;	// Delay NMI
#endif
			read_idle(pcSC);
			pcSC = ar;
			Last;
		case O_BRANCH_BP:	// Page crossed, branch backwards
			read_idle(pcSC);
			pcSC = ar;
			state = O_BRANCH_BP1;
			break;
		case O_BRANCH_BP1:
			read_idle(pcSC + 0x100);
			Last;
		case O_BRANCH_FP:	// Page crossed, branch forwards
			read_idle(pcSC);
			pcSC = ar;
			state = O_BRANCH_FP1;
			break;
		case O_BRANCH_FP1:
			read_idle(pcSC - 0x100);
			Last;


		// Flag group
		case O_SEC:
			read_idle(pcSC);
			c_flag = true;
			Last;

		case O_CLC:
			read_idle(pcSC);
			c_flag = false;
			Last;

		case O_SED:
			read_idle(pcSC);
			d_flag = true;
			Last;

		case O_CLD:
			read_idle(pcSC);
			d_flag = false;
			Last;

		case O_SEI:
			read_idle(pcSC);
			i_flag = true;
			Last;

		case O_CLI:
			read_idle(pcSC);
			i_flag = false;
			Last;

		case O_CLV:
			read_idle(pcSC);
			v_flag = false;
			Last;


		// NOP group
		case O_NOP:
			read_idle(pcSC);
			Last;


/*
 * Undocumented opcodes start here
 */

		// NOP group
		case O_NOP_I:
			read_idle(pcSC);
			pcSC++;
			Last;

		case O_NOP_A:
			read_idle(ar);
			Last;


		// Load A/X group
		case O_LAX:
			read_to(ar, data);
			set_nz(a = x = data);
			Last;


		// Store A/X group
		case O_SAX:
			write_byte(ar, a & x);
			Last;


		// ASL/ORA group
		case O_SLO:
			c_flag = rdbuf & 0x80;
			rdbuf <<= 1;
			write_byte(ar, rdbuf);
			set_nz(a |= rdbuf);
			Last;


		// ROL/AND group
		case O_RLA:
			data = rdbuf & 0x80;
			rdbuf = c_flag ? (rdbuf << 1) | 0x01 : rdbuf << 1;
			c_flag = data;
			write_byte(ar, rdbuf);
			set_nz(a &= rdbuf);
			Last;


		// LSR/EOR group
		case O_SRE:
			c_flag = rdbuf & 0x01;
			rdbuf >>= 1;
			write_byte(ar, rdbuf);
			set_nz(a ^= rdbuf);
			Last;


		// ROR/ADC group
		case O_RRA:
			data = rdbuf & 0x01;
			rdbuf = c_flag ? (rdbuf >> 1) | 0x80 : rdbuf >> 1;
			c_flag = data;
			write_byte(ar, rdbuf);
			do_adc(rdbuf);
			Last;


		// DEC/CMP group
		case O_DCP:
			write_byte(ar, --rdbuf);
			set_nz(ar = a - rdbuf);
			c_flag = ar < 0x100;
			Last;


		// INC/SBC group
		case O_ISB:
			write_byte(ar, ++rdbuf);
			do_sbc(rdbuf);
			Last;


		// Complex functions
		case O_ANC_I:
			read_to(pcSC, data);
			pcSC++;
			set_nz(a &= data);
			c_flag = n_flag & 0x80;
			Last;

		case O_ASR_I:
			read_to(pcSC, data);
			pcSC++;
			a &= data;
			c_flag = a & 0x01;
			set_nz(a >>= 1);
			Last;

		case O_ARR_I:
			read_to(pcSC, data);
			pcSC++;
			data &= a;
			a = (c_flag ? (data >> 1) | 0x80 : data >> 1);
			if (!d_flag) {
				set_nz(a);
				c_flag = a & 0x40;
				v_flag = (a & 0x40) ^ ((a & 0x20) << 1);
			} else {
				n_flag = c_flag ? 0x80 : 0;
				z_flag = a;
				v_flag = (data ^ a) & 0x40;
				if ((data & 0x0f) + (data & 0x01) > 5)
					a = a & 0xf0 | (a + 6) & 0x0f;
				if (c_flag = ((data + (data & 0x10)) & 0x1f0) > 0x50)
					a += 0x60;
			}
			Last;

		case O_ANE_I:
			read_to(pcSC, data);
			pcSC++;
			set_nz(a = (a | 0xee) & x & data);
			Last;

		case O_LXA_I:
			read_to(pcSC, data);
			pcSC++;
			set_nz(a = x = (a | 0xee) & data);
			Last;

		case O_SBX_I:
			read_to(pcSC, data);
			pcSC++;
			set_nz(x = ar = (x & a) - data);
			c_flag = ar < 0x100;
			Last;

		case O_LAS:
			read_to(ar, data);
			set_nz(a = x = sp = data & sp);
			Last;

		case O_SHS:		// ar2 contains the high byte of the operand address
			write_byte(ar, (ar2+1) & (sp = a & x));
			Last;

		case O_SHY:		// ar2 contains the high byte of the operand address
			write_byte(ar, y & (ar2+1));
			Last;

		case O_SHX:		// ar2 contains the high byte of the operand address
			write_byte(ar, x & (ar2+1));
			Last;

		case O_SHA:		// ar2 contains the high byte of the operand address
			write_byte(ar, a & x & (ar2+1));
			Last;
