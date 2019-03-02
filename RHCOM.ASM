;Disassembly of the HD6301V1 "COM" MCU code found in a prototype Riding Hero cartridge
;Not guaranteed to have gone into production
;Comments/doc by HPMAN and furrtek

;MCU runs in mode 7 (P20, P21 and P22 pulled high)
;Memory map:
;$0000~$001F: Internal registers
;$0020~$007F: Unused
;$0080~$00FF: RAM
;$0100~$EFFF: Unused
;$F000~$FFFF: ROM

;Vectors:
;TRAP:	F4D6 (error)
;SC1:	F4BA (link receive)
;TOF:	F4D6 (error)
;OCF:	F4D6 (error)
;ICF:	F4D6 (error)
;IRQ1:	F4CB (CPU write)
;SWI:	F4D6 (error)
;NMI:	F4D6 (error)
;RESET:	F000 (start)

;RAM:
;$C2 start of message buffer (14 bytes ?)

;$D0~$D1
;$D2~$D3
;$D4~$D5
;$D6~$D7
;$D8~$D9
;$DA~$DB
;$DC

;$E2 is an error counter ?
;$E3 some counter ? -----------------
;$E4 some bitmask ? -----------------
;$E5 is receive byte counter
;$E6 ?
;$E7 is the output code (read by CPU)
;$E8 related to $F3 ?
;$E9 is the input code (wrote by CPU)
;$EA another byte counter ?
;$EB bit 0 is CPU write flag ? (data ready in $E9), bit 1 is link receive flag
;$EC is TRCS register copy
;$ED is the received code (link)
;$EE~$EF buffer (FIFO ?) pointer
;$F0 receive timeout timer
;$F1 is status code/port1 mirror
;$F2 some bitmask ? -----------------
;$F3 is lower nibble of input code (parameter ?)
;$F4 start of some short buffer ?

;Status bit 0 (D8) is command error (D,E,F: wrong command)
;Status bit 2 (D10) is overrun receive error

	org	$F000
; RESET
LF000:
	sei

	lds	#$00FF      ; Stack point at end of RAM
	ldx	#$0080	    ; Clear RAM
LF007:
	clr	$7F,x
	dex
	bne	LF007

	ldaa	#$40	; Enable RAM (lol, already enabled at reset)
	staa	X0014
	ldaa	#$04	; 62500bps internal clock, NRZ
	staa	X0010
	ldaa	#$1A	; RIE, RXE, TXE
	staa	X0011
	ldaa	#$48	; Port3 IS3/IRQ1 enable, latch enable
	staa	X000F
	ldaa	X0011   ; Clear TRCS flags
	ldaa	X0012	; Receive register
	ldaa	#$F1	; Port1 direction 11110001
	staa	X0000
	ldaa	#$00	; Port1 data
	staa	X0002
	ldaa	#$00	; Port3 direction (inputs)
	staa	X0004
	ldaa	#$FF	; Port4 direction (outputs)
	staa	X0005
	ldaa	X0006	; Clear port3 latch
	ldaa	#$FF	; $FF to RAM $E9, $DE, $DF, $E0, $E1, $B4, $C2, $E9, $E7
	staa	X00E9	; Input code
	staa	X00DE
	staa	X00DF
	staa	X00E0
	staa	X00E1
	staa	X00B4
	staa	X00C2
	staa	X00E9	; Input code (again...)
	staa	X00E7	; Output code
	ldd	#$0080
	std	X00EE	    ; RAM $EE = $0080
	cli

LF056:
	ldaa	X0002	; Read port1
	bita	#$02    ; P11 is nSLOTCS ($02 is a mask, not a bit number)
	beq	LF08F       ; Slot is enabled ->
	clra
	staa	X0002	; Clear port1
	staa	X00E2	; Clear error counter ?
	staa	X00E5	; Reset byte counter
	staa	X00E8
	staa	X00EA
	staa	X00EB	; Clear flags
	staa	X00F1	; Clear status ?
	staa	X00F2
	staa	X00F3
	deca
	staa	X00B4	; $FF in RAM...
	staa	X00C2
	staa	X00DE
	staa	X00DF
	staa	X00E0
	staa	X00E1
	staa	X00E9	; Input code
	bra	LF056	; Loop until slot is enabled

