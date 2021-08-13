;********************************************************************
;********************************************************************
;**   pulse-counter.asm                                            **
;**
;**   Target MCU: Atmel ATmega328P                                 **
;**   X-TAL frequency: 16 MHz                                      **
;**   IDE: AVR Assembler 2 (Atmel Studio 6.2.1153)                 **
;**   Compiler: 
;**
;**   Brief description:                                           **
;**       PORTD with bits 0 to 3 configured as OUTPUT              **
;**                  bit 7 as INPUT                                **
;**       The main program's part shows 4 LEDs connected to        **
;**       4 least significant bits of PORT D.                      **
;**       The pulse counter applied in PD7 when SW2 is pushed and  **
;**       released. Register R17 is used to hold the pulse counter **
;**       value.                                                   **
;**
;**   Created: 2020/09/10 by chiepa                                **
;**   Modified: 2021/08/12 by dloubach                             **
;********************************************************************
;********************************************************************
                                
   .CSEG                        ; FLASH segment code
   .ORG 0                       ; entry point after POWER/RESET

RESET:
   LDI  R16, 0b00001111         ; set PD0 to PD3 as OUTPUTS and PD4 to PD7 as INPUTS
   OUT  DDRD, R16               ;
   LDI  R17, 0b00000000         ; resets inicial pulse counter
   OUT  PORTD, R17              ; write it to PORT D

READ_TO_GO:                     ; waits for open switch to start couting
   IN   R16,PIND                ;
   ANDI R16,0b10000000          ;
   BREQ READ_TO_GO              ;

WAIT_SWITCH:
   IN   R16, PIND               ;
   ANDI R16, 0b10000000         ;
   BRNE WAIT_SWITCH             ;

                                
WAIT_SWITCH_RELEASE:            ; waits for switch release
   IN   R16, PIND               ;
   ANDI R16,0b10000000          ;
   BREQ WAIT_SWITCH_RELEASE     ;

                                
INCREMENTS:                     ; counter increments and LED update
   INC  R17                     ;
   OUT  PORTD, R17              ;
   JMP  WAIT_SWITCH             ; jumps to WAIT_SWITCH

   .EXIT
