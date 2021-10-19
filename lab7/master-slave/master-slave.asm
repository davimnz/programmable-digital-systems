/*
 * master_slave.asm
 *
 *  Created: 15/10/2021 22:07:11
 *   Author: DAVI MUNIZ
 */

   .EQU BAUD_RATE_57600 = 16   ; constant for 57600 baud rate

   .EQU ENTER_KEY = 0x0d       ; enter ASCII code
   .EQU S_KEY = 83             ; S ASCII code
   .EQU L_KEY = 76             ; L ASCII code
   .EQU PLUS_KEY = 43          ; plus sign ASCII code
   .EQU MINUS_KEY = 45         ; minus sign ASCII code
   .EQU O_KEY = 79             ; O ASCII code
   .EQU N_KEY = 78             ; N ASCII code
   .EQU F_KEY = 70             ; F ASCII code

   .EQU PERIOD_COUNT = 40000   ; time constant for 20ms
   .EQU DEFAULT_COUNT = 2999   ; default count constant for zero degrees

   .EQU ACK_CODE = 0           ; ack code sent by slave to master

   .CSEG
   .ORG  0
    JMP  RESET

   .ORG  0x100

RESET:
    LDI R16, HIGH(RAMEND)   ; sets stack pointer to RAMEND
    OUT SPH, R16            ;
    LDI R16, LOW(RAMEND)    ;
    OUT SPL, R16            ;

	LDI R16, 0x00     ; stores character received by usart
	LDI R17, 0x00     ; stores variables in usart subroutines

	LDI R18, 0x00     ; stores first protocol character
	LDI R19, 0x00     ; stores second protocol character
	LDI R20, 0x00     ; stores third protocol character
	LDI R21, 0x00     ; stores fourth protocol character
	LDI R22, 0x00     ; stores fifth protocol character
	LDI R24, 0x00     ; stores angle first digit
	LDI R25, 0x00     ; stores angle second digit

	LDI R26, 0x00     ; stores the high part of count (16-bit)
	LDI R27, 0x00     ; stores the low part of count (16-bit)
	LDI R28, 0x00     ; stores the angle (8-bit)
	
	LDI R23, 0x00     ; stores number of characters in a line of master's terminal

    CALL INIT_PORTF   ; sets F0 as output
    CALL INIT_PORTL   ; sets L7 as input
	CALL INIT_PORTH   ; sets H0, H1 as output
	CALL USART0_INIT  ; initializes usart 0 (terminal)
	CALL USART1_INIT  ; initializes usart 1 (master - slave communication)

GET_TYPE:
    LDS  R16, PINL
    SBRC R16, 7
    JMP  MASTER
	JMP  SLAVE

MASTER:
    LDI R16, 0b00000001
    OUT PORTF, R16

    LDI  ZH, HIGH(2*MSG_MASTER)
	LDI  ZL, LOW(2*MSG_MASTER)
	CALL SEND_MSG_USART0
	
MASTER_LOOP:
	CPI  R23, 5
	BREQ MASTER_WAIT_ENTER

    CALL USART0_RECEIVE
    CALL USART0_TRANSMIT
	CALL USART1_TRANSMIT

	INC  R23
    CPI  R16, ENTER_KEY
	BREQ MASTER_END_WRITING
	JMP  MASTER_LOOP

MASTER_WAIT_ENTER:
    CALL USART0_RECEIVE
	CPI  R16, ENTER_KEY
	BREQ MASTER_SEND_ENTER
	JMP  MASTER_WAIT_ENTER

MASTER_SEND_ENTER:
    CALL USART0_TRANSMIT
	CALL USART1_TRANSMIT

MASTER_END_WRITING:
    ;CALL USART0_TRANSMIT
	;CALL USART1_TRANSMIT
    LDI  R23, 0x00

	CALL USART1_RECEIVE    ; receives character from slave and stores it in r16
	CPI  R16, ACK_CODE
	BREQ MASTER_ACK
	JMP  MASTER_INVALID

MASTER_ACK:
    LDI  ZH, HIGH(2*MSG_ACK)
	LDI  ZL, LOW(2*MSG_ACK)
	CALL SEND_MSG_USART0
	JMP  MASTER_LOOP

