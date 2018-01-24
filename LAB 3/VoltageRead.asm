$MODLP51
org 0000H
   ljmp MainProgram

CLK  EQU 22118400
BAUD equ 115200
BRG_VAL equ (0x100-(CLK/(16*BAUD)))
REF equ 4.096

; These ’EQU’ must match the wiring between the microcontroller and ADC
CE_ADC EQU P2.0
MY_MOSI EQU P2.1
MY_MISO EQU P2.2
MY_SCLK EQU P2.3


TIMER0_RELOAD_L DATA 0xf2
TIMER0_RELOAD_H DATA 0xf4



TIMER0_RATE   EQU 4096             ; 2048Hz squarewave (peak amplitude of CEM-1203 speaker)
TIMER0_RELOAD EQU ((65536-(CLK/TIMER0_RATE)))

SOUND_OUT     equ P3.7
SNOOZE_BUTTON equ P0.3
FAREN equ P0.5



; External interrupt 0 vector (not used in this code)
org 0x0003
	reti

; Timer/Counter 0 overflow interrupt vector
org 0x000B
	ljmp Timer0_ISR

; External interrupt 1 vector (not used in this code)
org 0x0013
	reti

; Timer/Counter 1 overflow interrupt vector (not used in this code)
org 0x001B
	reti

; Serial port receive/transmit interrupt vector (not used in this code)
org 0x0023 
	reti
	
; Timer/Counter 2 overflow interrupt vector
org 0x002B
	reti


dseg at 0x30
Result: ds 4
x:   ds 4
y:   ds 4
bcd: ds 5
buffer: ds 30


BSEG
mf: dbit 1

CSEG
; These 'equ' must match the wiring between the microcontroller and the LCD!
LCD_RS equ P1.1
LCD_RW equ P1.2
LCD_E  equ P1.3
LCD_D4 equ P3.2
LCD_D5 equ P3.3
LCD_D6 equ P3.4
LCD_D7 equ P3.5
$NOLIST
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$LIST

$NOLIST
$include(math32.inc) ; A library of Lmath functions
$LIST



;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 0                     ;
;---------------------------------;
Timer0_Init:
	mov a, TMOD
	anl a, #0xf0 ; Clear the bits for timer 0
	orl a, #0x01 ; Configure timer 0 as 16-timer
	mov TMOD, a
	mov TH0, #high(TIMER0_RELOAD)
	mov TL0, #low(TIMER0_RELOAD)
	; Set autoreload value
	mov TIMER0_RELOAD_H, #high(TIMER0_RELOAD)
	mov TIMER0_RELOAD_L, #low(TIMER0_RELOAD)
	; Enable the timer and interrupts
    setb ET0  ; Enable timer 0 interrupt
    setb TR0  ; Start timer 0
	ret

;---------------------------------;
; ISR for timer 0.  Set to execute;
; every 1/4096Hz to generate a    ;
; 2048 Hz square wave at pin P3.7 ;
;---------------------------------;

Timer0_ISR:
	cpl SOUND_OUT; Connect speaker to P3.7!
	reti

;---------------------------------;
; initialize the slave		      ;
;---------------------------------;

INIT_SPI:
 setb MY_MISO ; Make MISO an input pin
 clr MY_SCLK ; For mode (0,0) SCLK is zero
 ret

;---------------------------------;
; recieive and send data	      ;
;---------------------------------;

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

;---------------------------------;
; initialize the serial ports     ;
;---------------------------------;
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

; Send a character using the serial port
putchar1:
    jnb TI, putchar1
    clr TI
    mov SBUF, a
    ret
    
getchar:
	jnb RI, getchar
	clr RI
	mov a, SBUF
	ret	
    

; Send a constant-zero-terminated string using the serial port
SendString:
    clr A
    movc A, @A+DPTR
    jz SendStringDone ;if a = 0 go to sendstring done
    lcall putchar1
    inc DPTR
    sjmp SendString
    
SendStringDone:
    ret
 
 
GetString:
	mov R0, #buffer
GSLoop:
	lcall getchar
	push acc
	clr c
	subb a, #10H
	pop acc
	jc GSDone
	MOV @R0, A
	inc R0
	SJMP GSLoop
GSDone:
	clr a
	mov @R0, a
	ret

 Display_10_BCD:
	Display_BCD(bcd+4)
	Display_BCD(bcd+3)
	Display_BCD(bcd+2)
	Display_BCD(bcd+1)
	Display_BCD(bcd+0)
	ret

