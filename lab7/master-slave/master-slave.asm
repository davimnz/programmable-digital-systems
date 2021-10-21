;***********************************************************
;***********************************************************
;**  master-slave.asm                                     **
;**                                                       **
;**  Target uC: Atmel ATmega2560                          **
;**  X-TAL Frequency: 16MHz                               **
;**  AVRASM: AVR macro assembler 2.1.57                   ** 
;**          (build 16 Aug 27 2014 16:39:43)              **
;**                                                       **
;**  Created: 2021/10/16 Davi Muniz Vasconcelos           **
;***********************************************************
;***********************************************************

   .EQU BAUD_RATE_57600 = 16   ; constant for 57600 baud rate

   .EQU ENTER_KEY = 0x0d       ; enter ASCII code
   .EQU LF_KEY = 0x0a          ; line feed ASCII code 
   .EQU S_KEY = 83             ; S ASCII code
   .EQU L_KEY = 76             ; L ASCII code
   .EQU PLUS_KEY = 43          ; plus sign ASCII code
   .EQU MINUS_KEY = 45         ; minus sign ASCII code
   .EQU O_KEY = 79             ; O ASCII code
   .EQU N_KEY = 78             ; N ASCII code
   .EQU F_KEY = 70             ; F ASCII code

   .EQU PERIOD_COUNT = 40000   ; time constant for 20ms
   .EQU DEFAULT_COUNT = 2999   ; default count constant for zero degrees

   .EQU A_KEY = 65             ; A ASCII code
   .EQU C_KEY = 67             ; C ASCII code
   .EQU K_KEY = 75             ; K ASCII code

   .EQU I_KEY = 73             ; I ASCII code
   .EQU V_KEY = 86             ; V ASCII code
   .EQU D_KEY = 68             ; D ASCII code  

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
    CALL USART0_INIT  ; initializes usart 0 (terminal)
    CALL USART1_INIT  ; initializes usart 1 (master - slave communication)

GET_TYPE:             ; sets the microcontroller type - master or slave
    LDS  R16, PINL    ; reads PINL
    SBRC R16, 7       ; if L7 is clear, then type is slave. Goes to the SLAVE main function
    JMP  MASTER       ; if L7 is set, then type is master. Goes to the MASTER main function
    JMP  SLAVE        ;

MASTER:                           ; master's main function
    LDI R16, 0b00000001           ; sets F0 led on
    OUT PORTF, R16                ;

    LDI  ZH, HIGH(2*MSG_HASH)     ; sends hash of last commit
    LDI  ZL, LOW(2*MSG_HASH)      ;
    CALL SEND_MSG_USART0          ;
    LDI  ZH, HIGH(2*MSG_MASTER)   ; sends master identification message
    LDI  ZL, LOW(2*MSG_MASTER)    ;
    CALL SEND_MSG_USART0          ;
	
MASTER_LOOP:                      ; master main reading loop
    CPI  R23, 5                   ; verifies if five characters were written by user
    BREQ MASTER_WAIT_ENTER        ; if five characters were written, then waits the final enter key

    CALL USART0_RECEIVE           ; gets character from the user
    CALL USART0_TRANSMIT          ; sends user's character to terminal
    CALL USART1_TRANSMIT          ; sends user's character to slave

    INC  R23                      ; increase number of characters written by user 
    CPI  R16, ENTER_KEY           ; verifies if a enter key was written by user
    BREQ MASTER_END_WRITING       ; finishes the loop when user sends enter key
    JMP  MASTER_LOOP              ; repeats the loop until user hits enter key or writes five characters

MASTER_WAIT_ENTER:                ; waits enter key to finish a protocol with five characters
    CALL USART0_RECEIVE           ; gets character from the user
    CPI  R16, ENTER_KEY           ; verifies if a enter key was written by user 
    BREQ MASTER_SEND_ENTER        ; finishes protocol if r16 is enter key
    JMP  MASTER_WAIT_ENTER        ; repeats the loop until user hits enter key

MASTER_SEND_ENTER:                ; sends enter key to terminal and to slave if enter key was hitted after five characters input
    CALL USART0_TRANSMIT          ;
    CALL USART1_TRANSMIT          ;

