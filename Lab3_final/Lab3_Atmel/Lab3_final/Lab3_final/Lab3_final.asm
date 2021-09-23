;************************************************************************
;*   Projeto Lab3 final                                                 *
;*                                                                      *
;*   MCU alvo: Atmel ATmega2560 a 16 MHz com                            *
;*       - Módulos de Leds de 7 segmentos conectados ao PORTH;          *
;*       - Terminal alfanumérico "TERM0" conectado à USART0.            *
;*                                                                      *
;*Created by Marina in 22/09/2021                                       *
;************************************************************************

;***************
;* Constantes  *
;***************
; Constantes para configurar baud rate (2400:416, 9600:103, 57600:16, 115200:8).

   .equ  BAUD_RATE = 103
   .equ  RETURN = 0x0A				 ; Retorno do cursor.
   .equ  LINEFEED = 0x0D			 ; Descida do cursor.
   .equ  TIMER1_COMPA_vect = 0x0022  ; Vetor para atendimento a interrupções TIMRE1_COMPA match.
   .equ  CONST_OCR1A = 2999			 ; Constante para o registrador OCR1A do TIMER.
   .equ  CONST_ICR1 = 40000			 ; Constante para o registrador ICR1 do TIMER.
   
;*****************************
; Segmento de código (FLASH) *
;*****************************
   .cseg

; Ponto de entrada para RESET.
   .org  0 
   jmp   RESET

;*************************************************
;  PONTO DE ENTRADA DAS INTERRUPÇÕES DO TIMER1   *
;*************************************************
   .org  TIMER1_COMPA_vect
VETOR_TIMER1_COMPA:
   jmp   TIMER1_COMPA_INTERRUPT


   .org  0x100
RESET:
   ldi   r16, low(ramend)       ; Inicializa Stack Pointer.
   out   spl, r16               ; Para ATMega328 RAMEND=08ff.
   ldi   r16, high(ramend)
   out   sph, r16

   call  INIT_PORTS             ; Inicializa PORTH.
   call  USART0_INIT            ; Inicializa USART0.
   call  TIMER1_INIT_MODE4      ; Inicializa TIMER1.
   sei                          ; Habilita interrupções.


;****************************************************************************************
;*                         PARTE PRINCIPAL DO PROGRAMA                                  *

LOOP_PRINCIPAL:
	ldi   zh, high(2*MensHello)   
	ldi   zl, low(2*MensHello)
	call  PRINT_USART0

	;READING THE SERVER ID
	CALL USART0_RECEIVE
	CALL USART0_TRANSMIT
	MOV R18,R16

	;READING THE SIGNAL
	CALL USART0_RECEIVE
	CALL USART0_TRANSMIT
	MOV R19,R16

	;READING THE FIRST DIGIT OF THE ANGLE
	CALL USART0_RECEIVE
	CALL USART0_TRANSMIT
	MOV R20,R16

	;READING THE SECOND DIGIT OF THE ANGLE
	CALL USART0_RECEIVE
	CALL USART0_TRANSMIT
	MOV R21,R16

	ldi   zh, high(2*PularLinha)   
	ldi   zl, low(2*PularLinha)
	call  PRINT_USART0

	CPI R19, '+'
	BREQ SET_ANGLE_PLUS
	CPI R19, '-'
	BREQ SET_ANGLE_MINUS

LOOP:
	CALL SET_SERVE

	JMP LOOP_PRINCIPAL


;*                         FIM DA PARTE PRINCIPAL DO PROGRAMA                           *
;****************************************************************************************


;****************************************************************************************
;*           FUNÇÃO QUE CALCULA O MOVIMENTO DO SERVO SE O SINAL FOR +                   *
SET_ANGLE_PLUS:
	SUBI R20, '0'
	SUBI R21, '0'

	MOV R22,R20 ;GUARDANDO O ALGARISMO DA DEZENA
	
	ADD R20,R20 ;SOMANDO 2 VEZES O ALGARISMO DA DEZENA
	ADD R20,R20 ;SOMANDO 4 VEZES O ALGARISMO DA DEZENA
	ADD R20,R20 ;SOMANDO 8 VEZES O ALGARISMO DA DEZENA
	ADD R20,R22 ;SOMANDO 9 VEZES O ALGARISMO DA DEZENA
	ADD R20,R22 ;SOMANDO 10 VEZES O ALGARISMO DA DEZENA

	ADD R20,R21 ;SOMANDO A DEZENA*10 + UNIDADE

	LDI R21,11

	MUL R20,R21

	ASR R20
	ASR R20
	ASR R20

	LDI R22, HIGH(2999)
	LDI R21, LOW(2999)

	ADD R20,R21
	ADD R0,R20
	ADC R1,R22
	JMP LOOP

