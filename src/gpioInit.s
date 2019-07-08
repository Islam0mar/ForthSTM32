    @@ Serial terminal code common to all STM parts which share same UART layout
    @@    Define Terminal_USART_Base before use !
    .syntax unified
    .cpu cortex-m3
    .text
	.align	1
	.p2align 2,,3
    .include "stm32f103.i"
	.global	GPIO_Init
	.syntax unified
	.thumb
	.thumb_func
	.fpu softvfp
	.type	GPIO_Init, %function
    
    .equ Terminal_USART_Base   ,USART1_BASE   
    .equ Terminal_USART_SR     ,Terminal_USART_Base + 0x00
    .equ Terminal_USART_DR     ,Terminal_USART_Base + 0x04
    .equ Terminal_USART_BRR    ,Terminal_USART_Base + 0x08
    .equ Terminal_USART_CR1    ,Terminal_USART_Base + 0x0c
    .equ Terminal_USART_CR2    ,Terminal_USART_Base + 0x10
    .equ Terminal_USART_CR3    ,Terminal_USART_Base + 0x14
    .equ Terminal_USART_GTPR   ,Terminal_USART_Base + 0x18 

    @@Baudrate settings: Bit 11-4 Divider, Bit 3-0 Fractional

    @ Baud rate generation for 16 MHz:
    @ 16000000 / (16 * 115200 ) = 1000000 / 115200 = 8.6805
    @ 0.6805... * 16 = 10,8 rounds to 11 = B
    @ $8B

    @ For 8 MHz:

    @  8000000 / (16 * 115200 ) = 4.3403
    @  0.3403 * 16 = 5.4448
    @  Divider 4, Fractional term 5 or 6 --> $45 or $46.

    @ For 72 MHz:

    @  72000000 / (16 * 115200 ) = 39.0625
    @  0.0625 * 16 = 1 
    @  Divider 39, Fractional term 1 --> 0x271

    .macro Set_Terminal_USART_Baudrate
  
    @ Configure BRR by deviding the bus clock with the baud rate

    ldr r1, =Terminal_USART_BRR
    ldr r0, =0x271  @ 115200 bps
    str r0, [r1]

    @ Enable the USART, TX, interrupt , and RX circuit 
    ldr r1, =Terminal_USART_CR1
    ldr r0, = USART_CR1_UE| USART_CR1_TE | USART_CR1_RE | USART_CR1_RXNEIE
    str r0, [r1]

    .endm

@ Terminalroutinen
@ Terminal code and initialisations.
@ Porting: Rewrite this !

@ -----------------------------------------------------------------------------
GPIO_Init:
@ -----------------------------------------------------------------------------
  @ Most of the peripherals are connected to APB2.  Turn on the
  @ clocks for the interesting peripherals and all GPIOs.
    ldr r1, = RCC_APB2ENR
    ldr r0, [r1]
    orr r0, r0, #RCC_APB2ENR_AFIOEN|RCC_APB2ENR_IOPAEN|RCC_APB2ENR_IOPBEN|RCC_APB2ENR_IOPCEN|RCC_APB2ENR_AFIOEN|RCC_APB2ENR_USART1EN
    str r0, [r1]

   	/*
	 * Disable JTAG and SWO (Free PB3, PB4 and PA15)
	 */
    ldr r1, = AFIO_MAPR
    ldr r0, [r1]
    orr r0, r0, # AFIO_MAPR_SWJ_CFG_JTAGDISABLE
    str r0, [r1]

  @ Set PORTA pins in alternate function mode
  @ Put PA9  (TX) to alternate function output push-pull at 50 MHz
  @ Put PA10 (RX) to floating input
    ldr r1, = GPIOA_CRH
    ldr r0, = 0x000004B0      @  GPIO_CRH_MODE9 | GPIO_CRH_CNF9_1 | GPIO_CRH_CNF10_0 
    str r0, [r1]
	
    Set_Terminal_USART_Baudrate
	push {lr}
	mov r0, #37
	bl EnableIRQ
	pop {lr}
    bx lr
    .ltorg
    .end

