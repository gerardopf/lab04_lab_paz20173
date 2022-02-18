/*	
    Archivo:		lab04_pre_pgr.s
    Dispositivo:	PIC16F887
    Autor:		Gerardo Paz 20173
    Compilador:		pic-as (v2.30), MPLABX V6.00

    Programa:		RBIE y T0IE 
    Hardware:		Botones en puerto B
			Leds en puerto A

    Creado:			14/02/22
    Última modificación:	15/02/22	
*/
    
PROCESSOR 16F887
#include <xc.inc>

; CONFIG1
CONFIG  FOSC = INTRC_NOCLKOUT ; Oscillator Selection bits (INTOSCIO oscillator: I/O function on RA6/OSC2/CLKOUT pin, I/O function on RA7/OSC1/CLKIN)
CONFIG  WDTE = OFF            ; Watchdog Timer Enable bit (WDT disabled and can be enabled by SWDTEN bit of the WDTCON register)
CONFIG  PWRTE = OFF            ; Power-up Timer Enable bit (PWRT enabled)
CONFIG  MCLRE = OFF           ; RE3/MCLR pin function select bit (RE3/MCLR pin function is digital input, MCLR internally tied to VDD)
CONFIG  CP = OFF              ; Code Protection bit (Program memory code protection is disabled)
CONFIG  CPD = OFF             ; Data Code Protection bit (Data memory code protection is disabled)
CONFIG  BOREN = OFF           ; Brown Out Reset Selection bits (BOR disabled)
CONFIG  IESO = OFF            ; Internal External Switchover bit (Internal/External Switchover mode is disabled)
CONFIG  FCMEN = OFF           ; Fail-Safe Clock Monitor Enabled bit (Fail-Safe Clock Monitor is disabled)
CONFIG  LVP = OFF              ; Low Voltage Programming Enable bit (RB3/PGM pin has PGM function, low voltage programming enabled)