;****************************************************************************************
;*           FUNÇÃO QUE CALCULA O MOVIMENTO DO SERVO SE O SINAL FOR -                   *

SET_ANGLE_MINUS:
	SUBI R20, '0'
	SUBI R21, '0'

	MOV R22,R20 ;GUARDANDO O ALGARISMO DA DEZENA
	
	ADD R20,R20 ;SOMANDO 2 VEZES O ALGARISMO DA DEZENA
	ADD R20,R20 ;SOMANDO 4 VEZES O ALGARISMO DA DEZENA
	ADD R20,R20 ;SOMANDO 8 VEZES O ALGARISMO DA DEZENA
	ADD R20,R22 ;SOMANDO 9 VEZES O ALGARISMO DA DEZENA
	ADD R20,R22 ;SOMANDO 10 VEZES O ALGARISMO DA DEZENA

	ADD R20,R21 ;SOMANDO A DEZENA*10 + UNIDADE

	LDI R21,11

	MUL R20,R21

	ASR R20
	ASR R20
	ASR R20

	LDI R22, HIGH(2999)
	LDI R21, LOW(2999)

	SUB R21,R20
	SUB R21,R0
	SBC R22,R1

	MOV R0, R21
	MOV R1, R22

	JMP LOOP

;****************************************************************************************
;*                        FUNÇÃO QUE LÊ QUAL SERVO SERÁ MOVIDO                          *

SET_SERVE:
	CPI R18, '0'
	BREQ SERVERZERO
	CPI R18, '1'
	BREQ SERVERONE
	CPI R18, '2'
	BREQ SERVERTWO
	RJMP SET_SERVE
	
SERVERZERO:
   sts   ocr1ah, r1
   sts   ocr1al, r0

   RET

SERVERONE:
   sts   ocr1bh, r1	  
   sts   ocr1bl, r0

   RET

SERVERTWO:
   sts   ocr1ch, r1
   sts   ocr1cl, r0

   RET


;****************************************************************************************
;*                        INTERRUPT DRIVER DO do TIMER1_COMPA match                     *
;                                TIMER1_COMPA_INTERRUPT                                 * 
TIMER1_COMPA_INTERRUPT:
   push   r16
   lds    r16, sreg
   push   r16

; Esta interrupção foi disparada porque a TCNT1 atingiu o valor de OCR1A.
; TCNT1 é automaticamente zerado pelo TIMER e a contagem recomeça.
; Incrementa PORTH   e retorna.
   lds    r16, porth
   inc    r16
   sts    porth, r16
   
   pop    r16
   sts    sreg, r16
   pop    r16
   reti

;*                         FIM DO INTERRUPT DRIVER DO TIMER1                            *
;****************************************************************************************



;**************************************************
;  PRINT_USART0                                   *
;  Subrotina                                      *
;  Envia através da USART0 a mensagem apontada    *
;     por Z em CODSEG.                            *
;  O caractere '$' indica o término da mensagem.  *
;**************************************************
PRINT_USART0:
   push  r16
   lds   r16, sreg
   push  r16
   push  r17
   push  zh
   push  zl

PRINT_USART0_REP:
   lpm   r16,z+
   cpi   r16, '$'
   breq  FIM_PRINT_USART0
   call  USART0_Transmit
   jmp   PRINT_USART0_REP

FIM_PRINT_USART0:
   pop   zl
   pop   zh
   pop   r17
   pop   r16
   sts   sreg, r16
   pop   r16
   ret
            
;***********************************
;  INIT_PORTS                      *
;  Inicializa PORTB como saída     *
;    em PB5 e entrada nos demais   *
;    terminais.                    *
;  Inicializa PORTH como saída     *
;    e emite 0x00 em ambos.        *
;***********************************
INIT_PORTS:
   ldi   r16, 0b11100000        ; Para emitir em PB5 a onda quadrada gerada pelo TIMER1.
   out   ddrb, r16
   ldi   r16, 0b11111111
   sts   ddrh, r16
   ldi   r16, 0b00000000
   sts   porth, r16
   ret

