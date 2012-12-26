-TITLE ASM: PHASE 2 TRANSLATION FROM MINIMAL TOKENS TO X32 ASSEMBLY
-STITL Description
* Copyright 1987-2012 Robert B. K. Dewar and Mark Emmer.
* Copyright 2012 David Shields
* 
* This file is part of Macro SPITBOL.
* 
*     Macro SPITBOL is free software: you can redistribute it and/or modify
*     it under the terms of the GNU General Public License as published by
*     the Free Software Foundation, either version 2 of the License, or
*     (at your option) any later version.
* 
*     Macro SPITBOL is distributed in the hope that it will be useful,
*     but WITHOUT ANY WARRANTY; without even the implied warranty of
*     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*     GNU General Public License for more details.
* 
*     You should have received a copy of the GNU General Public License
*     along with Macro SPITBOL.  If not, see <http://www.gnu.org/licenses/>.
*
*
*  This program takes input file in MINIMAL lexeme form and
*  produces assembly code for an x32 processor.
*  The program obtains the name of the file to be translated from the
*  command line string in HOST(0).  Options relating to the processing
*  of comments can be changed by modifying the source.
*
*  In addition to the MINIMAL lexeme file, the program requires the
*  name of a "system definition file" that contains code specific
*  to a particular version.
*
*  You may also specify option flags on the command line to control the
*  code generation.  The following flags are processed:
*	COMPRESS	Generate tabs rather than spaces in output file
*       COMMENTS        Retain full-line and end-of-line comments
*
*  The variable MACHINE is set equal to the uppercase name of the machine
*  being processed.  Specific tests upon this variable are discouraged, as
*  all machine-dependent code should be placed in the machine-definition
*  file if possible.
*
*  In addition to the normal MINIMAL register complement, one scratch
*  work register, W0 is defined.
*  See the register map below for specific allocations.
*
*  This program is based in part on earlier translators for the
*  It is based in part on earlier translators for the DEC VAX
*  (VMS and UN*X) written by Steve Duff and Robert Goldberg, and the
*  PC-SPITBOL translator by David Shields.
*
*  To run under Spitbol:
*       spitbol -u "<file>:<machine>[:flag:...:flag]" asm.spt
*
*	reads <file>.lex	containing tokenized source code
*       writes <file>.s         with x32 assembly code
*	also writes <file>.err	with ERR and ERB error messages
*	using <machine>.def	to provide machine-specific information
*       parts of <machine>.hdr  are prepended and appended to <file>.s
*	also sets flags		to 1 after converting names to upper case
*	also reads <file>.pub	for debug symbols to be declared public
*
*  Example:
*       spitbol -u v37:dos:compress asm.spt
*
*
*  Revision History:
*
        VERSION = 'V1.12'
	RCODE = '_rc_'
*
*
-EJECT
*
*  Keyword initialization
*
	&ANCHOR = 1;	&STLIMIT = 10000000;	&TRIM	= 1;  &DUMP = 1
*
*  Useful constants
*
	LETTERS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
	UCASE   = LETTERS
	LCASE   = 'abcdefghijklmnopqrstuvwxyz'
	NOS     = '0123456789'
	TAB	= CHAR(9)
*
*  Data structures
*
	DATA('MINARG(I.TYPE,I.TEXT)')
	DATA('TSTMT(T.LABEL,T.OPC,T.OP1,T.OP2,T.OP3,T.COMMENT)')

	SECTNOW = 0

*	ppm_cases gives count of ppm/err statments that must follow call to
*	a procedure
	
	PPM_CASES = TABLE(50,,0)
	
*
*  Function definitions
*
*  CRACK parses STMT into a STMT data plex and returns it.
*  It fails if there is a syntax error.
*
	DEFINE('CRACK(LINE)OPERANDS,OPERAND,CHAR')
*
*	COMREGS - map minimal register names to target register names
	DEFINE('COMREGS(LINE)T,PRE,WORD')
*
*  Error is used to report an error for current statement
*
	DEFINE('ERROR(TEXT)')
	DEFINE('FLUSH()')
	DEFINE('GENAOP(STMT)')
	DEFINE('GENBOP(STMT)')
        DEFINE('GENLAB()')
	DEFINE('GENOP(GOPC,GOP1,GOP2,GOP3)')
	DEFINE('GENOPL(GOPL,GOPC,GOP1,GOP2,GOP3)')
	DEFINE('GENREP(OP)L1,L2)')
	DEFINE('GETARG(IARG,IACC)L1,L2,T1,T2')
	DEFINE('IFREG(IARG)')
	DEFINE('MEMMEM()T1')
	DEFINE('PRCENT(N)')
	DEFINE('PRSARG(IARG)L1,L2')
	DEFINE('TBLINI(STR)POS,CNT,INDEX,VAL,LASTVAL')

*  OUTSTMT is used to send a target statement to the target code
*  output file OUTFILE
*
	DEFINE('OUTSTMT(OSTMT)LABEL,OPCODE,OP1,OP2,OP3,COMMENT,T,STMTOUT')

*  READLINE is called to return the next non-comment line from
*  the Minimal input file (INFILE <=> LU1).   Note that it will
*  not fail on EOF, but it will return a Minimal END statement
*
	DEFINE('READLINE()')
*
	 P.COMREGS = BREAK(LETTERS) . PRE SPAN(LETTERS) . WORD

*  EXTTAB has entry for external procedures
*
	EXTTAB = TABLE(50)

*  LABTAB records labels in the code section, and their line numbers
*
	LABTAB = TABLE(500)

*  For each statement, code in generated into three
*  arrays of statements:
*
*	ASTMTS:	STATEMENTS AFTER OPCODE (()+, ETC.)
*	BSTMTS: STATEMENTS BEFORE CODE (-(), ETC)
*	CSTMTS: GENERATED CODE PROPER
*
	ASTMTS = ARRAY(20,'')
	BSTMTS = ARRAY(10,'')
	CSTMTS = ARRAY(20,'')
*
*  GENLABELS is count of generated labels (cf. GENLAB)
*
	GENLABELS = 0

*
*  Initialize variables
*
	LABCNT = NOUTLINES = NLINES = NSTMTS = NTARGET = NERRORS = 0
	NOPTIM1 = NOPTIM2 = 0
	LASTOPC = LASTOP1 = LASTOP2 =
	DATA_LC = 0
	MAX_EXI = 0
*
*  Initial patterns
*
*  P.CSPARSE Parses tokenized line
	P.CSPARSE = '{' BREAK('{') . INLABEL
.	'{' BREAK('{') . INCODE
.	'{' BREAK('{') . IARG1
.	'{' BREAK('{') . IARG2
.	'{' BREAK('{') . IARG3
.	'{' BREAK('{') . INCOMMENT
	'{' REM . SLINENO

*  Dispatch Table
*
	GETARGCASE = TABLE(27)
	GETARGCASE[1] = .GETARG.C.1;   GETARGCASE[2] = .GETARG.C.2
	GETARGCASE[3] = .GETARG.C.3;   GETARGCASE[4] = .GETARG.C.4
	GETARGCASE[5] = .GETARG.C.5;   GETARGCASE[6] = .GETARG.C.6
	GETARGCASE[7] = .GETARG.C.7;   GETARGCASE[8] = .GETARG.C.8
	GETARGCASE[9] = .GETARG.C.9;   GETARGCASE[10] = .GETARG.C.10
	GETARGCASE[11] = .GETARG.C.11; GETARGCASE[12] = .GETARG.C.12
	GETARGCASE[13] = .GETARG.C.13; GETARGCASE[14] = .GETARG.C.14
	GETARGCASE[15] = .GETARG.C.15; GETARGCASE[16] = .GETARG.C.16
	GETARGCASE[17] = .GETARG.C.17; GETARGCASE[18] = .GETARG.C.18
	GETARGCASE[19] = .GETARG.C.19; GETARGCASE[20] = .GETARG.C.20
	GETARGCASE[21] = .GETARG.C.21; GETARGCASE[22] = .GETARG.C.22
	GETARGCASE[23] = .GETARG.C.23; GETARGCASE[24] = .GETARG.C.24
	GETARGCASE[25] = .GETARG.C.25; GETARGCASE[26] = .GETARG.C.26
	GETARGCASE[27] = .GETARG.C.27

*
*  PIFATAL maps MINIMAL opcodes for which no A code allowed
*  to nonzero value. Such operations include conditional
*  branches with operand of form (X)+
*
	PIFATAL = TBLINI(
.	'AOV[1]BEQ[1]BNE[1]BGE[1]BGT[1]BHI[1]BLE[1]BLO[1]'
.	'BLT[1]BNE[1]BNZ[1]CEQ[1]CNE[1]MFI[1]NZB[1]ZRB[1]')
*
*



-STITL MAIN PROGRAM
*  Here follows the driver code for the "main" program.

