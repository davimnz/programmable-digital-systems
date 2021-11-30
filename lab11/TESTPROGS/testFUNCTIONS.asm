; Define origem da ROM e da RAM (este programa tem dois segmentos).
; Diretivas nao podem comecar na primeira coluna.

CODIGO		EQU	0000H

DADOS		EQU	0E000H

TOPO_RAM	EQU	0FFFFH


;********************************************
; Definicao de macros para que zmac reconheca
; novos mnemonicos de instrucao.
;********************************************

FILLBLOCK	MACRO
		DB	08H
		ENDM	

MOVBLOCK	MACRO
		DB	10H
		ENDM	

LONGADD		MACRO
		DB	18H
		ENDM	

LONGSUB		MACRO
		DB	20H
		ENDM	


LONGCMP		MACRO
		DB	28H
		ENDM	

JMP256		MACRO
		DB	0CBH
		ENDM


;********************
; Início do código  *
;********************

	ORG	CODIGO

INICIO:         LXI     SP,TOPO_RAM	; seta stack pointer para topo ram
                CALL    INICIASIO       ; inicia uart

                LXI     H,MENSAGEM	; envia mensagem inicial para uart
                CALL    DISPLAY		;


LOOP:		CALL	INPUT		; le uma letra de entrada

		CPI	'z'             ; se for z, demonstra a instrucao FILLBLOCK
		JZ	DEMO_FILLBLOCK  ;
		JMP	LOOP            ; se nao for z, le outra letra


DEMO_FILLBLOCK:	LXI	H, MENSAGEM_FILLBLOCK    ; mensagem de teste de fillblock
		CALL	DISPLAY                  ; 

CODE_FILLBLOCK:	LXI	B, 0050H
		LXI	H, DADOS
		MVI	A, 36H

		FILLBLOCK

END_FILLBLOCK:	CALL	INPUT
		CPI	'z'
		JZ	DEMO_MOVBLOCK
		JMP	END_FILLBLOCK


DEMO_MOVBLOCK:	LXI	H, MENSAGEM_MOVBLOCK
		CALL	DISPLAY

CODE_MOVBLOCK:

END_MOVBLOCK:	CALL	INPUT
		CPI	'z'
		JZ	DEMO_LONGADD
		JMP	END_MOVBLOCK


DEMO_LONGADD:	LXI	H, MENSAGEM_LONGADD
		CALL	DISPLAY

CODE_LONGADD:

END_LONGADD:	CALL 	INPUT
		CPI	'z'
		JZ	DEMO_LONGSUB
		JMP	END_LONGADD


DEMO_LONGSUB:	LXI	H, MENSAGEM_LONGSUB
		CALL	DISPLAY

CODE_LONGSUB:

END_LONGSUB:	CALL	INPUT
		CPI	'z'
		JZ	FIM_PROG
		JMP	END_LONGSUB

FIM_PROG:	LXI	H, MENSAGEM_FIM
		CALL	DISPLAY

END_LOOP:	JMP	END_LOOP

;****************************************************
;****************************************************
;    SUBROTINAS PARA MANIPULACAO DA UART 8250A     **
;                                                  **
;    NAO ALTERE O QUE VEM A SEGUIR !!!!            **
;****************************************************
;****************************************************


