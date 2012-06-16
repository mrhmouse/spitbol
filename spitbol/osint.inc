;   File:  osintinc            Version:  01.00
;   -------------------------------------------
;
;   This header file defines the interface between the Macro SPITBOL compiler
;   and any assembly-language OSINT modules.
;   Communication between the two is handled via a set of global variables
;   defined as externals below.

;  Copyright 1991 Robert Goldberg and Catspaw, Inc.

;   Set up externals for all the compiler's registers.

        DSeg_
%ifndef globals
	ext		reg_cp,dword
	ext		reg_wa,dword
	ext		reg_wb,dword
	ext		reg_wc,dword
	ext		reg_xr,dword
	ext		reg_xl,dword
	ext		reg_xs,dword
	ext		reg_ia,dword
%endif
        DSegEnd_

;   Macros to load a compiler register into a machine register

%macro          GET_CP 1
        mov             %1, reg_cp
        %endmacro

        %macro          GET_IA 1
        mov             %1, reg_ia
        %endmacro

        %macro          GET_WA 1
        mov             %1, reg_wa
        %endmacro

        %macro          GET_WB 1
        mov             %1, reg_wb
        %endmacro

        %macro          GET_WC 1
        mov             %1, reg_wc
        %endmacro

        %macro          GET_XR 1
        mov             %1, reg_xr
        %endmacro

        %macro          GET_XL 1
        mov             %1, reg_xl
        %endmacro

        %macro          GET_XS 1
        mov             %1, reg_xs
        %endmacro


;   Macros to store a machine register into a compiler register.

        %macro          SET_CP 1
        mov             reg_cp, %1
        %endmacro

        %macro          SET_IA 1
        mov             reg_ia, %1
        %endmacro

        %macro          SET_WA 1
        mov             reg_wa, %1
        %endmacro

        %macro          SET_WB 1
        mov             reg_wb, %1
        %endmacro

        %macro          SET_WC 1
        mov             reg_wc, %1
        %endmacro

        %macro          SET_XR 1
        mov             reg_xr, %1
        %endmacro

        %macro          SET_XL 1
        mov             reg_xl, %1
        %endmacro

        %macro          SET_XS 1
        mov             reg_xs, %1
        %endmacro


;   Return values to take exit N from interface

EXIT_1  equ       0
EXIT_2  equ       4
EXIT_3  equ       8
EXIT_4  equ       12
EXIT_5  equ       16
EXIT_6  equ       20
EXIT_7  equ       24
EXIT_8  equ       28
EXIT_9  equ       32

;    Return value to do a normal return from interface.

NORMAL_RETURN   equ       -1

        CSeg_

;       Function and macro to call into MINIMAL code.
;       The argument is an ordinal number defined below.
%ifndef globals
	ext		minimal,near
%endif
        %macro          MINIMAL 1
        push            offset %1
	callc		minimal,4
        %endmacro

;   Ordinals for MINIMAL calls from assembly language.
;
;   The order of entries here must correspond to the order of
;   calltab entries in the INTER assembly language module.
;
RELAJ   equ       0
RELCR   equ       1
RELOC   equ       2
ALLOC   equ       3
ALOCS   equ       4
ALOST   equ       5
BLKLN   equ       6
INSTA   equ       7
RSTRT   equ       8
START   equ       9
FILNM   equ       10
DTYPE   equ       1
ENEVS   equ       12
ENGTS   equ       13

;       Function and macro to get/set value from/to MINIMAL dataspace.
;       The argument is an ordinal number defined below.
;       The macro GETOFF returns the address of the value.
%ifne direct                                  ; [[
        %macro          GETOFF 2
        lea             %1,%2
        %endmacro

        %macro          GETMIN 2
        mov             %1,%2
        %endmacro

        %macro          SETMIN valno,value
        mov             %1,[dword %2]
        %endmacro

        %macro          SETMINR 2
        mov             %1,%2
        %endmacro

        %macro          access 2
        ext             %1,dword
        %endmacro

        %macro          access2 name
.ifndef globals
        ext            \name,dword
.endif
        %endmacro

        DSeg_
.else                                       ; ][
.ifndef globals
	ext		minoff,near
.endif
        %macro          GETOFF reg,valno
.ifnc \reg,eax
	push		eax
.endif
        push            offset \valno
	callc		minoff,4
.ifnc \reg,eax
        mov             \reg,eax
	pop		eax
.endif
        %endmacro

        %macro          GETMIN reg,valno
.ifnc \reg,eax
	push		eax
.endif
        push            offset \valno
	callc		minoff,4
        mov             \reg,[eax]
.ifnc \reg,eax
	pop		eax
.endif
        %endmacro

        %macro          SETMIN valno,value
.ifc \value,eax
	push		eax
.endif
        push            offset \valno
	callc		minoff,4
.ifc \value,eax
	pop		[eax]
.else
        mov             [eax],\value
.endif
        %endmacro

        %macro          access name
\name:  .byte           0
        %endmacro

        %macro          access2 name
\name:  .byte           0
        %endmacro

;   Ordinals for transferring MINIMAL values to/from assembly language.
;
;   The order of entries here must correspond to the order of
;   valtab entries in the INTER assembly language module.
;
;   The structure vords and the access macro is merely a device to
;   produce an enumeration similar to an enum structure to C.
;
        struc   vords
.endif                                      ; ]]

        access  GBCNT
        access  HEADV
        access  MXLEN
        access  STAGE
        access  TIMSX
        access  DNAMB
        access  DNAMP
        access  STATE
        access  B_EFC
        access  B_ICL
        access  B_SCL
        access  B_VCT
        access  B_XNT
        access  B_XRT
        access  STBAS
        access  STATB
        access  POLCT
        access  TYPET
        access  DFFNC
        access  LOWSPMIN
        access  FLPRT
        access  FLPTR
        access  GTCEF
        access  HSHTB
        access  PMHBS
        access  R_FCB
        access  C_AAA
        access  C_YYY
        access  G_AAA
        access  W_YYY
        access  S_AAA
        access  S_YYY
        access  R_COD
        access  KVSTN
        access  KVDMP
        access  KVFTR
        access  KVCOM
        access  KVPFL
        access  CSWFL
        access  STMCS
        access  STMCT
        access2 TICBLK
        access2 TSCBLK
        access2 ID1
        access2 ID2BLK
        access2 INPBUF
        access2 TTYBUF
        access  B_RCL

.if direct
        DSegEnd_
.else
        ends    vords
.endif

        CSegEnd_