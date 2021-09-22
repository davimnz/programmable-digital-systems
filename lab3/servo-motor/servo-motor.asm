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
   
   .EQU PERIOD_COUNT = 40000 ; Time constant for 20ms
   .EQU DEFAULT_COUNT = 2999 ; Default count constant for 0 degrees

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

    LDI R16, 0x00 ; General use register
    LDI R21, 0x00 ; Stores the servo number
    LDI R22, 0x00 ; Stores the sign
    LDI R23, 0x00 ; Stores the first digit of the angle
    LDI R24, 0x00 ; Stores the second digit of the angle
    LDI R25, 0x00 ; Stores the angle (8-bit)
    LDI R26, 0x00 ; Stores the high part of count (16-bit)
    LDI R27, 0x00 ; Stores the low part of count (16-bit)

READ_PROTOCOL:          ; The main reading loop
    CALL USART_RECEIVE  ; Saves the keyboard character in R16
    CALL USART_TRANSMIT ; Prints the character in R16
	
    CPI  R16, S_ASCII      ; Goes to the next char if the first char is "S" 
    BREQ READ_SERVO_NUMBER ;

END_READING:
    LDI  R16, 0x0D       ; Ends a unsuccessful protocol reading
    CALL USART_TRANSMIT  ;
    JMP  READ_PROTOCOL   ;

READ_SERVO_NUMBER:          ; Reads the second character of the protocol
    CALL USART_RECEIVE      ; Saves the keyboard character in R16
    CALL USART_TRANSMIT     ; Prints the R16 character

    CPI  R16, 0x30          ; Verifies if the servo number is zero
    BREQ STORE_SERVO_NUMBER ;

    CPI  R16, 0x31          ; Verifies if the servo number is one
    BREQ STORE_SERVO_NUMBER ;

    CPI  R16, 0x32          ; Verifies if the servo number is two
    BREQ STORE_SERVO_NUMBER ;

    JMP  END_READING ; Ends reading if R16 does not have a valid number: 0, 1, or 2

STORE_SERVO_NUMBER:
    MOV  R21, R16  ; Stores the servo number in R21
    SUBI R21, 0x30 ; Subtracts zero ASCII code to get the number

READ_SIGN:                ; Reads the third character of the protocol
    CALL USART_RECEIVE    ; Saves the keyboard character in R16
    CALL USART_TRANSMIT   ; Prints the R16 character

    CPI  R16, PLUS_ASCII  ; Verifies if the sign is '+'
    BREQ STORE_SIGN       ;

    CPI  R16, MINUS_ASCII ; Verifies if the sign is '-'
    BREQ STORE_SIGN       ;

    JMP  END_READING      ; Ends reading if R16 does not have a valid sign: + or -

STORE_SIGN:
    MOV R22, R16 ; Stores the sign in R22

READ_ANGLE_FIRST_DIGIT:  ; Reads the fourth character of the protocol
    CALL USART_RECEIVE   ; Saves the keyboard character in R16
    CALL USART_TRANSMIT  ; Prints the R16 character

    CALL IS_DIGIT ; Verifies if R16 is a digit

    MOV  R23, R16  ; If R16 is a digit, then copies it to R23
    SUBI R23, 0x30 ; Subtracts zero ASCII code to get the number

READ_ANGLE_SECOND_DIGIT:  ; Reads the fifth character of the protocol
    CALL USART_RECEIVE    ; Saves the keyboard character in R16
    CALL USART_TRANSMIT   ; Prints the R16 character

    CALL IS_DIGIT ; Verifies if R16 is a digit

    MOV  R24, R16  ; If R16 is a digit, then copies it to R24
    SUBI R24, 0x30 ; Subtracts zero ASCII code to get the number

    LDI  R16, 0x0D      ; Prints a new line
    CALL USART_TRANSMIT ;
    JMP  RUN_PROTOCOL   ; Runs the valid protocol input

