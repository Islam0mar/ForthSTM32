	.syntax unified
    .cpu cortex-m3
    .text
	.align	1
	.p2align 2,,3
    .include    "stm32f103.i"
	.global	USART1_IRQHandler
	.thumb
	.thumb_func
	.fpu softvfp
	.type	USART1_IRQHandler , %function
USART1_IRQHandler:
	ldr r0, = USART1_DR
	ldr r2, = var_FIFO_put			@ offset
	ldr r3, = FIFO
	ldr r1, [r2]
	ldrb r0, [r0]
	strb r0, [r3, r1]
	add r1, #1
	movw r3, #FIFO_SIZE -1
	and r1, r3
	str r1, [r2]
	bx lr
    .ltorg
	.align 2
	.global EnableIRQ
	.global DisableIRQ
	// r0 = IRQ num
EnableIRQ: 
	AND.W R1, R0, #0x1F
	MOV R2, #1
	LSL R2, R2, R1
	AND.W R1, R0, #0xE0
	LSR R1, R1, #3
	LDR R0,= NVIC_ISER0			@ ISER
	STR R2, [R0, R1]
	bx lr
	.align 2
DisableIRQ:
	AND.W R1, R0, #0x1F 
	MOV R2, #1
	LSL R2, R2, R1
	AND.W R1, R0, #0xE0 
	LSR R1, R1, #3
	LDR R0,= NVIC_ICER0 			@ ICER
	STR R2, [R0, R1]
	bx lr
 	.end
	