*
*  Loop until program exits via G.END
*
*  OPNEXT is invoked to initiate processing of the next line from
*  READLINE.
*  After doing this, OPNEXT branches to the generator routine indicated
*  for this opcode if there is one.
*  The generators all have entry points beginning
*  with "G.", and can be considered a logical extension of the
*  OPNEXT routine.  The generators have the choice of branching back
*  to DSGEN to cause the THISSTMT plex to be sent to OUTSTMT, or
*  or branching to DSOUT, in which case the generator must output
*  all needed code itself.
*
*  The generators are listed in a separate section below.
*
*
*  Get file name
*
	TRANSDATE = DATE()
        OUTPUT = 'MINIMAL to x32 translator'
*
*  Default the parameter string if none present
*
        PARMS = (DIFFER(HOST(0)) HOST(0), "s:s:compress")
        OUTPUT = IDENT(PARMS) "Filename (.lex) required" :S(END)

*
* Get machine definition file name following lexeme file name, and flags.
*
	PARMS ? BREAK(';:') . PARMS LEN(1) (BREAK(';:') | REM) . MACHINE
+		((LEN(1) REM . FLAGS) | '')
        OUTPUT = IDENT(MACHINE)
+		"Machine type file (.def) required"	:S(END)
	$REPLACE(MACHINE,LCASE,UCASE) = 1
*
* Parse and display flags, setting each one's name to non-null value (1).
*
FLGS	FLAGS ? ((LEN(1) BREAK(';:')) . FLAG LEN(1)) |
+	 ((LEN(1) REM) . FLAG) =			:F(FLGS2)
	FLAG = REPLACE(FLAG,LCASE,UCASE)
        OUTPUT = "Flag: " FLAG
	$FLAG = 1					:(FLGS)
*
*  Open machine definition file
*
FLGS2	FILENAMD = MACHINE '.def'
	INPUT(.DEFFILE,1,FILENAMD)			:S(DEFOK)
        OUTPUT = "Cannot open machine definition file: " FILENAMD :(END)
*
*  Read in statements, discarding comments and building a long string.
*  Spitbol code in machine definition file may contain one-line
*  statements and comments only.  Continuation lines are not processed
*  by this code (but could be easily handled).
*
DEFOK   OUTPUT = "Machine definition file: " FILENAMD
	DEFS =
DEFLOOP	LINE = DEFFILE					:F(DEFCOMP)
	LINE '*'					:S(DEFLOOP)
	DEFS = DIFFER(LINE) DEFS ';' LINE		:(DEFLOOP)
*
*  Compile the code, and execute it to perform initializations.
*  Returns to label COMPDONE when complete.
*
DEFCOMP	DEFS = CODE(DEFS '; :(COMPDONE)')		:S(COMPOK)
        OUTPUT = "Error compiling definitions file"
        OUTPUT = &ERRTEXT                             :(END)
COMPOK	ENDFILE(1)					:<DEFS>
COMPDONE DEFS =

* Various constants
*
        COMMENT.DELIM = ';'
*
*
*  BRANCHTAB maps MINIMAL opcodes 'BEQ', etc to desired
*  target instruction
*
	BRANCHTAB = TABLE(10)
	BRANCHTAB['BEQ'] = 'JE'
	BRANCHTAB['BNE'] = 'JNE'
	BRANCHTAB['BGT'] = 'JA'
	BRANCHTAB['BGE'] = 'JAE'
	BRANCHTAB['BLE'] = 'JBE'
	BRANCHTAB['BLT'] = 'JB'
	BRANCHTAB['BLO'] = 'JB'
	BRANCHTAB['BHI'] = 'JA'

*  OPTIM.TAB flags opcodes capable of participating in OR optimization
*		in OUTSTMT routine
*
	OPTIM.TAB = TABLE(10)
	OPTIM.TAB<"AND"> = 1
	OPTIM.TAB<"ADD"> = 1
	OPTIM.TAB<"SUB"> = 1
	OPTIM.TAB<"NEG"> = 1
	OPTIM.TAB<"OR"> = 1
	OPTIM.TAB<"XOR"> = 1
	OPTIM.TAB<"SHR"> = 1
	OPTIM.TAB<"SHL"> = 1
	OPTIM.TAB<"INC"> = 1
	OPTIM.TAB<"DEC"> = 1


*  ISMEM IS TABLE indexed by operand type which is nonzero if
*  operand type implies memory reference.

	ISMEM = ARRAY(30,0)
	ISMEM<3> = 1; ISMEM<4> = 1; ISMEM<5> = 1
	ISMEM<9> = 1; ISMEM<10> = 1; ISMEM<11> = 1
	ISMEM<12> = 1; ISMEM<13> = 1; ISMEM<14> = 1
	ISMEM<15> = 1
*
*  REGMAP maps MINIMAL register name to target machine
*  register/memory-location name.
*
	REGMAP = TABLE(30)
	REGMAP['XL'] = 'XL';  REGMAP['XT'] = 'XL'
	REGMAP['XR'] = 'XR';  REGMAP['XS'] = 'ESP'
	REGMAP['WA'] = 'WA';  REGMAP['WB'] = 'WB'
	REGMAP['WC'] = 'WC';  REGMAP['IA'] = 'WC'
	REGMAP['CP'] = 'EBP'
*	W0 is temp register
	REGMAP['W0'] = 'W0'

* REGLOW maps register to identify target, so
* can extract 'L' part.
	REGLOW = TABLE(3)
	REGLOW['WA'] = 'WA_L'
	REGLOW['WB'] = 'WB_L'
	REGLOW['WC'] = 'WC_L'
	REGLOW['W0'] = 'WA_L'


*  Quick reference:
	REG.IA = REGMAP['IA']
	REG.WA = REGMAP['WA']
	REG.CP = REGMAP['CP']
	W0 = REGMAP['W0']
*  Other definitions that are dependent upon things defined in the
*  machine definition file, and cannot be built until after the definition
*  file has been read in.
*
*  P.OUTSTMT examines output lines for certain types of comment contructions
	FILLC	  = (IDENT(COMPRESS) " ",TAB)
	P.OUTSTMT = (BREAK(FILLC) . LABEL SPAN(FILLC)) . LEADER
+			COMMENT.DELIM REM . COMMENT
	P.ALLTABS = SPAN(TAB) RPOS(0)

*  Strip end of comments if Y
*
	STRIP_COMMENT = (DIFFER(COMMENTS) 'N', 'Y')

	FILENAMI = PARMS '.lex'
        INPUT(.INFILE,1,FILENAMI)                     :S(INPUTOK)
        OUTPUT = 'Cannot open TOKEN file: ' FILENAMI  :(END)
INPUTOK OUTPUT = 'Input TOKEN file: ' FILENAMI
*
*
*
*  Associate output files.  Code is written to a temp file, which
*  will subsequently be rewound and reread for jump optimization.
*
	FILENAMO = PARMS '.tmp'
        OUTPUT(.OUTFILE,2,FILENAMO)                 :S(OUTPUTOK)
        OUTPUT = 'Cannot open TEMP file: ' FILENAMO :(END)
OUTPUTOK
        OUTPUT = 'Output TEMP file: ' FILENAMO

*
* Open file for compilation of Minimal ERR and ERB messages
*
        OUTPUT(.ERRFILE,3, PARMS ".err")             :S(ERR_OK)
        OUTPUT = "Cannot open error message file: " PARMS ".err" :(END)
ERR_OK


*  Then copy contents of <machine>.HDR (if it exists) to OUTFILE
*  Stop at line with just 'END' or end of file
*
	NOUTLINES = NOUTLINES + 1

	INPUT(.HDRFILE,4,MACHINE '.hdr')	:F(NOHDR)
	HAVEHDR = 1
        OUTPUT = 'Input HEADER file: ' MACHINE '.hdr'
HDRCOPY LINE = HDRFILE				:F(HDREND)
	IDENT(LINE,'END')			:S(NOHDR)
	OUTFILE = LINE
	NOUTLINES = NOUTLINES + 1		:(HDRCOPY)
HDREND	HAVEHDR =
NOHDR
*
*  Will have HAVEHDR non-null if more remains to copy out at end.
*
*  Read in PUB file if it exists.  This contains a list of symbols to
*  be declared public when encountered.
*
	PUBTAB = TABLE(2)
	INPUT(.PUBFILE,5, PARMS ".pub")		:F(NOPUB)
	PUBTAB = TABLE(101)
PUBCOPY	LINE = PUBFILE				:F(PUBEND)
	PUBTAB[LINE] = 1			:(PUBCOPY)
PUBEND	ENDFILE(5)
NOPUB

						:(DSOUT)
  &TRACE = 2000
  &FTRACE = 1000
*  &PROFILE = 1
DSOUT
OPNEXT	THISLINE = READLINE()
	CRACK(THISLINE)				:F(DSOUT)
*
* Append ':' after label if in code or data.
*
        TLABEL = INLABEL (DIFFER(INLABEL) GE(SECTNOW,3) ':', )
	I1 = PRSARG(IARG1)
	I2 = PRSARG(IARG2)
	I3 = PRSARG(IARG3)
	TCOMMENT = COMREGS(INCOMMENT) '} ' INCODE ' ' I.TEXT(I1) ' '
