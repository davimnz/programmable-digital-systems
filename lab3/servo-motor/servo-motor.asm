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
   
   .EQU PERIOD_COUNT = 40000 ; Time constant for 20ms
   .EQU MIN_COUNT = 2000     ; Time constant for 1ms

   .CSEG                     ; FLASH segment code
   .ORG 0                    ; Entry point after POWER/RESET
    JMP RESET

   .ORG 0x100

RESET:
    LDI R16, LOW(0x8FF)	     ; Sets Stack Pointer to RAMEND
    OUT SPL, R16             ;
    LDI R16, HIGH(0x8FF)     ;
    OUT SPH, R16             ;

    CALL USART_INIT          ; Goes to USART initialization code

	LDI R16, 0x00
	LDI R20, 0x00        ; Stores the last character read in the protocol
	LDI R21, 0x00        ; Stores the servo number
	LDI R22, 0x00        ; Stores the sign
	LDI R23, 0x00        ; Stores the first digit of the angle
	LDI R24, 0x00        ; Stores the second digit of the angle

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
    JMP RUN_PROTOCOL

READ_S:    
    JMP STORE_AND_TRANSMIT

READ_SERVO_NUMBER:
    MOV  R21, R16
    JMP STORE_AND_TRANSMIT

READ_SIGN:
    MOV  R22, R16
    JMP STORE_AND_TRANSMIT

READ_ANGLE_DIGIT_1:
    MOV R23, R16
    JMP STORE_AND_TRANSMIT

READ_ANGLE_DIGIT_2:
    MOV  R24, R16
    LDI  R20, 0x00
    CALL USART_TRANSMIT
    LDI  R16, 0x0D
    CALL USART_TRANSMIT
    JMP RUN_PROTOCOL

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

    .EXIT