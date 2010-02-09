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
 *  CPU_common.h - Definitions common to 6502/6510 SC emulation
 *
 *  Frodo (C) 1994-1997,2002 Christian Bauer
 */

#ifndef _CPU_COMMON_H_
#define _CPU_COMMON_H_


// States for addressing modes/operations (Frodo SC)
enum {
	// Read effective address, no extra cycles
	A_ZERO=0x18,
	A_ZEROX, A_ZEROX1,
	A_ZEROY, A_ZEROY1,
	A_ABS, A_ABS1,
	A_ABSX, A_ABSX1, A_ABSX2, A_ABSX3,
	A_ABSY, A_ABSY1, A_ABSY2, A_ABSY3,
	A_INDX, A_INDX1, A_INDX2, A_INDX3,
	A_INDY, A_INDY1, A_INDY2, A_INDY3, A_INDY4,

	// Read effective address, extra cycle on page crossing
	AE_ABSX, AE_ABSX1, AE_ABSX2,
	AE_ABSY, AE_ABSY1, AE_ABSY2,
	AE_INDY, AE_INDY1, AE_INDY2, AE_INDY3,

	// Read operand and write it back (for RMW instructions), no extra cycles
	M_ZERO,
	M_ZEROX, M_ZEROX1,
	M_ZEROY, M_ZEROY1,
	M_ABS, M_ABS1,
	M_ABSX, M_ABSX1, M_ABSX2, M_ABSX3,
	M_ABSY, M_ABSY1, M_ABSY2, M_ABSY3,
	M_INDX, M_INDX1, M_INDX2, M_INDX3,
	M_INDY, M_INDY1, M_INDY2, M_INDY3, M_INDY4,
	RMW_DO_IT, RMW_DO_IT1,

	// Operations (_I = Immediate/Indirect, _A = Accumulator)
	O_LDA, O_LDA_I, O_LDX, O_LDX_I, O_LDY, O_LDY_I,
	O_STA, O_STX, O_STY,
	O_TAX, O_TXA, O_TAY, O_TYA, O_TSX, O_TXS,
	O_ADC, O_ADC_I, O_SBC, O_SBC_I,
	O_INX, O_DEX, O_INY, O_DEY, O_INC, O_DEC,
	O_AND, O_AND_I, O_ORA, O_ORA_I, O_EOR, O_EOR_I,
	O_CMP, O_CMP_I, O_CPX, O_CPX_I, O_CPY, O_CPY_I,
	O_BIT,
	O_ASL, O_ASL_A, O_LSR, O_LSR_A, O_ROL, O_ROL_A, O_ROR, O_ROR_A,
	O_PHA, O_PHA1, O_PLA, O_PLA1, O_PLA2,
	O_PHP, O_PHP1, O_PLP, O_PLP1, O_PLP2,
	O_JMP, O_JMP1, O_JMP_I, O_JMP_I1,
	O_JSR, O_JSR1, O_JSR2, O_JSR3, O_JSR4,
	O_RTS, O_RTS1, O_RTS2, O_RTS3, O_RTS4,
	O_RTI, O_RTI1, O_RTI2, O_RTI3, O_RTI4,
	O_BRK, O_BRK1, O_BRK2, O_BRK3, O_BRK4, O_BRK5, O_BRK5NMI,
	O_BCS, O_BCC, O_BEQ, O_BNE, O_BVS, O_BVC, O_BMI, O_BPL,
	O_BRANCH_NP, O_BRANCH_BP, O_BRANCH_BP1, O_BRANCH_FP, O_BRANCH_FP1,
	O_SEC, O_CLC, O_SED, O_CLD, O_SEI, O_CLI, O_CLV,
	O_NOP,

	O_NOP_I, O_NOP_A,
	O_LAX, O_SAX,
	O_SLO, O_RLA, O_SRE, O_RRA, O_DCP, O_ISB,
	O_ANC_I, O_ASR_I, O_ARR_I, O_ANE_I, O_LXA_I, O_SBX_I,
	O_LAS, O_SHS, O_SHY, O_SHX, O_SHA,
	O_EXT
};


// Addressing mode for each opcode (first part of execution) (Frodo SC)
extern const uint8 ModeTab[256];

// Operation for each opcode (second part of execution) (Frodo SC)
extern const uint8 OpTab[256];

#endif
