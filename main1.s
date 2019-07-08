	.title	"SFORTH"
	.set SFORTH_VERSION,1
/* Directives */
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
tos	.req	r10		@ top of data stack item
fpc	.req 	r11		@ FORTH vm instruction ptr
rsp	.req 	r12		@ RETURN stack pointer
dsp	.req 	r13		@ DATA stack pointer
	/* NEXT macro. */
	// CAUTION!! support only thumb mode imply that bx take register with LSB is 1
	// ,so force .thumb_func
	.macro NEXT
	ldr r0, [fpc], #4
	bx  r0
	.endm

	.macro pushR reg
	str \reg, [rsp, #-4]!
	.endm

	.macro popR reg
	ldr \reg, [rsp], #4
	.endm

	.macro pushTOS
	push {tos}
	.endm

	.macro popTOS
	pop {tos}
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
	add fpc, r0, #1		@@ w points to codeword, so make
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
	ldr rsp, =return_stack_top      @ Set the initial return stack position
	cpsid i				@ disable interrupts
	bl ClockInit
	bl  set_up_data_segment         @ Set up the data segment
	bl  GPIO_Init
	cpsie i			@ enable interrupt
	ldr fpc, =cold_start             @ Make the IP point to cold_start
	NEXT                            @ Start the interpreter
	.ltorg
	.align 2
	.section .rodata
cold_start:			// High-level code without a codeword.
	.4byte QUIT

// data poiter initializer to last used ram segment .bss
	.text
	.align	1
	.p2align 2,,3
set_up_data_segment:
        ldr r1, =var_DP
	ldr r0, =end
        str r0, [r1]            @ Initialize DP to point at the beginning
                                @ of data segment
        bx      lr              @ Return

	
/* Flags - these are discussed later. */
	.set F_IMMED,0x80
	.set F_HIDDEN,0x20
	.set F_LENMASK,0x1f	// length mask

	// Store the chain of links.
	.set link,0

	.macro defword name, namelen, flags=0, label
	.section .rodata
	.align	2
	.globl name_\label
name_\label :
	.4byte link		// link
	.set link,name_\label
	.byte \flags+\namelen	// flags + length byte
	.ascii "\name"		// the name
	.align	2		// padding to next 2 byte boundary
	.4byte \label
	.section .text
	.align	1
	.p2align 2,,3
	.globl \label
	.thumb
	.thumb_func
	.fpu softvfp
	.type	\label, %function
\label :
	b DOCOL		// codeword - the interpreter
	// list of word pointers follow
	.endm

	.macro defcode name, namelen, flags=0, label
	.section .rodata
	.align	2
	.globl name_\label
name_\label :
	.4byte link		// link
	.set link,name_\label
	.byte \flags+\namelen	// flags + length byte
	.ascii "\name"		// the name
	.align	2		// padding to next 2 byte boundary
	.4byte \label
	.text
	.align	1
	.p2align 2,,3
	.globl \label
	.thumb
	.thumb_func
	.fpu softvfp
	.type	\label, %function
\label :			// assembler code follows
	.endm
	
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

	defcode "!=",2,,NEQU	// top two words are not equal?
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
    
@ LIT is used to compile literals in forth word.
@ When LIT is executed it pushes the literal (which is the next codeword)
@ into the stack and skips it (since the literal is not executable).

    defcode "LIT", 3,, LIT
	pushTOS
    ldr tos, [fpc], #4
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
	defvar "STATE",5,,STATE
	defvar "DP",2,,DP
	defvar "LATEST",6,,LATEST,name_EXECUTE @ latest defined code in ASM 
	// defvar "S0",2,,SZ   @ not needed as startup file sets SP
	defvar "BASE",4,,BASE,10

	.macro defconst name, namelen, flags=0, label, value
	defcode \name,\namelen,\flags,\label
	pushTOS
	ldr tos, = \value
	NEXT
	.endm

	defconst "VERSION",7,,VERSION,SFORTH_VERSION
	defconst "r0",2,,RZ,return_stack_top
	defconst "DOCOL",5,,__DOCOL,DOCOL
	defconst "F_IMMED",7,,__F_IMMED,F_IMMED
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

/*
	RETURN STACK ----------------------------------------------------------------------
*/

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

@ -----------------------------------------------------------------------------
    defcode "KEY",3,,KEY    @ ( -- c ) Receive one character
@ -----------------------------------------------------------------------------
    ldr r1, = USART1_SR
1:	ldr r0, [r1]
	tst r0, # USART_SR_RXNE        @ Check for reception 
	beq 1b                     @ wait for it
	pushTOS
	ldr r0, = USART1_DR
	ldrb tos, [r0]
	NEXT
    
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

	.macro getChar
	ldr r3, = USART1_SR
11:	ldr r0, [r3]
	tst r0, # USART_SR_RXNE        @ Check for reception 
	beq 11b                     @ wait for it
	ldr r0, = USART1_DR
	ldrb r0, [r0]

11:	ldr r2, [r3]
	tst r2, # USART_SR_TXE     @ Check for reception 
	beq 11b                @ quit if not
	ldr r2, = USART1_DR
	strb r0, [r2]
@@ 22:	ldr r2, [r3]
@@ 	tst r2, # USART_SR_TC
@@ 	beq 22b
	
	.endm
@ WORD ( -- addr length ) reads next word from stdin
@ skips spaces and comments, limited to 32 characters 
	defcode "WORD",4,,WORD
	bl _WORD
        push {r0}                 @ adress
        mov tos, r1                 @ length
        NEXT
_WORD:	
1:	getChar                   @ read a character
	cmp r0, #'\\'
	beq 3f                  @ skip comments until end of line
	cmp r0, #' '
	ble 1b                  @ skip blank character
	
	ldr     r1, =word_buffer
2:	strb r0, [r1], #1       @ store character in word buffer
	getChar                   @ read more characters until a space is found
	cmp r0, #' '
	bgt 2b

	ldr r0, =word_buffer    @ r0, address of word
	sub r1, r1, r0          @ r1, length of word

	bx lr
3:
	getChar                 @ skip all characters until end of line
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
        stmfd sp!, {r4-r6, lr}

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
        ldmfd sp!, {r4-r6, pc}
	


@ FIND ( addr length -- dictionary_address )
@ Tries to find a word in the dictionary and returns its address.
@ If the word is not found, NULL is returned.

	defcode "FIND",4,,FIND
	mov r1, tos  @length
	pop {r0} @addr
        bl _FIND
        mov tos, r0
        NEXT

_FIND:
        stmfd   sp!, {r5,r6,r8,r9}      @ save callee save registers
        ldr r2, =var_LATEST
        ldr r3, [r2]                    @ get the last defined word address
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
        mov r5, r0                      @ r5 contains searched string
        mov r6, r3                      @ r6 contains dict string
        add r6, r6, #5                  @ (we skip link and length fields)
                                        @ r2 contains the length

2:
        ldrb r8, [r5], #1               @ compare character per character
        ldrb r9, [r6], #1
        cmp r8,r9
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
        ldmfd   sp!, {r5,r6,r8,r9}      @ restore callee save registers
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
        bx lr
	
@@@ >DFA ( dictionary_address -- data_field_address )
@@@ Return the address of the first data field
	defword ">DFA",4,,TDFA
	.4byte TCFA		// >CFA		(get code field address)
	.4byte INCR4		// 4+		(add 4 to it to get to next word)
	.4byte EXIT		// EXIT		(return from FORTH word)

@ CREATE ( address length -- ) Creates a new dictionary entry
@ in the data segment.
	@ CREATE ( address length -- ) Creates a new dictionary entry
@ in the data segment.
@ CREATE ( address length -- ) Creates a new dictionary entry
@ in the data segment.

	defcode "CREATE",6,,CREATE
        pop {r0}          @ address of the word to insert into the dictionnary

        ldr r2,=var_DP
        ldr r3,[r2]     @ load into r3 and r8 the location of the header
        mov r8,r3

        ldr r4,=var_LATEST
        ldr r5,[r4]     @ load into r5 the link pointer

        str r5,[r3]     @ store link here -> last

        add r3,r3,#4    @ skip link adress
        strb tos,[r3]    @ store the length of the word
        add r3,r3,#1    @ skip the length adress

        mov r7,#0       @ initialize the incrementation

1:
        cmp r7,tos       @ if the word is completley read
        beq 2f

        ldrb r6,[r0],	#1 @ read and store a character
        strb r6,[r3], 	#1

        add r7,r7,#1    @ ready to rad the next character

        b 1b

2:

        add r3,r3,r7            @ skip the word

        add r3,r3,#3            @ align to next 4 byte boundary
        and r3,r3,#~3

        str r8,[r4]             @ update LATEST and HERE
        str r3,[r2]
		popTOS
        NEXT

        @ , ( n -- ) writes the top element from the stack at DP
	defcode ",",1,,COMMA
	mov r0, tos
        bl _COMMA
	popTOS
        NEXT
_COMMA:
        ldr     r1, =var_DP
        ldr     r2, [r1]        @ read HERE
        str     r0, [r2], #4    @ write value and increment address
        str     r2, [r1]        @ update HERE
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
	.4byte CREATE	// Create the dictionary entry / header
	.4byte LIT, DOCOL, COMMA	// Append DOCOL  (the codeword).
	.4byte LATEST, FETCH, HIDDEN // Make the word hidden (see below for definition).
	.4byte RBRAC		// Go into compile mode.
	.4byte EXIT		// Return from the function.

	defword ";",1,F_IMMED,SEMICOLON
	.4byte LIT, EXIT, COMMA	// Append EXIT (so the word will return).
	.4byte LATEST, FETCH, HIDDEN // Toggle hidden flag -- unhide the word (see below for definition).
	.4byte LBRAC		// Go back to IMMEDIATE mode.
	.4byte EXIT		// Return from the function.

@ IMMEDIATE ( -- ) sets IMMEDIATE flag of last defined word
	defcode "IMMEDIATE",9,F_IMMED,IMMEDIATE
	ldr r0, =var_LATEST     @
	ldr r1, [r0]            @ get the Last word
	add r1, r1, #4          @ points to the flag byte
                                
	mov r2, #0              @
	ldrb r2, [r1]           @ load the flag into r2
                                @
	eor r2, r2, #F_IMMED    @ r2 = r2 xor F_IMMED
	strb r2, [r1]           @ update the flag
	NEXT

@ HIDDEN ( dictionary_address -- ) sets HIDDEN flag of a word
	defcode "HIDDEN",6,,HIDDEN
    ldr r1, [tos, #4]!
    eor r1, r1, #F_HIDDEN
    str r1, [tos]
	popTOS
	NEXT

@ HIDE ( -- ) hide a word
	defword "HIDE",4,,HIDE
	.4byte WORD		// Get the word (after HIDE).
	.4byte FIND		// Look up in the dictionary.
	.4byte HIDDEN		// Set F_HIDDEN flag.
	.4byte EXIT		// Return.

@ TICK ( -- ads) returns the codeword address of next read word
@ only works in compile mode. Implementation is identical to LIT.
	defcode "'",3,,TICK
	ldr r1, [fpc], #4
	pushTOS
	mov tos, r1
	NEXT

@ BRANCH ( -- ) changes IP by offset which is found in the next codeword
	defcode "BRANCH",6,,BRANCH
        ldr r1, [fpc]
        add fpc, fpc, r1
        NEXT

@ 0BRANCH ( p -- ) branch if the top of the stack is zero

	defcode "0BRANCH",7,,ZBRANCH
    	cmp tos, #0              @ if the top of the stack is zero
	popTOS
        beq BRANCH         @ then branch
    	add fpc, fpc, #4          @ else, skip the offset
        NEXT

@ LITSTRING ( -- ) as LIT but for strings

	defcode "LITSTRING",9,,LITSTRING
        ldr r0, [fpc], #4        @ read length
        push {fpc}                 @ push address
        mov tos, r0                 @ push string
        add fpc, fpc, r0          @ skip the string
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

@ QUIT ( -- ) the first word to be executed
	defword "QUIT", 4,, QUIT
        .4byte RZ, RSPSTORE       @ Set up return stack
        .4byte INTERPRET          @ Interpret a word
        .4byte BRANCH,-8          @ loop

	
@ INTERPRET, reads a word from stdin and executes or compiles it
	defcode "INTERPRET",9,,INTERPRET
    @ No need to backup callee save registers here, since
    @ we are the top level routine

        mov r8, #0                      @ interpret_is_lit = 0

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
        bne 4f                          @ branch to 6 (execute)
        b 2f                            @ otherwise, branch to 2

1:  @ Not found in dictionary
        mov r8, #1                      @ interpret_is_lit = 1
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
        cmp r8,#1                       @ If it's a literal, we have to compile
        moveq r0,r6                     @ the integer ...
        bleq _COMMA                     @ .. too
        NEXT

4:  @ Executing
        cmp r8,#1                       @ if it's a literal, branch to 5
        beq 5f

                                        @ not a literal, execute now
        ldr r0, [r0]                    @ (it's important here that
        bx r0                           @  IP address in r0, since DOCOL
                                        @  assummes it)

5:  @ Push literal on the stack
	pushTOS
        mov tos, r6
        NEXT

	.macro sendS
	ldr r7, = USART1_DR
	ldr r3, = USART1_SR
111:
	ldr r0, [r3]
	tst r0, # USART_SR_TXE     @ Check for reception 
	beq 111b                @ quit if not
	ldr r0, [r1], #1
	strb r0, [r7]
	subs r2, #1
	bne 111b
222:
	ldr r0, [r3]
	tst r0, # USART_SR_TC
	beq 222b
	.endm
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

	
        .section .rodata
errmsg: .ascii "PARSE ERROR<"
errmsgend:

errmsg2: .ascii ">\n"
errmsg2end:

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

	.set RETURN_STACK_SIZE,512
	.bss
/* FORTH return stack. */
	.align	8
return_stack:
	.space RETURN_STACK_SIZE
return_stack_top:		// Initial top of return stack.
	.ltorg
/* END OF jonesforth.S */
	.align
	.end
	
