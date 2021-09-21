;***********************************************************
;***********************************************************
;**  servo-motor.asm                                      **
;**                                                       **
;**  Target uC: Atmel ATmega2560                          **
;**  X-TAL Frequency: 16MHz                               **
;**  AVRASM: AVR macro assembler 2.1.57                   ** 
;**          (build 16 Aug 27 2014 16:39:43)              **
;**                                                       **
;**  Created: 2021/09/17 Davi Muniz Vasconcelos           **
;***********************************************************
;***********************************************************

   .EQU BAUD_RATE_57600 = 16 ; Constant for baud rate
   
   .EQU S_ASCII = 83         ; S key value
   .EQU PLUS_ASCII = 43      ; + sign value
   .EQU MINUS_ASCII = 45     ; - sign value
   .EQU ENTER_ASCII = 10     ; Enter key value
   
   .EQU PERIOD_COUNT = 40000      ; Time constant for 20ms
   .EQU MIN_COUNT = 2000          ; Time constant for 1ms
   .EQU DEFAULT_COUNT = 3000      ; Default constant for motors

   .CSEG                     ; FLASH segment code
   .ORG 0                    ; Entry point after POWER/RESET
    JMP RESET

   .ORG 0x100

RESET:
    LDI R16, HIGH(RAMEND)    ; Sets Stack Pointer to RAMEND
    OUT SPH, R16             ;
    LDI R16, LOW(RAMEND)     ;
    OUT SPL, R16             ;

    CALL USART_INIT          ; Goes to USART initialization code
    CALL PORTB_INIT          ; Goes to PORTB initialization code
	CALL TIMER1_INIT_MODE14  ; Goes to TIMER1 initialization code

    LDI R16, 0x00
    LDI R20, 0x00        ; Stores the last character read in the protocol
    LDI R21, 0x00        ; Stores the servo number
    LDI R22, 0x00        ; Stores the sign
    LDI R23, 0x00        ; Stores the first digit of the angle
    LDI R24, 0x00        ; Stores the second digit of the angle
	LDI R25, 0x00        ; Stores the angle (8-bit)
	LDI R26, 0x00        ; Stores the high part of count (16-bit)
	LDI R27, 0x00        ; Stores the low part of count (16-bit)

READ_PROTOCOL:
    CALL USART_RECEIVE       ; Reads a character from the keyboard to R16

    CPI  R16, 0x00           ; Avoids reading no characters
    BREQ READ_PROTOCOL       ;
	
    CPI  R20, 0x00           ; Reads the first letter S
    BREQ READ_S              ;

    CPI  R20, S_ASCII        ; Reads the servo number after the S letter
    BREQ READ_SERVO_NUMBER   ;

    CPI  R16, PLUS_ASCII     ; Saves the plus sign into R22
    BREQ READ_SIGN           ;

    CPI  R16, MINUS_ASCII    ; Saves the minus sign into R22
    BREQ READ_SIGN           ;

    CPI  R20, PLUS_ASCII     ; Reads the first digit of the angle after a plus sign
    BREQ READ_ANGLE_DIGIT_1  ;

    CPI  R20, MINUS_ASCII    ; Reads the first digit of the angle after a minus sign
    BREQ READ_ANGLE_DIGIT_1  ;

    CPI  R16, ENTER_ASCII    ; Reads the second digit of the angle after sign
    BREQ STORE_AND_TRANSMIT  ;

    JMP  READ_ANGLE_DIGIT_2  ; Reads the second digit of the angle

STORE_AND_TRANSMIT:
    MOV  R20, R16            ; Saves the current character into R20
    CALL USART_TRANSMIT      ; Prints the last character and clears R16

    JMP  READ_PROTOCOL       ; Waits enter key to finish

RUN_PROTOCOL:
    LDI R28, 0x0a
    CALL GET_COUNT  ; correct

	CPI  R21, 0
	BREQ CHANGE_SERVO_0

	CPI  R21, 1
	BREQ CHANGE_SERVO_1

	CPI  R21, 2
	BREQ CHANGE_SERVO_2

READ_S:    
    JMP STORE_AND_TRANSMIT

READ_SERVO_NUMBER:
    MOV  R21, R16
	SUBI R21, 0x30 ; Subtracts zero ASCII code to obtain the number
    JMP  STORE_AND_TRANSMIT

READ_SIGN:
    MOV  R22, R16
    JMP  STORE_AND_TRANSMIT

READ_ANGLE_DIGIT_1:
    MOV  R23, R16
	SUBI R23, 0x30 ; Subtracts zero ASCII code to obtain the digit
    JMP  STORE_AND_TRANSMIT

READ_ANGLE_DIGIT_2:
    MOV  R24, R16
	SUBI R24, 0x30  ; Subtracts zero ASCII code to obtain the digit
    LDI  R20, 0x00
    CALL USART_TRANSMIT
    LDI  R16, 0x0D
    CALL USART_TRANSMIT
    JMP  RUN_PROTOCOL

GET_COUNT:
    PUSH R16     ; Saves R16 into stack

    ADD R25, R24 ; Sums the unit angle digit to R25
	
    LDI R16, 10  ; Gets the tens of the angle 
    MUL R23, R16 ;
	ADD R25, R0  ;

    ;MOV R29, R25  ; debug, R25 is correct

    CPI  R22, PLUS_ASCII ; Branch if the angle is positive
	BREQ GET_PLUS_COUNT  ;

	CPI  R22, MINUS_ASCII ; Branch if the angle is negative
	BREQ GET_MINUS_COUNT  ;

