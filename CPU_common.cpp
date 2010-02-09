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
 *  CPU_common.cpp - Definitions common to 6502/6510 SC emulation
 *
 *  Frodo (C) 1994-1997,2002 Christian Bauer
 */

#include "sysdeps.h"

#include "CPU_common.h"


// Addressing mode for each opcode (first part of execution) (Frodo SC)
const uint8 ModeTab[256] = {
	O_BRK,	A_INDX,	1,		M_INDX,	A_ZERO,	A_ZERO,	M_ZERO,	M_ZERO,	// 00
	O_PHP,	O_ORA_I,O_ASL_A,O_ANC_I,A_ABS,	A_ABS,	M_ABS,	M_ABS,
	O_BPL,	AE_INDY,1,		M_INDY,	A_ZEROX,A_ZEROX,M_ZEROX,M_ZEROX,// 10
	O_CLC,	AE_ABSY,O_NOP,	M_ABSY,	AE_ABSX,AE_ABSX,M_ABSX,	M_ABSX,
	O_JSR,	A_INDX,	1,		M_INDX,	A_ZERO,	A_ZERO,	M_ZERO,	M_ZERO,	// 20
	O_PLP,	O_AND_I,O_ROL_A,O_ANC_I,A_ABS,	A_ABS,	M_ABS,	M_ABS,
	O_BMI,	AE_INDY,1,		M_INDY,	A_ZEROX,A_ZEROX,M_ZEROX,M_ZEROX,// 30
	O_SEC,	AE_ABSY,O_NOP,	M_ABSY,	AE_ABSX,AE_ABSX,M_ABSX,	M_ABSX,
	O_RTI,	A_INDX,	1,		M_INDX,	A_ZERO,	A_ZERO,	M_ZERO,	M_ZERO,	// 40
	O_PHA,	O_EOR_I,O_LSR_A,O_ASR_I,O_JMP,	A_ABS,	M_ABS,	M_ABS,
	O_BVC,	AE_INDY,1,		M_INDY,	A_ZEROX,A_ZEROX,M_ZEROX,M_ZEROX,// 50
	O_CLI,	AE_ABSY,O_NOP,	M_ABSY,	AE_ABSX,AE_ABSX,M_ABSX,	M_ABSX,
	O_RTS,	A_INDX,	1,		M_INDX,	A_ZERO,	A_ZERO,	M_ZERO,	M_ZERO,	// 60
	O_PLA,	O_ADC_I,O_ROR_A,O_ARR_I,A_ABS,	A_ABS,	M_ABS,	M_ABS,
	O_BVS,	AE_INDY,1,		M_INDY,	A_ZEROX,A_ZEROX,M_ZEROX,M_ZEROX,// 70
	O_SEI,	AE_ABSY,O_NOP,	M_ABSY,	AE_ABSX,AE_ABSX,M_ABSX,	M_ABSX,
	O_NOP_I,A_INDX,	O_NOP_I,A_INDX,	A_ZERO,	A_ZERO,	A_ZERO,	A_ZERO,	// 80
	O_DEY,	O_NOP_I,O_TXA,	O_ANE_I,A_ABS,	A_ABS,	A_ABS,	A_ABS,
	O_BCC,	A_INDY,	1,		A_INDY,	A_ZEROX,A_ZEROX,A_ZEROY,A_ZEROY,// 90
	O_TYA,	A_ABSY,	O_TXS,	A_ABSY,	A_ABSX,	A_ABSX,	A_ABSY,	A_ABSY,
	O_LDY_I,A_INDX,	O_LDX_I,A_INDX,	A_ZERO,	A_ZERO,	A_ZERO,	A_ZERO,	// a0
	O_TAY,	O_LDA_I,O_TAX,	O_LXA_I,A_ABS,	A_ABS,	A_ABS,	A_ABS,
	O_BCS,	AE_INDY,1,		AE_INDY,A_ZEROX,A_ZEROX,A_ZEROY,A_ZEROY,// b0
	O_CLV,	AE_ABSY,O_TSX,	AE_ABSY,AE_ABSX,AE_ABSX,AE_ABSY,AE_ABSY,
	O_CPY_I,A_INDX,	O_NOP_I,M_INDX,	A_ZERO,	A_ZERO,	M_ZERO,	M_ZERO,	// c0
	O_INY,	O_CMP_I,O_DEX,	O_SBX_I,A_ABS,	A_ABS,	M_ABS,	M_ABS,
	O_BNE,	AE_INDY,1,		M_INDY,	A_ZEROX,A_ZEROX,M_ZEROX,M_ZEROX,// d0
	O_CLD,	AE_ABSY,O_NOP,	M_ABSY,	AE_ABSX,AE_ABSX,M_ABSX,	M_ABSX,
	O_CPX_I,A_INDX,	O_NOP_I,M_INDX,	A_ZERO,	A_ZERO,	M_ZERO,	M_ZERO,	// e0
	O_INX,	O_SBC_I,O_NOP,	O_SBC_I,A_ABS,	A_ABS,	M_ABS,	M_ABS,
	O_BEQ,	AE_INDY,O_EXT,	M_INDY,	A_ZEROX,A_ZEROX,M_ZEROX,M_ZEROX,// f0
	O_SED,	AE_ABSY,O_NOP,	M_ABSY,	AE_ABSX,AE_ABSX,M_ABSX,	M_ABSX
};