MASTER_INVALID:
    LDI  ZH, HIGH(2*MSG_INVALID)
	LDI  ZL, LOW(2*MSG_INVALID)
	CALL SEND_MSG_USART0
	JMP  MASTER_LOOP

SLAVE:
    CALL TIMER1_INIT_MODE14
    CALL INIT_PORTB
	LDI  ZH, HIGH(2*MSG_SLAVE)  ; sends slave identification message to terminal
	LDI  ZL, LOW(2*MSG_SLAVE)   ;
	CALL SEND_MSG_USART0        ;

SLAVE_INIT_REGISTERS:
    LDI R18, 0xff
	LDI R19, 0xff
	LDI R20, 0xff
	LDI R21, 0xff
	LDI R22, 0xff

SLAVE_READ_FIRST:               
    CALL USART1_RECEIVE         ; reads first character sent by master
	MOV  R18, R16               ; r18 stores first letter of protocol

	CPI  R18, ENTER_KEY
	BREQ SLAVE_UNSUCCESS_JMP

	CPI  R18, S_KEY             ; verifies if first letter is "S"
	BREQ SLAVE_READ_SERVO       ; goes to servo protocol reading

	CPI  R18, L_KEY             ; verifies if first letter is "L"
	BREQ SLAVE_READ_LED         ; goes to led protocol reading

	JMP  SLAVE_UNSUCCESS_1      ; if component letter not valid

SLAVE_READ_SERVO:
    CALL USART1_RECEIVE         ; reads character sent by master to r16 
	MOV  R19, R16               ; r19 stores servo number

	CPI  R19, ENTER_KEY
	BREQ SLAVE_UNSUCCESS_JMP

	CPI  R19, 0x30              ; verifies if servo number is zero
	BREQ SLAVE_READ_SIGNAL      ;

	CPI  R19, 0x31              ; verifies if servo number is one
	BREQ SLAVE_READ_SIGNAL      ; 

	CPI  R19, 0x32              ; verifies if servo number is two
	BREQ SLAVE_READ_SIGNAL      ;

	JMP  SLAVE_UNSUCCESS_2      ; if servo number not valid

SLAVE_READ_SIGNAL:
	CALL USART1_RECEIVE         ; reads character sent by master to r16
	MOV  R20, R16               ; r20 stores the sign

	CPI  R20, ENTER_KEY
	BREQ SLAVE_UNSUCCESS_JMP

	CPI  R20, PLUS_KEY          ; verifies if sign is +
	BREQ SLAVE_READ_ANGLE_FIRST_DIGIT    ;

	CPI  R20, MINUS_KEY                  ; verifies if sign is -
	BREQ SLAVE_READ_ANGLE_FIRST_DIGIT    ;

	JMP  SLAVE_UNSUCCESS_3               ; if sign is not valid

SLAVE_READ_ANGLE_FIRST_DIGIT:
    CALL USART1_RECEIVE   ; reads character sent by master to r16
	MOV  R21, R16

	CPI  R21, ENTER_KEY
	BREQ SLAVE_UNSUCCESS_JMP

	CALL FIRST_DIGIT_IS_DIGIT

	MOV  R24, R21         ; r24 stores the first digit of angle
	SUBI R24, 0x30        ; subtracts zero ASCII code to get digit

SLAVE_READ_ANGLE_SECOND_DIGIT:
    CALL USART1_RECEIVE   ; reads character sent by master to r16
	MOV  R22, R16

	CPI  R22, ENTER_KEY
	BREQ SLAVE_UNSUCCESS_JMP

	CALL SECOND_DIGIT_IS_DIGIT

	MOV  R25, R22         ; r25 stores the second digit of angle
	SUBI R25, 0x30        ; subtracts zero ASCII code to get digit
	JMP  SLAVE_SUCCESS_READ_ENTER

SLAVE_UNSUCCESS_JMP:
    JMP SLAVE_UNSUCCESS