.		I.TEXT(I2) ' ' I.TEXT(I3)
	ARGERRS = 0
						:($('G.' INCODE))
*  Here if bad opcode
DS01	ERROR('BAD OP-CODE')			:(DSOUT)

*  GENERATE TOKENS.
*
DS.TYPERR
	ERROR('OPERAND TYPE ZERO')		:(DSOUT)
-STITL COMREGS(LINE)T,PRE,WORD
COMREGS
	LINE P.COMREGS =			:F(COMREGS1)
	WORD = EQ(SIZE(WORD),2) DIFFER(T = REGMAP[WORD]) T
	COMREGS = COMREGS PRE WORD		:(COMREGS)
COMREGS1 COMREGS = COMREGS LINE			:(RETURN)
-STITL CRACK(LINE)
*  CRACK is called to create a STMT plex containing the various
*  entrails of the Minimal Source statement in LINE.  For
*  conditional assembly ops, the opcode is the op, and OP1
*  is the symbol.  Note that DTC is handled as a special case to
*  assure that the decomposition is correct.
*
*  CRACK will print an error and fail if a syntax error occurs.
*
CRACK   NSTMTS  = NSTMTS + 1
	OP1 = OP2 = OP3 = TYP1 = TYP2 = TYP3 =
	LINE    P.CSPARSE			:S(RETURN)
*  Here on syntax error
*
	ERROR('SOURCE LINE SYNTAX ERROR')	:(FRETURN)
-STITL ERROR(TEXT)
*  This module handles reporting of errors with the offending
*  statement text in THISLINE.  Comments explaining
*  the error are written to the listing (including error chain), and
*  the appropriate counts are updated.
*
ERROR   OUTFILE = '* *???* ' THISLINE
	OUTFILE = '*       ' TEXT
.	          (IDENT(LASTERROR),'. LAST ERROR WAS LINE ' LASTERROR)
	LASTERROR = NOUTLINES
	NOUTLINES = NOUTLINES + 2
	LE(NERRORS = NERRORS + 1, 10)		:S(DSOUT)
        OUTPUT = 'Too many errors, quitting'  :(END)
-STITL GENAOP(STMT)
GENAOP
	ASTMTS[ASTMTS.N = ASTMTS.N + 1] = STMT	:(RETURN)
-STITL GENBOP(STMT)
GENBOP
	BSTMTS[BSTMTS.N = BSTMTS.N + 1] = STMT	:(RETURN)

-STITL GENLAB()
*  Generate unique labels for use in generated code
GENLAB	GENLAB = '_L' LPAD(GENLABELS = GENLABELS + 1,4,'0') :(RETURN)

-STITL GENOPL(GOPL,GOPC,GOP1,GOP2,GOP3)
*  Generate operation with label
GENOPL	CSTMTS[CSTMTS.N = CSTMTS.N + 1] =
.		TSTMT(GOPL,GOPC,GOP1,GOP2,GOP3)		:(RETURN)

-STITL GENOP(GOPC,GOP1,GOP2,GOP3)
*  Generate operation with no label
GENOP   GENOPL(,GOPC,GOP1,GOP2,GOP3)            :(RETURN)

-STITL GETARG(IARG,IACC)
GETARG	L1 = I.TEXT(IARG)
	L2 = I.TYPE(IARG)
	EQ(L2)					:F($(GETARGCASE[L2]))
	GETARG = L1			:(RETURN)

* INT
GETARG.C.1 GETARG = L1				:(RETURN)

* DLBL
GETARG.C.2 GETARG = L1			:(RETURN)

* WLBL, CLBL
GETARG.C.3
GETARG.C.4 GETARG = 'DWORD [' L1 ']'     :(RETURN)

* ELBL, PLBL
GETARG.C.5
GETARG.C.6 GETARG = L1			:(RETURN)

* W,X, Map register name
GETARG.C.7
GETARG.C.8
	GETARG = REGMAP[L1]			:(RETURN)

* (X), Register indirect
GETARG.C.9
	L1 LEN(1) LEN(2) . L2
	L2 = REGMAP[L2]
	GETARG = 'DWORD [' L2 ']'		:(RETURN)

* (X)+, Register indirect, post increment
* Use lea reg,[reg+4] unless reg is esp, since it takes an extra byte.
* Actually, lea reg,[reg+4] and add reg,4 are both 2 cycles and 3 bytes
* for all the other regs, and either could be used.
GETARG.C.10
	L1 = SUBSTR(L1,2,2)
	T1 = REGMAP[L1]
	GETARG = 'DWORD [' T1 ']'
	(IDENT(L1,'XS') GENAOP(TSTMT(,'ADD',T1,'4'))) :S(RETURN)
	GENAOP(TSTMT(,'LEA',T1,'[' T1 '+4]'))	:(RETURN)

*  -(X), Register indirect, pre decrement
GETARG.C.11
	T1 = REGMAP[SUBSTR(L1,3,2)]
	GETARG = 'DWORD [' T1 ']'
	GENBOP(TSTMT(,'LEA',T1,'[' T1 '-4]'))	:(RETURN)

* INT(X)
* DLBL(X)
GETARG.C.12
GETARG.C.13
	L1 BREAK('(') . T1 '(' LEN(2) . T2
	GETARG = 'DWORD [(4*' T1 ')+' REGMAP[T2] ']'   	:(RETURN)

*  NAME(X), WHERE NAME IS IN WORKING SECTION
GETARG.C.14
GETARG.C.15
	L1 BREAK('(') . T1 '(' LEN(2) . T2
	GETARG = 'DWORD [' T1 '+'  REGMAP[T2] ']'	:(RETURN)

* Signed Integer
GETARG.C.16 GETARG = L1				:(RETURN)

* Signed Real
GETARG.C.17 GETARG = L1				:(RETURN)

*  =DLBL
GETARG.C.18
	GETARG = SUBSTR(L1,2)		:(RETURN)

*  *DLBL
GETARG.C.19
	GETARG = '4*' SUBSTR(L1,2)	:(RETURN)

*  =NAME (Data section)
GETARG.C.20
GETARG.C.21
        GETARG =  SUBSTR(L1,2) :(RETURN)

*  =NAME (Program section)
GETARG.C.22
        GETARG =  SUBSTR(L1,2)   :(RETURN)

*  PNAM, EQOP
GETARG.C.23
GETARG.C.24 GETARG = L1			:(RETURN)

* PTYP, TEXT, DTEXT
GETARG.C.25
GETARG.C.26
GETARG.C.27 GETARG = L1				:(RETURN)

-STITL MEMMEM()T1
MEMMEM
*  MEMMEM is called for those ops for which both operands may be
*  in memory, in which case, we generate code to load first operand
*  to pseudo-register 'W0', and then modify the first argument
*  to reference this register
*
  EQ(ISMEM[I.TYPE(I1)])				:S(RETURN)
  EQ(ISMEM[I.TYPE(I2)])				:S(RETURN)
*  here if memory-memory case, load first argument
  T1 = GETARG(I1)
  I1 = MINARG(8,'W0')
  GENOP('MOV','W0',T1)				:(RETURN)

-STITL PRCENT(N)
PRCENT PRCENT = 'PRC_' '+'  (4 * ( N - 1)) :(RETURN)

-STITL OUTSTMT(OSTMT)LABEL,OPCODE,OP1,OP2,OP3,COMMENT)
*  This module writes the components of the statement
*  passed in the argument list to the formatted .s file
*
OUTSTMT	LABEL = T.LABEL(OSTMT)
*  attach source label to first generated instruction
	DIFFER(LABEL)				:S(OUTSTMT1)
	IDENT(TLABEL)				:S(OUTSTMT1)
	LABEL = TLABEL; TLABEL =

OUTSTMT1
	COMMENT = T.COMMENT(OSTMT)
* DS SUPPRESS COMMENTS
 	COMMENT = TCOMMENT = 
 	:(OUTSTMT2)
*  attach source comment to first generated instruction
	DIFFER(COMMENT)				:S(OUTSTMT2)
	IDENT(TCOMMENT)				:S(OUTSTMT2)
	COMMENT = TCOMMENT; TCOMMENT =
OUTSTMT2
	OPCODE = T.OPC(OSTMT)
	OP1 = T.OP1(OSTMT)
	OP2 = T.OP2(OSTMT)
	OP3 = T.OP3(OSTMT)
	DIFFER(COMPRESS)			:S(OUTSTMT6)
	STMTOUT = RPAD( RPAD(LABEL,7) ' ' RPAD(OPCODE,4) ' '
.		  (IDENT(OP1), OP1
.			(IDENT(OP2), ',' OP2
.				(IDENT(OP3), ',' OP3))) ,27)
.       (IDENT(STRIP_COMMENT,'Y'), ' ' (IDENT(COMMENT), ';') COMMENT)
.						:(OUTSTMT5)
OUTSTMT6
	STMTOUT = LABEL TAB OPCODE TAB