; We can display a number any way we want.  In this case with
; four decimal places.
Display_formated_BCD:
	Display_char(#' ')
	Display_BCD(bcd+3)
	Display_BCD(bcd+2)
	Display_char(#'.')
	Display_BCD(bcd+1)
	Display_BCD(bcd+0)
	ret
	
wait_for_P4_5:
	jb P4.5, $ ; loop while the button is not pressed
	Wait_Milli_Seconds(#50) ; debounce time
	jb P4.5, wait_for_P4_5 ; it was a bounce, try again
	jnb P4.5, $ ; loop while the button is pressed
	ret


 
Bonus:
;---------------------------------;
; comparisons 				      ;
;---------------------------------;
	; x is currently the temperature
	
	Load_y(25)
	;x<y
	lcall x_lt_y
	
	jb mf, printcold
	
	Load_y(27)
	;x<y
	lcall x_lt_y
	jb mf, printperf
	
	Load_y(29)
	;x<y
	lcall x_lt_y
	jb mf, printhot
	
	sjmp printfire
	
printcold:
	Set_Cursor(2,1)
	Send_Constant_String(#cold)
	ret
	
printperf:
	Set_Cursor(2,1)
	Send_Constant_String(#perf)
	ret
	
printhot:
	Set_Cursor(2,1)
	Send_Constant_String(#hot)
	ret
	
printfire:
	Set_Cursor(2,1)
	Send_Constant_String(#fire)
	lcall firealarm
	ret
	
;---------------------------------;
; FIRE ALARM				      ;
;---------------------------------;	
firealarm:
	lcall Timer0_Init
	
	jb SNOOZE_BUTTON, go  ; 
	Wait_Milli_Seconds(#50)	; Debounce delay.  This macro is also in 'LCD_4bit.inc'
	jb SNOOZE_BUTTON, go  ; if the button is not pressed skip
	jnb SNOOZE_BUTTON, $
	clr TR0
	clr ET0
	
go:
	ret


Hello_World: DB  'Hello, World!', '\r', '\n', 0
String: db 'good' , '\r', '\n', 0 
Voltage: db 'Voltage is:', '\r', '\n', 0  
Temp: db 'Temperature is:', '\r', '\n', 0  
space: db '\r', '\n', 0
Temper: DB  'Temperature:', 0
cold: DB  'Bundle Up', 0
perf: DB  'This is Perfect', 0
hot: DB  'Too Hot, UGH', 0
fire: db 'FIRE FIRE FIRE' , 0


;---------------------------------;
; MAIN PROGRAM LOOP			      ;
;---------------------------------;


MainProgram:
    mov SP, #7FH ; Set the stack pointer to the begining of idata
    
	; initalize lcd and serial ports
    lcall LCD_4BIT
    lcall InitSerialPort ;
    lcall INIT_SPI
 	mov P0M0, #0
    mov P0M1, #0
    setb EA  
    
    Set_Cursor(1,1)
	Send_Constant_String(#Temper)
    Set_Cursor(1,15)
    WriteData(#0xDF)
    Set_Cursor(1,16)
    WriteData(#'C')
loop: ;begin the infinite loop  
 
 	clr CE_ADC
 	
	mov R0, #00000001B ; Start bit:1
	lcall DO_SPI_G
	mov R0, #10000000B ; Single ended, read channel 0
	lcall DO_SPI_G
	mov a, R1 ; save the high bits first ; since we're reading a 10 bit value
	anl a, #00000011B ; We need only the two least significant bits (8 and 9)
	mov Result+1, a ; Save result high.
	mov R0, #55H ; It doesn't matter what we transmit...
	lcall DO_SPI_G
	mov Result, R1 ; R1 contains bits 0 to 7. Save result low.
	
	setb CE_ADC ;disable

;start doing stuff	
	Load_X(0)

	mov a,Result
	mov x,a
	mov a,Result+1
	mov x+1,a
	
;	lcall hex2bcd
			
 ;	Set_Cursor(2, 7)
;	lcall Display_10_BCD
;	Send_BCD(bcd+2)
;	Send_BCD(bcd+1)
;	Send_BCD(bcd)

	mov DPTR, #space
;	lcall SendString
	
 ;	mov bcd, Result
 ;	mov bcd+1, Result+1
 ;	mov x, bcd

 
; calculate voltage out
	Load_X(0)
	Load_y(0)
;	Load_X(bcd)

	mov a,Result
	mov x,a
	mov a,Result+1
	mov x+1,a
		
	load_y(410)
	lcall mul32
	load_y(1023)
	lcall div32
	load_y(273)
	lcall sub32

	
	Wait_Milli_Seconds(#255)
 	Wait_Milli_Seconds(#255)
       
    mov DPTR, #Temp
;	lcall SendString
	
	lcall hex2bcd

    Send_BCD(bcd) 
    
    mov DPTR, #space
	lcall SendString 
	
	Set_Cursor(1, 13)
	Display_BCD(bcd)
	
	lcall Bonus
    	
    ljmp loop 
 	
END
