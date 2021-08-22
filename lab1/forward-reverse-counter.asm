;*********************************************************************
;*********************************************************************
;**   forward-reverse-counter.asm                                   **
;**                                                                 **
;**   Target uC: Atmel ATmega328P                                   **
;**   X-TAL frequency: 16 MHz                                       **
;**   AVRASM: AVR macro assembler 2.1.57                            **
;**           (build 16 Aug 27 2014 16:39:43)                       **
;**                                                                 **
;**  Created: 2021/08/20 by Davi Muniz Vasconcelos                  **
;*********************************************************************
;*********************************************************************

   .EQU BAUD_RATE_57600 = 16      ; Constant for baud rate
   .EQU ASCII_D = 68              ; D letter in ASCII code
   .EQU ASCII_I = 73              ; I letter in ASCII code
   .EQU MIN_COUNTER_VALUE = 0x00  ; Minimum counter value
   .EQU MAX_COUNTER_VALUE = 0x0F  ; Maximum counter value

   .CSEG		; FLASH segment code
   .ORG 0		; entry point after POWER/RESET
    JMP RESET

   .ORG 0x100

RESET:
	IN   R16, PINC          ; Waits reset switch to be released
	ANDI R16, 0b01000000    ;
	BREQ RESET              ;

    LDI R16, LOW(0x8FF)	    ; Sets Stack Pointer to RAMEND
    OUT SPL, R16            ;
    LDI R16, HIGH(0x8FF)    ;
    OUT SPH, R16            ;
	
    CALL USART_INIT  ; Goes to USART initialization code
    CALL PORTD_INIT  ; Goes to PORTD initialization code

    LDI  ZH, HIGH(2*MSG_INC)  ; Prints increase mode instruction
    LDI  ZL, LOW(2*MSG_INC)
    CALL SEND_MSG

    LDI  ZH, HIGH(2*MSG_DEC)  ; Prints decrease mode instruction
    LDI  ZL, LOW(2*MSG_DEC)
    CALL SEND_MSG

    LDI R20, 0x00  ; R20 stores the current counter value
    LDI R21, 0x00  ; R21 stores the current counter mode (increase 0x00, decrease 0x01)
	
    LDI ZH, HIGH(2*MSG_DEFAULT_MODE)  ; Prints a message that specifies the default counter mode (increase)
    LDI ZL, LOW(2*MSG_DEFAULT_MODE)
    CALL SEND_MSG

READ_TO_GO:                   ; Waits for open switch to start couting
    IN   R16, PIND            ;
    ANDI R16, 0b00000100      ;
    BREQ READ_TO_GO           ;

CHECK_TERM:
    CALL USART_RECEIVE        ; Receives counter mode instruction given by terminal
    CALL SET_COUNTER_MODE     ; Changes counter mode if the user request

CHECK_PIN_STATE:
    IN	 R19, PIND            ; Verifies if D2 is active
    SBRS R19, 2               ;
    CALL WAIT_SWITCH_RELEASE  ;

    JMP  CHECK_TERM           ; Main loop

;*********************************************************************
;  Subroutine WAIT_SWITCH_RELEASE
;  Waits the switch to be released
;*********************************************************************
WAIT_SWITCH_RELEASE:
    IN   R19, PIND
    ANDI R19, 0b00000100	  
    BREQ WAIT_SWITCH_RELEASE

UPDATE_COUNTER:         ; Updates counter after switch is released.
						; R21 stores the current mode. 0x00 means increase, and 0x01 means decrease.
    SBRS R21, 0         ; Skips next instruction if bit 0 is 1
    CALL INC_COUNTER    ; Increases the count

    SBRC R21, 0         ; Skips next instruction if bit 0 is 0
    CALL DEC_COUNTER    ; Decreases the count
    RET

;*********************************************************************
;  Subroutine INC_COUNTER
;  Increases the counter value by one
;  Sets the count in the valid range, if necessary
;*********************************************************************
INC_COUNTER:
    PUSH R17                       ; Saves R17 into stack

    LDI  R17, MAX_COUNTER_VALUE    ; Loads 15 into R17
    INC  R20                       ; Increases the current count
    CP   R17, R20                  ; Compares current value and max value
    BRCS SET_COUNTER_TO_MIN_VALUE  ; Sets counter to zero if count > 15
	
    CALL SET_PORTD                 ; Sets PORTD to R20

    POP  R17                       ; Restores R17
    RET                            ; Returns to UPDATE_COUNTER

