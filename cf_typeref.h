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
 *  cf_typeref.h
 *  iFrodo
 *
 *  Created by Stuart Carnie on 5/6/08.
 *  Copyright 2008 __MyCompanyName__. All rights reserved.
 *
 */

/* Call CFRelease on a CFTypeRef and reset it to NULL. */
template <class A>
inline void safe_release(A& target)
{
    if (target) {
		CFRelease(target);
		target = NULL;
    }
}

/* Call CFRetain on a CFTypeRef and safely ignore NULL. */
template <class A>
inline A safe_retain(A& target)
{
    if (target) {
		/* We need the cast here because CFRetain returns a CFTypeRef which is
		 * a const void *, and we are declared to return whatever type A is,
		 * although it basically has to be some CF pointer type.
		 */
		return (A)CFRetain(target);
    } else {
		return NULL;
    }
}

/* Compare two CFTypeRefs. CFEqual doesn't handle being passed NULL, so this
 * is a safe wrapper.
 */
template <class T>
static bool cftype_equal(const T& lhs, const T& rhs)
{
	if (rhs == lhs) {
	    /* Pointer comparison matches. */
	    return true;
	} else if (lhs == NULL || rhs == NULL) {
	    /* One side (but not both) is NULL. */
	    return false;
	} else {
	    return (CFEqual(lhs, rhs) != 0);
	}
}

template <class T> class cf_typeref
	{
	public:
		cf_typeref(T ref) : m_ref(ref) {}
		~cf_typeref() { safe_release(this->m_ref); }
		
		/* Return the CFTypeRef we are holding. */
		operator T() const { return this->m_ref; }
		
		/* We are false if the CFTypeRef we hold is NULL. */
		operator bool() const { return this->m_ref != NULL; }
		
		bool operator==(const T& rhs) const
		{
			return cftype_equal<T>(this->m_ref, rhs);
		}
		
		/* Compare to a matching cf_typeref<T>. */
		bool operator==(const cf_typeref& rhs) const
		{
			return cftype_equal<T>(this->m_ref, rhs->m_ref);
		}
		
	private:
		/* Disable assignment and copy constructor. We don't wan to be doing
		 * reference counting. This class is only intended for very simple RAII
		 * codepaths.
		 */
		cf_typeref(const cf_typeref&); // nocopy
		cf_typeref& operator=(const cf_typeref&); // nocopy
		
		T m_ref;
	};