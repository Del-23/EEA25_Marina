/******************************************************************************************
*******************************************************************************************
** Lab 7 - Marina Gonçalves                                                              **
*******************************************************************************************
******************************************************************************************/
#include <avr/io.h>
#include <stdio.h>
#include <avr/interrupt.h>
#include <string.h>
#include "commit.h"

#define F_CPU 16000000UL
#include <util/delay.h>			// Aqui F_CPU é utilizada.

/*  Protótipos de funções  */
void Timer1Init(void);

void USART0Init(void);
int USART0SendByte(char u8Data,FILE *stream);
int USART0ReceiveByte(FILE *stream);

void USART1Init(void);
int USART1SendByte(char u8Data,FILE *stream);
int USART1ReceiveByte(FILE *stream);

void comandoRecebidoPelo_MASTER(char *comando);
void comandoEnviadoPara_SLAVE(char *comando);
void validacaoRecebidaPelo_MASTER(char *comando);
void comandoRecebidoDo_MASTER_Pelo_SLAVE(char *comando);
int validacaoFeitaPelo_SLAVE(char *comando);
void rodarServo(char *comando);
void acenderLED (char *comando);

/*  Stream para a USART0 e a USART1  */
FILE usart0_str = FDEV_SETUP_STREAM(USART0SendByte, USART0ReceiveByte, _FDEV_SETUP_RW);
FILE usart1_str = FDEV_SETUP_STREAM(USART1SendByte, USART1ReceiveByte, _FDEV_SETUP_RW);

/* Variáveis globais */
char comando[5];
 
/*  Loop principal  */
int main(void)
{
    DDRB=0xff;
	
	DDRL=0xff;
	PORTL=0x00;
	
	DDRH=0xff;
	PORTH=0x00;
	
    Timer1Init();
	sei();
		
	USART0Init();
	USART1Init(); 

		//IDENTIFICANDO O uC MASTER (PL7 EM ALTO)
		if ((PINL >> 7) == 1){
			fprintf(&usart0_str,"%s *** MASTER ***\n", hash);
			while(1){
				DDRF= 0xff;
				PORTF = 0x01; //ligando o LED do master em PF0
				comandoRecebidoPelo_MASTER(comando);//Master recebe o comando digitado pelo usuário
				comandoEnviadoPara_SLAVE(comando);//Master envio o comando recebido para o Slave 
				validacaoRecebidaPelo_MASTER(comando);//Master recebe o retorno do slave sobre a validade do comando (ACK = 1 ou INV = 0) e mostra na tela
			}
		}
	//IDENTIFICANDO O uC SLAVE (PL7 EM BAIXO)
		if ((PINL >> 7) == 0){
			fprintf(&usart0_str,"%s *** SLAVE ***\n", hash);
			while(1){
				comandoRecebidoDo_MASTER_Pelo_SLAVE(comando);
				if (validacaoFeitaPelo_SLAVE(comando) == 1){
					if (comando[0] == 'S'){
						rodarServo(comando);
					}
					if (comando[0] == 'L'){
						acenderLED (comando);
					}
				}
			}
		}
  }
/************************************************************************
*  FUNÇÕES  DA COMUNICAÇÃO MASTER-SLAVE   *
************************************************************************/
void comandoRecebidoPelo_MASTER(char *comando){
	fprintf(&usart0_str,"Digite um comando valido para o slave:\n");
	for (int i = 0; i < 5; i++){
		comando[i] = (char)USART0ReceiveByte(&usart0_str);
	}
	for (int i = 0; i < 5; i++){
		USART0SendByte((int)comando[i], &usart0_str);
	}
	fprintf(&usart0_str,"\n");
}

void comandoEnviadoPara_SLAVE(char *comando){
	for (int i = 0; i < 5; i++){
		USART1SendByte((int)comando[i], &usart1_str);
	}
}

void validacaoRecebidaPelo_MASTER(char *comando){
	if (USART1ReceiveByte(&usart1_str) == '0'){
		fprintf(&usart0_str,"INV\n");
	}
	else{
		fprintf(&usart0_str,"ACK\n");
	}
}