;********************************************************************
; Subroutine IS_DIGIT                                              **
; Verifies if the fourth or fifth protocol character is a digit    **
; If the character is a digit, returns to the next protocol step   **
; Otherwise, restarts the protocol reading                         **
;********************************************************************
IS_DIGIT:
    CPI  R16, 0x30   ; Verifies if R16 is '0'
    BREQ DIGIT_TRUE  ;

    CPI  R16, 0x31   ; Verifies if R16 is '1'
    BREQ DIGIT_TRUE  ;

    CPI  R16, 0x32   ; Verifies if R16 is '2'
    BREQ DIGIT_TRUE  ;

    CPI  R16, 0x33   ; Verifies if R16 is '3'
    BREQ DIGIT_TRUE  ;

    CPI  R16, 0x34   ; Verifies if R16 is '4'
    BREQ DIGIT_TRUE  ;

    CPI  R16, 0x35   ; Verifies if R16 is '5'
    BREQ DIGIT_TRUE  ;

    CPI  R16, 0x36   ; Verifies if R16 is '6'
    BREQ DIGIT_TRUE  ;

    CPI  R16, 0x37   ; Verifies if R16 is '7'
    BREQ DIGIT_TRUE  ;

    CPI  R16, 0x38   ; Verifies if R16 is '8'
    BREQ DIGIT_TRUE  ;

    CPI  R16, 0x39   ; Verifies if R16 is '9'
    BREQ DIGIT_TRUE  ;

    JMP  END_READING ; Finishes the protocol reading if R16 is not a digit

DIGIT_TRUE: ; Returns to the next step of protocol reading
    RET     ; 

;***********************************************************************************
; Subroutine RUN_PROTOCOL                                                         **             
; Runs a valid protocol input                                                     **
;***********************************************************************************
RUN_PROTOCOL:            ; Runs a valid protocol input
    CALL GET_COUNT       ; Evaluates the count for the given angle

    CPI  R21, 0          ; If the servo number is 0, then changes the OCR1 of servo 0  
    BREQ CHANGE_SERVO_0  ;

    CPI  R21, 1          ; If the servo number is 1, then changes the OCR1 of servo 1
    BREQ CHANGE_SERVO_1  ;

    CPI  R21, 2          ; If the servo number is 2, then changes the OCR1 of servo 2
    BREQ CHANGE_SERVO_2  ;

CHANGE_SERVO_0:       ; Changes the OCR1 value of servo 0
    STS OCR1CH, R26   ;
    STS OCR1CL, R27   ;
    JMP READ_PROTOCOL ; Starts a new protocol reading

CHANGE_SERVO_1:       ; Changes the OCR1 value of servo 1
    STS OCR1BH, R26   ;
    STS OCR1BL, R27   ;
    JMP READ_PROTOCOL ; Starts a new protocol reading

CHANGE_SERVO_2:       ; Changes the OCR1 value of servo 2
    STS OCR1AH, R26   ;
    STS OCR1AL, R27   ;
    JMP READ_PROTOCOL ; Starts a new protocol reading

;************************************************************
; Subroutine GET_COUNT                                     **
; Gets the timer count (OCR1) for a given angle             **
;************************************************************
GET_COUNT:
    PUSH R16     ; Saves R16 into stack

    ADD R25, R24 ; Sums the unit angle digit to R25
	
    LDI R16, 10  ; Gets the tens of the angle 
    MUL R23, R16 ;
    ADD R25, R0  ;

    CPI  R22, PLUS_ASCII  ; Branch if the angle is positive
    BREQ GET_PLUS_COUNT   ;

    CPI  R22, MINUS_ASCII ; Branch if the angle is negative
    BREQ GET_MINUS_COUNT  ;

;************************************************************
; Subroutine GET_PLUS_COUNT                                **
; Gets the timer count (OCR1) for a positive angle         **
;************************************************************
GET_PLUS_COUNT:                   ; Gets the count for a plus sign angle 
    LDI R26, HIGH(DEFAULT_COUNT)  ;
    LDI R27, LOW(DEFAULT_COUNT)   ;

    CPI  R25, 0                   ; Does not evaluate the count if the angle is zero
    BREQ RETURN_PLUS_MULTIPLY_11  ;