SLAVE_READ_LED:
    CALL USART1_RECEIVE
	MOV  R19, R16

	CPI  R19, ENTER_KEY
	BREQ SLAVE_UNSUCCESS_JMP

	CPI  R19, 0x30
	BREQ SLAVE_READ_LED_STATUS_1

	CPI  R19, 0x31
	BREQ SLAVE_READ_LED_STATUS_1

    JMP SLAVE_UNSUCCESS_2

SLAVE_READ_LED_STATUS_1:
    CALL USART1_RECEIVE
    MOV  R20, R16

	CPI  R20, ENTER_KEY
	BREQ SLAVE_UNSUCCESS_JMP

    CPI  R20, O_KEY
    BREQ SLAVE_READ_LED_STATUS_2

    JMP  SLAVE_UNSUCCESS_3

SLAVE_READ_LED_STATUS_2:
    CALL USART1_RECEIVE
    MOV  R21, R16

	CPI  R21, ENTER_KEY
	BREQ SLAVE_UNSUCCESS_JMP

    CPI  R21, F_KEY
    BREQ SLAVE_READ_LED_STATUS_OFF

    CPI  R21, N_KEY
    BREQ SLAVE_READ_LED_STATUS_ON

	JMP  SLAVE_UNSUCCESS_4

SLAVE_READ_LED_STATUS_OFF:
    CALL USART1_RECEIVE
	MOV  R22, R16

	CPI  R22, ENTER_KEY
	BREQ SLAVE_UNSUCCESS_JMP

	CPI  R22, F_KEY
	BREQ SLAVE_SUCCESS_READ_ENTER

	JMP  SLAVE_UNSUCCESS_READ_ENTER

SLAVE_READ_LED_STATUS_ON:
    CALL USART1_RECEIVE
	MOV  R22, R16

	CPI  R22, ENTER_KEY
	BREQ SLAVE_UNSUCCESS_JMP

	CPI  R22, N_KEY
	BREQ SLAVE_SUCCESS_READ_ENTER

	JMP  SLAVE_UNSUCCESS_READ_ENTER

SLAVE_SUCCESS_READ_ENTER:
    CALL USART1_RECEIVE
	CPI  R16, ENTER_KEY
	BREQ SLAVE_SUCCESS
	JMP  SLAVE_SUCCESS_READ_ENTER

SLAVE_SUCCESS:
	LDI  R16, ACK_CODE             ; sends ack code to master
	CALL USART1_TRANSMIT           ;

    CALL SLAVE_SEND_RECEIVED_MSG   ; sends master message to usart 0

	CPI  R18, L_KEY
	BREQ SLAVE_SUCCESS_LED
	
	CPI  R18, S_KEY
	BREQ SLAVE_SUCCESS_SERVO  

	JMP  SLAVE_INIT_REGISTERS          ; goes back to read another input

SLAVE_SUCCESS_LED:
    CPI  R19, 0x30
	BREQ SLAVE_CHANGE_LED_0

	CPI  R19, 0x31
	BREQ SLAVE_CHANGE_LED_1

SLAVE_CHANGE_LED_0:
    CPI  R22, F_KEY
	BREQ SLAVE_LED_0_OFF

	CPI  R22, N_KEY
	BREQ SLAVE_LED_0_ON

SLAVE_LED_0_OFF:
    LDS R16, PORTH
	LDI R17, 0b11111110
	AND R16, R17
	STS PORTH, R16
	JMP SLAVE_INIT_REGISTERS

SLAVE_LED_0_ON:
    LDS R16, PORTH
	LDI R17, 0b00000001
	OR  R16, R17
    STS PORTH, R16
	JMP SLAVE_INIT_REGISTERS

SLAVE_CHANGE_LED_1:
    CPI  R22, F_KEY
	BREQ SLAVE_LED_1_OFF

	CPI  R22, N_KEY
	BREQ SLAVE_LED_1_ON

SLAVE_LED_1_OFF:
    LDS R16, PORTH
	LDI R17, 0b11111101
	AND R16, R17
	STS PORTH, R16
	JMP SLAVE_INIT_REGISTERS

SLAVE_LED_1_ON:
    LDS R16, PORTH
	LDI R17, 0b00000010
	OR  R16, R17
    STS PORTH, R16
	JMP SLAVE_INIT_REGISTERS