;*****************************************
;  USART0_INIT                           *
;  Subrotina para inicializar a USART0.  *
;*****************************************
; Inicializa USART0: modo assincrono, 9600 bps, 1 stop bit, sem paridade.  
; Os registradores são:
;     - UBRR0 (USART0 Baud Rate Register)
;     - UCSR0 (USART0 Control Status Register B)
;     - UCSR0 (USART0 Control Status Register C)
USART0_INIT:
   ldi   r17, high(BAUD_RATE)   ;Estabelece Baud Rate.
   sts   ubrr1h, r17
   ldi   r16, low(BAUD_RATE)
   sts   ubrr1l, r16
   ldi   r16, (1<<rxen1)|(1<<txen1)  ;Habilita receptor e transmissor.
   
   sts   ucsr1b, r16
   ldi   r16, (0<<usbs0)|(1<<ucsz01)|(1<<ucsz00)   ;Frame: 8 bits dado, 1 stop bit,
   sts   ucsr1c, r16            ;sem paridade.
   
   ret

;*************************************
;  USART0_TRANSMIT                   *
;  Subrotina para transmitir R16.    *
;*************************************
USART0_TRANSMIT:
   push  r17                    ;Salva R17 na pilha.

WAIT_TRANSMIT0:
   lds   r17, ucsr1a
   sbrs  r17, udre1             ;Aguarda BUFFER do transmissor ficar vazio.      
   rjmp  WAIT_TRANSMIT0
   sts   udr1, r16              ;Escreve dado no BUFFER.

   pop   r17                    ; Restaura R17 e retorna.
   ret

;*******************************************
;  USART0_RECEIVE                          *
;  Subrotina                               *
;  Aguarda a recepção de dado pela USART0  *
;  e retorna com o dado em R16.            *
;*******************************************
USART0_RECEIVE:
   push  r17						  ; Salva R17 na pilha.

WAIT_RECEIVE0:
   lds   r17,ucsr1a
   sbrs  r17,rxc1
   rjmp  WAIT_RECEIVE0          ;Aguarda chegada do dado.
   lds   r16,udr1               ;Le dado do BUFFER e retorna.

   pop   r17						  ; Restaura R17 e retorna.
   ret

;*********************************
; TIMER1_INIT_MODE14              *
; OCR1A =15625, PRESCALER/1024   *
;*********************************
TIMER1_INIT_MODE4:

; ICR1 = 40000
   ldi   r16, CONST_ICR1>>8
   sts   icr1h, r16
   ldi   r16, CONST_ICR1 & 0xff		  
   sts   icr1l, r16

; OCR1A = 3000
   ldi   r16, CONST_OCR1A>>8
   sts   ocr1ah, r16
   ldi   r16, CONST_OCR1A & 0xff		  
   sts   ocr1al, r16

; OCR1B = 3000
   ldi   r16, CONST_OCR1A>>8
   sts   ocr1bh, r16
   ldi   r16, CONST_OCR1A & 0xff		  
   sts   ocr1bl, r16

; OCR1C
   ldi   r16, CONST_OCR1A>>8
   sts   ocr1ch, r16
   ldi   r16, CONST_OCR1A & 0xff		  
   sts   ocr1cl, r16


; Modo 14, CTC: (WGM13, WGM12, WGM11, WGM10)=(1,1,1,0)
; Comutar OC1A para gerar onda quadrada: (COM1A1,COM1A0)=(1,0), (Tabela 3)
   ldi   r16, (1<<com1a1) | (0<<com1a0) | (1<<com1b1) | (0<<com1b0) | (1<<com1c1) | (0<<com1c0) | (1<<wgm11) | (0<<wgm10)
   sts   tccr1a, r16

; Modo 14, CTC: (WGM13, WGM12, WGM11, WGM10)=(1,1,1,0), (Tabela 2)
; Clock select: (CS12,CS11,CS10)=(0,1,0), PRESCALER/8, (Tabela 1)
; No input capture: (ICNC1) | (0<<ICES1)
   ldi   r16,(0<<icnc1) | (0<<ices1) | (1<<wgm13) | (1<<wgm12) | (0<<cs12) |(1<<cs11) | (0<<cs10)
   sts   tccr1b, r16

; Timer/Counter 1 Interrupt(s) initialization
; Aqui, por exemplo, pede interrupcao s,empre que contagem=OCR1A
   ldi   r16, (0<<icie1) | (0<<ocie1c) | (0<<ocie1b) | (0<<ocie1a) | (0<<toie1)
   sts   timsk1, r16

   ret

;*******************************************
; Strings e mensagens a serem impressas.   *
;    '$' é usado como terminador.          *
;*******************************************
MensHello:
   .db   "Digite um comando:",RETURN,LINEFEED, "S",'$'

PularLinha:
	.db " ", RETURN, LINEFEED, '$'

;*****************************
; Finaliza o programa fonte  *
;*****************************
   .exit


