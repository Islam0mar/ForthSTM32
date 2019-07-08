	.title	"SFORTH"
	.set SFORTH_VERSION,1
	.thumb                  @ (same as saying '.code 16')
	.syntax unified
	.cpu cortex-m3
	.fpu softvfp
	.include    "stm32f103.i"

@@ Reserve three special registers: 
@@ SP(r13) stack pointer
@@ LR(r14) link register
@@ PC(r15) interpreter pointer points to the next line of code which will be excuted
@@ PSR program status register
@       ARM register usage
col .req 	r7 		@ absolute address of docol
up	.req	r8		@ user area pointer
do	.req 	r9 		@ absolute address of dodoes
tos	.req	r10		@ top of data stack item
fpc	.req 	r11		@ FORTH vm instruction ptr
rsp	.req 	r12		@ RETURN stack pointer
dsp	.req 	r13		@ DATA stack pointer

// NEXT macro
// NOTE!! support only thumb mode imply that bx take register with LSB is 1
// ,so force .thumb_func for all labels
	.macro NEXT
	ldr pc, [fpc], #4
	.endm

// return stack macors
	.macro pushR reg
	str \reg, [rsp, #-4]!
	.endm

	.macro popR reg
	ldr \reg, [rsp], #4
	.endm

	.macro pushTOS
	push {tos}
	.endm

// prevent underflow, mov has a limited value, so we shifted sp value to get twice the size of the stack and compare that with the max stack value defined in the linker script 
// should be twice the value in linker script 
	@@ .equ stack_end, 0x400

	.macro popTOS
	@@ mov r1, sp
	@@ and r1, #0x700
	@@ cmp r1 , # stack_end
	@@ poplt {tos}
	pop {tos}
	.endm

	.macro sendS
	ldr r6, = USART1_DR
111:
	ldr r0, = USART1_SR
	ldr r0, [r0]
	tst r0, # USART_SR_TXE      
	beq 111b                
	ldrb r0, [r1], #1
	strb r0, [r6]
	subs r2, #1
	bne 111b
222:
	ldr r0, = USART1_SR
	ldr r0, [r0]
	tst r0, # USART_SR_TC
	beq 222b
	.endm
	
/* DOCOL - the interpreter! */
	.text
	.align	1
	.p2align 2,,3
	.thumb
	.thumb_func
	.fpu softvfp
	.type	DOCOL, %function
DOCOL:
	pushR fpc		    @@ push fpc on to the return stack
	sub fpc, lr, #1		@@ -1 due to thumb mode
	NEXT
@@ @@@ set offset to get DODOES address from DOCOL address
@@ 	.set x, .-DOCOL
@@ 	.set v, x-1					
@@ 	.set v, v | (v >> 1)
@@ 	.set v, v | (v >> 2)
@@ 	.set v, v | (v >> 4)
@@ 	.set v, v | (v >> 8)
@@ 	.set v, v | (v >> 16)
@@ 	.set v,  v+1;				@ v = nearest power of 2 (x)
@@ 	.macro  sum param=0, to=v
@@     .if     \to-(1 << \param)
@@     sum     "(\param+1)",\to
@@     .else
@@ 	.set offset, \param			@ offset = ln2(x)
@@ 	.endif
@@     .endm
@@ 	sum
@@ 	.rept (v-x)/2				@ padding to align to the offset power of 2
@@ 	nop
@@ 	.endr
	
/* DODOES for OOP */
	.text
	.align	1
	.p2align 2,,3
	.thumb
	.thumb_func
	.fpu softvfp
	.type	DODOES, %function
DODOES:
	ldr r0, [lr, #-1]!
	cbz r0, 1f					@ Is offset zero ?
	pushR fpc 						@ push fpc on return stack
	mov fpc, lr							@  Get pointer to behavior words
1:	pushTOS							@ Push the pointer to its data
	add tos, lr, #4					@ Data field pointer
	NEXT
	
/* Assembler entry point. */
	.text
	.align	1
	.p2align 2,,3
	.globl main
	.syntax unified
	.thumb
	.thumb_func
	.fpu softvfp
	.type	main, %function
main:
	cpsid i			@ disable interrupt
	ldr rsp, =return_stack_top      @ Set the initial return stack position
	bl ClockInit
	bl set_up_data_segment         @ Set up the data segment
	bl GPIO_Init
	bl set_up_vectorTable_RAM
	cpsie i			@ enable interrupt
	ldr up, = var_MAIN+4		@ follower for multitasking
	ldr col, = DOCOL			@ absolute adrress for docol to be used in every new word "bx col"
	ldr do, = DODOES
	ldr fpc, = var_BOOT            @ Make the fpc point to BOOT
	ldr r0, = start
	mov r1, #(startend-start)

	bl _FIND
	cmp r0, #0
	blne _TCFA
	bxne r0
	
	NEXT                            @ Start the interpreter
	.ltorg

	.section .rodata
	.align 2
start:
	.ascii "START"
startend:
	.align 2

	
	.align	1
	.p2align 2,,3
	.thumb
	.thumb_func
	.fpu softvfp
	.type	set_up_vectorTable_RAM, %function
set_up_vectorTable_RAM:	
	cpsid i
	ldr r0, = SCB_VTOR
	ldr r1, = SCB_VTOR_TBLBASE 	@ RAM with offest 0, start at 0x20000000
	str r1, [r0]
	dsb							@ wait for store to complete
	cpsie i
	bx lr

// should be the first thing in .data section and in ram
	.align 2
	.equ  BootRAM, 0xF108F85F
	.data
vectorTable_RAM:
	.4byte __stack_end__
	.4byte Reset_Handler
	.4byte NMI_Handler
	.4byte HardFault_Handler
	.4byte MemManage_Handler
	.4byte BusFault_Handler
	.4byte UsageFault_Handler
	.4byte 0
	.4byte 0
	.4byte 0
	.4byte 0
	.4byte SVC_Handler
	.4byte DebugMon_Handler
	.4byte 0
	.4byte PendSV_Handler
	.4byte SysTick_Handler
	.4byte WWDG_IRQHandler 		//  <= external interrupts    ||
	.4byte PVD_IRQHandler  		//                            \/
	.4byte TAMPER_IRQHandler
	.4byte RTC_IRQHandler
	.4byte FLASH_IRQHandler
	.4byte RCC_IRQHandler
	.4byte EXTI0_IRQHandler
	.4byte EXTI1_IRQHandler
	.4byte EXTI2_IRQHandler
	.4byte EXTI3_IRQHandler
	.4byte EXTI4_IRQHandler
	.4byte DMA1_Channel1_IRQHandler
	.4byte DMA1_Channel2_IRQHandler
	.4byte DMA1_Channel3_IRQHandler
	.4byte DMA1_Channel4_IRQHandler
	.4byte DMA1_Channel5_IRQHandler
	.4byte DMA1_Channel6_IRQHandler
	.4byte DMA1_Channel7_IRQHandler
	.4byte ADC1_2_IRQHandler
	.4byte USB_HP_CAN1_TX_IRQHandler
	.4byte USB_LP_CAN1_RX0_IRQHandler
	.4byte CAN1_RX1_IRQHandler
	.4byte CAN1_SCE_IRQHandler
	.4byte EXTI9_5_IRQHandler
	.4byte TIM1_BRK_IRQHandler
	.4byte TIM1_UP_IRQHandler
	.4byte TIM1_TRG_COM_IRQHandler
	.4byte TIM1_CC_IRQHandler
	.4byte TIM2_IRQHandler
	.4byte TIM3_IRQHandler
	.4byte TIM4_IRQHandler
	.4byte I2C1_EV_IRQHandler
	.4byte I2C1_ER_IRQHandler
	.4byte I2C2_EV_IRQHandler
	.4byte I2C2_ER_IRQHandler
	.4byte SPI1_IRQHandler
	.4byte SPI2_IRQHandler
	.4byte USART1_IRQHandler
	.4byte USART2_IRQHandler
	.4byte USART3_IRQHandler
	.4byte EXTI15_10_IRQHandler
	.4byte RTC_Alarm_IRQHandler
	.4byte USBWakeUp_IRQHandler
	/*.4byte 0
	.4byte 0
	.4byte 0
	.4byte 0
	.4byte 0
	.4byte 0
	.4byte 0
	//.4byte BootRAM */         /* @0xF108F85F. This is for boot in RAM mode*/
	.section .data
	.global	FIFO_put
	.global FIFO_get
	.global	FIFO
	.global	FIFO_end
	.align 2
FIFO_put:
	.4byte 0
FIFO_get:
	.4byte 0
FIFO:
	.space FIFO_SIZE
FIFO_end:
	.align 2
	.align
	
// data poiter initializer to last used ram segment .bss
	.text
	.thumb
	.thumb_func
	.align	1
	.p2align 2,,3
set_up_data_segment:
	push {r4}
	ldr r1, =var_DP
	ldr r2, =var_FLASH
	ldr r3, =var_RAM
	ldr r0, =end			 @ end defined in linker script to specify the end of ram usage
    str r0, [r1]            @ Initialize DP to point at the beginning of data segment
	// TODO function to compile in flash
	str r0, [r3]			@ start of free region in RAM
	ldr r0, =_code			@ last unsed area in FLASH
@@@ search for last used flash
1:	ldr r1, [r0]
	adds r1, #1
	addcc r0, #2
	bcc 1b
	ldr r1, [r0, #4]
	adds r1, #1
	addcc r0, #2
	bcc 1b
	str r0, [r2]			@ start of free region in FLASH
@@@ search for the new value of LATEST
	ldr r2, = QUIT
	ldrh r2, [r2, #-1] 			@ get "blx col"
	ldrh r4, = DODOES_ADRS		@ get "blx do"
	
1:	ldrh r1, [r0,#-2]!
	cmp r1, r2
	cmpne r1, r4
	bne 1b 						@ iterate till the code field ends

	@@ flash end = 0x08010000
	mov r2, 0x0800
1:	ldr r1, [r0,#-2]!			@ due to the 2-byte saving made in docol
	lsr r3, r1, 16
	cmp r3, r2				   @ align as a multiple of 8 ,so can't have 00 as padding and 0 isn't a valid for names 
	bne 1b						@ iterate till the length and name ends

	ldr r1, =var_LATEST
    ldr r2, =var_F_LATEST
    str r0, [r1]
	str r0, [r2]

	pop {r4}
    bx      lr              @ Return
	.ltorg
	
/* Flags - these are discussed later. */
	.set F_IMMED,0x80   // immediate
	.set F_COMPO,0x40   // compile only
	.set F_HIDDEN,0x20  // hidden
	.set F_LENMASK,0x1f	// length mask

// Store the chain of links.
	.set link,0

	.macro defword name, namelen, flags=0, label
	.text
	.align	2
	.globl name_\label
name_\label :
	.4byte link		// link
	.set link,name_\label
	.byte \flags+\namelen	// flags + length byte
	.ascii "\name"		// the name
	.align	2		// padding to next 2 byte boundary
	.align	1
	.p2align 2,,3
	.globl \label
	.thumb
	.thumb_func // should be used to get the correct address when being called with bx
	.fpu softvfp
	.type	\label, %function
\label :
	blx col 		// enter docolon
	// list of word pointers follow
	.endm

	.macro defcode name, namelen, flags=0, label
	.text
	.align	2
	.globl name_\label
name_\label :
	.4byte link		// link
	.set link,name_\label
	.byte \flags+\namelen	// flags + length byte
	.ascii "\name"		// the name
	.align	2		// padding to next 2 byte boundary
	.align	1
	.p2align 2,,3
	.globl \label
	.thumb
	.thumb_func  	 // should be used to get the correct address when being called with bx
	.fpu softvfp
	.type	\label, %function
\label :			// assembler code follows
	.endm

/*
	Most of the following code is taken from
	jonesforth port to arm with minimum 
	change to be direct threaded code


	*/
@@@ assembly words
@@@ DROP ( a -- ) drops the top element of the stack
	defcode "DROP",4,,DROP
	popTOS
	NEXT
	
@ SWAP ( a b -- b a )
	defcode "SWAP",4,,SWAP
	pop {r0}       @ swap top two elements on stack
	pushTOS
	mov tos, r0
	NEXT
	
@ DUP ( a -- a a )
	defcode "DUP",3,,DUP
    push {tos}        
    NEXT		    
	
@ ( a b c -- a b c b ) 
	defcode "OVER",4,,OVER
	@@ ( a b c) r0 = b we take the element at DSP + 4
    @@ and since DSP is the top of the stack we will load
    @@ the second element of the stack in r0
	pushTOS
    ldr tos, [sp, #4]        
    NEXT

@@ ROT ( a b c -- b c a) rotation
    defcode "ROT",3,,ROT
    pop {r0}          	@ ( a ) r0 = b
    pop {r1}          	@ (  ) r1 = a
    push {r0}         	@ ( b )
    pushTOS        		@ ( b c )
    mov tos, r1         @ ( b c a )
    NEXT
	
@ -ROT ( a b c -- c a b ) backwards rotation	
	defcode "-ROT",4,,NROT
    pop {r0}          	@ ( a ) r0 = b
    pop {r1}          	@ ( ) r1 = a
    pushTOS         	@ ( c )
    push {r1}         	@ ( c a )
    mov tos, r0         	@ ( c a b )
    NEXT
	
@@@ ( a b -- )
	defcode "2DROP",5,,TWODROP // drop top two elements of stack
	popTOS
	popTOS
	NEXT

@@@ (a b -- a b a b)
	defcode "2DUP",4,,TWODUP // duplicate top two elements of stack
	ldr r0, [sp]		@ ( a b ), r0 = a
    pushTOS        		@ ( a b b ) 
    push {r0}        @ ( a b a b  ) , r0 = a
	NEXT

@@@ ( a b c d -- c d a b)
	defcode "2SWAP",5,,TWOSWAP // swap top two pairs of elements of stack
	pop {r0}				   	@ ( a b d), r0 = c
	pop {r1}					@ (a d), r1 = b
	pop {r2}					@ ( d ), r2 = a
	push {r0}
	pushTOS
	push {r2}
	mov tos, r1
	NEXT

@ ?DUP ( 0 -- 0 | a -- a a ) duplicates if non-zero
	defcode "?DUP",4,,QDUP	// duplicate top of stack if non-zero
    cmp tos, #0     @ test if x==0
    beq 1f          @ if x==0 we jump to 1
    pushTOS        @ ( a a ) it's now duplicated
1:	NEXT         @ ( a a / 0 )

@ 1+ ( a | a+1 ) increments the top element
    defcode "1+",2,,INCR
    add tos,tos,#1
    NEXT
    
    defcode "1-",2,,DECR
    sub tos,tos,#1
    NEXT

    defcode "4+",2,,INCR4
    add tos,tos,#4
    NEXT

    defcode "4-",2,,DECR4
    sub tos,tos,#4
    NEXT

    defcode "+",1,,ADD
    pop {r0}
    add tos, r0, tos
    NEXT

    defcode "-",1,,SUB
    pop {r0}
    sub tos, r0, tos
    NEXT


    defcode "*",1,,MUL
    pop {r0}
    mul tos, r0, tos
    NEXT

    defcode "/",1,,DIV
	pop {r0}
	UDIV tos, r0, tos
	NEXT

/*
	In this FORTH, only /MOD and U/MOD is primitive.  Later we will define the /, MOD and other words in
	terms of the primitives /MOD and U/MOD.  The design of the i386 assembly instructions idiv and div which
	leave both quotient and remainder makes this the obvious choice.
*/
@ ( a b -- r q ) where a = q * b + r
	defcode "/MOD",4,,DIVMOD
	pop {r0}
	mov r1, tos
	SDIV tos,r0,tos				@ quotient
    MUL r1,r1,tos
    sub r1,r0,r1
	push {r1}		    		@ push remainder
    NEXT

@ ( a b -- r q ) where a = q * b + r
	defcode "U/MOD",5,,UDIVMOD
	pop {r0}
	mov r1, tos
	UDIV tos,r0,tos				@ quotient
    MUL r1,r1,tos
    sub r1,r0,r1
	push {r1}		    		@ push remainder
    NEXT

/*
	Lots of comparison operations like =, <, >, etc..

	ANS FORTH says that the comparison words should return all (binary) 1's for
	TRUE and all 0's for FALSE.  This is a bit of a strange convention for C
	programmers ...
	Anyway, -1 meaning TRUE and 0 meaning FALSE.
*/
@ = ( a b | p ) where p is 1 when a and b are equal (0 otherwise)

    defcode "=",1,,EQU	// top two words are equal?
    pop {r0}
    cmp r0, tos
    moveq tos, #1
    movne tos, #0
    NEXT

	defcode "<>",2,,NEQU	// top two words are not equal?
    pop {r0}
    cmp r0, tos
    movne tos, #1
    moveq tos, #0
    NEXT

	defcode "<",1,,LT
    pop {r0}
    cmp r0, tos
    movlt tos, #1
    movge tos, #0
    NEXT

	defcode ">",1,,GT
    pop {r0}
    cmp r0, tos
    movgt tos, #1
    movle tos, #0
    NEXT

	defcode "<=",2,,LE
    pop {r0}
    cmp r0, tos
    movle tos, #1
    movgt tos, #0
    NEXT

	defcode ">=",2,,GE
    pop {r0}
    cmp r0, tos
    movge tos, #1
    movlt tos, #0
    NEXT

	defcode "0=",2,,ZEQU	// top of stack equals 0?
    cmp tos, #0
    moveq tos, #1
    movne tos, #0
    NEXT

	defcode "0>",2,,ZGT
    cmp tos, #0
    movgt tos, #1
    movle tos, #0
    NEXT

	defcode "0<",2,,ZLT	// comparisons with 0
    cmp tos, #0
    movlt tos, #1
    movge tos, #0
    NEXT

	defcode "0<>",3,,ZNEQU	// top of stack not 0?
    cmp tos, #0
    movne tos, #1
    moveq tos, #0
    NEXT

	defcode "AND",3,,AND	// bitwise AND
	pop {r0}
    and tos, r0, tos
    NEXT

	defcode "OR",2,,OR	// bitwise OR
	pop {r0}
    orr tos, r0, tos
    NEXT

	defcode "XOR",3,,XOR	// bitwise XOR
	pop {r0}
    eor tos, r0, tos
    NEXT

	defcode "INVERT",6,,INVERT // this is the FORTH bitwise "NOT" function (cf. NEGATE and NOT)
    mvn tos, tos
	NEXT

	defcode "EXIT",4,,EXIT
	popR fpc	            @ pop return stack into %esi
    NEXT

	defcode "EXITISR",7,,EXITISR
	mrs r0, ipsr
	cbz r0, 1f
	bx lr
1:	popR fpc	            @ pop return stack into %esi
    NEXT
    
@ LIT is used to compile literals in forth word.
@ When LIT is executed it pushes the literal (which is the next codeword)
@ into the stack and skips it (since the literal is not executable).

    defcode "LIT",3,F_COMPO,LIT
	pushTOS
    ldr tos, [fpc], #4
    NEXT

@@@ writes "b docol" for new words
	defcode "DOCOL,",6,F_COMPO,DOCOL_COMMA
	ldr r1, = QUIT
	ldrh r0, [r1, #-1] 			@ get "b docol"  

	ldr     r1, =var_DP
    ldr     r2, [r1]        @ read DP
	
2:  strh     r0, [r2], #2    @ write value and increment address
    str     r2, [r1]        @ update DP
    NEXT

@ C! and @! are the same for bytes
    defcode "C!",2,,STOREBYTE
    pop {r0}
    strb r0, [tos]
	popTOS
    NEXT


    defcode "C@",2,,FETCHBYTE
    ldrb tos, [tos]
    NEXT

    @ ! ( value address -- ) write value at address
	defcode "!",1,,STORE
    pop {r0}
    str r0, [tos]
	popTOS
    NEXT

	@@ +! ( +amount addrs  -- )
	defcode "+!",2,,ADDSTORE
	pop {r0}		// the amount to add
	ldr r1, [tos]
	add r1, r0	// add it
	str r1, [tos]
	popTOS
	NEXT

	@@ -! ( -amount addrs  -- )
	defcode "-!",2,,SUBSTORE
	pop {r0}		// the amount to sub
	ldr r1, [tos]
	sub r1, r0	// add it
	str r1, [tos]
	popTOS
	NEXT

	defcode "@",1,,FETCH
	@ @ ( address -- value ) reads value from address
    ldr tos, [tos]
    NEXT

/* and CMOVE is a block copy operation. */
@@@ ( source dest length -- )
	defcode "CMOVE",5,,CMOVE
    pop {r0}
    pop {r1}
1:
    cmp tos, #0              @ while length > 0
    ldrbgt r3, [r1], #1     @ read character from source
    strbgt r3, [r0], #1     @ and write it to dest (increment both pointers)
    subgt tos, tos, #1        @ decrement length
    bgt 1b
	popTOS
    NEXT

/*
	BUILT-IN VARIABLES ----------------------------------------------------------------------

	These are some built-in variables and related standard FORTH words.  Of these, the only one that we
	have discussed so far was LATEST, which points to the last (most recently defined) word in the
	FORTH dictionary.  LATEST is also a FORTH word which pushes the address of LATEST (the variable)
	on to the stack, so you can read or write it using @ and ! operators.  For example, to print
	the current value of LATEST (and this can apply to any FORTH variable) you would do:

	LATEST @ . CR

	To make defining variables shorter, I'm using a macro called defvar, similar to defword and
	defcode above.  (In fact the defvar macro uses defcode to do the dictionary header).
*/

	.macro defvar name, namelen, flags=0, label, initial=0
	defcode \name,\namelen,\flags,\label
	pushTOS
	ldr tos, = var_\name
	NEXT
	.data
	.align	2
var_\name:
	.4byte \initial
	.endm

/*
	The built-in variables are:

	STATE		Is the interpreter executing code (0) or compiling a word (non-zero)?
	LATEST		Points to the latest (most recently defined) word in the dictionary.
	DP		Points to the next free byte of memory.  When compiling, compiled words go here.
	S0		Stores the address of the top of the parameter stack.
	BASE		The current base for printing and reading numbers.

	*/
	/* RAM vector table*/

	defvar "STATE",5,,STATE
	defvar "DP",2,,DP
	defvar "FLASH",5,,FLASH		// latest flash position
	defvar "RAM",3,,RAM			// latest ram position 
	defvar "LATEST",6,,LATEST,name_QUIT @ latest defined word
	defvar "F_LATEST",8,,F_LATEST,name_QUIT @ latest defined word FLASH
	defvar "BASE",4,,BASE,10
	defvar "S0",2,,SZ,__stack_end__
	defvar "R0",2,,RZ,return_stack_top
	defvar "BOOT",4,,BOOT,QUIT

	defvar "FIFO",4,,_FIFO,FIFO
	defvar "FIFO_put",8,,_FIFO_put,FIFO_put
	defvar "FIFO_get",8,,_FIFO_get,FIFO_get
	
	.macro defconst name, namelen, flags=0, label, value
	defcode \name,\namelen,\flags,\label
	pushTOS
	ldr tos, = \value
	NEXT
	.endm

	defconst "VERSION",7,,VERSION,SFORTH_VERSION
	defconst "F_IMMED",7,,__F_IMMED,F_IMMED
	defconst "F_COMPO",7,,__F_COMPO,F_COMPO
	defconst "F_HIDDEN",8,,__F_HIDDEN,F_HIDDEN
	defconst "F_LENMASK",9,,__F_LENMASK,F_LENMASK

	defconst "O_RDONLY",8,,__O_RDONLY,0
	defconst "O_WRONLY",8,,__O_WRONLY,1
	defconst "O_RDWR",6,,__O_RDWR,2
	defconst "O_CREAT",7,,__O_CREAT,0100
	defconst "O_EXCL",6,,__O_EXCL,0200
	defconst "O_TRUNC",7,,__O_TRUNC,01000
	defconst "O_APPEND",8,,__O_APPEND,02000
	defconst "O_NONBLOCK",10,,__O_NONBLOCK,04000

	defconst "__stack_end__",13,,foo0,vectorTable_RAM + 4*0
	defconst "Reset_Handler",13,,foo1,vectorTable_RAM + 4*1 
	defconst "NMI_Handler",11,,foo2,vectorTable_RAM + 4*2 
	defconst "HardFault_Handler",17,,foo3,vectorTable_RAM + 4*3
	.ltorg
	defconst "MemManage_Handler",17,,foo4,vectorTable_RAM + 4*4 
	defconst "BusFault_Handler",16,,foo5,vectorTable_RAM + 4*5 
	defconst "UsageFault_Handler",18,,foo6,vectorTable_RAM + 4*6 
	defconst "SVC_Handler",11,,foo7,vectorTable_RAM + 4*11 
	defconst "DebugMon_Handler",16,,foo8,vectorTable_RAM + 4*12 
	defconst "PendSV_Handler",14,,foo9,vectorTable_RAM + 4*14 
	defconst "SysTick_Handler",15,,foo10,vectorTable_RAM + 4*15 
	defconst "WWDG_IRQHandler",15,,foo11,vectorTable_RAM + 4*16
	.ltorg
	defconst "PVD_IRQHandler",14,,foo12,vectorTable_RAM + 4*17   
	defconst "TAMPER_IRQHandler",17,,foo13,vectorTable_RAM + 4*18 
	defconst "RTC_IRQHandler",14,,foo14,vectorTable_RAM + 4*19 
	defconst "FLASH_IRQHandler",16,,foo15,vectorTable_RAM + 4*20 
	defconst "RCC_IRQHandler",14,,foo16,vectorTable_RAM + 4*21 
	defconst "EXTI0_IRQHandler",16,,foo17,vectorTable_RAM + 4*22 
	defconst "EXTI1_IRQHandler",16,,foo18,vectorTable_RAM + 4*23 
	defconst "EXTI2_IRQHandler",16,,foo19,vectorTable_RAM + 4*24 
	defconst "EXTI3_IRQHandler",16,,foo20,vectorTable_RAM + 4*25 
	defconst "EXTI4_IRQHandler",16,,foo21,vectorTable_RAM + 4*26 
	.ltorg
	defconst "DMA1_Channel1_IRQHandler",24,,foo22,vectorTable_RAM + 4*27 
	defconst "DMA1_Channel2_IRQHandler",24,,foo23,vectorTable_RAM + 4*28 
	defconst "DMA1_Channel3_IRQHandler",24,,foo24,vectorTable_RAM + 4*29 
	defconst "DMA1_Channel4_IRQHandler",24,,foo25,vectorTable_RAM + 4*30 
	defconst "DMA1_Channel5_IRQHandler",24,,foo26,vectorTable_RAM + 4*31 
	defconst "DMA1_Channel6_IRQHandler",24,,foo27,vectorTable_RAM + 4*32 
	defconst "DMA1_Channel7_IRQHandler",24,,foo28,vectorTable_RAM + 4*33 
	defconst "ADC1_2_IRQHandler",17,,foo29,vectorTable_RAM + 4*34 
	defconst "USB_HP_CAN1_TX_IRQHandler",25,,foo30,vectorTable_RAM + 4*35 
	defconst "USB_LP_CAN1_RX0_IRQHandler",26,,foo31,vectorTable_RAM + 4*36
	defconst "CAN1_RX1_IRQHandler",19,,foo32,vectorTable_RAM + 4*37 
	defconst "CAN1_SCE_IRQHandler",19,,foo33,vectorTable_RAM + 4*38 
	defconst "EXTI9_5_IRQHandler",18,,foo34,vectorTable_RAM + 4*39 
	defconst "TIM1_BRK_IRQHandler",19,,foo35,vectorTable_RAM + 4*40 
	defconst "TIM1_UP_IRQHandler",18,,foo36,vectorTable_RAM + 4*41 
	defconst "TIM1_TRG_COM_IRQHandler",23,,foo37,vectorTable_RAM + 4*42
	defconst "TIM1_CC_IRQHandler",18,,foo38,vectorTable_RAM + 4*43 
	defconst "TIM2_IRQHandler",15,,foo39,vectorTable_RAM + 4*44 
	defconst "TIM3_IRQHandler",15,,foo40,vectorTable_RAM + 4*45 
	defconst "TIM4_IRQHandler",15,,foo41,vectorTable_RAM + 4*46 
	defconst "I2C1_EV_IRQHandler",18,,foo42,vectorTable_RAM + 4*47
	defconst "I2C1_ER_IRQHandler",18,,foo43,vectorTable_RAM + 4*48
	defconst "I2C2_EV_IRQHandler",18,,foo44,vectorTable_RAM + 4*49
	defconst "I2C2_ER_IRQHandler",18,,foo45,vectorTable_RAM + 4*50
	defconst "SPI1_IRQHandler",15,,foo46,vectorTable_RAM + 4*51 
	defconst "SPI2_IRQHandler",15,,foo47,vectorTable_RAM + 4*52 
	defconst "USART1_IRQHandler",17,,foo48,vectorTable_RAM + 4*53 
	defconst "USART2_IRQHandler",17,,foo49,vectorTable_RAM + 4*54 
	defconst "USART3_IRQHandler",17,,foo50,vectorTable_RAM + 4*55 
	defconst "EXTI15_10_IRQHandler",20,,foo51,vectorTable_RAM + 4*56 
	defconst "RTC_Alarm_IRQHandler",20,,foo52,vectorTable_RAM + 4*57
	defconst "USBWakeUp_IRQHandler",20,,foo53,vectorTable_RAM + 4*58
	//defconst "BootRAM",7,,foo54,vectorTable_RAM + 4*66
	/* @0xF108F85F. This is for boot in RAM mode*/

/*
	RETURN STACK ----------------------------------------------------------------------
*/
@ >R ( a --  )
    defcode ">R",2,,TOR
    pushR tos
	popTOS
    NEXT

@ R> ( -- a ) move the top element from the return stack to the data stack

    defcode "R>",2,,FROMR
	pushTOS
	popR tos
    NEXT

@ RDROP drops the top element from the return stack

    defcode "RDROP",5,,RDROP
    add rsp,rsp,#4
    NEXT

@ RSP@, RSP!, DSP@, DSP! manipulate the return and data stack pointers

    defcode "RSP@",4,,RSPFETCH
	pushTOS
    mov tos, rsp
    NEXT

    defcode "RSP!",4,,RSPSTORE
	mov rsp, tos
	popTOS
    NEXT

/*
	PARAMETER (DATA) STACK ----------------------------------------------------------------------


    */
    defcode "DSP@",4,,DSPFETCH
	pushTOS
    mov tos, sp
    NEXT

    defcode "DSP!",4,,DSPSTORE
    mov sp, tos
    NEXT

@ ( -- 0|c ) Receive one character
    defcode "KEY?",4,,ISKEY    
    ldr r1, = USART1_SR
	ldr r0, [r1]
	tst r0, # USART_SR_RXNE        @ Check for reception 
	pushTOS
	moveq tos, #0
	ldrne r0, = USART1_DR
	ldrbne tos, [r0]
	NEXT
	
@ ( -- c ) Receive one character
    defcode "KEY",3,,KEY    
	bl _KEY                 @ Call _KEY
	mov tos, r0          	@ push the return value on the stack
	NEXT

_KEY:
	ldr r2, = FIFO_put
1:	ldr r0, [r2]			@ top FIFO 
	ldr r3, = FIFO_get      
	ldr r1, [r3]			@ currkey
	cmp r0, r1				
	beq 1b
	ldr r2 , = FIFO
	ldrb r0, [r2, r1]		@ load the first byte of currkey
	movw r2, # FIFO_SIZE -1
	add r1, #1
	and r1, r2				@ Increments CURRKEY
	str r1, [r3]
	bx lr                   @ return
    .ltorg
	
@@@ ( c -- )
	defcode "EMIT",4,,EMIT
	ldr r1, = USART1_SR
emitPoll:
	ldr r0, [r1]
	tst r0, # USART_SR_TXE     @ Check for reception 
	beq emitPoll                @ quit if not
	ldr r0, = USART1_DR
	strb tos, [r0]
	popTOS
	NEXT

@ WORD ( -- addr length ) reads next word from stdin
@ skips spaces and comments, limited to 32 characters 
	defcode "WORD",4,,WORD
	bl _WORD
	pushTOS
        push {r0}                 @ address
        mov tos, r1                 @ length
        NEXT
_WORD:
	push {r4, lr}
1:	bl _KEY                   @ read a character
	cmp r0, #'\\'
	beq 3f                  @ skip comments until end of line
	cmp r0, #' '
	ble 1b                  @ skip blank character
	
	ldr     r4, =word_buffer
2:	strb r0, [r4], #1       @ store character in word buffer
	bl _KEY                   @ read more characters until a space is found
	cmp r0, #' '
	bgt 2b

	ldr r0, =word_buffer    @ r0, address of word
	sub r1, r4, r0          @ r1, length of word

	pop {r4, pc}
3:
	bl _KEY                 @ skip all characters until end of line
	cmp r0, #'\n'
	bne 3b
	b 1b
@ word_buffer for WORD
    .data
word_buffer:
    .space 32
    
@ NUMBER ( addr length -- n e ) converts string to number
@ n is the parsed number
@ e is the number of unparsed characters

	defcode "NUMBER",6,,NUMBER
	pop {r0}						@ addr
	mov r1, tos
        bl _NUMBER
        push {r0}
        mov tos, r1
        NEXT

_NUMBER:
        stmfd sp!, {r3-r6, lr}

        @ Save address of the string.
        mov r2, r0

        @ r0 will store the result after conversion.
        mov r0, #0

        @ Check if length is positive, otherwise this is an error.
        cmp r1, #0
        ble 5f

        @ Load current base.
        ldr r3, =var_BASE
        ldr r3, [r3]

        @ Load first character and increment pointer.
        ldrb r4, [r2], #1

        @ Check trailing '-'.
        mov r5, #0
        cmp r4, #45 @ 45 in '-' en ASCII
        @ Number is positive.
        bne 2f
        @ Number is negative.
        mov r5, #1
        sub r1, r1, #1

        @ Check if we have more than just '-' in the string.
        cmp r1, #0
        @ No, proceed with conversion.
        bgt 1f
        @ Error.
        mov r1, #1
        b 5f
1:
        @ number *= BASE
        @ Arithmetic shift right.
        @ On ARM we need to use an additional register for MUL.
        mul r0, r0, r3

        @ Load the next character.
        ldrb r4, [r2], #1
2:
        @ Convert the character into a digit.
        sub r4, r4, #48 @ r4 = r4 - '0'
        cmp r4, #0
        blt 4f @ End, < 0
        cmp r4, #9
        ble 3f @ chiffre compris entre 0 et 9

        @ Test if hexadecimal character.
        sub r4, r4, #17 @ 17 = 'A' - '0'
        cmp r4, #0
        blt 4f @ End, < 'A'
        add r4, r4, #10
3:
        @ Compare to the current base.
        cmp r4, r3
        bge 4f @ End, > BASE

        @ Everything is fine.
        @ Add the digit to the result.
        add r0, r0, r4
        sub r1, r1, #1

        @ Continue processing while there are still characters to read.
        cmp r1, #0
        bgt 1b
4:
        @ Negate result if we had a '-'.
        cmp r5, #1
        rsbeq r0, r0, #0
5:
        @ Back to the caller.
        ldmfd sp!, {r3-r6, pc}
	


@ PAREN_FIND ( addr length -- dictionary_address )
@ Tries to find a word in the dictionary and returns its address.
@ If the word is not found, NULL is returned.

	defcode "(FIND)",6,,PAREN_FIND
	mov r1, tos  @length
	pop {r0} @addr
        bl _FIND
        mov tos, r0
        NEXT

_FIND:
        stmfd   sp!, {r3,r4,r5,r6}      @ save callee save registers
        ldr r2, =var_LATEST
        ldr r3, [r2]                    @ get the last defined word address
	    mov r5, r0                      @ r5 contains searched string

1:
        cmp r3, #0                      @ did we check all the words ?
        beq 4f                          @ then exit

        ldrb r2, [r3, #4]               @ read the length field
        and r2, r2, #(F_HIDDEN|F_LENMASK) @ keep only length + hidden bits
        cmp r2, r1                      @ do the lengths match ?
                                        @ (note that if a word is hidden,
                                        @  the test will be always negative)
        bne 3f                          @ branch if they do not match
                                        @ Now we compare strings characters
        mov r6, r3                      @ r6 contains dict string
        add r6, r6, #5                  @ (we skip link and length fields)
                                        @ r2 contains the length

2:
        ldrb r4, [r5], #1               @ compare character per character
        ldrb r0, [r6], #1
    	cmp r4,r0
		subne r2, r1, r2
		addne r2, #1
		subne r5, r2
        bne 3f                          @ if they do not match, branch to 3
        subs r2,r2,#1                   @ decrement length
        bne 2b                          @ loop

                                        @ here, strings are equal
        b 4f                            @ branch to 4

3:
        ldr r3, [r3]                    @ Mismatch, follow link to the next
        b 1b                            @ dictionary word
4:
        mov r0, r3                      @ move result to r0
        ldmfd   sp!, {r3,r4,r5,r6}      @ restore callee save registers
        bx lr
@ >CFA ( dictionary_address -- executable_address )
@ Transformat a dictionary address into a code field address

	defcode ">CFA",4,,TCFA
	mov r0,tos
        bl _TCFA
        mov tos, r0
        NEXT
_TCFA:
        add r0,r0,#4            @ skip link field
        ldrb r1, [r0], #1       @ load and skip the length field
        and r1,r1,#F_LENMASK    @ keep only the length
        add r0,r0,r1            @ skip the name field
        add r0,r0,#3            @ find the next 4-byte boundary
    	and r0,r0,#~3
		add r0, #1				@ for thumb
        bx lr
	
@@@ >DFA ( dictionary_address -- data_field_address )
@@@ Return the address of the first data field
	defword ">DFA",4,,TDFA
	.4byte TCFA		// >CFA		(get code field address)
	.4byte INCR 	// 1+	(add 2 to it to get to next word)
	.4byte EXIT		// EXIT		(return from FORTH word)

@ HEADER ( address length -- ) Creates a new dictionary entry
@ in the data segment.

	defcode "HEADER,",7,F_COMPO,HEADER_COMMA
        pop {r0}          @ address of the word to insert into the dictionnary

        ldr r2,=var_DP
        ldr r3,[r2]     @ load into r3 and r6 the location of the header
        mov r6,r3

        ldr r4,=var_LATEST
        ldr r5,[r4]     @ load into r5 the link pointer

        str r5,[r3], #4     @ store link here -> last

 //       add r3,r3,#4    @ skip link address
        strb tos,[r3], #1    @ store the length of the word
        //add r3,r3,#1    @ skip the length address

        mov r5,#0       @ initialize the incrementation

1:
        cmp r5,tos       @ if the word is completley read
        beq 2f

        ldrb r1,[r0],	#1 @ read and store a character
        strb r1,[r3], 	#1 @ and skip the word

        add r5,r5,#1    @ ready to rad the next character

    	b 1b

2:      
		add r3,r3,#3            @ align to next 4 byte boundary
        and r3,r3,#~3

        str r6,[r4]             @ update LATEST and HERE
        str r3,[r2]
		popTOS
        NEXT

        @ , ( n -- ) writes the top element from the stack at DP
	defcode ",",1,F_COMPO,COMMA
	mov r0, tos
        bl _COMMA
	popTOS
        NEXT
_COMMA:
        ldr     r1, =var_DP
        ldr     r2, [r1]        @ read DP
        str     r0, [r2], #4    @ write value and increment address
        str     r2, [r1]        @ update DP
        bx      lr
	
@ [ ( -- ) Change interpreter state to Immediate mode
	defcode "[",1,F_IMMED,LBRAC
	ldr     r0, =var_STATE
    mov     r1, #0
    str     r1, [r0]
	NEXT

@ ] ( -- ) Change interpreter state to Compilation mode
	defcode "]",1,,RBRAC
	ldr     r0, =var_STATE
    mov     r1, #1
    str     r1, [r0]
	NEXT

@ : ( -- ) Define a new forth word
	defword ":",1,,COLON
	.4byte WORD		// Get the name of the new word
	.4byte HEADER_COMMA	// Create the dictionary entry / header
	.4byte DOCOL_COMMA	// Append DOCOL  (the codeword).
	.4byte LATEST, FETCH, HIDDEN // Make the word hidden (see below for definition).
	.4byte RBRAC		// Go into compile mode.
	.4byte EXIT		// Return from the function.

	defword ";",1,F_IMMED+F_COMPO,SEMICOLON
	.4byte STATE, FETCH, TWODIV, ZBRANCH, 24 // goto normal ;
	.4byte LIT, EXITISR, COMMA,	BRANCH, 16 	// interrupt 
	.4byte LIT, EXIT, COMMA	// Append EXIT (so the word will return).
	.4byte LATEST, FETCH, HIDDEN // Toggle hidden flag -- unhide the word (see below for definition).
	.4byte LBRAC		// Go back to IMMEDIATE mode.
	.4byte ISFLASH
	.4byte EXIT		// Return from the function.

@ IMMEDIATE ( -- ) sets IMMEDIATE flag of last defined word
	defcode "IMMEDIATE",9,F_COMPO+F_IMMED,IMMEDIATE
	ldr r0, =var_LATEST     @
	ldr r1, [r0]            @ get the Last word
	add r1, r1, #4          @ points to the flag byte
                                
	mov r2, #0              @
	ldrb r2, [r1]           @ load the flag into r2
                                @
	eor r2, r2, #F_IMMED    @ r2 = r2 xor F_IMMED
	strb r2, [r1]           @ update the flag
	NEXT

@ COMPILE-ONLY ( -- ) sets COMPILEONLY flag of last defined word
	defcode "COMPILE-ONLY",12,F_COMPO+F_IMMED,COMPILE_ONLY
	ldr r0, =var_LATEST     @
	ldr r1, [r0]            @ get the Last word
	add r1, r1, #4          @ points to the flag byte
                                
	mov r2, #0              @
	ldrb r2, [r1]           @ load the flag into r2
                                @
	eor r2, r2, #F_COMPO    @ r2 = r2 xor F_COMPO
	strb r2, [r1]           @ update the flag
	NEXT

@ HIDDEN ( dictionary_address -- ) sets HIDDEN flag of a word
	defcode "HIDDEN",6,,HIDDEN
    ldr r1, [tos, #4]!
    eor r1, r1, #F_HIDDEN
    str r1, [tos]
	popTOS
	NEXT

@ INTERRUPT ( -- ) Change interpreter state to interrupt mode
	defcode "INTERRUPT",9,F_COMPO+F_IMMED,INTERRUPT
	ldr     r0, =var_STATE
    mov     r1, #2
    str     r1, [r0]
	NEXT
	
@ HIDE ( -- ) hide a word
	defword "HIDE",4,,HIDE
	.4byte WORD		// Get the word (after HIDE).
	.4byte PAREN_FIND		// Look up in the dictionary.
	.4byte HIDDEN		// Set F_HIDDEN flag.
	.4byte EXIT		// Return.

@ BRACKET_TICK ( -- ads) returns the codeword address of next read word
@ only works in compile mode. Implementation is identical to LIT.
	defcode "[']",3,F_COMPO,BRACKET_TICK
	ldr r1, [fpc], #4
	pushTOS
	mov tos, r1
	NEXT

@ BRANCH ( -- ) changes IP by offset which is found in the next codeword
	defcode "BRANCH",6,F_COMPO,BRANCH
        ldr r1, [fpc]
        add fpc, fpc, r1
        NEXT

@ 0BRANCH ( p -- ) branch if the top of the stack is zero

	defcode "0BRANCH",7,F_COMPO,ZBRANCH
    cmp tos, #0              @ if the top of the stack is zero
	popTOS
    beq BRANCH         @ then branch
    add fpc, fpc, #4          @ else, skip the offset
    NEXT

@ LITSTRING ( -- address length) as LIT but for strings

	defcode "LITSTRING",9,F_COMPO,LITSTRING
	pushTOS
    ldr tos, [fpc], #4        @ read length
        push {fpc}                 @ push address
        add fpc, fpc, tos          @ skip the string
        add fpc, fpc, #3          @ find the next 2-byte boundary
        and fpc, fpc, #~3
        NEXT

@ TELL ( addr length -- ) writes a string to stdout

	defcode "TELL",4,,TELL
	pop {r1}					@addr
	ldr r2, = USART1_DR
	ldr r3, = USART1_SR
1:	ldr r0, [r3]
	tst r0, # USART_SR_TXE     @ Check for reception 
    beq 1b                @ quit if not
	ldr r0, [r1], #1
	strb r0, [r2]
	subs tos, #1
	bne 1b
2:	ldr r0, [r3]
	tst r0, # USART_SR_TC
	beq 2b
	popTOS
    NEXT
	
	
@ INTERPRET, reads a word from stdin and executes or compiles it
	defcode "INTERPRET",9,,INTERPRET
    @ No need to backup callee save registers here, since
    @ we are the top level routine
        mov r3, #0                      @ interpret_is_lit = 0

	ldr r1, = USART1_SR
123:
	ldr r0, [r1]
	tst r0, # USART_SR_TXE     @ Check for reception 
	beq 123b                @ quit if not
	ldr r0, = USART1_DR
	mov r1, #6 
	strb r1, [r0]
	
        bl _WORD                        @ read a word from stdin
        mov r4, r0                      @ store it in r4,r5
        mov r5, r1

        bl _FIND                        @ find its dictionary entry
        cmp r0, #0                      @ if not found go to 1
        beq 1f

    @ Here the entry is found
        ldrb r6, [r0, #4]               @ read length and flags field
        bl _TCFA                        @ find code field address
    	tst r6, #F_IMMED                @ if the word is immediate	
		beq 2f                            @ otherwise, branch to 2
		tst r6, #F_COMPO		@ compile only?
	    bxeq r0                          @ (execute)
		ldr r1, =var_STATE              @ Are we compiling or executing ?
        ldr r1, [r1]
        cmp r1, #0
		beq 7f
        bxne r0                          @ (execute)

1:  @ Not found in dictionary
        mov r3, #1                      @ interpret_is_lit = 1
        mov r0, r4                      @ restore word
        mov r1, r5
        bl _NUMBER                      @ convert it to number
        cmp r1, #0                      @ if errors were found
        bne 6f                          @ then fail

    @ it's a literal
        mov r6, r0                      @ keep the parsed number if r6
        ldr r0, =LIT                    @ we will compile a LIT codeword

2:  @ Compiling or Executing
        ldr r1, =var_STATE              @ Are we compiling or executing ?
        ldr r1, [r1]
        cmp r1, #0
        beq 4f                          @ Go to 4 if in interpret mode
		
    @ Here in compile mode

        bl _COMMA                       @ Call comma to compile the codeword
        cmp r3,#1                       @ If it's a literal, we have to compile
        moveq r0,r6                     @ the integer ...
        bleq _COMMA                     @ .. too
        NEXT

4:  @ Executing
        cmp r3,#1                       @ if it's a literal, branch to 5
        beq 5f

		tst r6, #F_COMPO		@ compile only?
		bne 7f
                                        @ not a literal, execute now
        @@ ldr r0, [r0]
								@ (it's important here that
		bx r0                           @  IP address in r0, since DOCOL
                                        @  assummes it)

5:  @ Push literal on the stack
	pushTOS
        mov tos, r6
        NEXT

6:  @ Parse error
        ldr r1, =errmsg
        mov r2, #(errmsgend-errmsg)
	sendS
	
        mov r1, r4
        mov r2, r5
	sendS
	
        ldr r1, =errmsg2
        mov r2, #(errmsg2end-errmsg2)
	sendS
        NEXT


7:	@ compile only word
	 ldr r1, =errmsg3
     mov r2, #(errmsg3end-errmsg3)
	sendS
	
        mov r1, r4
        mov r2, r5
	sendS
	
        ldr r1, =errmsg2
        mov r2, #(errmsg2end-errmsg2)
	sendS
        NEXT
	
        .section .rodata
errmsg: .ascii "NOT RECOGNIZED<"
errmsgend:

errmsg2: .ascii ">\n"
errmsg2end:

errmsg3: .ascii "COMPILATION ONLY, USE IN DEFINITION<"
errmsg3end:

	
@ CHAR ( -- c ) put the ASCII code of the first character of the next word
@ on the stack

	defcode "CHAR",4,,CHAR
        bl _WORD
        ldrb r1, [r0]
	pushTOS
        mov tos, r1
        NEXT

@ EXECUTE ( xt -- ) jump to the address on the stack

	defcode "EXECUTE",7,,EXECUTE
    ldr r1, [tos]
	popTOS
    bx r1
	
@ C2FLASH compile to flash memory
	defcode "C2FLASH",7,,C2FLASH	
	@@ NOTE: that you have to fill all unused FLASH with 0xFF to be able to correctly program them
@@@ Unlock Flash Control

	ldr r2, =FLASH_SR
1:  ldr r3, [r2]
    ands r3, #FLASH_SR_BSY
    bne 1b

	ldr r3, =FLASH_CR
	ldr r3, [r3]
	tst r3, #FLASH_CR_LOCK
	beq 2f
	
1:	ldr r2, =FLASH_KEYR
	ldr r3, =FLASH_KEY1
	ldr r1, =FLASH_KEY2
	str r3, [r2]
	str r1, [r2]

2:	ldr r2, =FLASH_SR
1:  ldr r3, [r2]
    ands r3, #FLASH_SR_BSY
    bne 1b
	
@@@ Enable write
	ldr r2, =FLASH_CR
	ldr r3, [r2]
	orr r3, #FLASH_CR_PG @ Select Flash programming
	str r3, [r2]

@@@ update ram DP variable
	ldr r0, =var_DP
	ldr r1, =var_RAM
	ldr r2, [r0]				
	str r2, [r1]			
	
	NEXT

@ C2RAM compile to RAM memory
	defcode "C2RAM",5,,C2RAM
@ Lock Flash 
	ldr r2, =FLASH_CR
	ldr r0, [r2]
	orr r0, #FLASH_CR_LOCK
	str r0, [r2]

@@@ update ram DP variable
	ldr r0, =var_DP
	ldr r1, =var_RAM
	ldr r2, [r1]				
	str r2, [r0]
	
	NEXT
	
@ ?FLASH ( -- ) if flash compilation write the latest defined word to flash and update latest
	defcode "?FLASH",6,,ISFLASH
	ldr r2, =FLASH_CR
	ldr r2, [r2]
	tst r2, #FLASH_CR_LOCK
	beq 1f						@ goto flash
3:	NEXT
	
1:	
@@@ correct value for latest and flash latest 
	ldr r2, =var_F_LATEST
	ldr r4, =var_FLASH
	ldr r4, [r4]				@ r4 = latest flash
	ldr r1, [r2]				@ latest flash old
	str r4, [r2]				@ var_f_latest = latest flash
@@@ store link n flash
	strh r1, [r4], #2
	ldr r2, =FLASH_SR
1:  ldr r3, [r2]
    ands r3, #FLASH_SR_BSY
    bne 1b
	
	lsr r1, #16
	strh r1, [r4], #2
	ldr r2, =FLASH_SR
1:  ldr r3, [r2]
    ands r3, #FLASH_SR_BSY
    bne 1b
	
@@@ copy new defined word into flash
	ldr r3, =var_LATEST
	ldr r0, [r3]				@ r0 = start of copying data
	ldr r3, =var_DP
	ldr r3, [r3]
	add r0, #4			  		@ skip the link
	@@ copy length + name
    ldrb r5, [r0]				@ load the length field
    and r5, r5, #F_LENMASK		@ keep only the length
	add r5, #1					@ length byte
	ands r1, r5, #0x1
	addne r5, #1				@ make it even
	
2:	ldrh r2, [r0], #2
	strh r2, [r4], #2
1:	ldr r1, =FLASH_SR
	ldr r1, [r1]
    ands r1, #FLASH_SR_BSY
    bne 1b
	subs r5, #2
	bne 2b

	add r5,r4,#3            @ find the next 4-byte boundary
    and r5,r5,#~3
	cmp r4, r5
	beq 6f
2:	mov r2,  #0					@ 0 padding
	strh r2, [r4], #2
1:	ldr r1, =FLASH_SR
	ldr r1, [r1]
    ands r1, #FLASH_SR_BSY
    bne 1b
	cmp r4, r5
	bne 2b

6:	add r0,r0,#3            @ find the next 4-byte boundary
    and r0,r0,#~3
	@@ r0 = start address of data to copy RAM
	@@ r4 = start address of data to paste FLASH
2:	ldr r2, [r0]
	lsr r1, r2, 16 
	cmp r1, #0x2000
	beq 5f						@ if it is relative ram address replace it with relative FLASH ADDRESS
	
	ldrh r2, [r0], #2
	strh r2, [r4], #2
1:	ldr r1, =FLASH_SR
	ldr r1, [r1]
    ands r1, #FLASH_SR_BSY
    bne 1b
	
4:	cmp r0, r3
	bne 2b
@@@ update FLASH
	ldr r0, =var_FLASH
	str r4, [r0]
@@@ update DP = old value
	ldr r1, =var_RAM
	ldr r3, =var_DP
	ldr r1, [r1]
	str r1,	[r3]

	ldr r3, =var_LATEST
	ldr r0, [r3]				@ r0 = start of copying data
	ldr r1, [r0]				@ r1 = latest RAM (or flash)
	ldr r2, =var_F_LATEST
	ldr r2, [r2]
	cmp r2, r1
	movgt r1, r2				@ no definition in ram
	str r1, [r3]				@ var_latest = latest RAM
	
@@@ update the first link in RAM  
	@@ search latest link in RAM
	ldr r4, =var_LATEST
    ldr r3, [r4]                    @ get the last defined word address in ram (or in FLASH after reset)
	ldr r0, =__stack_start__
	ldr r2, =var_F_LATEST
	ldr r2, [r2]
	mov r1, r3
1:	cmp r3, r0
	ble 2f						@ first def in RAM
	mov r1, r3
	ldr r3, [r3]
	b 1b

2:	cmp r3,r1
	strne r2, [r1]
	b 3b

5:   // replace ram address with flash address
	sub r1, r2, r0				@ get ram offset
	add r2, r4, r1				@ set offset for flash
	strh r2, [r4], #2
1:	ldr r1, =FLASH_SR
	ldr r1, [r1]
    ands r1, #FLASH_SR_BSY
    bne 1b
	
	lsr r2, #16
	strh r1, [r4], #2
1:	ldr r1, =FLASH_SR
	ldr r1, [r1]
    ands r1, #FLASH_SR_BSY
    bne 1b
	
	add r0, #4
	b 4b
	
/*----------------------------------------------------------------*/

@ DODOES ( --  )  put "blx do" at DP
	defcode "DODOES,",7,F_COMPO,DODOES_COMMA
	ldr r0, = DODOES_ADRS
	ldrh r0, [r0]
	ldr     r1, =var_DP
    ldr     r2, [r1]        @ read DP
    strh    r0, [r2], #2    @ write value and increment address
    str     r2, [r1]        @ update DP
	NEXT
	@@ 32 bits branch and link dodoes in machine language
	.align 2
DODOES_ADRS:
	blx do
	
/*
	ANS Forth Core Words  ----------------------------------------------------------------------
	Some lower level ANS Forth CORE words are not presented in the orignal jonesforth. They are
	included here without explaination.
*/

/* Macros to deal with the return stack. */
	@@ 2* ( a -- a*2) 
	defcode "2*",2,,TWOMUL
	lsl tos, #1
	NEXT

	@@ 2/ ( a -- a/2)
	defcode "2/",2,,TWODIV
	lsr tos, #1
	NEXT
	
	@@ (DO) ( limit  index -- ) ( R: -- limit index)
	defcode "(DO)", 4,F_COMPO,PAREN_DO
	pop {r0}		// pop parameter stack into r0, push it on the return stack
	pushR r0		@ limit
	pushR tos		@ index
	popTOS
	NEXT

	@@ (LOOP) (  -- ) ( R: limit index --  |limit index )
	defcode "(LOOP)", 6,F_COMPO,PAREN_LOOP
	popR r1						@ index
	popR r0						@ limit 
	add r1, #1
	cmp r0, r1
	beq 1f
	pushR r0		@ limit
	pushR r1		@ index
	ldr r0, [fpc]
	add fpc, r0 	// add the offset to the instruction pointer
	NEXT
1:
	add fpc, #4		// skip offset
	NEXT

	@@ (+LOOP) ( n  -- ) ( R: limit index --  |limit index )
	defcode "(+LOOP)", 7,F_COMPO,PAREN_PLUS_LOOP
	popR r1						@ index
	popR r0						@ limit
	sub r1, r0		// index-limit in r1
	add tos, r1		// index-limit+n in r1
	eors r1, tos
	add r1, tos, r0		// index+n in r1
	popTOS
	bmi 1f			
	pushR r0		@ limit
	pushR r1		@ index
	ldr r0, [fpc]
	add fpc, r0 	// add the offset to the instruction pointer
	NEXT
1:
	add fpc, #4				// skip offset
	NEXT

	@@ UNLOOP ( -- ) ( R: limit index --  )
	defcode "UNLOOP", 6,F_COMPO,UNLOOP
	add rsp, #8
	NEXT

	@@ I ( -- n ) return stack first element
	defcode "I", 1,,I
	pushTOS
	ldr tos, [rsp]
	NEXT

	@@ J ( -- ) return stack third element
	defcode "J", 1,,J
	pushTOS
	ldr tos, [rsp, #8]
	NEXT

@@ INTERRUPT
@ NVIC_ENABLE (irq#number -- ) 
	defcode "NVIC_ENABLE",11,,NVIC_ENABLE
	mov r0, tos
	popTOS
	bl EnableIRQ
	NEXT

@ NVIC_DISABLE (irq#number -- ) 
	defcode "NVIC_DISABLE",12,,NVIC_DISABLE
	mov r0, tos
	popTOS
	bl DisableIRQ
	NEXT
	
@ REG! ( -- ) 
	defcode "REG!",4,F_COMPO+F_IMMED,REG_STORE
	push {r4-r6}
	NEXT

@ REG@ ( -- ) 
	defcode "REG@",4,F_COMPO+F_IMMED,REG_FETCH
	pop {r4-r6}
	NEXT
	
@  WFI       ( -- )
@   		Wait For Interrupt
	defcode "WFI",3,,WFI
	wfi
	NEXT

@  WFE       ( -- )
@   		Wait For Event
	defcode "WFE",3,,WFE
	wfe
	NEXT

@  RESET       ( -- )
@   		Hardware Reset
	defcode "RESET",5,,RESET
	ldr r0, = SCB_AIRCR
	ldr r1, = SCB_AIRCR_VECTKEY|SCB_AIRCR_SYSRESETREQ
	str r1, [r0]
	.pool
@  PRIMASK     ( -- primask )
@   		Read PRIMASK
	defcode "PRIMASK",7,,PRIMASK
	pushTOS
	mrs tos, PRIMASK
	NEXT

@  IPSR       ( -- ipsr )
@   		Read IPSR
	defcode "IPSR",4,,IPSR
	pushTOS
	mrs tos, ipsr
	NEXT


@  SEV       ( -- )
@   		Send Event
	defcode "SEV",3,,SEV
	sev
	NEXT

@   dint       ( -- )
@   		Disable interrupts
	defcode "DINT",4,,DINT
	cpsid	i
	NEXT


@   eint       ( -- )
@   		Enable interrupts 
	defcode	"EINT",4,,EINT
	cpsie	i
	NEXT

	
@@@ Multi Tasker
@   PAUSE	( -- )
@		Stop current task and transfer control to the task of which
@		'status' USER variable is stored in 'follower' USER variable
@		of current task.
@
@   : PAUSE	rp@  sp@ stackTop !	follower @  >R ; COMPILE-ONLY
	defcode "PAUSE",5,F_COMPO,PAUSE
	pushR fpc					@ store fpc because this is codeword not in forth words that start with docol which does this
	pushTOS						@ store tos
	push {rsp}					@ store rsp
	str sp, [up, #4]			@ store sp
	ldr r0, [up]				@ follower @
	mov fpc, r0					@ >R ;
	NEXT

@   wake	( -- )
@		Wake current task.
@
@   : wake   R> userP !  stackTop @ sp!  rp! ; COMPILE-ONLY
	defcode "WAKE",4,F_COMPO,WAKE
	mov up, fpc 				@ update user pointer
	ldr sp, [up, #4]			@ restore sp
	pop {rsp}					@ restore rsp
	popTOS						@ restore tos
	popR fpc					@ restore fpc
	NEXT

@   UP	( -- up )
@		push up on the stack.
	defcode "UP",2,,UP
	pushTOS
	mov tos, up
	NEXT

@   GOTO	( -- )
@		goto address in fpc.
	defcode "GOTO",4,F_COMPO,GOTO
	ldr fpc, [fpc]
	NEXT

@   MAIN	( -- )
@		main task.
	defvar "MAIN",4,,MAIN,WAKE
	.4byte var_MAIN 
	.4byte __stack_end__
	
@@@ latest should be defword
	@ QUIT ( -- ) the first word to be executed
	defword "QUIT", 4,, QUIT
    .4byte RZ, FETCH, RSPSTORE       @ Set up return stack
    .4byte INTERPRET          @ Interpret a word
    .4byte BRANCH,-8          @ loop

	.set RETURN_STACK_SIZE,512
	.bss
/* FORTH return stack. */
	.align	2
return_stack:
	.space RETURN_STACK_SIZE
return_stack_top:		// Initial top of return stack.
	.align
	.ltorg
	.end
/* END OF jonesforth.S */	
