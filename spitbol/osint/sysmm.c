/*
/	File:  SYSMM.C		Version:  01.04
/	---------------------------------------
/
/	Contents:	Function zysmm
*/
/*  Copyright 1991 Robert Goldberg and Catspaw, Inc. */

/*
/	zysmm- get more memory
/
/	Parameters:
/	    None
/	Returns:
/	    XR - number of addtional words obtained
/	Exits:
/	    None
/
/  V1.02 08/06/89 - if allocation fails, try smaller amounts within reason.
/  V1.03 11/07/89 - add sanity check to make sure new memory is contiguous
/		    with old end of heap.
/  V1.04 01/29/91 - remove else clause within moremem(), add comments.
/
*/

#include "port.h"

zysmm()

{
	long n;
	char *dummy;

	SET_XR( 0 );			/* Assume allocation will fail */

  /*
	/   If not already at maximum allocation, try to get more memory.
	*/
	if ( topmem < maxmem ) {
	    n = moremem(memincb, &dummy);
	    topmem += n;		/*  adjust current top address	*/
	    SET_XR( n / sizeof(word) ); /*  set # of words obtained*/
	    }
  return NORMAL_RETURN;
}

/*
 * moremem(n) - Attempt to fetch n bytes more memory.
 *		Returns number of bytes actually obtained.
 *		Address returned by sbrk returned in *pp.
 *
 *	Returns the maximum amount <= n.
 *
 * Strategy: Attempt to allocate n bytes.  If success, return.
 * If fail, set n = n/2, and repeat until n is too small.
 * Accumulate all memory obtained for all values of n.
 */
long moremem(n,pp)
long n;
char **pp;
{
	long start, result;
	char *p;

	n &= -(int)sizeof(word);		/* multiple of word size only */
	start = n;			/* initial request size */
	result = 0;			/* nothing obtained yet */
	*pp = (char *) 0;		/* no result sbrk value */

	while ( n >= sizeof(word) ) {	/* Word is minimum allocation unit */
	    p = (char *)sbrk((uword)n);		/* Attempt allocation */
	    if ( p != (char *) -1 ) {	/* If successful */
		result += n;		/* Accumulate allocation size */
		if (*pp == (char *) 0) {/* First success? */
		    if (p != topmem) {
			wrterr( "Internal system error--SYSMM" );
			__exit(1);
		        }
		    *pp = p;		/* record first allocation */
		    }
		if (n == start)		/* If easily satisfied, great */
		    break;
	        }
    	    n >>= 1;			/* Continue with smaller request size */
	    n &= -(int)sizeof(word);		/* Always keeping it a word multiple */
	    }
	return result;
}