// Operation for each opcode (second part of execution) (Frodo SC)
const uint8 OpTab[256] = {
	1,		O_ORA,	1,		O_SLO,	O_NOP_A,O_ORA,	O_ASL,	O_SLO,	// 00
	1,		1,		1,		1,		O_NOP_A,O_ORA,	O_ASL,	O_SLO,
	1,		O_ORA,	1,		O_SLO,	O_NOP_A,O_ORA,	O_ASL,	O_SLO,	// 10
	1,		O_ORA,	1,		O_SLO,	O_NOP_A,O_ORA,	O_ASL,	O_SLO,
	1,		O_AND,	1,		O_RLA,	O_BIT,	O_AND,	O_ROL,	O_RLA,	// 20
	1,		1,		1,		1,		O_BIT,	O_AND,	O_ROL,	O_RLA,
	1,		O_AND,	1,		O_RLA,	O_NOP_A,O_AND,	O_ROL,	O_RLA,	// 30
	1,		O_AND,	1,		O_RLA,	O_NOP_A,O_AND,	O_ROL,	O_RLA,
	1,		O_EOR,	1,		O_SRE,	O_NOP_A,O_EOR,	O_LSR,	O_SRE,	// 40
	1,		1,		1,		1,		1,		O_EOR,	O_LSR,	O_SRE,
	1,		O_EOR,	1,		O_SRE,	O_NOP_A,O_EOR,	O_LSR,	O_SRE,	// 50
	1,		O_EOR,	1,		O_SRE,	O_NOP_A,O_EOR,	O_LSR,	O_SRE,
	1,		O_ADC,	1,		O_RRA,	O_NOP_A,O_ADC,	O_ROR,	O_RRA,	// 60
	1,		1,		1,		1,		O_JMP_I,O_ADC,	O_ROR,	O_RRA,
	1,		O_ADC,	1,		O_RRA,	O_NOP_A,O_ADC,	O_ROR,	O_RRA,	// 70
	1,		O_ADC,	1,		O_RRA,	O_NOP_A,O_ADC,	O_ROR,	O_RRA,
	1,		O_STA,	1,		O_SAX,	O_STY,	O_STA,	O_STX,	O_SAX,	// 80
	1,		1,		1,		1,		O_STY,	O_STA,	O_STX,	O_SAX,
	1,		O_STA,	1,		O_SHA,	O_STY,	O_STA,	O_STX,	O_SAX,	// 90
	1,		O_STA,	1,		O_SHS,	O_SHY,	O_STA,	O_SHX,	O_SHA,
	1,		O_LDA,	1,		O_LAX,	O_LDY,	O_LDA,	O_LDX,	O_LAX,	// a0
	1,		1,		1,		1,		O_LDY,	O_LDA,	O_LDX,	O_LAX,
	1,		O_LDA,	1,		O_LAX,	O_LDY,	O_LDA,	O_LDX,	O_LAX,	// b0
	1,		O_LDA,	1,		O_LAS,	O_LDY,	O_LDA,	O_LDX,	O_LAX,
	1,		O_CMP,	1,		O_DCP,	O_CPY,	O_CMP,	O_DEC,	O_DCP,	// c0
	1,		1,		1,		1,		O_CPY,	O_CMP,	O_DEC,	O_DCP,
	1,		O_CMP,	1,		O_DCP,	O_NOP_A,O_CMP,	O_DEC,	O_DCP,	// d0
	1,		O_CMP,	1,		O_DCP,	O_NOP_A,O_CMP,	O_DEC,	O_DCP,
	1,		O_SBC,	1,		O_ISB,	O_CPX,	O_SBC,	O_INC,	O_ISB,	// e0
	1,		1,		1,		1,		O_CPX,	O_SBC,	O_INC,	O_ISB,
	1,		O_SBC,	1,		O_ISB,	O_NOP_A,O_SBC,	O_INC,	O_ISB,	// f0
	1,		O_SBC,	1,		O_ISB,	O_NOP_A,O_SBC,	O_INC,	O_ISB
};
