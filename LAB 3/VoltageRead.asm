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
putchar:
    jnb TI, putchar
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
    lcall putchar
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

Hello_World: DB  'Hello, World!', '\r', '\n', 0
String: db 'good' , '\r', '\n', 0 
Voltage: db 'Voltage is:', '\r', '\n', 0  


;---------------------------------;
; MAIN PROGRAM LOOP			      ;
;---------------------------------;


MainProgram:
    mov SP, #7FH ; Set the stack pointer to the begining of idata
    
<<<<<<< Updated upstream
    lcall LCD_4BIT
    lcall InitSerialPort
    lcall INIT_SPI
=======
    Set_Cursor(1,1)
	Send_Constant_String(#Hello_World)
    
    lcall InitSerialPort ;sets up serial port with putty
    lcall INIT_SPI ;sets up serial port with mcp
>>>>>>> Stashed changes
    
loop: ;begin the infinite loop  
 
 	clr CE_ADC
 	
	mov R0, #00000001B ; Start bit:1
	lcall DO_SPI_G
	mov R0, #10000000B ; Single ended, read channel 0
	lcall DO_SPI_G
	mov a, R1 ; save the high bits first
	anl a, #00000011B ; We need only the two least significant bits (8 and 9)
	mov Result+1, a ; Save result high.
	mov R0, #55H ; It doesn't matter what we transmit...
	lcall DO_SPI_G
	mov Result, R1 ; R1 contains bits 0 to 7. Save result low.
	
	setb CE_ADC ;disable
	
; calculate voltage out
	Load_X(Result)
	Load_y(4096)
	lcall mul32
	Load_y(1023)
	lcall div32
	Load_y(1000)
	lcall div32
	mov a, x
	hex2bcd(x)
	
	;da a
	
;	mov a, Result
	
;	cjne a, #0x0, goto
 ;   ljmp loop   
  ;  mov DPTR, #Hello_World
    
 ;  da a
  ;  mov Result, a
    
    mov DPTR, #Voltage
 	lcall SendString
	Send_BCD(bcd)
	Wait_Milli_Seconds(#255)
 	Wait_Milli_Seconds(#255)
 	Wait_Milli_Seconds(#255)
 	Wait_Milli_Seconds(#255)
    ;lcall SendString    
    ljmp loop 
 
 goto:  
 
 ;	mov DPTR, #Hello_World
 ;	lcall SendString
 	Send_BCD(#bcd)
 	Wait_Milli_Seconds(#255)
 	Wait_Milli_Seconds(#255)
 	
 	ljmp loop   
END
