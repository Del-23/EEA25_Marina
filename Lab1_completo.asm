;**********************************************************************************************
;**********************************************************************************************
;**   Target uC: Atmel ATmega328P                                                            **
;**   X-TAL frequency: 16 MHz                                                                **
;**                                                                                          **
;**   Description:                                                                           **
;**       Sets the USART to operate in asynch mode with:                                     **
;**            57600 bps,																	 **
;**            1 stop bit,																	 **
;**            no  parity																	 **
;**																						     **
;**       The firmware main loop (FOREVER) communicates a messagevia a terminal which should **
;**       be connected to the uC's and TX ports (USART). The loop goes as follows:			 **												 
;**            1. Sends a message asking for a key to be pressed in the host keyboard        **                            
;**            2. Waits for the incoming char to get received								 **
;**            3. Prints a message indicating the received char and the correspoding code    **                        
;**            4. Back to setp 1.															 ** 
;**																							 **
;**  Created: 2020/08/08 by chiepa															 **
;**  Modified: 2021/08/13 by dloubach														 **
;**  Used as model to lab1: 2021/09/07 by Marina											 **										  
;**********************************************************************************************
;**********************************************************************************************

   ;; constants for baut rates
   .EQU	BAUD_RATE_2400 = 416
   .EQU	BAUD_RATE_9600 = 103
   .EQU	BAUD_RATE_57600 = 16
   .EQU	BAUD_RATE_115200 = 8

   .EQU RETURN = 0x0A			; cursor comes back to the beggining of the line
   .EQU LINEFEED = 0x0D			; cursor goes down to the next line

.CSEG							; FLASH segment code
   .ORG	0                       ; entry point after POWER/RESET
	JMP   RESET

   .ORG	0x100

;*****************************************************************************
;  Routine RESET
;  Resets the last command given to the serial terminal by pressing D or I
;*****************************************************************************

RESET:
	LDI		R16, LOW(RAMEND)	    ; init stack pointer (constant RAMEND is defined as the last address in SRAM)
	OUT		SPL, R16
	LDI		R16, HIGH(RAMEND)
	OUT		SPH, R16

	CALL	USART_INIT		        ; goes to USART init code

    CALL	PORTD_INIT				; set ports

    LDI		ZH, HIGH(2*PROMPT)	    ; prints the "PROMPT" (the message to press a key)
	LDI		ZL, LOW(2*PROMPT)
	CALL	SENDS

	LDI		R16, 'I'			    ; sets default command as increment (I)

;*******************************************************************************
;  Routine FOREVER (main loop)
;  Checks if the switch has been pressed and if there is a caractere to be read
;*******************************************************************************

FOREVER:
	
	PUSH	R16
	IN		R16,PIND				 ; checks if the switch has been pressed
	ANDI	R16,0b10000000
    BREQ	ESPERA_LIBERACAO
	POP		R16

	CALL	USART_RECEIVE			 ; checks if there is a caractere to be read. If there is, reads it

	JMP		FOREVER


;*******************************************************************************
;  Subroutine BOTTOM
;  Checks if the D or I key has been pressed (or any other key too)
;*******************************************************************************

BOTTOM:
	POP		R16
	CPI		R16, 'I'				; compares if the pressed key is 'I'
	BREQ	EQUAL_I					; if it is, goes to EQUAL_I, which increments
	CALL	EQUAL_D					; if it is not, goes to EQUAL_D, which decrements
	JMP		FOREVER

EQUAL_I:
	CALL	INCREMENTS
	LDI		R16, 'I'
	JMP		FOREVER

EQUAL_D:
	CALL	DECREMENTS
	LDI		R16, 'D'
	RET

; observation: this subroutine considers that the operator only presses I or D. If it is not the case
; any other key different from I will result in a decrement (subroutine EQUAL_D)

;*********************************************************************************
;  Subroutine SENDS
;  Sends a message pointed by register Z in the FLAHS memory
;*********************************************************************************
SENDS:
	PUSH	R16

SENDS_REP:
   LPM		R16, Z+
   CPI		R16, '$'
   BREQ		END_SENDS
   CALL		USART_Transmit
   JMP		SENDS_REP

END_SENDS:
   POP		R16
   RET

;**************************************************************************************
;  Subroutine SWITCH
;  Uses code given by prof. Chiepa in project ContPulses (left in Portuguese as it was)
;**************************************************************************************
ESPERA_LIBERADA:
	IN		R16,PIND
	ANDI	R16,0b10000000
	BREQ	ESPERA_LIBERADA