.		  (IDENT(OP1), OP1
.		    (IDENT(OP2), ',' OP2
.		      (IDENT(OP3), ',' OP3)))
.       (IDENT(STRIP_COMMENT,'Y'), TAB (IDENT(COMMENT), ';') COMMENT)
*
**	Send text to OUTFILE
*
**
OUTSTMT5
**
**	Send text to output file if not null.
*
	STMTOUT = REPLACE(TRIM(STMTOUT),'$','_')
	IDENT(STMTOUT)				:S(RETURN)
	OUTFILE = STMTOUT
	NTARGET	= NTARGET + 1
	NOUTLINES = NOUTLINES + 1
*
*  Record code labels in table with delimiter removed.
	(GE(SECTNOW,5) DIFFER(LABEL))		:F(RETURN)
	LABEL ? BREAK(':') . LABEL	:F(RETURN)
	LABTAB<LABEL> = NOUTLINES		:(RETURN)

-STITL PRSARG(IARG)
PRSARG	PRSARG = MINARG(0)
	IARG BREAK(',') . L1 ',' REM . L2	:F(RETURN)
	PRSARG = MINARG(CONVERT(L1,'INTEGER'),L2)	:(RETURN)
-STITL READLINE()
*  This routine returns the next statement line in the input file
*  to the caller.  It never fails.  If there is no more input,
*  then a Minimal END statement is returned.
*  Comments are passed through to the output file directly.
*
*
READLINE READLINE = INFILE                      :F(RL02)
	NLINES  = NLINES + 1
	IDENT( READLINE )			:S(READLINE)
	LEQ( SUBSTR( READLINE,1,1 ),'*' )       :F(RL01)
*
*  Only print comment if requested.
*
	IDENT(STRIP_COMMENT,'N')		:F(READLINE)
        READLINE LEN(1) = ';'
	OUTFILE = READLINE
	NOUTLINES = NOUTLINES + 1               :(READLINE)
*
*  Here if not a comment line
*
RL01						:(RETURN)
*
*  Here on EOF
*
RL02    READLINE = '       END'
						:(RL01)
-STITL TBLINI(STR)
*  This routine is called to initialize a table from a string of
*  index/value pairs.
*
TBLINI   POS     = 0
*
*  Count the number of "[" symbols to get an assessment of the table
*  size we need.
*
TIN01   STR     (TAB(*POS) '[' BREAK(']') *?(CNT = CNT + 1) @POS)
.						:S(TIN01)
*
*  Allocate the table, and then fill it. Note that a small memory
*  optimisation is attempted here by trying to re-use the previous
*  value string if it is the same as the present one.
*
	TBLINI   = TABLE(CNT)
TIN02   STR     (BREAK('[') $ INDEX LEN(1) BREAK(']') $ VAL LEN(1)) =
.						:F(RETURN)
	VAL     = CONVERT( VAL,'INTEGER' )
	VAL     = IDENT(VAL,LASTVAL) LASTVAL
	LASTVAL = VAL
	TBLINI[INDEX] = VAL			:(TIN02)
-STITL Generators

IFREG	GE(I.TYPE(IARG),7) LE(I.TYPE(IARG),8)
.						:F(FRETURN)S(RETURN)

G.FLC
	T1 = SUBSTR(GETARG(I1),2,1) 'L'
	T2 = GENLAB()
*	GENOP('MOV','DWORD[at_num]','EAX')
* 	GENOP('CALL','at_note3')
	GENOP('CMP',T1,"'a'")
	GENOP('JB', T2 )
	GENOP('CMP',T1,"'z'")
	GENOP('JA', T2)
	GENOP('SUB',T1,'32')
        GENOPL(T2 ':')                  :(OPDONE)

G.MOV
*  perhaps change MOV X,(XR)+ to
*	mov ax,X; STOWS
*
*  Perhaps do  MOV (XL)+,Wx as
*	lodsw
*	xchg ax,Tx
*  and also MOV (XL)+,NAME as
*	lodsw
*	mov NAME,W0
*  NEED TO PROCESS MEMORY-MEMORY CASE
*  CHANGE 'MOV (XS)+,A' TO 'POP A'
*  CHANGE 'MOV A,-(XS)' TO 'PUSH A'
	T1 = I.TEXT(I1); T2 = I.TEXT(I2)
	IDENT(T1,'(XL)+')			:S(MOV.XLP)
	IDENT(T1,'(XT)+')			:S(MOV.XTP)
	IDENT(T1,'(XS)+')			:S(MOV.XSP)
	IDENT(T2,'(XR)+')			:S(MOV.XRP)
	IDENT(T2,'-(XS)')			:S(MOV.2)
	MEMMEM()
	GENOP('MOV',GETARG(I2),GETARG(I1))
						:(OPDONE)
MOV.XTP
MOV.XLP
	IDENT(T2,'(XR)+') GENOP('MOVSD')	:S(OPDONE)
	GENOP('LODSD')
	IDENT(T2,'-(XS)') GENOP('PUSH','W0')	:S(OPDONE)
	GENOP('MOV',GETARG(I2),'W0')		:(OPDONE)
MOV.XSP
	IDENT(I.TEXT(I2),'(XR)+')		:S(MOV.XSPRP)
	GENOP('POP',GETARG(I2))			:(OPDONE)
MOV.XSPRP GENOP('POP','W0')
	GENOP('STOSD')				:(OPDONE)
MOV.XRP GENOP('MOV','W0',GETARG(I1))
	GENOP('STOSD')				:(OPDONE)
MOV.2
	GENOP('PUSH',GETARG(I1))		:(OPDONE)

* Odd/Even tests.  If W reg, use low byte of register.
G.BOD	T1 = GETARG(I1)
	T1 = EQ(I.TYPE(I1),8) REGLOW[T1]
	GENOP('TEST',T1,'1')
	GENOP('JNE',GETARG(I2))			:(OPDONE)

G.BEV	T1 = GETARG(I1)
	T1 = EQ(I.TYPE(I1),8) REGLOW[T1]
	GENOP('TEST',T1,'1')
	GENOP('JE',GETARG(I2))			:(OPDONE)

G.BRN   GENOP('JMP',GETARG(I1))			:(OPDONE)

G.BSW	T1 = GETARG(I1)
	T2 = GENLAB()
	IDENT(I.TEXT(I3))			:S(G.BSW1)
	GENOP('CMP',T1,GETARG(I2))
	GENOP('JGE',GETARG(I3))
* Here after default case.
G.BSW1	GENOP('JMP', 'DWORD [' T2 '+' T1 '*4]') 
        GENOP('segment .data')
        GENOPL(T2 ':')                  :(OPDONE)

G.IFF   GENOP('dd',GETARG(I2))               :(OPDONE)

G.ESW   
        GENOP('segment .text')                          :(OPDONE)
G.ENT
*
*  Entry points are stored in byte before program entry label
*  last arg is optional, in which case no initial 'db' need be
*  issued. We force odd alignment so can distinguish entry point
*  addresses from block addresses (which are always even).
*
*  Note that this address of odd/even is less restrictive than
*  the MINIMAL definition, which defines an even address as being
*  a multiple of CFP_B (4), and an odd address as one that is not
*  a multiple of CFP_B (ends in 1, 2, or 3).  The definition here
*  is a simple odd/even, least significant bit definition.
*  That is, for us, 1 and 3 are odd, 2 and 4 are even.
*

	T1 = I.TEXT(I1)
        GENOP('align',2)
        (DIFFER(T1) GENOP('db',T1), GENOP('NOP'))
	GENOP()
*  Note that want to attach label to last instruction
	T1 = CSTMTS[CSTMTS.N]
	T.LABEL(T1) = TLABEL
	CSTMTS[CSTMTS.N] = T1
*  Here to see if want label made public
	TLABEL ? RTAB(1) . TLABEL ':'
        (DIFFER(PUBTAB[TLABEL]), DIFFER(DEBUG)) GENOP('global',TLABEL)
	TLABEL =				:(OPDONE)

G.BRI	GENOP('JMP',GETARG(I1))			:(OPDONE)

G.LEI	T1 = REGMAP[I.TEXT(I1)]
	GENOP('MOVZX',T1,'BYTE [' T1 '-1]' )	:(OPDONE)

G.JSR	
	JSR_PROC = GETARG(I1)
	GENOP('CALL',JSR_PROC)		
*	get count of following ppm statements
	JSR_COUNT = PPM_CASES[JSR_PROC]
	EQ(JSR_COUNT)				:S(OPDONE)
*	AT_SUSPEND()
	JSR_CALLS = JSR_CALLS +  1
	JSR_LABEL = 'CALL_' JSR_CALLS
	JSR_LABEL_NORM = JSR_LABEL 
	GENOP('DEC','DWORD [' RCODE ']')
	GENOP('JS',JSR_LABEL_NORM)

*	generate branch around for ppms that will follow
*	take the branch if normal return (eax==0)
						:(OPDONE)

G.ERR
G.PPM