PLUS_MULTIPLY_11:          ; Iteratively multiplies by 11 the given angle and adds to DEFAULT_COUNT, since the integer part of (4000 - 2000) / 180 is 11
    LDI R16, 11            ;
    ADD R27, R16           ; Adds 11 to the low part of the count
    LDI R16, 0             ;
    ADC R26, R16           ; Adds a carry to the high part of the count, if any

    DEC R25                ; Decreases the given angle

    CPI  R25, 0            ; Repeats until the given angle is zero
    BRNE PLUS_MULTIPLY_11  ;

    MOV R16, R23           ; Loads the angle first digit into R16
    INC R16                ;
    ADD R27, R16           ; Sums additional value in the low part of the count to reduce angle error
    LDI R16, 0             ; 
    ADC R26, R16           ; Adds a carry in the high part of the count, if any 

RETURN_PLUS_MULTIPLY_11:   ; Finishes the evaluation of the count for a given positive angle 
    POP R16                ; Restores R16
    RET

;************************************************************
; Subroutine GET_MINUS_COUNT                               **
; Gets the timer count (OCR1) for a negative angle         **
;************************************************************
GET_MINUS_COUNT:                  ; Gets the count for a minus sign angle
    LDI R26, HIGH(DEFAULT_COUNT)  ;
    LDI R27, LOW(DEFAULT_COUNT)   ;

    CPI  R25, 0                   ; Does not evaluate the count if the angle is zero
    BREQ RETURN_MINUS_MULTIPLY_11 ;

MINUS_MULTIPLY_11:         ; Iteratively multiplies by 11 the given angle and subtracts of DEFAULT_COUNT, since the integer part of (4000 - 2000) / 180 is 11
    LDI R16, 11            ;
    SUB R27, R16           ; Subtracts 11 of the count low part
    LDI R16, 0             ;
    SBC R26, R16           ; Subtracts a carry of the count high part, if any

    DEC R25                ; Decreases the given angle

    CPI  R25, 0            ; Repeats until the given angle is zero
    BRNE MINUS_MULTIPLY_11 ;

    SUB  R27, R23          ; Subtracts the angle first digit of the count low part to reduce angle error
    LDI  R16, 0            ; 
    SBC  R26, R16          ; Subtracts a carry of the count high part, if any
    SUBI R27, 1            ; Subtracts 1 of the count low part to reduce angle error
    SBC  R26, R16          ; Subtracts a carry of the count high part, if any

RETURN_MINUS_MULTIPLY_11:  ; Finishes the evaluation of the count for a given negative angle
    POP R16                ; Restores R16
    RET

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

    POP	R17               ; Restores R17
    RET

;*********************************************************************
;  Subroutine USART_RECEIVE
;  Receives the char from USART and places it in the register R16 
;*********************************************************************
USART_RECEIVE:
    PUSH R17               ; Saves R17 into stack

WAIT_RECEIVE:
    LDS	 R17, UCSR0A
    SBRS R17, RXC0
    RJMP WAIT_RECEIVE      ; Waits data
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

;**************************************
; Subroutine TIMER1_INIT_MODE14      **
; Initializes timer 1 in mode 14     **
; ICR = 40000 (20ms)                 **
; 0CR1A = 2999 (0 degrees)           **
; OCR1B = 2999 (0 degrees)           **
; OCR1C = 2999 (0 degrees)           **
; PRESCALER/8                        **
;**************************************
TIMER1_INIT_MODE14:
; ICR1 = 40000
    LDI R16, HIGH(PERIOD_COUNT)
    STS ICR1H, R16
    LDI R16, LOW(PERIOD_COUNT)
    STS ICR1L, R16

; OCR1A, OCR1B, OCR1C = 2999
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