; Aguarda liberação da chave
ESPERA_LIBERACAO:
	IN		R16,PIND
	ANDI	R16,0b10000000
	BREQ	ESPERA_LIBERACAO
	JMP		BOTTOM


;****************************************************************************
;  Subroutine INCREMENTS ou DECREMENTS (mathematical operations)
;  Configures the counter to add 1 or to subtract 1 due to the pressed key
;****************************************************************************
INCREMENTS:		
	INC		R17
	OUT		PORTD,R17
	INC		R17
	OUT		PORTD,R17
	INC		R17
	OUT		PORTD,R17
	INC		R17
	OUT		PORTD,R17
	RET

DECREMENTS:
	DEC		R17
	OUT		PORTD,R17
	DEC		R17
	OUT		PORTD,R17
	DEC		R17
	OUT		PORTD,R17
	DEC		R17
	OUT		PORTD,R17
	RET

;*********************************************************************
;  Subroutine PORTD_INIT
;  Configures PD7,pd6 and PD0 as INPUTS and PD5 to PD1 as OUTPUTS
;  Resets all four LEDs by writing 0s
;*********************************************************************
PORTD_INIT:
   LDI		R16, 0b00111110
   OUT		DDRD, R16
   LDI		R16, 0b00000000
   OUT		PORTD, R16
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
	LDI		R17, HIGH(BAUD_RATE_57600)				; sets the baud rate
	STS		UBRR0H, R17
	LDI		R16, LOW(BAUD_RATE_57600)
	STS		UBRR0L, R16
	LDI		R16, (1<<RXEN0)|(1<<TXEN0)				; enables RX and TX

	STS		UCSR0B, R16
	LDI		R16, (0<<USBS0)|(3<<UCSZ00)				; frame: 8 data bits, 1 stop bit
	STS		UCSR0C, R16								; no parity bit

	RET

;*********************************************************************
;  Subroutine USART_TRANSMIT  
;  Transmits (TX) R16   
;*********************************************************************
USART_TRANSMIT:
   PUSH		R17                     ; saves R17 into stack

WAIT_TRANSMIT:
	LDS		R17, UCSR0A
	SBRS	R17, UDRE0		        ; waits for TX buffer to get empty
	RJMP	WAIT_TRANSMIT
	STS		UDR0, R16	            ; writes data into the buffer

	POP		R17                     ; restores R17
	RET

;*********************************************************************
;  Subroutine USART_RECEIVE
;  Receives the char from USAR and places it in the register R16 
;*********************************************************************
USART_RECEIVE:
	PUSH	R17                      ; saves R17 into stack

WAIT_RECEIVE:
	LDS		R17, UCSR0A
	SBRS	R17, RXC0
	RJMP	GO_TO_FOREVER	         ; waits for the data incomings
	LDS		R16, UDR0		         ; reads the data
	STS		CARACTERE, R16 
	CALL	CONFIRMED_ORDER

	POP		R17						 ; restores R17
	RET

GO_TO_FOREVER:
	POP		R17						 ; restores R17
	RET

CONFIRMED_ORDER:
	LDI		ZH, HIGH(2*RESULT)		 ; prints "chair received" (RESULT variable)
	LDI		ZL, LOW(2*RESULT)
	CALL	SENDS

	LDI		R16, '''				 ; prints single quotes
	CALL	USART_TRANSMIT

	LDS		R16, CARACTERE			 ; prints received char
	CALL	USART_TRANSMIT
	
	LDI		R16, '''				 ; prints single quotes
	CALL	USART_TRANSMIT

	LDI		ZH, HIGH(2*PONTORTLF)	 ; prints '.', RETURN, LINEFEED
	LDI		ZL, LOW(2*PONTORTLF)
	CALL	SENDS

	LDI		ZH, HIGH(2*RTLF)		 ; prints RETURN, LINEFEED
	LDI		ZL, LOW(2*RTLF)
	CALL	SENDS

	LDS		R16, CARACTERE			 ; restores R16 to the pressed charactere

	RET 

;*********************************************************************
; Hard coded messages
;*********************************************************************
PROMPT: 
			.DB  "Press a key", RETURN, LINEFEED, '$'
RESULT:
			.DB  "Char received:", '$'
RTLF:
			.DB   0x0a, 0x0d, '$'           ; carriage return & line feed chars
PONTORTLF:
			.DB  '.', RETURN, LINEFEED, '$'

;*********************************************************************	
.DSEG
	.ORG 0x200
CARACTERE:
	.BYTE 1
		
.EXIT

