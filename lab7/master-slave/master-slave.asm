/*
 * master_slave.asm
 *
 *  Created: 15/10/2021 22:07:11
 *   Author: DAVI MUNIZ
 */

   .EQU BAUD_RATE_57600 = 16   ; constant for 57600 baud rate

   .EQU ENTER_KEY = 0x0a       ; enter ASCII code
   .EQU S_KEY = 83             ; S ASCII code
   .EQU L_KEY = 76             ; L ASCII code
   .EQU PLUS_KEY = 43          ; plus sign ASCII code
   .EQU MINUS_KEY = 45         ; minus sign ASCII code
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
	
	LDI R23, 0x00     ; stores number of characters in a line of master's terminal

    CALL INIT_PORTF   ; sets F0 as output
    CALL INIT_PORTL   ; sets L7 as input
	CALL USART0_INIT
	CALL USART1_INIT

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
	BREQ MASTER_END_WRITING

    CALL USART0_RECEIVE
    CALL USART0_TRANSMIT
	CALL USART1_TRANSMIT
	
	INC  R23
    JMP  MASTER_LOOP

MASTER_END_WRITING:
    LDI  R23, 0x00

	LDI  R16, 0x0A         ; line feed, carriage return in usart 0
	CALL USART0_TRANSMIT   ;
	LDI  R16, 0x0D         ;
	CALL USART0_TRANSMIT   ;

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
    LDI  ZH, HIGH(2*MSG_SLAVE)  ; sends slave identification message to terminal
	LDI  ZL, LOW(2*MSG_SLAVE)   ;
	CALL SEND_MSG_USART0        ;

SLAVE_READ_FIRST:               
    CALL USART1_RECEIVE         ; reads first character sent by master
	MOV  R18, R16               ; r18 stores first letter of protocol

	CPI  R18, S_KEY             ; verifies if first letter is "S"
	BREQ SLAVE_READ_SERVO       ; goes to servo protocol reading

	CPI  R18, L_KEY             ; verifies if first letter is "L"
	BREQ SLAVE_READ_LED         ; goes to led protocol reading

	JMP  SLAVE_UNSUCCESS_1   ; if component letter not valid

SLAVE_READ_SERVO:
    CALL USART1_RECEIVE       ; reads character sent by master to r16 
	MOV  R19, R16             ; r19 stores servo number

	CPI  R19, 0x30            ; verifies if servo number is zero
	BREQ SLAVE_READ_SIGNAL    ;

	CPI  R19, 0x31            ; verifies if servo number is one
	BREQ SLAVE_READ_SIGNAL    ; 

	CPI  R19, 0x32            ; verifies if servo number is two
	BREQ SLAVE_READ_SIGNAL    ;

	JMP  SLAVE_UNSUCCESS_2    ; if servo number not valid

SLAVE_READ_SIGNAL:
	CALL USART1_RECEIVE                  ; reads character sent by master to r16
	MOV  R20, R16                        ; r20 stores the sign

	CPI  R20, PLUS_KEY                   ; verifies if sign is +
	BREQ SLAVE_READ_ANGLE_FIRST_DIGIT    ;

	CPI  R20, MINUS_KEY                  ; verifies if sign is -
	BREQ SLAVE_READ_ANGLE_FIRST_DIGIT    ;

	JMP  SLAVE_UNSUCCESS_3               ; if sign is not valid

SLAVE_READ_ANGLE_FIRST_DIGIT:
    CALL USART1_RECEIVE   ; reads character sent by master to r16
	MOV  R21, R16

	CALL FIRST_DIGIT_IS_DIGIT

	MOV  R24, R21         ; r24 stores the first digit of angle
	SUBI R24, 0x30        ; subtracts zero ASCII code to get digit

SLAVE_READ_ANGLE_SECOND_DIGIT:
    CALL USART1_RECEIVE   ; reads character sent by master to r16
	MOV  R22, R16

	CALL SECOND_DIGIT_IS_DIGIT

	MOV  R25, R22         ; r25 stores the second digit of angle
	SUBI R25, 0x30        ; subtracts zero ASCII code to get digit
	JMP  SLAVE_SUCCESS

SLAVE_READ_LED:
    JMP SLAVE_READ_LED

SLAVE_UNSUCCESS_1:
    CALL USART1_RECEIVE
	MOV  R19, R16

SLAVE_UNSUCCESS_2:
    CALL USART1_RECEIVE
	MOV  R20, R16

SLAVE_UNSUCCESS_3:
    CALL USART1_RECEIVE
	MOV  R21, R16

SLAVE_UNSUCCESS_4:
    CALL USART1_RECEIVE
	MOV  R22, R16

SLAVE_UNSUCCESS:
    LDI  R16, 0xff
	CALL USART1_TRANSMIT
	CALL SLAVE_SEND_RECEIVED_MSG
	JMP SLAVE_READ_FIRST

SLAVE_SUCCESS:
	LDI  R16, ACK_CODE             ; sends ack code to master
	CALL USART1_TRANSMIT           ;

    CALL SLAVE_SEND_RECEIVED_MSG   ; sends master message to usart 0

	JMP  SLAVE_READ_FIRST          ; goes back to read another input

SLAVE_SEND_RECEIVED_MSG:
    MOV  R16, R18
	CALL USART0_TRANSMIT

	MOV  R16, R19
	CALL USART0_TRANSMIT

	MOV  R16, R20
	CALL USART0_TRANSMIT

	MOV  R16, R21
	CALL USART0_TRANSMIT

	MOV  R16, R22
	CALL USART0_TRANSMIT

	LDI  R16, 0x0A
	CALL USART0_TRANSMIT
	LDI  R16, 0X0D
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

    JMP  SLAVE_UNSUCCESS   ; goes to unsuccess protocol reading

DIGIT_TRUE: ; returns to the next step of protocol reading
    RET     ; 

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