; Slot enabled
LF08F:
	inc	X00F0	; $F0 starts at 0, now 1
	ldaa	X00EB
	bita	#$01	; Got a byte from CPU ?
	bne	LF09C   ; Yup ->
	jmp	LF193	; Nope ->

; Process CPU write
LF09C:
	; AIM AND Immediate $FE with RAM $EB (clear CPU write flag)
	; EIM XOR Immediate $80 with RAM $F1 (toggle status bit 3)
	ldaa	X00F2
	bne	LF0B7
	ldab	X00E9	; Input code
	andb	#$F0    ; Upper nibble is index in jump table
	ldx	#$F4DA
	lsrb            ; 0BBBB000
	lsrb            ; 00BBBB00
	lsrb            ; 000BBBB0
	abx     	; B+X -> X
	ldx	$00,x
	jmp	$00,x	; Index jump

;
LF0B7:
	bita	#$01
	beq	LF0DE
	ldab	X00E8
	cmpb	X00F3
	beq	LF117
	ldx	#$00D0
	abx     	; B+X -> X
	ldaa	X00E9	; Input code
	staa	$00,x
	ldaa	$01,x
	staa	X0007	; Port4 data (output code)
	; AIM AND Immediate $EF with RAM $F1
	ldaa	X00F1	; Status ?
	staa	X0002	; Port1 data
	inc	X00E8
	jmp	LF193
;
LF0DE:
	ldab	X00E8
	cmpb	X00F3
	beq	LF0FC
	ldx	#$00D0
	abx     	; B+X -> X
	ldaa	$01,x
	staa	X0007	; Port4 data (output code)
	; AIM AND Immediate $EF with RAM $F1
	ldaa	X00F1	; Status ?
	staa	X0002	; Port1 data
	inc	X00E8
	jmp	LF193
;
LF0FC:
	ldx	#$00D0
	abx     	; B+X -> X
	ldaa	$00,x
	coma
	staa	X0007	; Port4 data (output code)
	; AIM AND Immediate $EF with RAM $F1
	ldaa	X00F1	; Status ?
	staa	X0002	; Port1 data
	clra
	staa	X00E8
	staa	X00F2
	jmp	LF193
;
LF117:
	clra
	staa	X00F2
	ldx	#$00CF
	abx     	; B+X -> X
	ldaa	$00,x
	coma
	cmpa	X00E9	; Input code
	beq	LF13D
	ldaa	$01,x
	coma
	staa	X0007	; Port4 data (output code)
	; OIM OR Immediate $20 with RAM $F1 (set status bit 1)
	; AIM AND Immediate $EF with RAM $F1
	ldaa	X00F1	; Status ?
	staa	X0002	; Port1 data
	clr	X00E8
	jmp	LF193
;
LF13D:
	ldab	X00E7	; Output code
	cmpb	#$FF
	bne	LF159
	ldaa	$01,x
	staa	X0007	; Port4 data (output code)
	; OIM OR Immediate $20 with RAM $F1 (set status bit 1)
	; AIM AND Immediate $EF with RAM $F1
	ldaa	X00F1	; Status ?
	staa	X0002	; Port1 data
	clr	X00E8
	jmp	LF193
;
LF159:
	ldaa	$01,x
	coma
	staa	X0007	; Port4 data (output code)
	clra
	xgdx	?????
	clr	$DE,x
;
	; AIM AND Immediate $CF with RAM $F1
	ldaa	X00F1	; Status ?
	staa	X0002	; Port1 data
	clr	X00E8
	ldx	X00EE
	ldd	X00D0
	std	$00,x
	ldd	X00D2
	std	$02,x
	ldd	X00D4
	std	$04,x
	ldd	X00D6
	std	$06,x
	ldd	X00D8
	std	$08,x
	ldd	X00DA
	std	$0A,x
	ldaa	X00DC
	staa	$0C,x
LF193:
	ldaa	X00EB	; Got a byte from link ?
	bita	#$02
	bne	LF19D	; Yup ->
	jmp	LF257   ; Nope ->

; Process link receive
LF19D:
	; AIM AND Immediate $FD (11111101) with RAM $EB
	ldab	X00EC
	bitb	#$40	; Overrun framing error ?
	bne	LF1AE	; Yup ->
	bitb	#$80	; Receive data register full ?
	bne	LF1CE	; Yup ->
	jmp	LF257

