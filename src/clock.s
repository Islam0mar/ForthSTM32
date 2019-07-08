@@@ set clock external 8Mhz PLL to 72Mhz
    .cpu cortex-m3
    .text
	.align	1
	.p2align 2,,3
	.include "stm32f103.i"
	.global	ClockInit
	.syntax unified
	.thumb
	.thumb_func
	.fpu softvfp
	.type	ClockInit, %function
ClockInit:
	@@ 2 wait latency for 72Mhz
	ldr r0, = FLASH_ACR
	ldr r1, [r0]
	orr r1, # FLASH_ACR_LATENCY_2 | FLASH_ACR_PRFTBE @ 2 wait states
	str r1, [r0]
	
    @@ orr r0, #RCC_CR_PLLON | RCC_CR_HSEON | RCC_CR_HSION
    ldr r1, = RCC_CR
    ldr r0, [r1]
    orr r0, #RCC_CR_HSEON
    str r0, [r1]

    @@ wait untill HSE is ready
w8:
    ldr r0, [r1]
    tst r0, RCC_CR_HSERDY
    beq w8

    @@ set PLL 72Mhz
    ldr r1, = RCC_CFGR
    ldr r0, [r1]
    ldr r2, =RCC_CFGR_PLLMULL9 | RCC_CFGR_PLLXTPRE_HSE | RCC_CFGR_PLLSRC_HSE | RCC_CFGR_PPRE1_DIV2 | RCC_CFGR_PPRE2_DIV1 | RCC_CFGR_HPRE_DIV1 | RCC_CFGR_ADCPRE_DIV6
    orr r0, r2
    str r0, [r1]
    ldr r1, = RCC_CR
    ldr r0, [r1]
    orr r0, #RCC_CR_PLLON
    str r0, [r1]
    
    @@ wait untill PLL is locked
wait:
    ldr r0, [r1]
    tst r0, RCC_CR_PLLRDY
    beq wait

    @@ 
    ldr r1, = RCC_CFGR
    ldr r0, [r1]
    orr r0, #RCC_CFGR_SW_PLL
    str r0, [r1]
    bx  lr
	nop							@ for cache

	.ltorg
    .end