void comandoRecebidoDo_MASTER_Pelo_SLAVE(char *comando){
	for (int i = 0; i < 5; i++){
		comando[i] = (char)USART1ReceiveByte(&usart1_str);
	}
	for (int i = 0; i < 5; i++){
		USART0SendByte((int)comando[i], &usart0_str);
	}
	fprintf(&usart0_str,"\n");
}

int validacaoFeitaPelo_SLAVE(char *comando){
	//verifica se há erro já no primeiro caractere
	if (!(comando[0] == 'S'||comando[0] == 'L')){
		USART1SendByte('0', &usart1_str);
		return 0;
	}
	//Se não houver erro no primeiro caractere, verifica os demais caracteres para cada caso (servo ou led)
	if(comando[0] == 'S'){
		if (!(comando[1] == '0'||comando[1] == '1'||comando[1] == '2')){
			USART1SendByte('0', &usart1_str);
			return 0;
		}
		
		if(!(comando[2] =='+'||comando[2] == '-')){
			USART1SendByte('0', &usart1_str);
			return 0;			
		}
		if(!(comando[3] >= '0' && comando[3] <= '9')){
			USART1SendByte('0', &usart1_str);
			return 0;
		}
		if(!((comando[3] != '9' && (comando[4] >= '0' && comando[4] <= '9')) || (comando[3] == '9' && comando [4] == '0'))){
			USART1SendByte('0', &usart1_str);
			return 0;
		}
	}
	if(comando[0] == 'L'){
		if (!(comando[1] == '0'||comando[1] == '1')){
			USART1SendByte('0', &usart1_str);
			return 0;
		}
		if(!(comando[2] =='O')){
			USART1SendByte('0', &usart1_str);
			return 0;
		}
		if(!((comando[3] == 'N' && comando [4] == 'N')||((comando[3] == 'F' && comando [4] == 'F')))){
			USART1SendByte('0', &usart1_str);
			return 0;			
		}
	}
	USART1SendByte('1', &usart1_str);
	return 1;
}
/************************************************************************
*  FUNÇÕES DE ATUAÇÃO (RODAR SERVO OU ACENDER LED)   *
************************************************************************/
void rodarServo(char *comando){
	int resultado = (int)(comando[3] - '0') *10 + (int)(comando[4] - '0');
	int angulo = 0;
	if (comando[2] == '+'){		
		angulo = 100/9 * resultado + 2999;
	}
	
	if (comando[2] == '-'){
		angulo = -(100/9 * resultado) + 2999;
	}
		if (comando[1] =='0'){
			OCR1AH = angulo >> 8;
			OCR1AL =  angulo & 0xff;
		}
		if (comando[1] =='1'){
			OCR1BH =  angulo >> 8;
			OCR1BL = angulo & 0xff;
		}
		if (comando[1] =='2'){
			OCR1CH =  angulo >> 8;
			OCR1CL =  angulo & 0xff;
		}
	}
	

void acenderLED (char *comando){
	if (comando[1] == '0' && comando[3] == 'N'){
		PORTH ^= (-1 ^ PORTH) & (1UL << 0);
	}
	if (comando[1] == '0' && comando[3] == 'F'){
		PORTH ^= (-0 ^ PORTH) & (1UL << 0);
	}
	if (comando[1] == '1' && comando[3] == 'N'){
		PORTH ^= (-1 ^ PORTH) & (1UL << 1);
	}
	if (comando[1] == '1' && comando[3] == 'F'){
		PORTH ^= (-0 ^ PORTH) & (1UL << 1);
	}

}

/************************************************************************
*  FUNÇÕES  DO TIMER  *
************************************************************************/
void Timer1Init(void){
    /* Inicializacao to TIMER1:
            Modo 14 (CTC-Conta até OCR1A volta para zero e interrompe)
			Fonte de pulsos CPU_CLOCK dividida por 8 pelo PRESCALLER	*/
	
	int CONST_OCR1A = 2999;
	int CONST_ICR1 = 40000;
	
	ICR1H=CONST_ICR1>>8;
	ICR1L=CONST_ICR1 & 0xff;
	
	OCR1AH=CONST_OCR1A>>8;
	OCR1AL=CONST_OCR1A & 0xff;
	
	OCR1BH=CONST_OCR1A>>8;
	OCR1BL=CONST_OCR1A & 0xff;
	
	OCR1CH=CONST_OCR1A>>8;
	OCR1CL=CONST_OCR1A & 0xff;

    TCCR1A=(1<<COM1A1) | (0<<COM1A0) | (1<<COM1B1) | (0<<COM1B0) | (1<<COM1C1) | (0<<COM1C0) | (1<<WGM11) | (0<<WGM10);
    TCCR1B=(0<<ICNC1) | (0<<ICES1) | (1<<WGM13) | (1<<WGM12) | (0<<CS12) | (1<<CS11) | (0<<CS10);

    TIMSK1=(0<<ICIE1) | (0<<OCIE1C) | (0<<OCIE1B) | (0<<OCIE1A) | (0<<TOIE1);
  }