; Overrun framing error
LF1AE:
	clra
	staa	X00E5	; Reset byte counter
	staa	X00EA
	deca
	staa	X00C2
	staa	X00B4
	inc	X00E2	; Error counter ?
	ldaa	X00F1	; Status ?
	oraa	#$40    ; Set status bit 2
	anda	#$FE	; Mask out P10, just in case (transmit enable, not status)
	staa	X00F1	; Status ?
	staa	X0002	; Port1 data
	jmp	LF257

; Got byte ok
LF1CE:
	ldab	X00E5	; Byte counter
	cmpb	#$0D
	beq	LF1E5	; Already got 13 bytes ? ->
	clra
	xgdx	?????
	ldaa	X00ED	; Received code
	staa	$C2,x	; Store in list @ $C2+x
	inc	X00E5	; Byte counter
	; OIM OR Immediate $04 with RAM $EB
	jmp	LF257

; Got message OK
LF1E5:
	; AIM AND Immediate $FE with RAM $F1
	ldaa	X00F1	; Status ?
	staa	X0002	; Port1 data
	clra
	xgdx	?????
	ldaa	X00ED	; Received code
	staa	$C2,x   ; Store 14th byte (the last)
	clra
	staa	X00EA
	staa	X00E5	; Reset byte counter
	deca
	staa	X00B4

	ldaa	X00C2	; RAM $C2 (first byte of message) & 3: 0~3 -> 1~4, gives B=$02,$04,$08,$10
	anda	#$03
	inca
	ldab	#$01
LF207:
	aslb
	deca
	bne	LF207
	lsrb		; B=$01,$02,$04,$08
	orab	X00E4
	stab	X00E4

	ldab	X00C2
	andb	#$03
	ldx	#$00F4
	abx     	; X = $00F4 + (RAM $C2 & 3)
	clr	$00,x
	cmpb	X00E7	; Output code
	beq	LF252
	ldx	#$F4FA
	abx     	; B+X -> X
	abx     	; B+X -> X
	incb
	andb	#$03
	stab	X00E3
	ldx	$00,x
	ldd	X00C3
	std	$00,x
	ldd	X00C5
	std	$02,x
	ldd	X00C7
	std	$04,x
	ldd	X00C9
	std	$06,x
	ldd	X00CB
	std	$08,x
	ldd	X00CD
	std	$0A,x
	ldaa	X00CF
	staa	$0C,x
LF252:
	ldaa	#$FF
	staa	X00C2
LF257:
	ldaa	X00F0
	cmpa	#$28
	bcs	LF296
	ldx	#$00F4
	ldab	X00E3
	abx     	; B+X -> X
	ldaa	$00,x
	inca
	cmpa	#$0A
	bne	LF27C
	ldaa	#$01
	incb
LF26F:
	asla
	decb
	bne	LF26F
	lsra
	coma
	anda	X00E4
	staa	X00E4
	clra
LF27C:
	staa	$00,x
	inc	X00E3
	; AIM AND Immediate $03 with RAM $E3
	clra
	staa	X00E5	; Reset byte counter
	staa	X00EA
	staa	X00F0
	; AIM AND Immediate $FE with RAM $F1
	ldaa	X00F1	; Status ?
	staa	X0002	; Port1 data
LF296:
	ldaa	X0011	; Read TRCS
	bita	#$20    ; Transmit register empty ?
	beq	LF309   ; Nope ->
	ldaa	X00B4
	cmpa	#$FF
	bne	LF309
	clra
	ldab	X00E7	; Output code
	cmpb	#$FF
	beq	LF309
	xgdx	?????
	ldab	$DE,x
	bne	LF309
	orab	X00EA
	orab	X00E5	; Byte counter
	bne	LF309
	xgdx	?????
	eorb	X00E3
	bne	LF309
	ldx	X00EE	; X=$00EE
	ldd	$00,x
	std	X00B5	; RAM $B5 <- RAM $EE
	ldd	$02,x
	std	X00B7	; RAM $B7 <- RAM $F0
	ldd	$04,x
	std	X00B9	; RAM $B9 <- RAM $F2
	ldd	$06,x
	std	X00BB	; RAM $BB <- RAM $F4
	ldd	$08,x
	std	X00BD	; RAM $BD <- RAM $F6
	ldd	$0A,x
	std	X00BF	; RAM $BF <- RAM $F8
	ldaa	$0C,x
	staa	X00C1	; RAM $C1 <- RAM $FA
	ldaa	X00E7	; Output code
	staa	X00B4
	; OIM OR Immediate $01 with RAM $F1 (P10 high, enable TX buffer in 75176)
	ldab	X00F1	; Status ?
	stab	X0002	; Port1 data
	staa	X0013	; Transmit register