MASTER_END_WRITING:               ; waits for slave confirmation of protocol sent by master
    LDI  R23, 0x00                ; resets number of characters written in usart 0

MASTER_READ_SLAVE_RESPONSE_LOOP:          ; reads the slave's response of protocol sent by master
    CALL USART1_RECEIVE                   ; reads a character from slave
    CPI  R16, LF_KEY                      ; finishes the reading if character sent is enter key
    BREQ MASTER_END                       ;
    CALL USART0_TRANSMIT                  ; sends character to master's terminal
    JMP  MASTER_READ_SLAVE_RESPONSE_LOOP  ; goes back to read another character

MASTER_END:
    LDI  R16, ENTER_KEY           ; sends enter key to master's terminal
    CALL USART0_TRANSMIT          ;
    JMP  MASTER_LOOP              ; goes back to read another user's input

SLAVE:                            ; slave's main function
    CALL TIMER1_INIT_MODE14       ; initializes timer
    CALL INIT_PORTB               ; sets B5, B6, B7 as output
    CALL INIT_PORTH               ; sets H0, H1 as output
    LDI  ZH, HIGH(2*MSG_HASH)     ; sends hash of last commit
    LDI  ZL, LOW(2*MSG_HASH)      ;
    CALL SEND_MSG_USART0          ;
    LDI  ZH, HIGH(2*MSG_SLAVE)    ; sends slave identification message to terminal
    LDI  ZL, LOW(2*MSG_SLAVE)     ;
    CALL SEND_MSG_USART0          ;

SLAVE_INIT_REGISTERS:             ; initializes registers to default value. 0xff means that register did not read any character
    LDI R18, 0xff                 ;
    LDI R19, 0xff                 ;
    LDI R20, 0xff                 ;
    LDI R21, 0xff                 ;
    LDI R22, 0xff                 ;

SLAVE_READ_FIRST:                 ; reads first character sent by master
    CALL USART1_RECEIVE           ;
    MOV  R18, R16                 ; r18 stores first character of protocol

    CPI  R18, ENTER_KEY           ; if character is enter key, then protocol is not valid
    BREQ SLAVE_UNSUCCESS_JMP      ; goes to unsuccessful protocol function

    CPI  R18, S_KEY               ; verifies if first letter is "S"
    BREQ SLAVE_READ_SERVO         ; goes to servo protocol reading

    CPI  R18, L_KEY               ; verifies if first letter is "L"
    BREQ SLAVE_READ_LED           ; goes to led protocol reading

    JMP  SLAVE_UNSUCCESS_1        ; if first letter is not valid

SLAVE_READ_SERVO:                 ; servo protocol reading. reads second character sent by master (servo number)
    CALL USART1_RECEIVE           ; 
    MOV  R19, R16                 ; r19 stores second character of servo protocol

    CPI  R19, ENTER_KEY           ; if second character is enter key, then protocol is not valid
    BREQ SLAVE_UNSUCCESS_JMP      ; goes to unsuccessful protocol function

    CPI  R19, 0x30                ; verifies if servo number is zero
    BREQ SLAVE_READ_SIGNAL        ; 

    CPI  R19, 0x31                ; verifies if servo number is one
    BREQ SLAVE_READ_SIGNAL        ; 

    CPI  R19, 0x32                ; verifies if servo number is two
    BREQ SLAVE_READ_SIGNAL        ;

    JMP  SLAVE_UNSUCCESS_2        ; if servo number is not valid

SLAVE_READ_SIGNAL:                ; reads third character sent by master (plus or minus sign)
    CALL USART1_RECEIVE           ;
    MOV  R20, R16                 ; r20 stores third character of servo protocol

    CPI  R20, ENTER_KEY           ; if third character is enter key, then protocol is not valid
    BREQ SLAVE_UNSUCCESS_JMP      ; goes to unsuccessful protocol function

    CPI  R20, PLUS_KEY                 ; verifies if sign is +
    BREQ SLAVE_READ_ANGLE_FIRST_DIGIT  ;

    CPI  R20, MINUS_KEY                ; verifies if sign is -
    BREQ SLAVE_READ_ANGLE_FIRST_DIGIT  ;

    JMP  SLAVE_UNSUCCESS_3             ; if sign is not valid