GET_PLUS_COUNT:
	LDI R26, HIGH(DEFAULT_COUNT)
	LDI R27, LOW(DEFAULT_COUNT)
    JMP MULTIPLY_11

GET_MINUS_COUNT:
    LDI R26, HIGH(MIN_COUNT)
	LDI R27, LOW(MIN_COUNT)

MULTIPLY_11:
    LDI R16, 11
	ADD R27, R16
	LDI R16, 0
	ADC R26, R16

	DEC R25

	CPI  R25, 0
	BRNE MULTIPLY_11

	POP R16 ; Restores R16
	RET

CHANGE_SERVO_0:
    STS OCR1CH, R26
    STS OCR1CL, R27
	JMP READ_PROTOCOL

CHANGE_SERVO_1:
    STS OCR1BH, R26
	STS OCR1BL, R27
	JMP READ_PROTOCOL

CHANGE_SERVO_2:
    STS OCR1AH, R26
	STS OCR1AL, R27
	JMP READ_PROTOCOL

;*********************************************************************
;  Subroutine USART_INIT  
;  Setup for USART: asynch mode, 57600 bps, 1 stop bit, no parity
;  Used registers:
;     - UBRR0 (USART0 Baud Rate Register)
;     - UCSR0 (USART0 Control Status Register B)
;     - UCSR0 (USART0 Control Status Register C)
;*********************************************************************	
USART_INIT:
    LDI	R17, HIGH(BAUD_RATE_57600)   ; Sets the baud rate
    STS	UBRR0H, R17                  ;
    LDI	R16, LOW(BAUD_RATE_57600)    ;
    STS	UBRR0L, R16                  ;
    LDI	R16, (1<<RXEN0)|(1<<TXEN0)   ; Enables RX and TX

    STS	UCSR0B, R16
    LDI	R16, (0<<USBS0)|(3<<UCSZ00)  ; Frame: 8 data bits, 1 stop bit
    STS	UCSR0C, R16                  ; No parity bit
    RET

;*********************************************************************
;  Subroutine USART_TRANSMIT  
;  Transmits (TX) R16 and clears it
;*********************************************************************
USART_TRANSMIT:
    PUSH R17              ; Saves R17 into stack

WAIT_TRANSMIT:
    LDS  R17, UCSR0A
    SBRS R17, UDRE0       ; Waits for TX buffer to get empty
    RJMP WAIT_TRANSMIT
    STS	 UDR0, R16        ; Writes data into the buffer
    ANDI R16, 0x00        ; Clears R16 to avoid multiple transmits

    POP	R17               ; Restores R17
    RET

;*********************************************************************
;  Subroutine USART_RECEIVE
;  Receives the char from USART and places it in the register R16 
;*********************************************************************
USART_RECEIVE:
    PUSH R17               ; Saves R17 into stack

    LDS	 R17, UCSR0A
    SBRC R17, RXC0
    LDS  R16, UDR0         ; Reads the data

    POP	 R17               ; Restores R17
    RET

;*********************************************************************
;  Subroutine PORTB_INIT
;  Sets PB5, PB6, and PB7 as outputs
;*********************************************************************
PORTB_INIT:
    LDI R16, 0b11100000
    OUT DDRB, R16
    RET

;*********************************
; TIMER1_INIT_MODE14             *
;                                *
;*********************************
TIMER1_INIT_MODE14:
; ICR1 = 40000
    LDI R16, HIGH(PERIOD_COUNT)
    STS ICR1H, R16
    LDI R16, LOW(PERIOD_COUNT)
    STS ICR1L, R16

; OCR1A, OCR1B, OCR1C = 3000
    LDI R16, DEFAULT_COUNT>>8
    STS OCR1AH, R16
    STS OCR1BH, R16
    STS OCR1CH, R16
    LDI R16, DEFAULT_COUNT & 0xFF
    STS OCR1AL, R16
    STS OCR1BL, R16
    STS OCR1CL, R16

; Mode 14: (WGM13, WGM12, WGM11, WGM10)=(1,1,1,0)
; Clear on match, set at bottom: (COM1A1,COM1A0)=(1,0) (COM1B1,COM1B0)=(1,0) (COM1C1,COM1C0)=(1,0)
    LDI R16, (1<<COM1A1) | (0<<COM1A0) | (1<<COM1B1) | (0<<COM1B0) | (1<<COM1C1) | (0<<COM1C0) | (1<<WGM11) | (0<<WGM10)
    STS TCCR1A, R16

; Mode 14: (WGM13, WGM12, WGM11, WGM10)=(1,1,1,0)
; Clock select: (CS12,CS11,CS10)=(0,1,0), PRESCALER/8
; No input capture: (0<<ICNC1) | (0<<ICES1)
    LDI R16, (0<<ICNC1) | (0<<ICES1) | (1<<WGM13) | (1<<WGM12) | (0<<CS12) |(1<<CS11) | (0<<CS10)
    STS TCCR1B, R16

; Timer/Counter 1 Interrupt(s) initialization
; No interrupt is needed to generate PWM
    LDI R16, (0<<ICIE1) | (0<<OCIE1C) | (0<<OCIE1B) | (0<<OCIE1A) | (0<<TOIE1)
    STS TIMSK1, R16
    RET

   .EXIT