;****************************
;  Definicao de constantes  *
;****************************
RBR             EQU     08H     ; Com bit DLA (LCR.7) em 0.
THR             EQU     08H     ; Com bit DLA (LCR.7) em 0.     
IER             EQU     09H     ; Com bit DLA (LCR.7) em 0.
IIR             EQU     0AH
LCR             EQU     0BH
MCR             EQU     0CH
LSR             EQU     0DH
MSR             EQU     0EH
DLL             EQU     08H     ; Com bit DLA (LCR.7) em 1.
DLM             EQU     09H     ; Com bit DLA (LCR.7) em 1.
SCR             EQU     0FH
;*******************************************************
;  INICIASIO                                           *
;    Inicializa a UART 8250A                           *
;                                                      *
;    UART 8250A inicializada com:                      *
;      - 1 stop bit;                                   *
;      - sem paridade;                                 *
;      - palavras de 8 bits;                           *
;      - baud rate = CLOCK/(16*DIVISOR).               *
;                                                      *
;                                                      *
;    Para operar a 9600 baud devemos ter portanto:     *
;        DIVISOR = 1843200/(16*9600) = 12 = 0CH        *
;                                                      *
;*******************************************************
INICIASIO:      PUSH    PSW

                MVI     A,10000011B
                OUT     LCR
                MVI     A,0CH
                OUT     DLL
                MVI     A,00H
                OUT     DLM
                MVI     A,00000011B
                OUT     LCR

                POP     PSW
                RET
;                               *
;********************************

;*********************************************************************
;  OUTPUT                                                            *
;    Envia A para transmissao pela UART 8250A.                       *
;                                                                    *
;    Somente retorna apos conseguir escrever A no BUFFER da UART.    *
;    Preserva todos os registradores.                                *
;                                                                    *
;   STATUS_UART = (DSR,BRKDET,FE,OE,PE,TXEMPTY,RXREADY,TXREADY)      *
;                                                                    *
;*********************************************************************
OUTPUT:         PUSH    PSW
                PUSH    B

                MOV     B,A
OUTPUTLP:       IN      LSR
                ANI     20H
                JZ      OUTPUTLP
                MOV     A,B
                OUT     THR

                POP     B
                POP     PSW
                RET
;                               *
;********************************

;****************************************************************************
;  INPUT                                                                    *
;    Le byte recebido pela UART 8250A                                       *
;                                                                           *
;      Somente retorna apos detectar um byte no BUFFER de dados da UART.    *
;                                                                           *
;      Retorna com o byte em A.  Preserva os demais registradores.          *
;                                                                           *
;      STATUS_UART = (DSR,BRKDET,FE,OE,PE,TXEMPTY,RXREADY,TXREADY)          *
;                                                                           *
;****************************************************************************
INPUT:          PUSH    PSW

INPUTLP:        IN      LSR
                ANI     00000001B
                JZ      INPUTLP

                POP     PSW
                IN      RBR
                RET
;                               *
;********************************

;****************************************************
; DISPLAY                                           *
;   Subrotina para imprimir cadeia de caracteres.   *
;                                                   *
;   Parametro: HL aponta para string ASCII          *
;   terminado em "$"                                *
;****************************************************

DISPLAY:        PUSH    PSW
                PUSH    B
                PUSH    D
                PUSH    H

ADIANTE:        MOV     A,M
                CPI     "$"
                JZ      DISPLAY_FIM
                CALL    OUTPUT
                INX     H
                JMP     ADIANTE

DISPLAY_FIM:    POP     H
                POP     D
                POP     B
                POP     PSW
                RET
;                               *
;********************************

;**********************************
; Cadeias de caracteres em ROM.   *
;**********************************

RETURN          EQU     0DH
LINEFEED	EQU	0AH

MENSAGEM:
		DB	"Este programa testa quatro funcoes.",RETURN
		DB	"Aperte a letra z para prosseguir",RETURN,"$"

MENSAGEM_FILLBLOCK:
		DB	"Funcao FILLBLOCK.",RETURN,"$"

MENSAGEM_MOVBLOCK:
		DB	"Funcao MOVBLOCK.",RETURN,"$"

MENSAGEM_LONGADD:
		DB	"Funcao LONGADD.",RETURN,"$"

MENSAGEM_LONGSUB:
		DB	"Funcao LONGSUB",RETURN,"$"

MENSAGEM_FIM:
		DB	"Pode encerrar o programa",RETURN,"$"

;                               *
;********************************


;       Final do segmento "CODIGO"                                   **
;                                                                    **
;**********************************************************************
;**********************************************************************

        END	INICIO