SLAVE_SUCCESS_SERVO:
    CALL SLAVE_GET_COUNT       ; evaluates the count for the given angle

    CPI  R19, 0x30             ; if the servo number is 0, then changes the OCR1 of servo 0  
    BREQ SLAVE_CHANGE_SERVO_0  ;

    CPI  R19, 0x31             ; if the servo number is 1, then changes the OCR1 of servo 1
    BREQ SLAVE_CHANGE_SERVO_1  ;

    CPI  R19, 0x32             ; if the servo number is 2, then changes the OCR1 of servo 2
    BREQ SLAVE_CHANGE_SERVO_2  ;

SLAVE_CHANGE_SERVO_0:          ; changes the OCR1 value of servo 0
    STS OCR1AH, R26            ;
    STS OCR1AL, R27            ;
    JMP SLAVE_INIT_REGISTERS   ; starts a new protocol reading

SLAVE_CHANGE_SERVO_1:          ; changes the OCR1 value of servo 1
    STS OCR1BH, R26            ;
    STS OCR1BL, R27            ;
    JMP SLAVE_INIT_REGISTERS   ; starts a new protocol reading

SLAVE_CHANGE_SERVO_2:          ; changes the OCR1 value of servo 2
    STS OCR1CH, R26            ;
    STS OCR1CL, R27            ;
    JMP SLAVE_INIT_REGISTERS   ; starts a new protocol reading

;************************************************************
; Subroutine GET_COUNT                                     **
; Gets the timer count (OCR1) for a given angle             **
;************************************************************
SLAVE_GET_COUNT:
    PUSH R16     ; Saves R16 into stack

    ADD R28, R25 ; Sums the unit angle digit to R25
	
    LDI R16, 10  ; Gets the tens of the angle 
    MUL R24, R16 ;
    ADD R28, R0  ;

    CPI  R20, PLUS_KEY         ; Branch if the angle is positive
    BREQ SLAVE_GET_PLUS_COUNT  ;

    CPI  R20, MINUS_KEY        ; Branch if the angle is negative
    BREQ SLAVE_GET_MINUS_COUNT ;

;************************************************************
; Subroutine GET_PLUS_COUNT                                **
; Gets the timer count (OCR1) for a positive angle         **
;************************************************************
SLAVE_GET_PLUS_COUNT:             ; Gets the count for a plus sign angle 
    LDI R26, HIGH(DEFAULT_COUNT)  ;
    LDI R27, LOW(DEFAULT_COUNT)   ;

    CPI  R28, 0                         ; Does not evaluate the count if the angle is zero
    BREQ SLAVE_RETURN_PLUS_MULTIPLY_11  ;

SLAVE_PLUS_MULTIPLY_11:          ; Iteratively multiplies by 11 the given angle and adds to DEFAULT_COUNT, since the integer part of (4000 - 2000) / 180 is 11
    LDI R16, 11                  ;
    ADD R27, R16                 ; Adds 11 to the low part of the count
    LDI R16, 0                   ;
    ADC R26, R16                 ; Adds a carry to the high part of the count, if any

    DEC R28                     ; Decreases the given angle

    CPI  R28, 0                 ; Repeats until the given angle is zero
    BRNE SLAVE_PLUS_MULTIPLY_11 ;

    MOV R16, R24           ; Loads the angle first digit into R16
    INC R16                ;
    ADD R27, R16           ; Sums additional value in the low part of the count to reduce angle error
    LDI R16, 0             ; 
    ADC R26, R16           ; Adds a carry in the high part of the count, if any 

SLAVE_RETURN_PLUS_MULTIPLY_11:  ; Finishes the evaluation of the count for a given positive angle 
    POP R16                     ; Restores R16
    RET

;************************************************************
; Subroutine GET_MINUS_COUNT                               **
; Gets the timer count (OCR1) for a negative angle         **
;************************************************************
SLAVE_GET_MINUS_COUNT:            ; Gets the count for a minus sign angle
    LDI R26, HIGH(DEFAULT_COUNT)  ;
    LDI R27, LOW(DEFAULT_COUNT)   ;

    CPI  R28, 0                         ; Does not evaluate the count if the angle is zero
    BREQ SLAVE_RETURN_MINUS_MULTIPLY_11 ;

