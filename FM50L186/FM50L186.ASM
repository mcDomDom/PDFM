version	equ	1

; Copyright, 1990-1992, Russell Nelson, Crynwr Software
; FM TOWNS FM50L186/FM50L187 port mcDomDom 2024

;   This program is free software; you can redistribute it and/or modify
;   it under the terms of the GNU General Public License as published by
;   the Free Software Foundation, version 1.
;
;   This program is distributed in the hope that it will be useful,
;   but WITHOUT ANY WARRANTY; without even the implied warranty of
;   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;   GNU General Public License for more details.
;
;   You should have received a copy of the GNU General Public License
;   along with this program; if not, write to the Free Software
;   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.


	.286				;the FM50L186 requires a 286.

	include	defs.asm

EBASE		equ	0
DATA_REG	equ	00h			;FM50L186/FM50L187
ADDR_REG	equ	DATA_REG+2	;FM50L186/FM50L187
DSLINK_REG	equ	DATA_REG+4	;FM50L186/FM50L187

code	segment	para public
	assume	cs:code, ds:code

	public	int_no
int_no	db	10,0,0,0			;must be four bytes long for get_number.
io_addr	dw	0c50h,0
mac_addr_buf	db	20h dup(0)	;êÊì™3byteÇ…0x4C,41,4EÇ™äiî[Ç≥ÇÍÅA+17hÇ©ÇÁ6byteÇ…macÉAÉhÉåÉXÇ™äiî[Ç≥ÇÍÇÈ

	public	driver_class, driver_type, driver_name, driver_function, parameter_list
driver_class	db	BLUEBOOK, IEEE8023, 0		;from the packet spec
driver_type	db	97		;from the packet spec
driver_name	db	'FM50L186',0	;name of the driver.
driver_function	db	2		;basic, extended
parameter_list	label	byte
	db	1	;major rev of packet driver
	db	9	;minor rev of packet driver
	db	14	;length of parameter list
	db	EADDR_LEN	;length of MAC-layer address
	dw	GIANT	;MTU, including MAC headers
	dw	MAX_MULTICAST * EADDR_LEN	;buffer size of multicast addrs
	dw	RECEIVE_BUF_COUNT-1	;(# of back-to-back MTU rcvs) - 1
	dw	TRANSMIT_BUF_COUNT-1	;(# of successive xmits) - 1
int_num	dw	0	;Interrupt # to hook for post-EOI
			;processing, 0 == none,

reset_lance	macro
	mov	ax,0ff7ch		;stop LANCE
	outport CSR0			;should use hardware reset here
	endm

	include	lance.asm

	public	usage_msg
usage_msg	db	"usage: FM50L186 [options] <packet_int_no> <hardware_irq> <io_addr>",CR,LF,'$'
bad_reset_msg	db	"Unable to reset the FM50L186.",CR,LF,'$'
bad_init_msg	db	"Unable to initialize the FM50L186.",CR,LF,'$'
no_memory_msg	db	"Unable to allocate enough memory, look at end_resident in FM50L186.ASM",CR,LF,'$'

	public	copyright_msg
copyright_msg	db	"Packet driver for an FM50L186, version ",'0'+(majver / 10),'0'+(majver mod 10),".",'0'+lance_version,".",'0'+version,CR,LF
		db	'$'

	public	parse_args
parse_args:
;exit with nc if all went well, cy otherwise.
	assume	ds:code
	mov	di,offset int_no
	call	get_number
	mov	di,offset io_addr
	call	get_number
	clc
	ret

check_board:
	clc
	ret

	public dslink_address
dslink_address:
;arg:	si=io_addr di=offset rom_address
;CLIÇ‚STIÇÕñ≥Ç≠ÇƒÇ‡ëÂè‰ïvÇ»ãCÇ™Ç∑ÇÈ
	CLI
	PUSH					AX
    PUSH                    BX
    PUSH                    CX	;ADD
    PUSH					DX	;ADD
    CMP                     si, 0c50h
    JNZ                     LAB_IO_0C58
    MOV                     DX, 0c54h
    JMP                     LAB_IO_OK
LAB_IO_0C58:
    CMP                     si, 0c58h
    JNZ                     LAB_IO_ERROR
    MOV                     DX, 0c5ch
    JMP                     LAB_IO_OK
LAB_IO_ERROR:
    JMP                     LAB_RET_NG
LAB_IO_OK:
    MOV                     BX,offset mac_addr_buf
    MOV                     CX,0f8h	;248
    SHR                     CX,1h
    SHR                     CX,1h
    SHR                     CX,1h
    MOV                     AX,1h
    OUT                     DX,AX	;DSLINK_REG
    PUSH                    CX
    MOV                     CX,4h
LAB_IN_LOOP1:
    IN                      AL,DX	;DSLINK_REG
    LOOP                    LAB_IN_LOOP1
    POP                     CX
    XOR                     SI,SI
LAB_NEXT_BYTE:
    PUSH                    CX
    XOR                     CX,CX
    XOR                     AX,AX
LAB_NEXT_BIT:
    IN                      AL,DX	;DSLINK_REG
    TEST                    AL,40h
    JZ                      LAB_BIT_OK
    MOV                     AL,1h
    SHL                     AL,CL
    ADD                     AH,AL
LAB_BIT_OK:
    INC                     CL
    CMP                     CL,8h
    JNZ                     LAB_NEXT_BIT
    POP                     CX
    MOV                     SI,CX
    MOV                     byte ptr [BX + SI -1],AH
    LOOP                    LAB_NEXT_BYTE
    MOV                     AX,1h
    OUT                     DX,AX	;DSLINK_REG
    MOV                     CX,4h
LAB_0000_5936:
    IN                      AL,DX
    TEST                    AL,40h
    JZ                      LAB_0000_593e
    JMP                     LAB_0000_596a
LAB_0000_593e:
    LOOP                    LAB_0000_5936
    MOV                     CX,0fch
LAB_0000_5943:
    IN                      AL,DX
    LOOP                    LAB_0000_5943
    MOV                     CX,4h
LAB_0000_5949:
    IN                      AL,DX
    TEST                    AL,40h
    JZ                      LAB_0000_5951
    JMP                     LAB_0000_596a
LAB_0000_5951:
    LOOP                    LAB_0000_5949
    MOV                     BX,offset mac_addr_buf
    CMP                     byte ptr [BX],4ch
    JNZ                     LAB_0000_596a
    CMP                     byte ptr [BX + 1],41h
    JNZ                     LAB_0000_596a
    CMP                     byte ptr [BX + 2],4eh
    JNZ                     LAB_0000_596a
    JMP                     LAB_0000_5976
LAB_0000_596a:
    JMP						LAB_RET_NG
LAB_0000_5976:
    MOV                     BX,offset mac_addr_buf
    MOV                     AX,0b0h
    SHR                     AX,1h
    SHR                     AX,1h
    SHR                     AX,1h
    ADD                     BX,AX
    PUSH                    BX			;BX=>DAT_0000_09d4
    INC                     BX
    MOV                     CX,5h
    MOV                     DL,byte ptr [BX]
LAB_0000_598b:
    INC                     BX
    MOV                     AL,byte ptr [BX]
    XOR                     DL,AL
    LOOP                    LAB_0000_598b
    POP                     BX
    CMP                     DL,byte ptr [BX]
    JZ                      LAB_RET_OK
    JMP						LAB_RET_NG
LAB_RET_OK:
    MOV                     AX,0b8h
    MOV                     CX,6h
    SHR                     AX,1h
    SHR                     AX,1h
    SHR                     AX,1h
    MOV                     SI,offset mac_addr_buf
    ADD                     SI,AX
    REP MOVSB               ;SI->DI block transfer
    POP						DX	;ADD
    POP                     CX	;ADD
	POP						BX
	POP						AX	;ADD
    CLC
    STI
    RET
LAB_RET_NG:
    POP                     CX	;ADD
    POP						DX	;ADD
    POP                     BX
    POP						AX
    STC
    STI
    RET

code	ends

	end