*  Here with return code in RCODE. It is zero for normal return
*  and positive for error return. Decrement the value.
*  If it is negative then this is normal return. Otherwise,
*  proceed decrementing RCODE until it goes negative,and then
*  take the appropriate branch.

	T1 = GETARG(I1)

*  Branch to next case if RCODE code still not negative.
	IDENT(INCODE,'PPM')			:S(G.PPM.LOOP)
	COUNT.ERR =  COUNT.ERR + 1
	ERRFILE =   I.TEXT(I1) ' ' I.TEXT(I2)
	MAX.ERR = GT(T1,MAX.ERR) T1
						:(G.PPM.LOOP)

G.PPM.LOOP.NEXT
	GENOPL(LAB_NEXT ':')
 	JSR_COUNT = JSR_COUNT - 1
* 	EQ(JSR_COUNT) AT_RESTORE()
	EQ(JSR_COUNT) GENOPL(JSR_LABEL_NORM ':') :(OPDONE)
G.PPM.LOOP
	LAB_NEXT = GENLAB()
	GENOP('DEC','DWORD [' RCODE ']')
	GENOP('JNS',LAB_NEXT)
	IDENT(INCODE,'PPM')			:S(G.PPM.LOOP.PPM)
*  Here if error exit via EXI. Set RCODE to exit code and jump 
*  to error handler with error code in RCODE
G.PPM.LOOP.ERR
	GENOP('MOV','DWORD [' RCODE ']', +T1)
	GENOP('JMP','ERR_')
						:(G.PPM.LOOP.NEXT)
G.PPM.LOOP.PPM
*	check each ppm case and take branch if appropriate
	IDENT(I.TEXT(I1))			:S(G.PPM.2)
	COUNT.PPM = COUNT.PPM + 1
	GENOP('JMP',	GETARG(I1))
						:(G.PPM.LOOP.NEXT)

G.PPM.2
*  A PPM with no arguments, which should never be executed, is
*  translated to ERR 299,Internal logic error: Unexpected PPM branch
	T1 = 299
	ERRFILE =  T1 ' Internal logic error: Unexpected PPM branch'
						:(G.PPM.LOOP.ERR)

G.PRC

*  NOP needed to get labels straight
	PRC.ARGS = GETARG(I2)
	PPM_CASES[INLABEL] = I.TEXT(I2)
	INLABEL =
	MAX_EXI = GT(PRC.ARGS,MAX_EXI) PRC.ARGS
	PRC.TYPE = I.TEXT(I1)		:($('G.PRC.' PRC.TYPE))
G.PRC.E
G.PRC.R						:(OPDONE)

G.PRC.N
*  Store return address in reserved location
	PRC.COUNT = PRC.COUNT + 1
	GENOP('POP', 'DWORD [' PRCENT(PRC.COUNT) ']')		:(OPDONE)

G.EXI	
        T1 = GETARG(I1); T2 = PRC.TYPE; T3 = I.TEXT(I1)
*  If type R or E, and no exit parameters, just return
 	DIFFER(T2,'N') EQ(PRC.ARGS)	GENOP('RET')	:S(OPDONE)
        T3 = IDENT(T3) '0'
    	GENOP('MOV','DWORD [' RCODE ']',+T3)
	IDENT(T2,'N')				:S(G.EXI.1)
	GENOP('RET')				:(OPDONE)
G.EXI.1

	GENOP('MOV','W0', 'DWORD ['  PRCENT(PRC.COUNT) ']' )
	GENOP('JMP','W0')
						:(OPDONE)
G.ENP   GENOP()					:(OPDONE)

G.ERB
	ERRFILE =  I.TEXT(I1) ' ' I.TEXT(I2)
*	Set RCODE to error code and branch to error handler
	GENOP('MOV', 'DWORD [' RCODE ']',  +(I.TEXT(I1)))
 	GENOP('JMP','ERR_')
						:(OPDONE)


G.ICV   GENOP('INC',GETARG(I1))    :(OPDONE)
G.DCV   GENOP('DEC',GETARG(I1))    :(OPDONE)

G.ZER	IDENT(I.TEXT(I1),'(XR)+') GENOP('XOR','W0','W0')
+		GENOP('STOSD')			:S(OPDONE)
	IFREG(I1)				:S(G.ZER1)
	IDENT(I.TEXT(I1),'-(XS)')		:S(G.ZER.XS)
	GENOP('XOR','W0','W0')
	GENOP('MOV',GETARG(I1),'W0')		:(OPDONE)
G.ZER1	T1 = GETARG(I1)
	GENOP('XOR',T1,T1)			:(OPDONE)
G.ZER.XS GENOP('PUSH','0')			:(OPDONE)

G.MNZ   GENOP('MOV',GETARG(I1),'ESP')		:(OPDONE)

G.SSL   GENOP()					:(OPDONE)
G.SSS   GENOP()					:(OPDONE)

G.RTN
	GENOP()
                                                :(OPDONE)

G.ADD	MEMMEM()
	GENOP('ADD',GETARG(I2),GETARG(I1))	:(OPDONE)

G.SUB	MEMMEM()
	GENOP('SUB',GETARG(I2),GETARG(I1))	:(OPDONE)

G.ICA   GENOP('ADD',GETARG(I1),'4')		:(OPDONE)
G.DCA   GENOP('SUB',GETARG(I1),'4')		:(OPDONE)

G.BEQ
G.BNE
G.BGT
G.BGE
G.BLT
G.BLE
G.BLO
G.BHI
*
*  These operators all have two operands, MEMMEM may apply
*  Issue target opcode by table lookup.
*
	MEMMEM()
	T1 = BRANCHTAB[INCODE]
	GENOP('CMP',GETARG(I1),GETARG(I2))
	GENOP(BRANCHTAB[INCODE],GETARG(I3))
.						:(OPDONE)

G.BNZ
	IFREG(I1)				:S(G.BNZ1)
        GENOP('CMP', GETARG(I1) ,'0')
	GENOP('JNZ',GETARG(I2))			:(OPDONE)
G.BNZ1	GENOP('OR',GETARG(I1),GETARG(I1))
	GENOP('JNZ',GETARG(I2))			:(OPDONE)

G.BZE   IFREG(I1)				:S(G.BZE1)
        GENOP('CMP', GETARG(I1)  ,'0')
	GENOP('JZ',GETARG(I2))			:(OPDONE)
G.BZE1
	T1 = GETARG(I1)
	GENOP('OR',T1,T1)
	GENOP('JZ',GETARG(I2))			:(OPDONE)

G.LCT
*
*  If operands differ must emit code
*
	DIFFER(I.TEXT(I1),I.TEXT(I2))		:S(G.LCT.1)
*  Here if operands same. Emit no code if no label, else emit null
	IDENT(TLABEL)				:S(OPNEXT)
	GENOP()					:(OPDONE)

G.LCT.1	GENOP('MOV',GETARG(I1),GETARG(I2))	:(OPDONE)

G.BCT
*  Can issue LOOP if target register is CX.
	T1 = GETARG(I1)
	T2 = GETARG(I2)
	:(G.BCT2)
	IDENT(T1,'WA')				:S(G.BCT1)
G.BCT2	GENOP('DEC',T1)
	GENOP('JNZ',T2)				:(OPDONE)
G.BCT1	GENOP('LOOP',T2)			:(OPDONE)

G.AOV   GENOP('ADD',GETARG(I2),GETARG(I1))
	GENOP('JC',GETARG(I3))			:(OPDONE)
G.LCP
*  Use CP for code pointer.
	GENOP('MOV','DWORD [MINCP]',GETARG(I1))		
						:(OPDONE)

G.SCP   
	GENOP('MOV',GETARG(I1),'DWORD [MINCP]')
						:(OPDONE)
G.LCW
*  Should be able to get LODSD; XCHG W0,GETARG(I1)
	GENOP('MOV',W0,'DWORD [MINCP]')
	GENOP('MOV',GETARG(I1),'[' W0 ']')
	GENOP('ADD',W0,'4')			
	GENOP('MOV','DWORD [MINCP]',W0)
						:(OPDONE)


G.ICP   	
	GENOP('MOV',W0,'DWORD [MINCP]')
	GENOP('ADD',W0,'4')
	GENOP('MOV','DWORD [MINCP]',W0)
						:(OPDONE)

*  INTEGER ACCUMULATOR KEPT IN WDX (WC)
G.LDI	GENOP('MOV',REG.IA,GETARG(I1))		:(OPDONE)

G.ADI   GENOP('ADD',REG.IA,GETARG(I1))		:(OPDONE)

G.MLI	GENOP('IMUL',REG.IA,GETARG(I1))		:(OPDONE)

G.SBI   GENOP('SUB',REG.IA,GETARG(I1))		:(OPDONE)

G.DVI
G.RMI
*	Move argument to EAX, call procedure
	GENOP('MOV','W0',GETARG(I1))
	GENOP('CALL', INCODE '_')	:(OPDONE)

G.STI   GENOP('MOV',GETARG(I1),REG.IA)		:(OPDONE)

