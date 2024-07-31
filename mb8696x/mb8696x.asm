;
; Packet driver for MB8696x
; Copyleft Yoshi / MAY.'99, JUL.'99
;

VerMB8696x	equ	1

DR_TYPE	equ	100
DR_NAME equ	'MB8696x'

MEM_WIND		equ	0d000h
CNET_MAC_OFF	equ	58h
LAC_MAC_OFF_BX	equ	96h
LAC_MAC_OFF_AX	equ	92h

TYPE_MBH10302	equ	0
TYPE_CNET_PC	equ	1
TYPE_LAC_CD02xAX	equ	2
TYPE_LAC_CD02xBX	equ	3
TYPE_OTHER		equ	-1

MBH0			equ	10h
MAC_ADDR_BASE	equ	1Ah
;ADD FMV-18x
MAC_ADDR_BASE_FMV	equ	14h

MBH_MAGIC		equ	0dh
MBH_INT_TR_ENA	equ	10h
DLC_DISEN		equ 00h

MBH_CHK_REG     equ 12h
MBH_CHK_LEN     equ 3

DEFAULT_INT_NO	equ	3
DEFAULT_IO_ADDR	equ	300h

    extrn   get_hex: near
    extrn   crlf: near
    
W_reg	Macro	reg,val		;write to an ethercoupler register
	Mov	DX,io_addr
	Add	DX,reg
	Mov	AL,val
	Out	DX,AL		;ethercoupler register
	endm

code	segment	word public
	assume	cs:code, ds:code

    card_type  dw  2 dup(0)			; 0:MHB10302->FMV-18x
									; 1:C-NET(PC)C
									; 2:LAC-CD02xAX
									; 3:LAC-CD02xBX
									;-1:other
chk_mac:
;arg:	ds:si=Mac address
;ret:	zero=1 alrady set
;       zero=0 no set
	push	si
    mov cx,EADDR_LEN        ;check mac address is all zero
chk_mac0:
    or  al,[si]
    inc si
    loop    chk_mac0
    pop	si
    ret

; read mac address form EEPROM
;arg: ds:si <- rom_addrss, di<-io_addr
;ret: [ds:si] <- mac address
read_mac_addr:
;	xor	ax,ax
;	or	ax,word ptr[SI]
;	or	ax,word ptr[SI+2]
;	or	ax,word ptr[SI+4]
	
	call	chk_mac
    jnz	read_mac0
    ret						; already set MAC address
;    
read_mac0:
	mov	bx,di				; bx <- io_addr
	mov	cx,EADDR_LEN		; read mac address from EEPROM
    mov	ax,card_type
    cmp	ax,TYPE_MBH10302	;is MBH10302
    jz	read_mac_mbh
    

    mov	di,CNET_MAC_OFF;
    cmp	ax,TYPE_CNET_PC		;is C-NET(PC)C
    jz	read_mac_other
    
    mov	di,LAC_MAC_OFF_BX
    cmp	ax,TYPE_LAC_CD02xBX	;is LAC-CD02xBX
    jz	read_mac_other
	
	mov	di,LAC_MAC_OFF_AX
    cmp	ax,TYPE_LAC_CD02xAX	;is LAC-CD02xBX
    jz	read_mac_other
    ret

;
;read MAC from C-NET
; read MAC from LAC-CD02xAX/BX
read_mac_other:
	push	es
	mov	ax,MEM_WIND
	mov	es,ax
read_mac_loop:
	mov	al,byte ptr es:[di]
	mov	[si],al
	inc	di
	inc	di
	inc	si
	loop	read_mac_loop
	pop	es
	ret
    
;read MAC from MBH10302
read_mac_mbh:
;DLCR7 set
	mov	dx,bx
	add	dx,7
	mov	al,0aah				; ED_BYPASS+PWRON+RBS_BMPR+EOPPOL
	out	dx,al				;ethercoupler register
;
	mov	dx,bx
	;MOD FMV-18x
	;add	dx,MAC_ADDR_BASE	; and base of MAC_ADDRESS
	add	dx,MAC_ADDR_BASE_FMV			; and base of MAC_ADDRESS_FMV

read_mac_mbh_loop:
	in	al,dx			; read byte of factory address
	mov	[si],al
	inc	dx
	inc	si
	loop	read_mac_mbh_loop			; until copy is done...
	ret

;MBH10302 check
; cardType is  MBH10302  then card_type <- TYPE_MBH10302
;              CNET(PC)  then card_type <- TYPE_CNET_PC
;              LAC-CD02xAX then card_type <- TYPE_LAC_CD02xAX
;              LAC-CD02xBX then card_type <- TYPE_LAC_CD02xBX
;                        else card_type <- TYPE_OTHER
;MBH10302 : I/O+11h - 17h = 00h
;->FMV-18x: I/O+14h - 16h = 00h,00h,0eh
;CNET(PC) : CIS:[58h]	00h,FFh,80h,FFh,4Ch,FFh
;LAC-CD02xAX: CIS][93h]	00h,FFh,96,FFh,98h,FFh
;LAC-CD02xBX: CIS][96h]	00h,FFh,96,FFh,98h,FFh
get_board_parameters:
if 0	;ADD FMV-18x
    mov cx,MBH_CHK_LEN
    xor ax,ax
    xor	bx,bx
    mov dx,io_addr
    add dx,MBH_CHK_REG