SLAVE_READ_ANGLE_FIRST_DIGIT:     ; reads fourth character sent by master (angle first digit)
    CALL USART1_RECEIVE           ;
    MOV  R21, R16                 ; r21 stores fourth character of servo protocol

    CPI  R21, ENTER_KEY           ; if fourth character is enter key, then protocol is not valid
    BREQ SLAVE_UNSUCCESS_JMP      ; goes to unsuccessful protocol function

    CALL FIRST_DIGIT_IS_DIGIT     ; verifies if fourth character is digit

    MOV  R24, R21                 ; r24 stores first digit of angle
    SUBI R24, 0x30                ; subtracts zero ASCII code to get digit

SLAVE_READ_ANGLE_SECOND_DIGIT:    ; reads fifth character sent by master (angle second digit)
    CALL USART1_RECEIVE           ;
    MOV  R22, R16                 ; r22 stores fifth character of servo protocol

    CPI  R22, ENTER_KEY           ; if fifth character is enter key, then protocol is not valid
    BREQ SLAVE_UNSUCCESS_JMP      ; goes to unsuccessful protocol function

    CALL SECOND_DIGIT_IS_DIGIT    ; verifies if fifth character is digit

    MOV  R25, R22                 ; r25 stores the second digit of angle
    SUBI R25, 0x30                ; subtracts zero ASCII code to get digit
    JMP  SLAVE_SUCCESS_READ_ENTER ; waits master's enter key to send message to master and execute protocol

SLAVE_UNSUCCESS_JMP:              ; auxiliary label to jump to unsuccessful protocol function
    JMP SLAVE_UNSUCCESS           ;

SLAVE_READ_LED:                   ; led protocol reading. reads second character sent by master (led number)
    CALL USART1_RECEIVE           ;
    MOV  R19, R16                 ; r19 stores second character of led protocol

    CPI  R19, ENTER_KEY           ; if second character is enter key, then protocol is not valid
    BREQ SLAVE_UNSUCCESS_JMP      ; goes to unsuccessful protocol function

    CPI  R19, 0x30                ; verifies if led number is zero
    BREQ SLAVE_READ_LED_STATUS_1  ; goes to read the first character of led status

    CPI  R19, 0x31                ; verifies if led number is one
    BREQ SLAVE_READ_LED_STATUS_1  ; goes to read the first character of led status

    JMP SLAVE_UNSUCCESS_2         ; if led number is not valid

SLAVE_READ_LED_STATUS_1:          ; reads the first letter of led status
    CALL USART1_RECEIVE           ;
    MOV  R20, R16                 ; r20 stores third character of led protocol

    CPI  R20, ENTER_KEY           ; if third character is enter key, then protocol is not valid
    BREQ SLAVE_UNSUCCESS_JMP      ; goes to unsuccessful protocol function 

    CPI  R20, O_KEY               ; verifies if first letter of led status if "O"
    BREQ SLAVE_READ_LED_STATUS_2  ; goes to read the second character of led status

    JMP  SLAVE_UNSUCCESS_3        ; if first letter of led status is not valid

SLAVE_READ_LED_STATUS_2:          ; reads the second letter of led status
    CALL USART1_RECEIVE           ;
    MOV  R21, R16                 ; r21 stores fourth character of led protocol

    CPI  R21, ENTER_KEY           ; if fourth character is enter key, then protocol is not valid
    BREQ SLAVE_UNSUCCESS_JMP      ; goes to unsuccessful protocol function

    CPI  R21, F_KEY                ; verifies if second letter of led status is "F"
    BREQ SLAVE_READ_LED_STATUS_OFF ; goes to read the third character of led status. this character must be "F" to be a valid protocol 

    CPI  R21, N_KEY                ; verifies if second letter of led status is "N"
    BREQ SLAVE_READ_LED_STATUS_ON  ; goes to read the third character of led status. this character must be "N" to be a valid protocol

    JMP  SLAVE_UNSUCCESS_4         ; if second letter of led status is not valid

