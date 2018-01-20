$MODLP51
org 0000H
   ljmp MainProgram

CLK  EQU 22118400
BAUD equ 115200
BRG_VAL equ (0x100-(CLK/(16*BAUD)))
; These ’EQU’ must match the wiring between the microcontroller and ADC
CE_ADC EQU P2.0
MY_MOSI EQU P2.1
MY_MISO EQU P2.2
MY_SCLK EQU P2.3

CSEG

INIT_SPI:
 setb MY_MISO ; Make MISO an input pin
 clr MY_SCLK ; For mode (0,0) SCLK is zero
 ret

DO_SPI_G:
 push acc
 mov R1, #0 ; Received byte stored in R1
 mov R2, #8 ; Loop counter (8-bits)
DO_SPI_G_LOOP:
 mov a, R0 ; Byte to write is in R0
 rlc a ; Carry flag has bit to write
 mov R0, a
 mov MY_MOSI, c
 setb MY_SCLK ; Transmit
 mov c, MY_MISO ; Read received bit
 mov a, R1 ; Save received bit in R1
 rlc a
 mov R1, a
 clr MY_SCLK
 djnz R2, DO_SPI_G_LOOP
 pop acc
 ret
; Configure the serial port and baud rate

InitSerialPort:
    ; Since the reset button bounces, we need to wait a bit before
    ; sending messages, otherwise we risk displaying gibberish!
    mov R1, #222
    mov R0, #166
    djnz R0, $   ; 3 cycles->3*45.21123ns*166=22.51519us
    djnz R1, $-4 ; 22.51519us*222=4.998ms
    ; Now we can proceed with the configuration
	orl	PCON,#0x80
	mov	SCON,#0x52
	mov	BDRCON,#0x00
	mov	BRL,#BRG_VAL
	mov	BDRCON,#0x1E ; BDRCON=BRR|TBCK|RBCK|SPD;
    ret

; Configure serial port and baud rate
clr TR1 ; Disable timer 1
anl TMOD, #0x0f ; Mask the bits for timer 1
orl TMOD, #0x20 ; Set timer 1 in 8-bit auto reload mode
orl PCON, #80H ; Set SMOD to 1
mov TH1, #244 ; for 115200 baud
mov TL1, #244
setb TR1 ; Enable timer 1
mov SCON, #52H


; Send a character using the serial port
putchar:
    jnb TI, putchar
    clr TI
    mov SBUF, a
    ret

; Send a constant-zero-terminated string using the serial port
SendString:
    clr A
    movc A, @A+DPTR
    jz SendStringDone
    lcall putchar
    inc DPTR
    sjmp SendString
SendStringDone:
    ret
 
Hello_World:
    DB  'Hello, World!', '\r', '\n', 0
    
;Forever:

;lcall Delay
;lcall Do_Something_With_Result
;sjmp Forever

MainProgram:
    mov SP, #7FH ; Set the stack pointer to the begining of idata
    
    lcall InitSerialPort
    lcall INIT_SPI
    
loop:   
 
 	clr CE_ADC
 	
	mov R0, #00000001B ; Start bit:1
	
	lcall DO_SPI_G
	
	mov R0, #10000000B ; Single ended, read channel 0
	
	lcall DO_SPI_G
	
	mov a, R1 ; R1 contains bits 8 and 9
	
	anl a, #00000011B ; We need only the two least significant bits
	
	mov Result+1, a ; Save result high.
	mov R0, #55H ; It doesn't matter what we transmit...
	lcall DO_SPI_G
	mov Result, R1 ; R1 contains bits 0 to 7. Save result low.
	setb CE_ADC
    
    
    mov DPTR, Result
    
    lcall SendString
    
    sjmp loop ; This is equivalent to 'forever: sjmp forever'
    
END