mbh_chk0:
    in  ax,dx;
    inc dx
    or  bx,ax
    loop    mbh_chk0
    cmp	bx,0h
    jnz	chk_cnet
    mov	card_type,TYPE_MBH10302			; is MBH10302
endif	;ADD FMV-18x
    mov dx,io_addr
    add dx,MAC_ADDR_BASE_FMV
    in  al,dx
    cmp al,00h
    jnz	chk_cnet

    inc dx
    in  al,dx
    cmp al,00h
    jnz	chk_cnet

    inc dx
    in  al,dx
    cmp al,0eh
    jnz	chk_cnet

    mov	card_type,TYPE_MBH10302			; is MBH10302->FMV-18x

;
; MBH10302 specific intialize
;
init_mbh:
	W_reg	DLCR6,DLC_DISEN	;disable data link ctrler prior to init
	W_reg	DLCR2,0
	W_reg	DLCR3,0
;
	W_reg	MBH0,MBH_MAGIC+MBH_INT_TR_ENA	;TNX from if_fe.c(FreeBSD)
	;W_reg	FE_FMV3, FE_FMV3_ENABLE_FLAG	;ADD FMV-18x
	ret

;C-NET(PC)C ?
chk_cnet:
	push	es
	mov	ax,MEM_WIND		;PCIC memory window
	mov	es,ax
	mov	si,CNET_MAC_OFF	
	cmp	byte ptr es:[si],00h
	jnz	chk_lac_bx
	cmp	byte ptr es:[si+2],80h
	jnz	chk_lac_bx
	cmp	byte ptr es:[si+4],4ch
	jnz	chk_lac_bx
	mov	card_type,TYPE_CNET_PC
	pop	es
	ret

;LAC-CD02xBX ?
chk_lac_bx:
	mov	si,LAC_MAC_OFF_BX
	cmp	byte ptr es:[si],00h
	jnz	chk_lac_ax
	cmp	byte ptr es:[si+2],80h
	jnz	chk_lac_ax
	cmp	byte ptr es:[si+4],98h
	jnz	chk_lac_ax
	mov	card_type,TYPE_LAC_CD02xBX
	pop	es
	ret
	
;LAC-CD02xAX ?
chk_lac_ax:
	mov	si,LAC_MAC_OFF_AX
	cmp	byte ptr es:[si],00h
	jnz	exit_chk_lac
	cmp	byte ptr es:[si+2],80h
	jnz	exit_chk_lac
	cmp	byte ptr es:[si+4],98h
	jnz	exit_chk_lac
	mov	card_type,TYPE_LAC_CD02xAX
	pop	es
	ret
	
exit_chk_lac:
	mov	card_type,TYPE_OTHER
	pop	es
	ret

code	ends

;
	include	ecoupler.asm
;
	public  usage_msg
usage_msg   db  "usage: MB8696x [options] <packet_int_no> <hardware_irq> <io_adr> [mac_address]",CR,LF,'$'

	public  copyright_msg
copyright_msg	label	byte
 db CR,LF
 db "MB8696x:  Driver for Fujitsu NICE(MB8696x), Version ",'0'+(majver / 10),'0'+(majver mod 10),".",'0'+version,'.','0'+VerMB8696x,CR,LF
 db "           / for PC-9801/9821 / Written by Yoshi, IT",CR,LF
 db "           / for FMV TOWNS / Port by mcDomDom",CR,LF
 db CR,LF,'$'

	public  parse_args
parse_args:
	assume	ds:code
;      parse  hardware interrupt number and I/O base address from the
;      command line.

;
; set default value
	mov	int_no,DEFAULT_INT_NO	;interupt level default
	mov	io_addr,DEFAULT_IO_ADDR	;I/O base address default
	mov	[io_addr+2],0;
;
	mov	di,offset int_no	; interrupt level?
	call	get_number
	jc	_parse_exit
	mov	di,offset io_addr	; first comes the I/O base address
	call	get_number
	push    ds
	pop     es
	mov	di,offset rom_address	;mac address
	call	get_eaddr
_parse_exit:
	clc
	ret

    include getea.asm
pccard_is		db  "PCCARD is ",'$'
;MOD FMV-18x
;mbh_card		db  "MBH10302 ",'$'
mbh_card		db  "FMV-18x ",'$'
cnet_pc_card	db	"C-NET(PC)C ",'$'
lac_cd02x_card	db	"LAC-CD02x ",'$'
oter_card		db  "unknown ",'$'

    public print_type
print_type:
    mov bx,offset oter_card			;oter card
    mov ax,card_type
    
    cmp	ax,TYPE_MBH10302
    jnz	print_type_cnet
    mov bx,offset mbh_card		;is MBH10302
    jmp	print_card_type			;print
print_type_cnet:
    cmp	ax,TYPE_CNET_PC
    jnz	print_type_lac
    mov bx,offset cnet_pc_card		;is CONTEC C-NET(PC)C
    jmp	print_card_type				;print
print_type_lac:
    cmp	ax,TYPE_LAC_CD02xAX
    jz	is_lac
    cmp	ax,TYPE_LAC_CD02xBX
    jnz	print_card_type
is_lac:
    mov bx,offset lac_cd02x_card	;is TDK LAC CD02x

print_card_type:
    mov dx,offset pccard_is
    mov ah,9
    int 21h

    mov dx,bx
	mov	di,offset card_type
	call print_number


    ret
code	ends
	end