SLAVE_MINUS_MULTIPLY_11:   ; Iteratively multiplies by 11 the given angle and subtracts of DEFAULT_COUNT, since the integer part of (4000 - 2000) / 180 is 11
    LDI R16, 11            ;
    SUB R27, R16           ; Subtracts 11 of the count low part
    LDI R16, 0             ;
    SBC R26, R16           ; Subtracts a carry of the count high part, if any

    DEC R28                ; Decreases the given angle

    CPI  R28, 0                  ; Repeats until the given angle is zero
    BRNE SLAVE_MINUS_MULTIPLY_11 ;

    SUB  R27, R24          ; Subtracts the angle first digit of the count low part to reduce angle error
    LDI  R16, 0            ; 
    SBC  R26, R16          ; Subtracts a carry of the count high part, if any
    SUBI R27, 1            ; Subtracts 1 of the count low part to reduce angle error
    SBC  R26, R16          ; Subtracts a carry of the count high part, if any

SLAVE_RETURN_MINUS_MULTIPLY_11:  ; Finishes the evaluation of the count for a given negative angle
    POP R16                      ; Restores R16
    RET

SLAVE_UNSUCCESS_1:
    CALL USART1_RECEIVE
	MOV  R19, R16

	CPI  R19, ENTER_KEY
	BREQ SLAVE_UNSUCCESS

SLAVE_UNSUCCESS_2:
    CALL USART1_RECEIVE
	MOV  R20, R16

	CPI  R20, ENTER_KEY
	BREQ SLAVE_UNSUCCESS

SLAVE_UNSUCCESS_3:
    CALL USART1_RECEIVE
	MOV  R21, R16

	CPI  R21, ENTER_KEY
	BREQ SLAVE_UNSUCCESS

SLAVE_UNSUCCESS_4:
    CALL USART1_RECEIVE
	MOV  R22, R16

	CPI  R22, ENTER_KEY
	BREQ SLAVE_UNSUCCESS

SLAVE_UNSUCCESS_READ_ENTER:
    CALL USART1_RECEIVE
	CPI  R16, ENTER_KEY
	BREQ SLAVE_UNSUCCESS
	JMP  SLAVE_UNSUCCESS_READ_ENTER

SLAVE_UNSUCCESS:
    LDI  R16, 0xff
	CALL USART1_TRANSMIT
	CALL SLAVE_SEND_RECEIVED_MSG
	JMP  SLAVE_INIT_REGISTERS

SLAVE_SEND_RECEIVED_MSG:
    MOV  R16, R18
	CPI  R16, 0xff
	BREQ SLAVE_SEND_LF_CR
	CPI  R16, ENTER_KEY
	BREQ SLAVE_SEND_LF_CR
	CALL USART0_TRANSMIT

	MOV  R16, R19
	CPI  R16, 0xff
	BREQ SLAVE_SEND_LF_CR
	CPI  R16, ENTER_KEY
	BREQ SLAVE_SEND_LF_CR
	CALL USART0_TRANSMIT

	MOV  R16, R20
	CPI  R16, 0xff
	BREQ SLAVE_SEND_LF_CR
	CPI  R16, ENTER_KEY
	BREQ SLAVE_SEND_LF_CR
	CALL USART0_TRANSMIT

	MOV  R16, R21
	CPI  R16, 0xff
	BREQ SLAVE_SEND_LF_CR
	CPI  R16, ENTER_KEY
	BREQ SLAVE_SEND_LF_CR
	CALL USART0_TRANSMIT

	MOV  R16, R22
	CPI  R16, 0xff
	BREQ SLAVE_SEND_LF_CR
	CPI  R16, ENTER_KEY
	BREQ SLAVE_SEND_LF_CR
	CALL USART0_TRANSMIT

SLAVE_SEND_LF_CR:
	LDI  R16, 0x0a
	CALL USART0_TRANSMIT
	LDI  R16, 0X0d
	CALL USART0_TRANSMIT
	RET

