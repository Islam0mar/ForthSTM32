    .syntax unified
    .cpu cortex-m3
    .text
	.align	1
	.p2align 2,,3
	.global	SystemInit
	.syntax unified
	.thumb
	.thumb_func
	.fpu softvfp
	.type	SystemInit, %function
SystemInit:
	@ args = 0, pretend = 0, frame = 0
	@ frame_needed = 0, uses_anonymous_args = 0
	@ link register save eliminated.
	@@ push	{r4, r5}	@
@ system_stm32f1xx.c:214:   RCC->CIR = 0x009F0000;
	mov	r5, #10420224	@ tmp133,
@ system_stm32f1xx.c:226:   SCB->VTOR = FLASH_BASE | VECT_TAB_OFFSET; /* Vector Table Relocation in Internal FLASH. */
	mov	r4, #134217728	@ tmp135,
@ system_stm32f1xx.c:179:   RCC->CR |= (uint32_t)0x00000001;
	ldr	r3, .L4	@ tmp120,
@ system_stm32f1xx.c:183:   RCC->CFGR &= (uint32_t)0xF8FF0000;
	ldr	r2, .L4+4	@ _4,
@ system_stm32f1xx.c:179:   RCC->CR |= (uint32_t)0x00000001;
	ldr	r1, [r3]	@ _1, MEM[(struct RCC_TypeDef *)1073876992B].CR
@ system_stm32f1xx.c:226:   SCB->VTOR = FLASH_BASE | VECT_TAB_OFFSET; /* Vector Table Relocation in Internal FLASH. */
	ldr	r0, .L4+8	@ tmp134,
@ system_stm32f1xx.c:179:   RCC->CR |= (uint32_t)0x00000001;
	orr	r1, r1, #1	@ _2, _1,
	str	r1, [r3]	@ _2, MEM[(struct RCC_TypeDef *)1073876992B].CR
@ system_stm32f1xx.c:183:   RCC->CFGR &= (uint32_t)0xF8FF0000;
	ldr	r1, [r3, #4]	@ _3, MEM[(struct RCC_TypeDef *)1073876992B].CFGR
	ands	r2, r2, r1	@, _4, _4, _3
	str	r2, [r3, #4]	@ _4, MEM[(struct RCC_TypeDef *)1073876992B].CFGR
@ system_stm32f1xx.c:189:   RCC->CR &= (uint32_t)0xFEF6FFFF;
	ldr	r2, [r3]	@ _5, MEM[(struct RCC_TypeDef *)1073876992B].CR
	bic	r2, r2, #17301504	@ _6, _5,
	bic	r2, r2, #65536	@ _6, _6,
	str	r2, [r3]	@ _6, MEM[(struct RCC_TypeDef *)1073876992B].CR
@ system_stm32f1xx.c:192:   RCC->CR &= (uint32_t)0xFFFBFFFF;
	ldr	r2, [r3]	@ _7, MEM[(struct RCC_TypeDef *)1073876992B].CR
	bic	r2, r2, #262144	@ _8, _7,
	str	r2, [r3]	@ _8, MEM[(struct RCC_TypeDef *)1073876992B].CR
@ system_stm32f1xx.c:195:   RCC->CFGR &= (uint32_t)0xFF80FFFF;
	ldr	r2, [r3, #4]	@ _9, MEM[(struct RCC_TypeDef *)1073876992B].CFGR
	bic	r2, r2, #8323072	@ _10, _9,
	str	r2, [r3, #4]	@ _10, MEM[(struct RCC_TypeDef *)1073876992B].CFGR
@ system_stm32f1xx.c:214:   RCC->CIR = 0x009F0000;
	str	r5, [r3, #8]	@ tmp133, MEM[(struct RCC_TypeDef *)1073876992B].CIR
@ system_stm32f1xx.c:226:   SCB->VTOR = FLASH_BASE | VECT_TAB_OFFSET; /* Vector Table Relocation in Internal FLASH. */
	str	r4, [r0, #8]	@ tmp135, MEM[(struct SCB_Type *)3758157056B].VTOR
@ system_stm32f1xx.c:228: }
	@@ pop	{r4, r5}
	bx	lr	@
.L5:
	.align	2
.L4:
	.word	1073876992
	.word	-117506048
	.word	-536810240
	.size	SystemInit, .-SystemInit

	.end
	