SLAVE_READ_LED_STATUS_OFF:         ; reads the third letter of led status
    CALL USART1_RECEIVE            ;
    MOV  R22, R16                  ; r22 stores the fifth character of led protocol

    CPI  R22, ENTER_KEY            ; if fifth character is enter key, then protocol is not valid
    BREQ SLAVE_UNSUCCESS_JMP       ; goes to unsuccessful protocol function

    CPI  R22, F_KEY                ; verifies if third letter of led status is "F"
    BREQ SLAVE_SUCCESS_READ_ENTER  ; protocol is valid. waits for enter key to finish and execute the led protocol

    JMP  SLAVE_UNSUCCESS_READ_ENTER ; if third letter of led status is not valid

SLAVE_READ_LED_STATUS_ON:         ; reads the third letter of led status
    CALL USART1_RECEIVE           ;
    MOV  R22, R16                 ; r22 stores the fifth character of led protocol

    CPI  R22, ENTER_KEY           ; if fifth character is enter key, then protocol is not valid
    BREQ SLAVE_UNSUCCESS_JMP      ; goes to unsuccessful protocol function

    CPI  R22, N_KEY               ; verifies if third letter of led status is "N"
    BREQ SLAVE_SUCCESS_READ_ENTER ; protocol is valid. waits for enter key to finish and execute the led protocol

    JMP  SLAVE_UNSUCCESS_READ_ENTER ; if third letter of led status is not valid

SLAVE_SUCCESS_READ_ENTER:         ; slave waits for enter key to execute a valid protocol sent by master
    CALL USART1_RECEIVE           ; 
    CPI  R16, ENTER_KEY           ; if key sent by master is enter key, then execute protocol
    BREQ SLAVE_SUCCESS            ;
    JMP  SLAVE_SUCCESS_READ_ENTER ; loops until master sends a enter key

SLAVE_SUCCESS:                    ; executes a valid protocol and sends confirmation code to master
    LDI  R16, A_KEY               ; sends A to master
    CALL USART1_TRANSMIT          ;
    
    LDI  R16, C_KEY               ; sends C to master
    CALL USART1_TRANSMIT          ;
    
    LDI  R16, K_KEY               ; sends K to master
    CALL USART1_TRANSMIT          ;
    
    LDI  R16, LF_KEY              ; sends linefeed to master
    CALL USART1_TRANSMIT          ;
    
    CALL SLAVE_SEND_RECEIVED_MSG  ; sends master's protocol to slave's terminal

    CPI  R18, L_KEY               ; if first letter of valid protocol is "L", then execute led protocol
    BREQ SLAVE_SUCCESS_LED        ;
	
    CPI  R18, S_KEY               ; if first letter of valid protocol is "S", then execute servo protocol
    BREQ SLAVE_SUCCESS_SERVO      ;

    JMP  SLAVE_INIT_REGISTERS     ; goes back to read another input

SLAVE_SUCCESS_LED:                ; executes a valid led protocol
    CPI  R19, 0x30                ; if led number is zero, then change led zero status
    BREQ SLAVE_CHANGE_LED_0       ;

    CPI  R19, 0x31                ; if led number is one, then change led one status
    BREQ SLAVE_CHANGE_LED_1       ;

SLAVE_CHANGE_LED_0:               ; changes led zero status, given a valid protocol
    CPI  R22, F_KEY               ; if fifth protocol character is "F", then set led 0 off. since led protocol is valid, we can only verify fifth character 
    BREQ SLAVE_LED_0_OFF          ;

    CPI  R22, N_KEY               ; if fifth protocol character is "N", then set led 0 on. since led protocol is valid, we can only verify fifth character
    BREQ SLAVE_LED_0_ON           ;

SLAVE_LED_0_OFF:                  ; sets led 0 off
    LDS R16, PORTH                ; r16 stores porth value
    LDI R17, 0b11111110           ;
    AND R16, R17                  ; changes bit 0 of r16 to zero with a AND operation
    STS PORTH, R16                ; sends new port values to porth
    JMP SLAVE_INIT_REGISTERS      ; goes back to read another input

SLAVE_LED_0_ON:                   ; sets led 0 on
    LDS R16, PORTH                ; r16 stores porth value
    LDI R17, 0b00000001           ;
    OR  R16, R17                  ; changes bit 0 of r16 to one with a OR operation
    STS PORTH, R16                ; sends new port values to porth
    JMP SLAVE_INIT_REGISTERS      ; goes back to read another input