FIRST_DIGIT_IS_DIGIT:
    CPI  R16, 0x30         ; verifies if r16 is '0'
    BREQ DIGIT_TRUE        ;

    CPI  R16, 0x31         ; verifies if r16 is '1'
    BREQ DIGIT_TRUE        ;

    CPI  R16, 0x32         ; verifies if r16 is '2'
    BREQ DIGIT_TRUE        ;

    CPI  R16, 0x33         ; verifies if r16 is '3'
    BREQ DIGIT_TRUE        ;

    CPI  R16, 0x34         ; verifies if r16 is '4'
    BREQ DIGIT_TRUE        ;

    CPI  R16, 0x35         ; verifies if r16 is '5'
    BREQ DIGIT_TRUE        ;

    CPI  R16, 0x36         ; verifies if r16 is '6'
    BREQ DIGIT_TRUE        ;

    CPI  R16, 0x37         ; verifies if r16 is '7'
    BREQ DIGIT_TRUE        ;

    CPI  R16, 0x38         ; verifies if r16 is '8'
    BREQ DIGIT_TRUE        ;

    CPI  R16, 0x39         ; verifies if r16 is '9'
    BREQ DIGIT_TRUE        ;

    JMP  SLAVE_UNSUCCESS_4 ; goes to unsuccess 4 protocol reading

SECOND_DIGIT_IS_DIGIT:
    CPI  R16, 0x30         ; verifies if r16 is '0'
    BREQ DIGIT_TRUE        ;

    CPI  R16, 0x31         ; verifies if r16 is '1'
    BREQ DIGIT_TRUE        ;

    CPI  R16, 0x32         ; verifies if r16 is '2'
    BREQ DIGIT_TRUE        ;

    CPI  R16, 0x33         ; verifies if r16 is '3'
    BREQ DIGIT_TRUE        ;

    CPI  R16, 0x34         ; verifies if r16 is '4'
    BREQ DIGIT_TRUE        ;

    CPI  R16, 0x35         ; verifies if r16 is '5'
    BREQ DIGIT_TRUE        ;

    CPI  R16, 0x36         ; verifies if r16 is '6'
    BREQ DIGIT_TRUE        ;

    CPI  R16, 0x37         ; verifies if r16 is '7'
    BREQ DIGIT_TRUE        ;

    CPI  R16, 0x38         ; verifies if r16 is '8'
    BREQ DIGIT_TRUE        ;

    CPI  R16, 0x39         ; verifies if r16 is '9'
    BREQ DIGIT_TRUE        ;

    JMP  SLAVE_UNSUCCESS_READ_ENTER ; goes to unsuccess protocol reading

DIGIT_TRUE: ; returns to the next step of protocol reading
    RET     ; 

;*********************************************************************
;  Subroutine INIT_PORTB
;  Sets PB5, PB6, and PB7 as outputs
;*********************************************************************
INIT_PORTB:
    LDI R16, 0b11100000
    OUT DDRB, R16
    RET

;*********************************************************************
;  Subroutine INIT_PORTF
;  Sets PF0 as output and PL1-7 as input
;*********************************************************************
INIT_PORTF:
    LDI R16, 0b00000001
    OUT DDRF, R16
	RET

;*********************************************************************
;  Subroutine INIT_PORTF
;  Sets PL0-7 as input
;*********************************************************************
INIT_PORTL:
    LDI R16, 0b00000000
    STS DDRL, R16
	RET

;*********************************************************************
;  Subroutine INIT_PORTH
;  Sets PH0, PH1 as input and PH2-7 as output 
;*********************************************************************
INIT_PORTH:
    LDI R16, 0b00000011
	STS DDRH, R16
	RET

