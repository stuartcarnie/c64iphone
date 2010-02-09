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

#define ADD_KEY(key) { #key, KeyCode_##key, #key },
#define ADD_KEY2(key, name) { #key, KeyCode_##key, #name },

struct tagKey {
	const char*	key;
	KeyCode		code;
	const char*	imageName;
};

static tagKey keys[] = {
	ADD_KEY2(CUP,crsrup)
	ADD_KEY2(CDN,crsrdown)
	ADD_KEY(F6)
	ADD_KEY(F5)
	ADD_KEY(F4)
	ADD_KEY(F3)
	ADD_KEY(F2)
	ADD_KEY(F1)
	ADD_KEY(F8)
	ADD_KEY(F7)
	ADD_KEY2(CLT,crsrleft)
	ADD_KEY2(CRT,crsrright)
	ADD_KEY2(RET,return)
	ADD_KEY(DEL)
	ADD_KEY2(INSERT, inst)
	ADD_KEY2(SHL, shift)
	ADD_KEY(E)
	ADD_KEY(S)
	ADD_KEY(Z)
	ADD_KEY2(N4,4)
	ADD_KEY(DOLLAR)
	ADD_KEY(A)
	ADD_KEY(W)
	ADD_KEY2(N3,3)
	ADD_KEY2(NUMBERSIGN,hash)
	ADD_KEY(X)
	ADD_KEY(T)
	ADD_KEY(F)
	ADD_KEY(C)
	ADD_KEY2(N6,6)
	ADD_KEY2(AMPERSAND,and)
	ADD_KEY(D)
	ADD_KEY(R)
	ADD_KEY2(N5,5)
	ADD_KEY(PERCENT)
	ADD_KEY(V)
	ADD_KEY(U)
	ADD_KEY(H)
	ADD_KEY(B)
	ADD_KEY2(N8,8)
	ADD_KEY(OPENPAREN)
	ADD_KEY(G)
	ADD_KEY(Y)
	ADD_KEY2(N7,7)
	ADD_KEY(QUOTE)
	ADD_KEY(N)
	ADD_KEY(O)
	ADD_KEY(K)
	ADD_KEY(M)
	ADD_KEY2(N0,0)
	ADD_KEY(J)
	ADD_KEY(I)
	ADD_KEY2(N9,9)
	ADD_KEY(CLOSEPAREN)
	ADD_KEY(COMMA)
	ADD_KEY2(LESSTHAN,lt)
	ADD_KEY(AT)
	ADD_KEY(COLON)
	ADD_KEY(OPENBRACKET)
	ADD_KEY2(PERIOD,dot)
	ADD_KEY2(GREATERTHAN,gt)
	ADD_KEY2(MINUS,subtract)
	ADD_KEY(L)
	ADD_KEY(P)
	ADD_KEY(PLUS)
	ADD_KEY2(DIVIDE,slash)
	ADD_KEY(QUESTION)
	ADD_KEY(CARET)
	ADD_KEY2(EQUALS,equal)
	ADD_KEY2(SHR,shift)
	ADD_KEY2(HOM,home)
	ADD_KEY2(CLEAR,clr)
	ADD_KEY(SEMICOLON)
	ADD_KEY(CLOSEBRACKET)
	ADD_KEY(ASTERISK)
	ADD_KEY(POUND)
	ADD_KEY(RUNSTOP)
	ADD_KEY(SHIFT_RUNSTOP)
	ADD_KEY(Q)
	ADD_KEY(COMMODORE)
	ADD_KEY(SPACE)
	ADD_KEY2(N2,2)
	ADD_KEY(DBLQUOTE)
	ADD_KEY(CONTROL)
	ADD_KEY(BACKSPACE)
	ADD_KEY2(N1,1)
	ADD_KEY2(EXCLAMATION,exclaim)
	ADD_KEY(RESTORE)
	//ADD_KEY(RESET)
	ADD_KEY2(TOGGLE_SPEED,turbo)
};

const int keyCount = sizeof(keys) / sizeof(keys[0]);

tagKey* findKey(const char* name) {
	for (int i = 0; i < keyCount; i++) {
		if (strcasecmp(name, keys[i].key) == 0)
			return &keys[i];
	}
	
	return NULL;
}