SET_COUNTER_TO_MIN_VALUE:          ; Sets count to zero
    LDI  R20, MIN_COUNTER_VALUE    ;
    CALL SET_PORTD                 ;

    POP  R17                       ; Restores R17
    RET                            ; Returns to UPDATE_COUNTER

;*********************************************************************
;  Subroutine DEC_COUNTER
;  Decreases the counter value by one
;  Sets the count in the valid range, if necessary
;*********************************************************************
DEC_COUNTER:
    PUSH R17                       ; Saves R17 into stack

    LDI  R17, MIN_COUNTER_VALUE    ; Loads zero into R17
    CPSE R17, R20                  ; Compares zero and current count
    JMP  DEC_REG                   ; Decreases R20 if current count is not zero

    LDI  R20, MAX_COUNTER_VALUE    ; Loads 15 into R20 if current count is zero
    CALL SET_PORTD                 ; Sets PORTD to R20

    POP  R17                       ; Restores R17
    RET                            ; Returns to UPDATE_COUNTER

DEC_REG:
    DEC  R20                       ; Decreases current count R20
    CALL SET_PORTD                 ; Sets PORTD to R20

    POP R17                        ; Restores R17
    RET                            ; Returns to UPDATE_COUNTER

;*********************************************************************
;  Subroutine SET_PORTD
;  Updates the value of PORTD
;  R20 stores the count
;*********************************************************************
SET_PORTD:
    SWAP R20           ; R20 needs swap because D7-D4 is being used
    OUT  PORTD, R20
    SWAP R20           ; Restores R20 in order to use inc/dec operations
    RET                

;*********************************************************************
;  Subroutine SET_COUNTER_MODE
;  Updates the counter mode for a given key
;  The current mode only switches if the new mode is different from the current
;  R16 stores the latest pressed key
;  R21 stores the current counter mode
;*********************************************************************
SET_COUNTER_MODE:
    CPI  R16, ASCII_D            ; Verifies if D key was pressed
    BREQ PRESS_D                 ;

    CPI  R16, ASCII_I            ; Verifies if I key was pressed
    BREQ PRESS_I                 ;
    RET

PRESS_D:                         ; Verifies if decrease mode was active
    CPI  R21, 0x01
    BRNE SET_COUNTER_DEC_MODE    ; Switches mode if decrease mode was not active
    RET

PRESS_I:                         ; Verifies if increase mode was active
    CPI  R21, 0x00
    BRNE SET_COUNTER_INC_MODE    ; Switches mode if increase mode was not active
    RET

;*********************************************************************
;  Subroutine SET_COUNTER_INC_MODE
;  Sets the counter mode to increase
;  R21 stores the current counter mode
;*********************************************************************
SET_COUNTER_INC_MODE:
    LDI  R21, 0x00                        ; 0x00 flag means increase mode

    LDI  ZH, HIGH(2*MSG_INC_CONFIRMATION) ; Prints confirmation message of increase mode
    LDI  ZL, LOW(2*MSG_INC_CONFIRMATION)  ;
    CALL SEND_MSG                         ;
	
    JMP CHECK_PIN_STATE                   ; Returns to main loop

;*********************************************************************
;  Subroutine SET_COUNTER_DEC_MODE
;  Sets the counter mode to decrease
;  R21 stores the current counter mode
;*********************************************************************
SET_COUNTER_DEC_MODE:
    LDI  R21, 0x01                        ; 0x01 flag means decrease mode

    LDI  ZH, HIGH(2*MSG_DEC_CONFIRMATION) ; Prints confirmation message of decrease mode
    LDI  ZL, LOW(2*MSG_DEC_CONFIRMATION)  ;
    CALL SEND_MSG                         ;
	
    JMP CHECK_PIN_STATE                   ; Returns to main loop

;*********************************************************************
;  Subroutine PORTD_INIT
;  Configures input/output of PORTD
;*********************************************************************
PORTD_INIT:
    LDI R18, 0b11110000 ; Set D7-D4 to output and D3-D0 to input
    OUT DDRD, R18
	
    LDI R18, 0x00       ; Set counter value to zero
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
    STS	UCSR0C, R16                  ; No parity bit
    RET

;*********************************************************************
;  Subroutine USART_TRANSMIT  
;  Transmits (TX) R16   
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

    LDS	 R17, UCSR0A
    SBRC R17, RXC0
    LDS  R16, UDR0         ; Reads the data

    POP	 R17               ; Restores R17
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

    .EXIT