;*********************************************************************
;  Subroutine USART1_INIT  
;  Setup for USART1: asynch mode, 57600 bps, 1 stop bit, no parity
;  Used registers:
;     - UBRR1 (USART1 Baud Rate Register)
;     - UCSR1 (USART1 Control Status Register B)
;     - UCSR1 (USART1 Control Status Register C)
;*********************************************************************	
USART1_INIT:
    LDI	R17, HIGH(BAUD_RATE_57600)   ; Sets the baud rate
    STS	UBRR1H, R17                  ;
    LDI	R16, LOW(BAUD_RATE_57600)    ;
    STS	UBRR1L, R16                  ;
    LDI	R16, (1<<RXEN1)|(1<<TXEN1)   ; Enables RX and TX

    STS	UCSR1B, R16
    LDI	R16, (0<<USBS1)|(3<<UCSZ01)  ; Frame: 8 data bits, 1 stop bit
    STS	UCSR1C, R16                  ; No parity bit
    RET

;*********************************************************************
;  Subroutine USART1_TRANSMIT  
;  Transmits (TX) R16 and clears it
;*********************************************************************
USART1_TRANSMIT:
    PUSH R17                    ; Saves R17 into stack

USART1_WAIT_TRANSMIT:
    LDS  R17, UCSR1A
    SBRS R17, UDRE1             ; Waits for TX buffer to get empty
    RJMP USART1_WAIT_TRANSMIT
    STS	 UDR1, R16              ; Writes data into the buffer

    POP	 R17                    ; Restores R17
    RET

;*********************************************************************
;  Subroutine USART1_RECEIVE
;  Receives the char from USART1 and places it in the register R16 
;*********************************************************************
USART1_RECEIVE:
    PUSH R17                   ; Saves R17 into stack

USART1_WAIT_RECEIVE:
    LDS	 R17, UCSR1A
    SBRS R17, RXC1
    RJMP USART1_WAIT_RECEIVE   ; Waits data
    LDS  R16, UDR1             ; Reads the data

    POP	 R17                   ; Restores R17
    RET

;*********************************************************************
;  Subroutine USART0_INIT  
;  Setup for USART0: asynch mode, 57600 bps, 1 stop bit, no parity
;  Used registers:
;     - UBRR0 (USART0 Baud Rate Register)
;     - UCSR0 (USART0 Control Status Register B)
;     - UCSR0 (USART0 Control Status Register C)
;*********************************************************************	
USART0_INIT:
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
;  Subroutine USART0_TRANSMIT  
;  Transmits (TX) R16 and clears it
;*********************************************************************
USART0_TRANSMIT:
    PUSH R17              ; Saves R17 into stack

WAIT_TRANSMIT:
    LDS  R17, UCSR0A
    SBRS R17, UDRE0       ; Waits for TX buffer to get empty
    RJMP WAIT_TRANSMIT
    STS	 UDR0, R16        ; Writes data into the buffer

    POP	 R17              ; Restores R17
    RET

;*********************************************************************
;  Subroutine USART0_RECEIVE
;  Receives the char from USART and places it in the register R16 
;*********************************************************************
USART0_RECEIVE:
    PUSH R17               ; Saves R17 into stack

WAIT_RECEIVE:
    LDS	 R17, UCSR0A
    SBRS R17, RXC0
    RJMP WAIT_RECEIVE      ; Waits data
    LDS  R16, UDR0         ; Reads the data

    POP	 R17               ; Restores R17
    RET

;*********************************************************************
;  Subroutine SEND_MSG_USART0
;  Sends a message pointed by register Z in the FLASH memory
;*********************************************************************
SEND_MSG_USART0:
    PUSH R16

SEND_MSG_LOOP:
    LPM  R16, Z+
    CPI  R16, '$'
    BREQ END_SEND_MSG
    CALL USART0_TRANSMIT
    JMP  SEND_MSG_LOOP

END_SEND_MSG:
    POP	R16
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

;*********************************************************************
;  Hard coded messages
;*********************************************************************
MSG_MASTER:
   .DB "*** MASTER *** ", 0x0A, 0x0D, '$'
MSG_SLAVE:
   .DB "*** SLAVE ***", 0x0A, 0x0D, '$'
MSG_ACK:
   .DB "ACK", 0x0A, 0x0D, '$'
MSG_INVALID:
   .DB "INVALID", 0x0A, 0x0D, '$'
MSG_LF:
   .DB 0x0A, '$'

   .EXIT