/*
Copyright 1987-2012 Robert B. K. Dewar and Mark Emmer.

This file is part of Macro SPITBOL.

    Macro SPITBOL is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Macro SPITBOL is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Macro SPITBOL.  If not, see <http://www.gnu.org/licenses/>.
*/

/*
    osread( mode, recsiz, ioptr, scptr )

    osread()  reads the next record from the input file associated with
    the passed IOBLK into the passed SCBLK.  mode determines whether the
    read should be line or raw mode.

        Line mode records are teminated with a new-line character (the
        new-line is not put in the scblk though).

        Raw mode records are simply the next recsiz characters.

    Parameters:
        mode    1=line mode / 0=raw mode
        recsiz  line mode:  max length of record to be read
                raw mode:   number of characters to be read
        ioptr   pointer to IOBLK associated with input file
        scptr   pointer to SCBLK to receive input record
    Returns:
        >0      length of record read
        -1      EOF
        -2      I/O error
*/

#include "typedef.h"
#include "port.h"
#include "os.h"
#include <string.h>

word
osread(mode, recsiz, ioptr, scptr)
word mode;
word recsiz;
struct ioblk *ioptr;
struct scblk *scptr;

{
    REGISTER struct bfblk *bfptr = MK_MP(ioptr->bfb, struct bfblk *);
    REGISTER char *cp = scptr->str;
    REGISTER char *bp;
    REGISTER word cnt = 0;
    REGISTER word fdn = ioptr->fdn;
    REGISTER word n;

#if HOST386
    if (ioptr->flg1 & IO_CIN)	/* End any special screen modes */
	termhost();
#endif				/* HOST386 */