; CONFIG2
CONFIG  BOR4V = BOR40V        ; Brown-out Reset Selection bit (Brown-out Reset set to 4.0V)
CONFIG  WRT = OFF             ; Flash Program Memory Self Write Enable bits (Write protection off)


 reset_timer0 macro		    //siempre hay que volver a asignarle el valor al TMR0
    BANKSEL TMR0
    MOVLW   246		    //Cargamos N en W
    MOVWF   TMR0	    //Cargamos N en el TMR0, listo el retardo de 10ms
    
    BCF	T0IF		    //Limpiar bandera de interrupción

    ENDM
    
    
 PSECT resVect, class=CODE, abs, delta=2	//Vector de Reset
 ORG 00h					// posición 0000h para el reset
 resVect:
       PAGESEL main
       GOTO    main
       
 //Variables de pines
 UP	EQU 0
 DOWN	EQU 1
       
       
 PSECT udata_shr		    //Memoria compartida
 W_TEMP:	    DS  1	    //1 byte
 STATUS_TEMP:	    DS  1	    //1 byte
 CONTT0:	    DS  2
    
 
 PSECT intVect, class=CODE, abs, delta=2    //Vector de interrupciones
 ORG 04h
 
 push:
    MOVWF   W_TEMP	    //Movemos W en la temporal
    SWAPF   STATUS, W	    //Pasar el SWAP de STATUS a W
    MOVWF   STATUS_TEMP	    //Guardar STATUS SWAP en W	
    
 isr:
    BTFSC   T0IF	    //Revisar bandera Timer0
    CALL    int_timer0
    
    
    BTFSC   RBIF	    //Revisar la interrupción de puerto B
    CALL    int_iocb
    
    
 pop:
    SWAPF   STATUS_TEMP, W  //Regresamos STATUS a su orden original y lo guaramos en W
    MOVWF   STATUS	    //Mover W a STATUS
    SWAPF   W_TEMP, F	    //Invertimos W_TEMP y se guarda en F
    SWAPF   W_TEMP, W	    //Volvemos a invertir W_TEMP para llevarlo a W
    RETFIE
    
    
 /*	Subrutinas de interrupción	*/
 int_iocb:	
    BANKSEL PORTB
    BTFSS   PORTB, UP
    INCF    PORTA	//Incremento
    
    BTFSS   PORTB, DOWN
    DECF    PORTA	//Decremento
    
    BCF	    RBIF	//Limpiar bandera
    
    RETURN
  
 int_timer0:
    reset_timer0    
    INCF    CONTT0
    MOVF    CONTT0, W
    SUBLW   100
    BTFSS   ZERO	//Verificar que ya sean 1000ms 
    GOTO    return_t0
    CLRF    CONTT0
    INCF    PORTC
    
 return_t0:    
    RETURN
    
    
 /*	    COONFIGURACIÓN uC		*/
 PSECT code, delta=2, abs	
 ORG 100h			//Dirección 100% seguro de que ya pasó el reseteo
 
 main:
    CALL    setup_io
    CALL    reloj
    CALL    timer0
    CALL    setup_io_ocB
    CALL    setup_int
    BANKSEL PORTA
    
 loop:
    
    GOTO    loop
 
 reloj:
    BANKSEL OSCCON
    BSF	SCS		//Activar oscilador interno
    
    // 1 MHz
    BSF IRCF2		// 1
    BCF IRCF1		// 0
    BCF IRCF0		// 0
    
    RETURN 

    
 timer0:
    // retraso de 10 ms
    // Fosc = 1MHz
    // PS = 256
    // T = 4 * Tosc * TMR0 * PS
    // Tosc = 1/Fosc
    // TMR0 = T * Fosc / (4 * PS) = 256-N
    // N = 256 - (10ms * 1MHz / (4 * 256))
    // N = 246 aprox
    
    BANKSEL OPTION_REG
    
    BCF T0CS	    //Funcionar como temporizador
    BCF PSA	    //Asignar Prescaler al Timer0
    
    //Prescaler de 1:256
    BSF PS2	    // 1
    BSF PS1	    // 1 
    BSF PS0	    // 1
    
    //Asignar los 100ms de retardo
    BANKSEL PORTA
    reset_timer0
    
    RETURN  
    

setup_io_ocB:
    BANKSEL IOCB
    BSF	    IOCB, UP
    BSF	    IOCB, DOWN
    
    BANKSEL PORTA
    MOVF    PORTB, W	//Se termina la condición de mismatch
    BCF	    RBIF	//Limpiar bandera
    
    RETURN  
    
 
 setup_io:
    
    BANKSEL ANSEL
    CLRF    ANSEL
    CLRF    ANSELH	//Digital in/out on A and B
    
    BANKSEL TRISB
    BSF	    TRISB, UP	//RB0 in
    BSF	    TRISB, DOWN	//RB1 in
    
    BANKSEL TRISA
    CLRF    TRISA	//Port A out
    CLRF    TRISC	//Port C out
    
    BANKSEL OPTION_REG
    BCF	    OPTION_REG, 7   //Pul up Port B enabled
    
    BANKSEL WPUB
    CLRF    WPUB	    //weak pull up disabled on all Port B
    BSF	    WPUB, UP
    BSF	    WPUB, DOWN	    //weak pull up enabled only on RB0 - RB1

    BANKSEL PORTA
    CLRF    PORTA
    CLRF    PORTC
    CLRF    PORTB	//Puertos limpios
    
    RETURN
    
    
 setup_int:
    BSF	    GIE		    //Global interruptions Enabled
    BSF	    RBIE	    //PORTB change interrupt enabled
    BCF	    RBIF	    //Limpiar bandera 
    
    BSF	    T0IE	    //Habilitar interrupción Timer0
    BCF	    T0IF	    //Limpiar bandera timer 0
    
    RETURN
    
 
 END