;
	; AIM AND Immediate $FB with RAM $EB
	inc     X00EA
	inc     X00E3
	; AIM AND Immediate $03 with RAM $E3
	clra
	ldab	X00E7	; Output code
	xgdx	?????
	ldaa	#$FF
	staa	$DE,x
LF309:
	ldaa	X00EB
	bita	#$04
	beq	LF33F
	ldaa	X00F0
	cmpa	#$0F
	bcs	LF33F
	ldaa	X00B4
	cmpa	#$FF
	beq	LF33F
	ldaa	X0011	; Read TRCS
	bita	#$20    ; Transmit register empty ?
	beq	LF33F	; Nope ->
	ldab	X00EA
	cmpb	#$0E
	beq	LF33F
;
	; AIM AND Immediate $FB with RAM $EB
	clra

	xgdx	?????
	ldaa	$B4,x
	inc	X00EA
	; OIM OR Immediate $01 with RAM $F1 (P10 high, enable TX buffer in 75176)
	ldab	X00F1	; Status ?
	stab	X0002	; Port1 data
	staa	X0013	; Transmit register
LF33F:
	jmp	LF056

Command9:
	sei
	ldx	#$0080
LF346:
	clr	$7F,x
	dex
	bne	LF346
	jmp	LF000

Command0:
	; AIM AND Immediate $EF with RAM $F1
	ldaa	X00F1	; Status ?
	staa	X0002	; Port1 data
	jmp	LF193

Command2:
	ldaa	X00E7	; Output code
	staa	X0007	; Port4 data (output code)
	; AIM AND Immediate $EF with RAM $F1
	ldaa	X00F1	; Status ?
	staa	X0002	; Port1 data
	jmp	LF193

Command1:
	ldaa	X00E9	; Input code
	tab
	anda	#$0C    ; Bits 2 and 3
	bne	LF3D6
	; AIM AND Immediate $EF with RAM $F1
	ldaa	X00F1	; Status ?
	staa	X0002	; Port1 data
	andb	#$03
	stab	X00E7	; Output code
	ldx	#$F4FA
	abx     	; B+X -> X
	abx     	; B+X -> X
	ldd	$00,x
	std	X00EE	; RAM $EE = $F4FA + X*2
	ldab	#$01
	ldaa	X00E9	; Input code
	anda	#$03
LF38F:
	deca
	bmi	LF396
	aslb
	jmp	LF38F
;
LF396:
	orab	X00E4
	stab	X00E4
	jmp	LF193

Command4:
	ldaa	X00E9	; Input code
	anda	#$0F
	staa	X00F3	; RAM $F3 is lower nibble of input code
	; AIM AND Immediate $EF with RAM $F1
	ldaa	X00F1	; Status ?
	staa	X0002	; Port1 data
	ldaa	#$FE
	staa	X00F2	; RAM $F2 = $FE
	jmp	LF193

Command3/CommandA:
	ldaa	X00E7	; Output code
	cmpa	#$FF
	beq	LF3D6	; Is $FF ? ->
	ldaa	X00E9	; Input code
	anda	#$0F
	staa	X00F3	; RAM $F3 is lower nibble of input code
	; AIM AND Immediate $EF with RAM $F1
	ldaa	X00F1	; Status ?
	staa	X0002	; Port1 data
	ldaa	#$FF
	staa	X00F2	; RAM $F2 = $FF
	jmp	LF193

CommandD/E/F:
	; OIM OR Immediate $10 with RAM $F1 (set status bit 0)
	ldaa	X00F1	; Status ?
	staa	X0002	; Port1 data
	jmp	LF193

