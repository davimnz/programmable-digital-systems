;*********************************************************************
;*********************************************************************
;**   forward-reverse-counter.asm                                   **
;**                                                                 **
;**   Target uC: Atmel ATmega328P                                   **
;**   X-TAL frequency: 16 MHz                                       **
;**   AVRASM: AVR macro assembler 2.1.57							**
;**			  (build 16 Aug 27 2014 16:39:43)						**
;**                                                                 **
;**  Created: 2021/08/20 by Davi Muniz Vasconcelos                  **
;*********************************************************************
;*********************************************************************

   .EQU BAUD_RATE_57600 = 16  ; Constant for baud rate
   .EQU ASCII_D = 68  ; D letter in ASCII code
   .EQU ASCII_I = 73  ; I letter in ASCII code
   .EQU MIN_COUNTER_VALUE = 0 ; Minimum counter value
   .EQU MAX_COUNTER_VALUE = 15 ; Maximum counter value

   .CSEG			; FLASH segment code
   .ORG 0			; entry point after POWER/RESET
	JMP RESET

   .ORG 0x100

RESET:
	LDI R16, LOW(0x8FF) ; Sets Stack Pointer to RAMEND
	OUT SPL, R16
	LDI R16, HIGH(0x8FF)
	OUT SPH, R16
	
	CALL USART_INIT  ; Goes to USART initialization code
	CALL PORTD_INIT  ; Goes to PORTD initialization code

	LDI  ZH, HIGH(2*MSG_INC)  ; Prints a message that has increase mode instruction
	LDI  ZL, LOW(2*MSG_INC)
	CALL SEND_MSG

	LDI  ZH, HIGH(2*MSG_DEC)  ; Prints a message that has decrease mode instruction
	LDI  ZL, LOW(2*MSG_DEC)
	CALL SEND_MSG

	LDI R18,0x00  ; Set counter decrease mode to zero
	STS DECREASE_MODE, R18

	LDI ZH, HIGH(2*MSG_DEFAULT_MODE)  ; Prints a message that specifies the default counter mode
	LDI ZL, LOW(2*MSG_DEFAULT_MODE)
	CALL SEND_MSG

READ_TO_GO:                       ; Waits for open switch to start couting
	IN   R16, PIND                ;
    ANDI R16, 0b00000100          ;
    BREQ READ_TO_GO               ;

MAIN_LOOP:
	CALL USART_RECEIVE ; Receives counter mode instruction given by terminal

	IN	 R19, PIND
	SBRS R19, 2
	CALL WAIT_SWITCH_RELEASE

	JMP  MAIN_LOOP

;*********************************************************************
;  Subroutine WAIT_SWITCH_RELEASE
;*********************************************************************
WAIT_SWITCH_RELEASE:
	IN   R19, PIND
	ANDI R19, 0b00000100
	BREQ WAIT_SWITCH_RELEASE

UPDATE_COUNTER:
	CALL USART_TRANSMIT
	; CPI  DECREASE_MODE, 0x00
	; CALL INC_COUNTER

	; CPI  DECREASE_MODE, 0x01
	; CALL DEC_COUNTER 
	RET

;*********************************************************************
;  Subroutine INC_COUNTER
;*********************************************************************

;*********************************************************************
;  Subroutine SET_COUNTER_MODE
;*********************************************************************
SET_COUNTER_MODE:
	CPI  R16, ASCII_D
	BREQ SET_COUNTER_DEC_MODE

	CPI  R16, ASCII_I
	BREQ SET_COUNTER_INC_MODE
	RET

;*********************************************************************
;  Subroutine SET_COUNTER_INC_MODE
;*********************************************************************
SET_COUNTER_INC_MODE:
	LDI  R18, 0x00 ; 0x00 flag indicates increase mode
	STS  DECREASE_MODE, R18

	LDI  ZH, HIGH(2*MSG_INC_CONFIRMATION) ; Prints confirmation message of increase mode
	LDI  ZL, LOW(2*MSG_INC_CONFIRMATION)
	CALL SEND_MSG
	RET

;*********************************************************************
;  Subroutine SET_COUNTER_DEC_MODE
;*********************************************************************
SET_COUNTER_DEC_MODE:
	LDI  R18, 0x01 ; 0x01 flag indicates decrease mode
	STS  DECREASE_MODE, R18

	LDI  ZH, HIGH(2*MSG_DEC_CONFIRMATION) ; Prints confirmation message of decrease mode
	LDI  ZL, LOW(2*MSG_DEC_CONFIRMATION)
	CALL SEND_MSG
	RET

;*********************************************************************
;  Subroutine PORTD_INIT
;  Configures input/output of PORTD
;*********************************************************************
PORTD_INIT:
	LDI R18, 0b11110000 ; Set D7-D4 to output and D3-D0 to input
	OUT DDRD, R18
	
	LDI R18, 0x00 ; Set counter value to zero
	OUT PORTD, R18
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
	STS	UBRR0H, R17
	LDI	R16, LOW(BAUD_RATE_57600)
	STS	UBRR0L, R16
	LDI	R16, (1<<RXEN0)|(1<<TXEN0)   ; Enables RX and TX

	STS	UCSR0B, R16
	LDI	R16, (0<<USBS0)|(3<<UCSZ00)  ; Frame: 8 data bits, 1 stop bit
	STS	UCSR0C, R16					 ; No parity bit
	RET

;*********************************************************************
;  Subroutine USART_TRANSMIT  
;  Transmits (TX) R16   
;*********************************************************************
USART_TRANSMIT:
	PUSH R17                     ; Saves R17 into stack

WAIT_TRANSMIT:
	LDS  R17, UCSR0A
	SBRS R17, UDRE0		         ; Waits for TX buffer to get empty
	RJMP WAIT_TRANSMIT
	STS	 UDR0, R16	             ; Writes data into the buffer

	POP	R17                      ; Restores R17
	RET

;*********************************************************************
;  Subroutine USART_RECEIVE
;  Receives the char from USART and places it in the register R16 
;*********************************************************************
USART_RECEIVE:
	PUSH	R17                 ; Saves R17 into stack

	LDS	 R17, UCSR0A
	SBRC R17, RXC0
	LDS  R16, UDR0		        ; Reads the data

	POP	R17                     ; Restores R17
	RET

;*********************************************************************
;  Subroutine SEND_MSG
;  Sends a message pointed by register Z in the FLASH memory
;*********************************************************************
SEND_MSG:
	PUSH R16

SEND_MSG_LOOP:
	LPM  R16, Z+
    CPI  R16, '$'
    BREQ END_SEND_MSG
    CALL USART_TRANSMIT
    JMP  SEND_MSG_LOOP

END_SEND_MSG:
	POP	R16
	RET

;*********************************************************************
;  Hard coded messages
;*********************************************************************
MSG_INC:
	.DB ":: Press I for increasing the counter", 0x0A, 0x0D, '$'
MSG_DEC:
	.DB ":: Press D for decreasing the counter", 0x0A, 0x0D, '$'
MSG_DEFAULT_MODE:
	.DB ":: Counter set to increase as default", 0x0A, 0x0D, '$'
MSG_INC_CONFIRMATION:
	.DB ":: Counter mode set to increase", 0x0A, 0x0D, '$'
MSG_DEC_CONFIRMATION:
	.DB ":: Counter mode set to decrease", 0x0A, 0x0D, '$'

;*********************************************************************
; Data segment (RAM)
;*********************************************************************
.DSEG
	.ORG 0x200

DECREASE_MODE:
	.BYTE 1

	.EXIT