G.NGI   GENOP('NEG',REG.IA)			:(OPDONE)

G.INO   GENOP('JNO',GETARG(I1))			:(OPDONE)
G.IOV   GENOP('JO',GETARG(I1))			:(OPDONE)

G.IEQ	GENOP('OR',REG.IA,REG.IA)
	GENOP('JE',GETARG(I1))			:(OPDONE)
G.IGE   GENOP('OR',REG.IA,REG.IA)
	GENOP('JGE',GETARG(I1))			:(OPDONE)
G.IGT   GENOP('OR',REG.IA,REG.IA)
	GENOP('JG',GETARG(I1))			:(OPDONE)
G.ILE   GENOP('OR',REG.IA,REG.IA)
	GENOP('JLE',GETARG(I1))			:(OPDONE)
G.ILT   GENOP('OR',REG.IA,REG.IA)
	GENOP('JL',GETARG(I1))			:(OPDONE)
G.INE   GENOP('OR',REG.IA,REG.IA)
	GENOP('JNE',GETARG(I1))			:(OPDONE)



*
*  Real operations
*
G.ITR	GENOP('CALL','ITR_')	:(OPDONE)

G.RTI	GENOP('CALL','RTI_')
	EQ(I.TYPE(I1))				:S(OPDONE)
*  HERE IF LABEL GIVEN, BRANCH IF REAL TOO LARGE
        GENOP('JC',GETARG(I1))                 :(OPDONE)

G.LDR
G.STR
G.ADR
G.SBR
G.MLR
G.DVR	
*  unlike the other minimal registers, ra is maintained not as a single
*  storage location, but as two successive 32-bit words, due to the x86
*  architecture. The consequence here is that we must deal with the address
*  of the ra, not its value.
	T1 = GETARG(I1)
	TYP1 = I.TYPE(I1)
* 	OUTPUT = 'g.rop before dword test ' t1 ' ' typ1
*	t1 'dword [' break(']') . leaarg rem
*	T1 'DWORD' =
	T1 = TRIM(T1)
*	OUTPUT = 'g.rop after dword test ' t1 ' leaarg ' leaarg
*	(GE(TYP1,9) LE(TYP1,15) GENOP('LEA','W0', T1),
*+	 GE(TYP1,3) LE(TYP1,4)  GENOP('LEA','W0', T1),
*+                GENOP('MOV','W0', GETARG(I1)))
                GENOP('MOV','W0', GETARG(I1))
	GENOP('CALL',INCODE '_')		:(OPDONE)


G.NGR
G.ATN
G.CHP
G.COS
G.ETX
G.LNF
G.SIN
G.SQR
G.TAN	GENOP('CALL',INCODE '_')		:(OPDONE)


G.RNO	T1 = 'JNO'				:(G.ROV1)
G.ROV	T1 = 'JO'
G.ROV1  GENOP('CALL','OVR_')
	GENOP(T1,GETARG(I1))			:(OPDONE)

G.REQ	T1 = 'JE'				:(G.R1)
G.RNE	T1 = 'JNE'				:(G.R1)
G.RGE	T1 = 'JGE'				:(G.R1)
G.RGT	T1 = 'JG'				:(G.R1)
G.RLE	T1 = 'JLE'				:(G.R1)
G.RLT	T1 = 'JL'
G.R1	GENOP('CALL','CPR_')
	GENOP(T1,GETARG(I1))			:(OPDONE)

G.PLC
G.PSC
*  Last arg is optinal.  If present and a register or constant,
*  use lea instead.

	T1 = GETARG(I1)
	T2 = I.TYPE(I2)
	((IFREG(I2), GE(T2,1) LE(T2,2))
+	GENOP('LEA',T1,'[CFP$F+' T1 '+' GETARG(I2) ']')) :S(OPDONE)
	GENOP('ADD',T1,'CFP$F')
	EQ(I.TYPE(I2))				:S(OPDONE)