SLAVE_CHANGE_LED_1:               ; changes led one status, given a valid protocol
    CPI  R22, F_KEY               ; if fifth protocol character is "F", then set led 1 off. since led protocol is valid, we can only verify fifth character
    BREQ SLAVE_LED_1_OFF          ;

    CPI  R22, N_KEY               ; changes led one status, given a valid protocol
    BREQ SLAVE_LED_1_ON           ; if fifth protocol character is "N", then set led 1 on. since led protocol is valid, we can only verify fifth character

SLAVE_LED_1_OFF:                  ; sets led 1 off
    LDS R16, PORTH                ; r16 stores porth value
    LDI R17, 0b11111101           ;
    AND R16, R17                  ; changes bit 1 of r16 to zero with a AND operation
    STS PORTH, R16                ; sends new port values to porth
    JMP SLAVE_INIT_REGISTERS      ; goes back to read another input

SLAVE_LED_1_ON:                   ; sets led 1 on
    LDS R16, PORTH                ; r16 stores porth value
    LDI R17, 0b00000010           ;
    OR  R16, R17                  ; changes bit 1 of r16 to one with a OR operation
    STS PORTH, R16                ; sends new port values to porth
    JMP SLAVE_INIT_REGISTERS      ; goes back to read another input

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

SLAVE_RETURN_MINUS_MULTIPLY_11:   ; Finishes the evaluation of the count for a given negative angle
    POP R16                       ; Restores R16
    RET

SLAVE_UNSUCCESS_1:                ; reading of a not valid protocol after a invalid first letter. moreover, user cannot use backspace
    CALL USART1_RECEIVE           ;
    MOV  R19, R16                 ; copies second letter of a invalid protocol to r19

    CPI  R19, ENTER_KEY           ; if r19 is enter key, then finish protocol reading
    BREQ SLAVE_UNSUCCESS          ;

SLAVE_UNSUCCESS_2:                ; reading of a not valid protocol after a invalid second letter. moreover, user cannot use backspace
    CALL USART1_RECEIVE           ;
    MOV  R20, R16                 ; copies third letter of a invalid protocol to r20

    CPI  R20, ENTER_KEY           ; if r20 is enter key, then finish protocol reading
    BREQ SLAVE_UNSUCCESS          ;

SLAVE_UNSUCCESS_3:                ; reading of a not valid protocol after a invalid third letter. moreover, user cannot use backspace
    CALL USART1_RECEIVE           ;
    MOV  R21, R16                 ; copies fourth letter of a invalid protocol to r21

    CPI  R21, ENTER_KEY           ; if r21 is enter key, then finish protocol reading
    BREQ SLAVE_UNSUCCESS          ;

SLAVE_UNSUCCESS_4:                ; reading of a not valid protocol after a invalid fourth letter. moreover, user cannot use backspace
    CALL USART1_RECEIVE           ;
    MOV  R22, R16                 ; copies fifth letter of a invalid protocol to r22

    CPI  R22, ENTER_KEY           ; if r22 is enter key, then finish protocol reading
    BREQ SLAVE_UNSUCCESS          ;

SLAVE_UNSUCCESS_READ_ENTER:          ; waits for master's enter key after a invalid protocol
    CALL USART1_RECEIVE              ;
    CPI  R16, ENTER_KEY              ; if r16 is enter key, then finishes invalid protocol
    BREQ SLAVE_UNSUCCESS             ;
    JMP  SLAVE_UNSUCCESS_READ_ENTER  ; loops until master sends a enter key

SLAVE_UNSUCCESS:                     ; finishes a invalid protocol
    LDI  R16, I_KEY                  ; sends I to master
    CALL USART1_TRANSMIT             ;
    
    LDI  R16, N_KEY                  ; sends N to master
    CALL USART1_TRANSMIT             ;
    
    LDI  R16, V_KEY                  ; sends V to master
    CALL USART1_TRANSMIT             ;
    
    LDI  R16, A_KEY                  ; sends A to master
    CALL USART1_TRANSMIT             ;
    
    LDI  R16, L_KEY                  ; sends L to master
    CALL USART1_TRANSMIT             ;
    
    LDI  R16, I_KEY                  ; sends I to master
    CALL USART1_TRANSMIT             ;
    
    LDI  R16, D_KEY                  ; sends D to master
    CALL USART1_TRANSMIT             ;
    
    LDI  R16, LF_KEY                 ; sends linefeed to master
    CALL USART1_TRANSMIT             ;

    CALL SLAVE_SEND_RECEIVED_MSG     ; sends master's protocol to slave's terminal
    JMP  SLAVE_INIT_REGISTERS        ; goes back to read another input