Command5:		; Similar to command 1
	ldaa	X00E9	; Input code
	tab
	anda	#$0C    ; Bits 2 and 3
	bne	LF3D6
	; AIM AND Immediate $EF with RAM $F1
	ldaa	X00F1	; Status ?
	staa	X0002	; Port1 data
	andb	#$03
	stab	X00E6
	ldx	#$F4FA
	abx     	; B+X -> X
	abx     	; B+X -> X
	ldx	$00,x
	ldd	$00,x
	std	X00D1	; RAM $D1 = $F4FA + X*2 (word)
	ldd	$02,x
	std	X00D3	; RAM $D3 = $F4FA + X*2 + 2 (word)
	ldd	$04,x
	std	X00D5	; RAM $D5 = $F4FA + X*2 + 4 (word)
	ldd	$06,x
	std	X00D7	; RAM $D7 = $F4FA + X*2 + 6 (word)
	ldd	$08,x
	std	X00D9	; RAM $D9 = $F4FA + X*2 + 8 (word)
	ldd	$0A,x
	std	X00DB	; RAM $DB = $F4FA + X*2 + A (word)
	ldaa	$0C,x
	staa	X00DD	; RAM $DD = $F4FA + X*2 + C (byte) always $FF ?
	clr	X00E8
	jmp	LF193

CommandC:
	ldaa	X00E7	; Output code
	cmpa	#$FF
	beq	LF3D6
	ldaa	X00E9	; Input code
	tab
	anda	#$0C
	bne	LF3D6
	; AIM AND Immediate $EF with RAM $F1
	ldaa	X00F1	; Status ?
	staa	X0002	; Port1 data
	andb	#$03
	ldx	#$F4FA
	abx     	; B+X -> X
	abx     	; B+X -> X
	ldx	$00,x
	ldd	$00,x
	std	X00D1
	ldd	$02,x
	std	X00D3
	ldd	$04,x
	std	X00D5
	ldd	$06,x
	std	X00D7
	ldd	$08,x
	std	X00D9
	ldd	$0A,x
	std	X00DB
	ldaa	$0C,x
	staa	X00DD
	clra
	staa	X00E8
	deca
	staa	X00F2
	ldaa	#$0D
	staa	X00F3
	jmp	LF193

Command6:
	; AIM AND Immediate $EF with RAM $F1
	ldaa	X00F1	; Status ?
	staa	X0002	; Port1 data
	ldaa	X00E9	; Input code
	staa	X00E8
	jmp	LF193

Command7:
XF48A:
	ldaa	X00E4
	staa	X0007	; Port4 data (output code)
	; AIM AND Immediate $EF with RAM $F1
	ldaa	X00F1	; Status ?
	staa	X0002	; Port1 data
	jmp	LF193

Command8:
	ldaa	X00E2	; Error counter ?
	staa	X0007	; Port4 data (output code)
	; AIM AND Immediate $EF with RAM $F1
	ldaa	X00F1	; Status ?
	staa	X0002	; Port1 data
	jmp	LF193

CommandB:
	ldaa	X00F1	; Status ?
	anda	#$BF
	; AIM AND Immediate $EF with RAM $F1
	staa	X00F1	; Status ?
	staa	X0002	; Port1 data
	jmp	LF193

SC1:
	ldaa	X0011	; Read TRCS
	staa	X00EC   ; Store
	ldaa	X0012	; Receive register
	staa	X00ED	; Store received code
	clr	X00F0
	; OIM OR Immediate $02 with RAM $EB (link receive flag)
	rti

IRQ1:
	ldaa	X000F   ; Clear port3 latch flag
	ldaa	X0006	; Port3 data (input code)
	staa	X00E9	; Input code
	; OIM OR Immediate $01 with RAM $EB (CPU write flag)
	rti

XF4D6:
	inc	X00E2	; Error counter ?
	rti

XF4DA:
; CPU command 0: $F34E	Update status
; CPU command 1: $F369
; CPU command 2: $F359	Read output code
; CPU command 3: $F3B7
; CPU command 4: $F39F
; CPU command 5: $F3E1
; CPU command 6: $F479	Put $E9 in $E8 ?
; CPU command 7: $F48A
; CPU command 8: $F49A	Read error counter
; CPU command 9: $F342	Reset
; CPU command A: $F3B7	Same as command 3
; CPU command B: $F4AA	Ack something ?
; CPU command C: $F426
; CPU command D: $F3D6	Invalid
; CPU command E: $F3D6	Invalid
; CPU command F: $F3D6	Invalid

XF4FA:
;0080 008D 009A 00A7 00B4 00C2 FF...