    /*
       /   Distinguish buffered from unbuffered I/O.
     */
    if (ioptr->flg1 & IO_WRC || ioptr->flg2 & IO_RAW) {

	/*
	 ********************
	 *  Unbuffered I/O  *
	 ********************
	 */

	if (mode == 1) {	/* line mode */

	    /*
	     * Unbuffered Line Mode
	     */
	    REGISTER char eol1 = ioptr->eol1;
	    REGISTER char eol2 = ioptr->eol2;
#ifdef EOT
	    /* Ignore eot char if IO_EOT bit set */
	    REGISTER char eot = (ioptr->flg1 & IO_EOT) ? eol1 : EOT;
#endif
	    word i;
	    char c;

#if PIPES
	    if (ioptr->flg2 & IO_PIP) {	/* if pipe, read 1 char at a time */

		do {		/* because there's no chance to backup */
		    n = read(fdn, &c, 1);
		    if (n > 0) {
			if (ioptr->flg2 & IO_LF) {
			    ioptr->flg2 &= ~IO_LF;
			    if (c == eol2)
				continue;
			}
			if (c == eol1) {
			    if (eol2)
				ioptr->flg2 |= IO_LF;
			    break;	/* exit loop on eol */
			}
#ifdef EOT
			if (c == eot) {
			    n = 0;
			    break;
			}
#endif
			if (cnt < recsiz) {
			    cnt++;
			    *cp++ = c;
			}
		    }
		}
		while (n > 0);	/* loop until eol or eof */
	    } else
#endif				/* PIPES */
	    {
		char findeol = 1;

		n = read(fdn, cp, recsiz);

		if (n > 0) {
		    cnt = n;

		    for (i = cnt; i--;) {	/* scan for eol1 */
#ifdef EOT
			if ((c = *cp++) == eol1 || c == eot)
#else
			if (*cp++ == eol1)
#endif
			{	/* if end of line (or EOF) */
			    findeol = 0;
			    cnt -= i + 1;
			    if (eol2) {
				if (i && *cp == eol2)
				    cp++;
				else if (testty(fdn)
					 && read(fdn, &c, 1) == 1
					 && c != eol2)
				    doset(ioptr, -1L, 1);	/* back up over non-eol2 */
			    }
			    if (testty(fdn))
				doset(ioptr, cp - scptr->str - n, 1);	/* backup file to point following line */
			    break;
			}
		    }

		    /*
		     * if we didn't see an eol, and this operating system does not
		     * read a line at time (through eol) automatically, then we have
		     * to keep reading one character at time until we find the eol.
		     */
		    if (findeol) {	/* on block device, discard chars */
			do {	/* until find eol */
			    i = read(fdn, &c, 1);
			    if (i > 0) {
#ifdef EOT
				if (c == eol1 || c == eot) {
				    if (c == eol1 && eol2
					&& read(fdn, &c, 1) == 1
					&& c != eol2)
#else
				if (c == eol1) {
				    if (eol2 && read(fdn, &c, 1) == 1
					&& c != eol2)
#endif
					doset(ioptr, -1L, 1);	/* back up over non-eol2 */
				    break;	/* exit loop on eol */
				}
			    }
			}
			while (i > 0);	/* loop until eol or eof */
		    }
		}
	    }
	}

	else {

	    /*
	     * Unbuffered Raw Mode
	     */
	    if (ioptr->flg2 & IO_RAW)
		ttyraw(fdn, 1);	/* set RAW mode         */
	    do {
		/*  loop till recsize satisfied         */
		/*  (read returns one or more chars per call)   */
		n = read(fdn, cp, recsiz);
		cp += n;
		cnt += n;
		recsiz -= n;
	    }
	    while ((recsiz) && (n > 0));

	    if (ioptr->flg2 & IO_RAW)
		ttyraw(fdn, 0);

	    /*  if no error, return aggregate count     */
	    if (n >= 0)
		n = cnt;
	}

	/*      if read error then take action  */
	if (n < 0)
	    return -2;

	/*      check for eof with nothing read */
	if (n == 0 && cnt == 0)
	    return -1;

	/*      everything ok, so return        */
	return cnt;
    }

    else {
	/*
	 ********************
	 *  Buffered I/O  *
	 ********************
	 */

	if (mode == 1) {	/* line mode */

	    /*
	     * Buffered Line Mode
	     */
	    REGISTER char eol1 = ioptr->eol1;
	    REGISTER char eol2 = ioptr->eol2;
#ifdef EOT
	    /* Ignore eot char if IO_EOT bit set */
	    REGISTER char eot = (ioptr->flg1 & IO_EOT) ? eol1 : EOT;
#endif
	    char *savecp;
	    char savechar;

	    /*
	     *  First phase:  copy characters to the result
	     *  buffer either until recsiz is exhausted or
	     *  we have copied the last character of a line.
	     *  This loop is speeded up by pretending that
	     *  the input line is no longer than the result.
	     */
	    do {
		REGISTER char *oldbp;

		/* if the buffer is exhausted, try to fill it */
		if (bfptr->next >= bfptr->fill) {
		    if (flush(ioptr))	/* flush any dirty buffer */
			return -2;

		    n = fillbuf(ioptr);

		    if (n < 0)
			return -2;	/* I/O error */

		    /* true EOF only at the beginning of a line */
		    if (!n)
			return cnt > 0 ? cnt : -1;	/* 1.04 */
		}

		/* set n to max # chars we can process this time */
		n = recsiz - cnt;
		if (n > bfptr->fill - bfptr->next)
		    n = bfptr->fill - bfptr->next;

		/* point bp and oldbp at the first char to be copied */
		oldbp = bp = bfptr->buf + bfptr->next;

		/* plant an eol1 at the end of the valid input */
		savecp = bp + n;
		savechar = *savecp;
		*savecp = eol1;

#ifdef EOT
		/* copy characters until we hit eol1 or EOT */
		while (*bp != eol1 && *bp != eot)
#else				/* EOT */
		/* copy characters until we hit eol1 */
		while (*bp != eol1)
#endif				/* EOT */

		    *cp++ = *bp++;

		/* restore the stolen character */
		*savecp = savechar;

		/* calculate how many characters were moved */
		n = bp - oldbp;
		cnt += n;
		bfptr->next += n;

		/* loop until we hit a real \n or recsiz is exhausted */
	    }
	    while (bp == savecp && cnt < recsiz);

	    /*
	     *  Second phase: discard characters up to and
	     *  including the next EOL1 in the input.
	     *  This loop is optimized to miminize startup
	     *  overhead, because it will usually be executed
	     *  only once (but never less than once!)
	     */
	    do {
		/*
		 *      decrement count of characters remaining
		 *      in the buffer, check for buffer underflow
		 */
		if (bfptr->next >= bfptr->fill) {
		    if (flush(ioptr))	/* flush any dirty buffer */
			return -2;

		    n = fillbuf(ioptr);

		    if (n < 0)
			return -2;	/* I/O error */

		    /* true EOF only at the beginning of a line */
		    if (!n)
			return cnt > 0 ? cnt : -1;	/* 1.04 */
		}

		/*
		 *      The buffer is guaranteed non-empty,
		 *      Pick up a character and bump the offset.
		 */
#ifdef EOT
		/* loop until we see eol1 or end of text */
	    }
	    while ((savechar = bfptr->buf[bfptr->next++]) != eol1 &&
		   savechar != eot);

	    if (!(ioptr->flg1 & IO_EOT) && savechar == EOT) {
		bfptr->next--;	/* back up so see it repeatedly */
		return (cnt > 0 ? cnt : -1);
	    }
#else				/* EOT */
		/* loop until we see an eol1 */
	    }
	    while (bfptr->buf[bfptr->next++] != eol1);
#endif				/* EOT */

	    /* if there is an eol2, look ahead for it   */
	    if (eol2) {
		if (bfptr->next >= bfptr->fill && testty(fdn)) {
		    if (flush(ioptr))	/* flush any dirty buffer */
			return -2;
		    fillbuf(ioptr);
		}

		if (bfptr->next < bfptr->fill
		    && (bfptr->buf[bfptr->next] == eol2))
		    bfptr->next++;	/* discard it if found  */
	    }

	}

	else {
	    /*
	     * Buffered Raw Mode
	     */
	    while (recsiz > 0) {
		/* if the buffer is exhausted, try to fill it */
		if (bfptr->next >= bfptr->fill) {

		    if (flush(ioptr))	/* flush any dirty buffer */
			return -2;

		    fsyncio(ioptr);	/* synchronize file and buffer */

		    n = read(fdn, bfptr->buf, bfptr->size);

		    /* input error, no good */
		    if (n < 0)
			return -2;

		    /* eof, return what we got so far */
		    if (n == 0)
			break;

		    bfptr->next = 0;
		    bfptr->fill = n;
		    bfptr->curpos += n;
		}

		/* calculate how many chars we can move */
		n = bfptr->fill - bfptr->next;
		if (n > recsiz)
		    n = recsiz;
		bp = bfptr->buf + bfptr->next;

		/* update pointers to move n characters */
		cnt += n;
		recsiz -= n;
		bfptr->next += n;

		/* move n characters from bp to cp */
		memcpy(cp, bp, n);
		cp += n;
	    }

	    /* if we couldn't make any progress, signal end of file */
	    if (cnt == 0)
		return -1;
	}
	return cnt;
    }
}

word
fillbuf(ioptr)
struct ioblk *ioptr;
{
    REGISTER struct bfblk *bfptr = MK_MP(ioptr->bfb, struct bfblk *);
    word n;

    fsyncio(ioptr);		/* synchronize file and buffer */

    n = read(ioptr->fdn, bfptr->buf, bfptr->size);

    if (n >= 0) {
	bfptr->next = 0;
	bfptr->fill = n;
	bfptr->curpos += n;
    }

    return n;
}