SLAVE_SEND_RECEIVED_MSG:             ; sends master's protocol to slave's terminal
    MOV  R16, R18                    ; copies first protocol character to r16
    CPI  R16, 0xff                   ; verifies if r16 is not a valid character. r18 is initialized as 0xff
    BREQ SLAVE_SEND_LF_CR            ; sends line feed carriage return if r16 is not a ascii character
    CPI  R16, ENTER_KEY              ; verifies if r16 is enter key to avoid double enter printing
    BREQ SLAVE_SEND_LF_CR            ; sends line feed carriage return if r16 is enter key 
    CALL USART0_TRANSMIT             ; sends r16 to slave's terminal if r16 is a valid character

    MOV  R16, R19                    ; copies second protocol character to r16
    CPI  R16, 0xff                   ; verifies if r16 is not a valid character. r19 is initialized as 0xff
    BREQ SLAVE_SEND_LF_CR            ; sends line feed carriage return if r16 is not a ascii character
    CPI  R16, ENTER_KEY              ; verifies if r16 is enter key to avoid double enter printing
    BREQ SLAVE_SEND_LF_CR            ; sends line feed carriage return if r16 is enter key
    CALL USART0_TRANSMIT             ; sends r16 to slave's terminal if r16 is a valid character

    MOV  R16, R20                    ; copies third protocol character to r16
    CPI  R16, 0xff                   ; verifies if r16 is not a valid character. r20 is initialized as 0xff
    BREQ SLAVE_SEND_LF_CR            ; sends line feed carriage return if r16 is not a ascii character
    CPI  R16, ENTER_KEY              ; verifies if r16 is enter key to avoid double enter printing
    BREQ SLAVE_SEND_LF_CR            ; sends line feed carriage return if r16 is enter key
    CALL USART0_TRANSMIT             ; sends r16 to slave's terminal if r16 is a valid character

    MOV  R16, R21                    ; copies fourth protocol character to r16
    CPI  R16, 0xff                   ; verifies if r16 is not a valid character. r21 is initialized as 0xff
    BREQ SLAVE_SEND_LF_CR            ; sends line feed carriage return if r16 is not a ascii character
    CPI  R16, ENTER_KEY              ; verifies if r16 is enter key to avoid double enter printing
    BREQ SLAVE_SEND_LF_CR            ; sends line feed carriage return if r16 is enter key
    CALL USART0_TRANSMIT             ; sends r16 to slave's terminal if r16 is a valid character

    MOV  R16, R22                    ; copies fifth protocol character to r16
    CPI  R16, 0xff                   ; verifies if r16 is not a valid character. r22 is initialized as 0xff
    BREQ SLAVE_SEND_LF_CR            ; sends line feed carriage return if r16 is not a ascii character
    CPI  R16, ENTER_KEY              ; verifies if r16 is enter key to avoid double enter printing
    BREQ SLAVE_SEND_LF_CR            ; sends line feed carriage return if r16 is enter key
    CALL USART0_TRANSMIT             ; sends r16 to slave's terminal if r16 is a valid character

SLAVE_SEND_LF_CR:                    ; sends line feed carriage return to slave's terminal
    LDI  R16, 0x0a                   ;
    CALL USART0_TRANSMIT             ;
    LDI  R16, 0X0d                   ;
    CALL USART0_TRANSMIT             ;
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
    LDI	R16, (1<<UCSZ11)|(1<<UCSZ10) ; Frame: 8 data bits, 1 stop bit
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
MSG_HASH:
   .DB "bb879094260615a56d2ff40f4152a8b79658acd5 ", '$'
MSG_MASTER:
   .DB "*** MASTER *** ", 0x0A, 0x0D, '$'
MSG_SLAVE:
   .DB "*** SLAVE ***", 0x0A, 0x0D, '$'
MSG_LF:
   .DB 0x0A, '$'

   .EXIT