*
*  Here if D_OFFSET_(given (in a variable), so add it in.
*
	GENOP('ADD',T1,GETARG(I2))		:(OPDONE)
*
*  LCH requires separate cases for each first operand possibility.
*
G.LCH
	T2 = I.TEXT(I2)
	T1 = GETARG(I1)

*  See if predecrement.
	LEQ('-',SUBSTR(T2,1,1))			:F(G.LCG.1)
	T2 BREAK('(') LEN(1) LEN(2) . T3
	GENOP('DEC',REGMAP[T3])
G.LCG.1
	T2 BREAK('(') LEN(1) LEN(2) . T3
	GENOP('MOVZX',T1,'BYTE [' REGMAP[T3] ']')

*  SEE IF POSTINCREMENT NEEDED
	T2 RTAB(1) '+'				:F(G.LCG.2)
	GENOP('INC',REGMAP[T3])
G.LCG.2						:(OPDONE)

G.SCH
	T2 = I.TEXT(I2)
	EQ(I.TYPE(I1),8)			:S(G.SCG.W)
	T1 = GETARG(I1)
	IDENT(T2,'(XR)+')			:F(G.SCG.0)
*
*  Here if can use STOSB.
*
	GENOP('MOV','AL',GETARG(I1))
	GENOP('STOSB')				:(OPDONE)

G.SCG.0
	LEQ('-',SUBSTR(T2,1,1))			:F(G.SCG.1)
	T2 BREAK('(') LEN(1) LEN(2) . T3
	GENOP('DEC',REGMAP[T3])
G.SCG.1
	T2 BREAK('(') LEN(1) LEN(2) . T3
	GENOP('MOV','W0',T1,)
	GENOP('MOV','[' REGMAP[T3] ']','AL')
*  See if postincrement needed.
	T2 RTAB(1) '+'				:F(G.SCG.2)
	GENOP('INC',REGMAP[T3])
G.SCG.2						:(OPDONE)
G.SCG.W
*
*  Here if moving character from work register, convert T1
*  to name of low part.
*
	T1 = REGLOW[I.TEXT(I1)]
	IDENT(T2,'(XL)')			:S(G.SCG.W.XL)
	IDENT(T2,'-(XL)')			:S(G.SCG.W.PXL)
	IDENT(T2,'(XL)+')			:S(G.SCG.W.XLP)
	IDENT(T2,'(XR)')			:S(G.SCG.W.XR)
	IDENT(T2,'-(XR)')			:S(G.SCG.W.PXR)
	IDENT(T2,'(XR)+')			:S(G.SCG.W.XRP)
G.SCG.W.XL
	GENOP('MOV','[XL]',T1)			:(OPDONE)
G.SCG.W.PXL
	GENOP('DEC','XL')
	GENOP('MOV','[XL]',T1)			:(OPDONE)
G.SCG.W.XLP
	GENOP('MOV','[XL]',T1)
	GENOP('INC','XL')			:(OPDONE)
G.SCG.W.XR
	GENOP('MOV','[XR]',T1)			:(OPDONE)
G.SCG.W.PXR
	GENOP('DEC','XR')
	GENOP('MOV','[XR]',T1)			:(OPDONE)
G.SCG.W.XRP
	GENOP('MOV','AL',T1)
	GENOP('STOSB')				:(OPDONE)
G.CSC  	IDENT(TLABEL)				:S(OPNEXT)
	GENOP()					:(OPDONE)

G.CEQ
	MEMMEM()
	GENOP('CMP',GETARG(I1),GETARG(I2))
	GENOP('JE',GETARG(I3))			:(OPDONE)

G.CNE   MEMMEM()
	GENOP('CMP',GETARG(I1),GETARG(I2))
	GENOP('JNZ',GETARG(I3))			:(OPDONE)

G.CMC
*	repe	cmpsb		;compare strings
*	mov	esi,0		;clear XL (without changing flags)
*	mov	edi,esi		;v1.02  XR also
*
	GENOP('REPE','CMPSB')
	GENOP('MOV','XL','0')
	GENOP('MOV','XR','XL')
	T1 = GETARG(I1)
	T2 = GETARG(I2)
	(IDENT(T1,T2) GENOP('JNZ',T1))		:S(OPDONE)
	GENOP('JA',T2)
	GENOP('JB',T1)				:(OPDONE)

G.TRC
*	xchg	esi,edi
*  tmp	movzx   eax,byte ptr [edi]	;get character
*	mov	al,[esi+eax]		;translate
*	stosd				;put back and increment ptr
*	loop	tmp
*	xor	esi,esi			;set XL to zero
*	xor	edi,edi			;v1.02  XR also
	GENOP('XCHG','XL','XR')
        GENOPL((T1 = GENLAB()) ':','MOVZX','W0','BYTE [XR]') 
	GENOP('MOV','AL','[XL+W0]')
	GENOP('STOSB')
	GENOP('DEC','ECX')
	GENOP('JNZ',T1)
*	GENOP('LOOP',T1)
	GENOP('XOR','XL','XL')
	GENOP('XOR','XR','XR')		:(OPDONE)


G.ANB   GENOP('AND',GETARG(I2),GETARG(I1))	:(OPDONE)
G.ORB   GENOP('OR',GETARG(I2),GETARG(I1))	:(OPDONE)
G.XOB   GENOP('XOR',GETARG(I2),GETARG(I1))	:(OPDONE)
G.CMB   GENOP('NOT',GETARG(I1))			:(OPDONE)

G.RSH
	GENOP('SHR',GETARG(I1),GETARG(I2))		:(OPDONE)

G.LSH
	GENOP('SHL',GETARG(I1),GETARG(I2))		:(OPDONE)

G.RSX	
	ERROR('RSX NOT SUPPORTED')
	T1 = REGMAP[SUBSTR(I.TEXT(I2),2,2)]
	IDENT(I.TEXT(I1),'WA')				:S(G.RSX.C)
	GENOP('XCHG',T1,'WA')
	GENOP('SHR',GETARG(I1),'CL')
	GENOP('XCHG',T1,'WA')				:(OPDONE)

G.RSX.C	GENOP('XCHG',T1,'WA')
	GENOP('SHR',T1,'CL')
	GENOP('XCHG',T1,'WA')				:(OPDONE)

G.LSX	
	ERROR('LSX NOT SUPPORTED')
	T1 = REGMAP[SUBSTR(I.TEXT(I2),2,2)]
	IDENT(I.TEXT(I1),'WA')				:S(G.LSX.C)
	GENOP('XCHG',T1,'WA')
	GENOP('SHL',GETARG(I1),'CL')
	GENOP('XCHG',T1,'WA')				:(OPDONE)

G.LSX.C	GENOP('XCHG',T1,'WA')
	GENOP('SHL',T1,'CL')
	GENOP('XCHG',T1,'WA')				:(OPDONE)

G.NZB	IFREG(I1)				:S(G.NZB1)
	GENOP('CMP',GETARG(I1),'0')
	GENOP('JNZ',GETARG(I2))			:(OPDONE)
G.NZB1	GENOP('OR',GETARG(I1),GETARG(I1))
	GENOP('JNZ',GETARG(I2))			:(OPDONE)

G.ZRB	IFREG(I1)				:S(G.ZRB1)
	GENOP('CMP',GETARG(I1),'0')
	GENOP('JZ',GETARG(I2))			:(OPDONE)
G.ZRB1	GENOP('OR',GETARG(I1),GETARG(I1))
	GENOP('JZ',GETARG(I2))			:(OPDONE)

* x32 is a Little-Endian machine, so ZGB must swap bytes.
*
*
G.ZGB	T1 = GETARG(I1)			;* 32-bit register name, e.g., EDX
        T2 = SUBSTR(T1,2,1) 'L'         ;* 8-bit low register name, e.g., DL
	T3 = SUBSTR(T1,2,1) 'H'		;* 8-bit high register name, e.g., DH
	GENOP('XCHG',T2,T3)		;* e.g., XCHG DL,DH
	GENOP('ROL',T1,16)		;* e.g., ROL EDX,16
	GENOP('XCHG',T2,T3)		;* e.g., XCHG DL,DH
						:(OPDONE)

G.ZZZ
 	GENOP('ZZZ',GETARG(I1))
						:(OPDONE)
G.WTB   GENOP('SAL',GETARG(I1),'2')		:(OPDONE)
G.BTW   GENOP('SHR',GETARG(I1),'2')		:(OPDONE)

G.MTI	(IDENT(I.TEXT(I1),'(XS)+') GENOP('POP',REG.IA)) :S(OPDONE)
	GENOP('MOV',REG.IA,GETARG(I1))		:(OPDONE)

G.MFI
*  LAST ARG IS OPTIONAL
*  COMPARE WITH CFP$M, BRANCHING IF RESULT NEGATIVE
	EQ(I.TYPE(I2))				:S(G.MFI1)
*  HERE IF LABEL GIVEN, BRANCH IF WC NOT IN RANGE (IE, NEGATIVE)
	GENOP('OR',REG.IA,REG.IA)
	GENOP('JS',GETARG(I2))
G.MFI1	IDENT(I.TEXT(I1),'WC') GENOP()		:S(OPDONE)
	IDENT(I.TEXT(I1),'-(XS)') GENOP('PUSH',REG.IA)	:S(OPDONE)
	GENOP('MOV',GETARG(I1),REG.IA)		:(OPDONE)

G.CTW
*  assume four chars per word
	T1 = GETARG(I1)
	GENOP('ADD',T1,'3+4*' I.TEXT(I2))
	GENOP('SHR',T1,'2')		:(OPDONE)

G.CTB
*  use add w,val*CFP.B+3; and w,-4
	T1 = GETARG(I1)
	GENOP('ADD',T1,'3+4*' I.TEXT(I2))
	GENOP('AND',T1,'-4')	:(OPDONE)

G.CVM	T1 = GETARG(I1)
	GENOP('IMUL',REG.IA,'10')
	GENOP('JO',T1)
	GENOP('SUB',REGMAP['WB'],'CH$D0')
	GENOP('SUB',REG.IA,REGMAP['WB'])
	GENOP('JO',T1)				:(OPDONE)

G.CVD	GENOP('CALL','CVD_')			:(OPDONE)

G.MVC
*	move chars from XL (ESI) to XR (EDI), count in WA (ECX)
*	Use Minimal specification
*
	T1 = GENLAB()
	GENOPL(T1 ':', 'LODSB')
	GENOP('STOSB')
	GENOP('DEC', 'WA')
	GENOP('JNZ',T1)

G.MVW
	GENOP('SHR','WA','2')
 	GENREP('MOVSD')
* 	GENOP('REP','MOVSD')		
					:(OPDONE)

G.MWB
*   move words backwards
	GENOP('SHR','WA','2')
	GENOP('STD')
	GENOP('LEA','XL','[XL-4]')
	GENOP('LEA','XR','[XR-4]')
 	GENREP('MOVSD')
*	GENOP('REP','MOVSD')
	GENOP('CLD')				:(OPDONE)

G.MCB
*   move characters backwards
	GENOP('STD')
	GENOP('DEC','XL')
	GENOP('DEC','XR')
 	GENREP('MOVSB')
*	GENOP('REP','MOVSB')
	GENOP('CLD')				:(OPDONE)
GENREP
*	Generate equivalent of REP op loop
	L1 = GENLAB()
	L2 = GENLAB()
	GENOPL(L1 ':')
	GENOP('OR','WA','WA')
	GENOP('JZ',L2)
	GENOP(OP)
	GENOP('DEC','WA')
	GENOP('JMP',L1)
	GENOPL(L2 ':')
						:(RETURN)

G.CHK   GENOP('CMP','ESP','LOWSPMIN')
	GENOP('JB','SEC06')			:(OPDONE)

DECEND
*  Here at end of DIC or DAC to see if want label made public
	TLABEL ? RTAB(1) . TLABEL ':'
        DIFFER(PUBTAB[TLABEL]) GENOP('global',TLABEL)  :(OPDONE)

G.DAC	T1 = I.TYPE(I1)
        T2 = "" ;*(LE(T1,2) "", LE(T1,4) "D_OFFSET_(", LE(T1,6) "D_OFFSET_(", "")
        GENOPL(TLABEL,'dd',T2 I.TEXT(I1))    :(DECEND)
G.DIC   GENOPL(TLABEL,'dd',I.TEXT(I1))               :(DECEND)

*
* Make sure don't attach label to the align.
*
* Note that we strip any leading plus sign from the constant.  With
* Microsoft MASM 6.0, it treats "+0.0" as an expression, and
* then says that real-valued expressions are illegal.
*
G.DRC   GENOP('align','4')
	T1 = I.TEXT(I1)
	T1 ? FENCE "+" = ""
        GENOP('dd',T1)
*  Note that want to attach label to last instruction
	T.LABEL(CSTMTS[CSTMTS.N]) = TLABEL
	TLABEL =					:(OPDONE)

G.DTC
*  CHANGE FIRST AND LAST CHARS TO " (ASSUME / USED IN SOURCE)
	T1 = I.TEXT(I1)
	T1 TAB(1) RTAB(1) . T2
	T1 = REMDR(SIZE(T2),4)
	DTC_LEN = SIZE(T2)
	DTC_MAX = GT(SIZE(T2),DTC_MAX) SIZE(T2)
*        T2 = "'" T2 "'"
*  Append nulls to complete last word so constant length is multiple
*  of word word
*        T2 = NE(T3) T2 DUPL(',0',4 - T3)
	T3 = ''
	T4 = 1
G.DTC.1

	T3 = T3 "'"  SUBSTR(T2,T4,1) "',"
	LE(T4 = T4 + 1, DTC_LEN)  :S(G.DTC.1)
	T1 = REMDR(SIZE(T2),4)
	EQ(T1)			:S(G.DTC.DONE)
*  Here to pad out to multiple of word size
	T1 = 4 - T1

G.DTC.2
	T3 = T3 "0,"
	GT(T1 = T1 - 1, 0)		:S(G.DTC.2)
G.DTC.DONE
	GENOPL(TLABEL,'db',SUBSTR(T3,1,SIZE(T3) - 1))
					:(OPDONE)
        GENOPL(TLABEL,'db',T2)              :(OPDONE)

G.DBC   GENOPL(TLABEL,'dd',GETARG(I1))       :(OPDONE)
G.EQU   GENOP('equ',I.TEXT(I1))			:(OPDONE)
G.EXP   
	PPM_CASES[INLABEL] = I.TEXT(I1)
	GENOP('extern',TLABEL)
	TLABEL =				:(OPDONE)

G.INP	
	PPM_CASES[INLABEL] = I.TEXT(I2)
	PRC.COUNT1 = IDENT(I.TEXT(I1),'N') PRC.COUNT1 + 1
+						:(OPNEXT)

G.INR						:(OPNEXT)

G.EJC	GENOP('')
						:(OPDONE)

G.TTL	GENOP('')
						:(OPDONE)

G.SEC	GENOP('')
	SECTNOW = SECTNOW + 1			:($("G.SEC." SECTNOW))

* Procedure declaration section
G.SEC.1 GENOP('segment .text')
        GENOP('global','SEC01')
        GENOPL('SEC01' ':')             :(OPDONE)

* Definitions section
G.SEC.2 
        GENOP('segment .data')
        GENOP('global','SEC02')
        GENOPL('SEC02' ':')             :(OPDONE)

* Constants section
G.SEC.3 
        GENOP('segment .data')
        GENOP('global','SEC03')
        GENOPL('SEC03' ':')     :(OPDONE)

* Working variables section
G.SEC.4 GENOP('global','ESEC03')
        GENOPL('ESEC03' ':')
        GENOP('segment .data')
        GENOP('global','SEC04')
        GENOPL('SEC04' ':')     :(OPDONE)

*  Here at start of program section.  If any N type procedures,
*  put out entry-word block declaration at end of working storage
G.SEC.5
*  Emit code to indicate in code section
*  Get direction set to up.
        GENOP('global','ESEC04')
        GENOPL('ESEC04' ':')
*        (GT(PRC.COUNT1) GENOPL('PRC$' ':','times', PRC.COUNT1 ' dd 0'))
	GENOP('PRC_: times ' PRC.COUNT1 ' dd 0')
        GENOP('global','LOWSPMIN')
        GENOPL('LOWSPMIN' ':','dd','0')
        GENOP('global','END_MIN_DATA')
        GENOPL('END_MIN_DATA' ':')
        GENOP('segment .text')
        GENOP('global','SEC05')
        GENOPL('SEC05' ':')     :(OPDONE)

*  Stack overflow section.  Output EXI__n tail code
G.SEC.6	
        GENOP('global','SEC06')
        GENOPL('SEC06'  ':', 'NOP')
				             :(OPDONE)

*  Error section.  Produce code to receive ERB's
G.SEC.7
        GENOP('global','SEC07')
        GENOPL('SEC07' ':')
	FLUSH()
*  Error section.  Produce code to receive ERB's

*	allow for some extra cases in case of max.err bad estimate
	N1 = MAX.ERR + 8
	OUTPUT = 'MAX.ERR ' MAX.ERR
	GENOPL('ERR_:','xchg',REG.WA,'DWORD [' RCODE ']')
						:(OPDONE)


OPDONE	FLUSH()					:(OPNEXT)
*
*  Here to emit BSTMTS, CSTMTS, ASTMTS. Attach input label and
*  comment to first instruction generated.
*
FLUSH	EQ(ASTMTS.N) EQ(BSTMTS.N) EQ(CSTMTS.N)	:F(OPDONE1)
*
*  Here if no statements, so output single 'null' statement to get label
*  and comment field right.
*
	OUTSTMT(TSTMT())			:(OPDONE.6)
OPDONE1	EQ(BSTMTS.N)				:S(OPDONE.2)
	I = 1
OPDONE.1
	OUTSTMT(BSTMTS[I])
	LE(I = I + 1, BSTMTS.N)			:S(OPDONE.1)

OPDONE.2	EQ(CSTMTS.N)			:S(OPDONE.4)
	I = 1
OPDONE.3
	OUTSTMT(CSTMTS[I])
	LE(I = I + 1, CSTMTS.N)			:S(OPDONE.3)

OPDONE.4	EQ(ASTMTS.N)			:S(OPDONE.6)
	I = 1
	IDENT(PIFATAL[INCODE])			:S(OPDONE.5)
*  Here if post incrementing code not allowed
	ERROR('POST INCREMENT NOT ALLOWED FOR OP ' INCODE)
OPDONE.5	OUTSTMT(ASTMTS[I])
	LE(I = I + 1, ASTMTS.N)			:S(OPDONE.5)
OPDONE.6 ASTMTS.N = BSTMTS.N = CSTMTS.N =	:(RETURN)
FLUSH_END

G.END
	&DUMP = 0
	IDENT(HAVEHDR)				:S(G.END.2)
*  Here to copy remaining part from hdr file
G.END.1	LINE = HDRFILE				:F(G.END.2)
	NTARGET = NTARGET + 1
	NOUTLINES = NOUTLINES + 1
	OUTFILE = LINE				:(G.END.1)
G.END.2


* Here at end of code generation.  Close the temp file, and reread
* it to perform jump optimization.
	ENDFILE(1)
	ENDFILE(2)
        OUTPUT = "Code generation complete, begin jump optimization"

	INPUT(.INFILE,1,FILENAMO)			:S(G.END.3)
        OUTPUT = 'Cannot reopen TEMP file: ' FILENAMO :(END)

G.END.3 FILENAMO = PARMS ".s"
        OUTPUT(.OUTFILE,2,FILENAMO '[-m10 -n0]')            :S(G.END.4)
        OUTPUT = 'Cannot open ASSEMBLY file: ' FILENAMO :(END)
G.END.4 OUTPUT = 'Output ASSEMBLY file: ' FILENAMO

***************************************************************************
* Jump optimization
*
* Forward jumps to target labels within JUMP_N lines of the jump receive
* a SHORT.  Exception is made for those lines that match NS_PAT.
*
* JUMP_N and NS_PAT are defined in the <machine>.def file.
*
***************************************************************************
*
	N = JUMP_N			;* # lines allowed for shortening
	JUMP = "J" SPAN(&UCASE)
	WS = SPAN(" " CHAR(9))
	LETS = &UCASE "_0123456789"
	L_PAT = SPAN(LETS)
	L_PATC = L_PAT ':'
	L_PAT2 = L_PAT . LABEL ':'
	STMT = ((L_PATC | "") WS JUMP WS) . FIRST (L_PAT . LABEL REM) . REST

	LNO = 0
G.END.5	LINE = INFILE					:F(G.END.7)
	LNO = LNO + 1
	:(G.END.6)
	LINE ? STMT					:F(G.END.6)
	(IDENT(LABEL,"SHORT"), IDENT(LABTAB<LABEL>))	:S(G.END.6)
	DISTANCE = LABTAB<LABEL> - LNO
	(GT(DISTANCE,0) LE(DISTANCE,N))			:F(G.END.6)
	LINE ? NS_PAT					:S(G.END.6)
	NOPTIM2 = NOPTIM2 + 1
        LINE = FIRST "SHORT " REST FILLC "# (Jump shortened)"
G.END.6	OUTFILE = LINE					:(G.END.5)

G.END.7 ENDFILE(1)
	ENDFILE(2)
	ENDFILE(3)
	HOST(1,"touch " PARMS ".err")
	HOST(1,"del " PARMS ".tmp")
        OUTPUT = '*** TRANSLATION COMPLETE ***'
        OUTPUT = NLINES ' LINES READ.'
        OUTPUT = NSTMTS ' STATEMENTS PROCESSED.'
        OUTPUT = NTARGET ' TARGET CODE LINES PRODUCED.'
        OUTPUT = NOPTIM1 ' "OR" optimizations performed.'
        OUTPUT = NOPTIM2 ' jumps shortened.'
        OUTPUT = MAX.ERR ' MAXIMUM ERR/ERB NUMBER.'
        OUTPUT = PRC.COUNT1 ' PRC COUNT.'
	OUTPUT = DTC_MAX ' MAXIMUM DTC LENGTH'
        OUTPUT = GT(PRC.COUNT,PRC.COUNT1)
.	  'DIFFERING COUNTS FOR N-PROCEDURES:'
.	  ' INP ' PRC.COUNT1 ' PRC ' PRC.COUNT
        OUTPUT = NERRORS ' ERRORS OCCURRED.'
        OUTPUT =
	ERRFILE = '* ' MAX.ERR ' MAXIMUM ERR/ERB NUMBER'
	ERRFILE  = '* ' PRC.COUNT ' PRC COUNT'
.		DIFFER(LASTERROR) 'THE LAST ERROR WAS IN LINE ' LASTERROR
	&CODE   = NE(NERRORS) 2001
        OUTPUT = COLLECT() ' FREE WORDS'
	:(END)
END