/************************************************************************
*  FUNÇÕES  DA USART0   *
************************************************************************/
void USART0Init(void){
	// Inicialização da USART0 com: assíncrona, 57600 bps, 8 bits,1 stop bit , sem paridade.
	// Deixa transmissor e receptor ativados.
	UCSR0A=(0<<RXC0) | (0<<TXC0) | (0<<UDRE0) | (0<<FE0) | (0<<DOR0) | (0<<UPE0) | (0<<U2X0) | (0<<MPCM0);
	UCSR0B=(0<<RXCIE0) | (0<<TXCIE0) | (0<<UDRIE0) | (1<<RXEN0) | (1<<TXEN0) | (0<<UCSZ02) | (0<<RXB80) | (0<<TXB80);
	UCSR0C=(0<<UMSEL01) |(0<<UMSEL00) | (0<<UPM01) | (0<<UPM00) | (0<<USBS0) | (1<<UCSZ01) | (1<<UCSZ00) | (0<<UCPOL0);
	UBRR0H=0x00;
	UBRR0L=16;
}

int USART0SendByte(char c,FILE *stream){
	if(c == '\n'){
		USART0SendByte('\r',stream); // Força o retorno para o início da linha no hiperterminal do Proteus.
	}
	while(!(UCSR0A&(1<<UDRE0))){};//Espera até que a transmissão do byte anterior seja completada.
	UDR0 = c;// Deposita o byte para transmissão.
	return 0;
}

int USART0ReceiveByte(FILE *stream){
	uint8_t u8Data;
	while(!(UCSR0A&(1<<RXC0))){}// Aguarda chegada de byte
	u8Data=UDR0;// Lê o byte
	//USART0SendByte(u8Data,stream);// Ecoa o byte recebido
	return u8Data;// Retorna com o byte recebido
}

/************************************************************************
*  FUNÇÕES  DA USART1   *
************************************************************************/
void USART1Init(void){
    /* Inicializacao da USART1:
	       8 bits, 1 stop bit, sem paridade
		   Baud rate = 57600 bps
		   Interrupcoes por recepcao de caractere
	*/
	UCSR1A=(0<<RXC1) | (0<<TXC1) | (0<<UDRE1) | (0<<FE1) | (0<<DOR1) | (0<<UPE1) | (0<<U2X1) | (0<<MPCM1);
    UCSR1B=(0<<RXCIE1) | (0<<TXCIE1) | (0<<UDRIE1) | (1<<RXEN1) | (1<<TXEN1) | (0<<UCSZ12) | (0<<RXB80) | (0<<TXB81);
    UCSR1C=(0<<UMSEL11) |(0<<UMSEL10) | (0<<UPM11) | (0<<UPM10) | (0<<USBS1) | (1<<UCSZ11) | (1<<UCSZ10) | (0<<UCPOL1);
    UBRR1H=0x00;
    UBRR1L=16;
}

int USART1SendByte(char u8Data,FILE *stream){
	if(u8Data == '\n'){
			USART1SendByte('\r',stream);// Força o retorno para o início da linha no hiperterminal do Proteus.
		}
	while(!(UCSR1A&(1<<UDRE1))){};//Espera até que a transmissão do byte anterior seja completada.
	UDR1 = u8Data;// Deposita o byte para transmissão.
	return 0;
}

int USART1ReceiveByte(FILE *stream){
	uint8_t u8Data;
	while(!(UCSR1A&(1<<RXC1))){};// Aguarda chegada de byte
	u8Data=UDR1;// Lê o byte
	//USART0SendByte(u8Data,stream);// Ecoa o byte recebido
	return u8Data;// Retorna com o byte recebido
}     