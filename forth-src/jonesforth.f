: MOD /MOD DROP ;
: '\n' 10 ;
: BL   32 ;
: CR '\n' EMIT ;
: SPACE BL EMIT ;
: NEGATE 0 SWAP - ;
: TRUE  -1 ;
: FALSE 0 ;
: NOT   0= ;
: LITERAL IMMEDIATE
    ['] LIT ,   
    ,   
;
: HERE DP @ ;
: ':'
    [       
    CHAR :      
    ]       
    LITERAL     
;
: ';' [ CHAR ; ] LITERAL ;
: '(' [ CHAR ( ] LITERAL ;
: ')' [ CHAR ) ] LITERAL ;
: '"' [ CHAR " ] LITERAL ;
: 'A' [ CHAR A ] LITERAL ;
: '0' [ CHAR 0 ] LITERAL ;
: '-' [ CHAR - ] LITERAL ;
: '.' [ CHAR . ] LITERAL ;
: [COMPILE] IMMEDIATE
    WORD        
    (FIND)      
    >CFA        
    ,       
;
: RECURSE IMMEDIATE COMPILE-ONLY
    LATEST @    
    >CFA        
    ,       
;
: IF IMMEDIATE COMPILE-ONLY
    ['] 0BRANCH ,   
    HERE        
    0 ,     
;

: THEN IMMEDIATE COMPILE-ONLY
    DUP
    HERE SWAP - 
    SWAP !      
;

: ELSE IMMEDIATE COMPILE-ONLY
    ['] BRANCH ,    
    HERE        
    0 ,     
    SWAP        
    DUP     
    HERE SWAP -
    SWAP !
;

: BEGIN IMMEDIATE COMPILE-ONLY
    HERE        
;

: UNTIL IMMEDIATE COMPILE-ONLY
    ['] 0BRANCH ,   
    HERE -  
    ,       
;

: AGAIN IMMEDIATE COMPILE-ONLY
    ['] BRANCH ,    
    HERE -  
    ,       
;

: WHILE IMMEDIATE COMPILE-ONLY
    ['] 0BRANCH ,   
    HERE        
    SWAP        
    0 ,     
;

: REPEAT IMMEDIATE COMPILE-ONLY
    ['] BRANCH ,    
    HERE - ,    
    DUP
    HERE SWAP - 
    SWAP !      
;

: UNLESS IMMEDIATE COMPILE-ONLY
    ['] NOT ,       
    [COMPILE] IF    
;

: ( IMMEDIATE
    1       
    BEGIN
        KEY     
        DUP '(' = IF    
            DROP        
            1+      
        ELSE
            ')' = IF    
                1-      
            THEN
        THEN
    DUP 0= UNTIL        
    DROP        
;
: NIP ( x y -- y ) SWAP DROP ;
: TUCK ( x y -- y x y ) SWAP OVER ;
: PICK ( x_u ... x_1 x_0 u -- x_u ... x_1 x_0 x_u )
    1+      ( add one because of 'u' on the stack )
    4 *     ( multiply by the word size )
    DSP@ +      ( add to the stack pointer )
    @           ( and fetch )
;
: SPACES    ( n -- )
    BEGIN
        DUP 0>      ( while n > 0 )
    WHILE
        SPACE       ( print a space )
        1-      ( until we count down to 0 )
    REPEAT
    DROP
;
: DECIMAL ( -- ) 10 BASE ! ;
: HEX ( -- ) 16 BASE ! ;

: U.        ( u -- )
    BASE @ U/MOD    ( width rem quot )
    ?DUP IF         ( if quotient <> 0 then )
        RECURSE     ( print the quotient )
    THEN

    ( print the remainder )
    DUP 10 < IF
        '0'     ( decimal digits 0..9 )
    ELSE
        10 -        ( hex and beyond digits A..Z )
        'A'
    THEN
    +
    EMIT
;

: .S        ( -- )
    DSP@        ( get current stack pointer )
    0 S0 @ + 4- ( pointer to the stack element )
    BEGIN
        OVER OVER <=    ( compare to current stack pointer )
    WHILE
        DUP @ U.    ( print the stack element )
        SPACE
        4-      ( move down )
    REPEAT
    DROP DROP
;
: UWIDTH    ( u -- width )
    BASE @ /    ( rem quot )
    ?DUP IF     ( if quotient <> 0 then )
        RECURSE 1+  ( return 1+recursive call )
    ELSE
        1       ( return 1 )
    THEN
;

: U.R       ( u width -- )
    SWAP        ( width u )
    DUP     ( width u u )
    UWIDTH      ( width u uwidth )
    ROT     ( u uwidth width )
    SWAP -      ( u width-uwidth )
    SPACES
    ( ... and then call the underlying implementation of U. )
    U.
;

: .R        ( n width -- )
    SWAP        ( width n )
    DUP 0< IF
        NEGATE      ( width u )
        1      
        SWAP        ( width 1 u )
        ROT     ( 1 u width )
        1-      ( 1 u width-1 )
    ELSE
        0       ( width u 0 )
        SWAP        ( width 0 u )
        ROT     ( 0 u width )
    THEN
    SWAP        ( flag width u )
    DUP     ( flag width u u )
    UWIDTH      ( flag width u uwidth )
    ROT     ( flag u uwidth width )
    SWAP -      ( flag u width-uwidth )

    SPACES      ( flag u )
    SWAP        ( u flag )

    IF          ( was it negative? print the - character )
        '-' EMIT
    THEN

    U.
;

: . 0 .R SPACE ;

: U. U. SPACE ;

: ? ( addr -- ) @ . ;

: WITHIN
    -ROT        ( b c a )
    OVER        ( b c a c )
    <= IF
        > IF        ( b c -- )
            TRUE
        ELSE
            FALSE
        THEN
    ELSE
        2DROP       ( b c -- )
        FALSE
    THEN
;

: DEPTH     ( -- n )
    S0 @ DSP@ -
    4-         
    4 /         ( A cell has four bytes )
;

: ALIGNED   ( addr -- addr )
    3 + 3 INVERT AND    ( (addr+3) & ~3 )
;

: ALIGN HERE ALIGNED DP ! ;

: C,
    HERE C! ( store the character in the compiled image )
    1 DP +! ( increment DP pointer by 1 byte )
;

: S" IMMEDIATE      ( -- addr len )
    STATE @ IF  ( compiling? )
        ['] LITSTRING , ( compile LITSTRING )
        HERE        ( save the address of the length word on the stack )
        0 ,     ( dummy length - we don't know what it is yet )
        BEGIN
            KEY         ( get next character of the string )
            DUP '"' <>
        WHILE
            C,      ( copy character )
        REPEAT
        DROP        ( drop the double quote character at the end )
        DUP     ( get the saved address of the length word )
        HERE SWAP - ( calculate the length )
        4-      ( subtract 4 (because we measured from the start of the length word) )
        SWAP !      ( and back-fill the length location )
        ALIGN       ( round up to next multiple of 4 bytes for the remaining code )
    ELSE        ( immediate mode )
        HERE        ( get the start address of the temporary space )
        BEGIN
            KEY
            DUP '"' <>
        WHILE
            OVER C!     ( save next character )
            1+      ( increment address )
        REPEAT
        DROP        ( drop the final " character )
        HERE -  ( calculate the length )
        HERE        ( push the start address )
        SWAP        ( addr len )
    THEN
;

: ." IMMEDIATE      ( -- )
    STATE @ IF  ( compiling? )
        [COMPILE] S"    ( read the string, and compile LITSTRING, etc. )
        ['] TELL ,  ( compile the final TELL )
    ELSE
        BEGIN
            KEY
            DUP '"' = IF
                DROP    ( drop the double quote character )
                EXIT    ( return from this function )
            THEN
            EMIT
        AGAIN
    THEN
;

: CONSTANT
    WORD        ( get the name (the name follows CONSTANT) )
    HEADER,     ( make the dictionary entry )
    DOCOL,      ( append DOCOL (the codeword field of this word) )
    ['] LIT ,       ( append the codeword LIT )
    ,       ( append the value on the top of the stack )
    ['] EXIT ,  ( append the codeword EXIT )
    ?FLASH
;

: ALLOT     ( n -- )
    DP +!   ( adds n to DP )
;

: CELLS ( n -- n ) 4 * ;

: VARIABLE
    WORD HEADER,    ( make the dictionary entry (the name follows VARIABLE) )
    DODOES, 0 ,    ( append DOCOL (the codeword field of this word) )
    1 CELLS ALLOT   ( allocate 1 cell of memory )
;
: CREATE
    WORD HEADER,    ( make the dictionary entry (the name follows VARIABLE) )
    DODOES, 0 ,    ( append DOCOL (the codeword field of this word) )
;

: DOES>
    R> LATEST @ >DFA !
;

: VALUE     ( n -- )
    WORD HEADER,    ( make the dictionary entry (the name follows VALUE) )
    DOCOL,    ( append DOCOL )
    ['] LIT ,       ( append the codeword LIT )
    ,       ( append the initial value )
    ['] EXIT ,  ( append the codeword EXIT )
;

: TO IMMEDIATE  ( n -- )
    WORD        ( get the name of the value )
    (FIND)      ( look it up in the dictionary )
    >DFA        ( get a pointer to the first data field (the 'LIT') )
    4+      ( increment to point at the value )
    STATE @ IF  ( compiling? )
        ['] LIT ,       ( compile LIT )
        ,       ( compile the address of the value )
        ['] ! ,     ( compile ! )
    ELSE        ( immediate mode )
        !       ( update it straightaway )
    THEN
;

( x +TO VAL adds x to VAL )
: +TO IMMEDIATE
    WORD        ( get the name of the value )
    (FIND)      ( look it up in the dictionary )
    >DFA        ( get a pointer to the first data field (the 'LIT') )
    4+      ( increment to point at the value )
    STATE @ IF  ( compiling? )
        ['] LIT ,       ( compile LIT )
        ,       ( compile the address of the value )
        ['] +! ,        ( compile +! )
    ELSE        ( immediate mode )
        +!      ( update it straightaway )
    THEN
;

: ID.
    4+      ( skip over the link pointer )
    DUP C@      ( get the flags/length byte )
    F_LENMASK AND   ( mask out the flags - just want the length )

    BEGIN
        DUP 0>      ( length > 0? )
    WHILE
        SWAP 1+     ( addr len -- len addr+1 )
        DUP C@      ( len addr -- len addr char | get the next character)
        EMIT        ( len addr char -- len addr | and print it)
        SWAP 1-     ( len addr -- addr len-1    | subtract one from length )
    REPEAT
    2DROP       ( len addr -- )
;

: ?COMPILE-ONLY
  4+
  C@
  F_COMPO AND
;

: ?HIDDEN
    4+      ( skip over the link pointer )
    C@      ( get the flags/length byte )
    F_HIDDEN AND    ( mask the F_HIDDEN flag and return it (as a truth value) )
;

: ?IMMEDIATE
    4+      ( skip over the link pointer )
    C@      ( get the flags/length byte )
    F_IMMED AND ( mask the F_IMMED flag and return it (as a truth value) )
;

: WORDS
    LATEST @    ( start at LATEST dictionary entry )
    BEGIN
        ?DUP        ( while link pointer is not null )
    WHILE
        DUP ?HIDDEN NOT IF  ( ignore hidden words )
            DUP ID.     ( but if not hidden, print the word )
            SPACE
        THEN
        @       ( dereference the link pointer - go to previous word )
    REPEAT
    CR
;

: FORGET
    WORD (FIND) ( find the word, gets the dictionary entry address )
    DUP @ LATEST !  ( set LATEST to point to the previous word )
    DP !        ( and store DP with the dictionary address )
;

: DUMP      ( addr len -- )
    BASE @ -ROT     ( save the current BASE at the bottom of the stack )
    HEX         ( and switch to hexadecimal mode )

    BEGIN
        ?DUP        ( while len > 0 )
    WHILE
        OVER 8 U.R  ( print the address )
        SPACE

        ( print up to 16 words on this line )
        2DUP        ( addr len addr len )
        1- 15 AND 1+    ( addr len addr linelen )
        BEGIN
            ?DUP        ( while linelen > 0 )
        WHILE
            SWAP        ( addr len linelen addr )
            DUP C@      ( addr len linelen addr byte )
            2 .R SPACE  ( print the byte )
            1+ SWAP 1-  ( addr len linelen addr -- addr len addr+1 linelen-1 )
        REPEAT
        DROP        ( addr len )

        ( print the ASCII equivalents )
        2DUP 1- 15 AND 1+ ( addr len addr linelen )
        BEGIN
            ?DUP        ( while linelen > 0)
        WHILE
            SWAP        ( addr len linelen addr )
            DUP C@      ( addr len linelen addr byte )
            DUP 32 128 WITHIN IF    ( 32 <= c < 128? )
                EMIT
            ELSE
                DROP '.' EMIT
            THEN
            1+ SWAP 1-  ( addr len linelen addr -- addr len addr+1 linelen-1 )
        REPEAT
        DROP        ( addr len )
        CR

        DUP 1- 15 AND 1+ ( addr len linelen )
        TUCK        ( addr linelen len linelen )
        -       ( addr linelen len-linelen )
        >R + R>     ( addr+linelen len-linelen )
    REPEAT

    DROP            ( restore stack )
    BASE !          ( restore saved BASE )
;

: CASE IMMEDIATE COMPILE-ONLY
    0       ( push 0 to mark the bottom of the stack )
;

: OF IMMEDIATE COMPILE-ONLY
    ['] OVER ,  ( compile OVER )
    ['] = ,     ( compile = )
    [COMPILE] IF    ( compile IF )
    ['] DROP ,      ( compile DROP )
;

: ENDOF IMMEDIATE COMPILE-ONLY
    [COMPILE] ELSE  ( ENDOF is the same as ELSE )
;

: ENDCASE IMMEDIATE COMPILE-ONLY
    ['] DROP ,  ( compile DROP )

    ( keep compiling THEN until we get to our zero marker )
    BEGIN
        ?DUP
    WHILE
        [COMPILE] THEN
    REPEAT
;

: EXCEPTION-MARKER
    RDROP           ( drop the original parameter stack pointer )
    0           ( there was no exception, this is the normal return path )
;

: CATCH     ( xt -- exn? )
    DSP@ 4+ >R      ( save parameter stack pointer (+4 because of xt) on the return stack )
    ['] EXCEPTION-MARKER 4+ ( push the address of the RDROP inside EXCEPTION-MARKER ... )
    >R          ( ... on to the return stack so it acts like a return address )
    EXECUTE         ( execute the nested function )
;

: THROW     ( n -- )
    ?DUP IF         ( only act if the exception code <> 0 )
        RSP@            ( get return stack pointer )
        BEGIN
            DUP R0 4- <     ( RSP < R0 )
        WHILE
            DUP @           ( get the return stack entry )
            ['] EXCEPTION-MARKER 4+ = IF    ( found the EXCEPTION-MARKER on the return stack )
                4+          ( skip the EXCEPTION-MARKER on the return stack )
                RSP!            ( restore the return stack pointer )

                ( Restore the parameter stack. )
                DUP DUP DUP     ( reserve some working space so the stack for this word
                              doesn't coincide with the part of the stack being restored )
                R>          ( get the saved parameter stack pointer | n dsp )
                4-          ( reserve space on the stack to store n )
                SWAP OVER       ( dsp n dsp )
                !           ( write n on the stack )
                DSP! EXIT       ( restore the parameter stack pointer, immediately exit )
            THEN
            4+
        REPEAT

        ( No matching catch - print a message and restart the INTERPRETer. )
        DROP

        CASE
        0 1- OF ( ABORT )
            ." ABORTED" CR
        ENDOF
            ( default case )
            ." UNCAUGHT THROW "
            DUP . CR
        ENDCASE
        QUIT
    THEN
;

: ABORT     ( -- )
    0 1- THROW
;

: [CHAR] ( "<spaces>name" -- ) IMMEDIATE CHAR ['] LIT , , ;
: 2OVER ( x1 x2 x3 x4 -- x1 x2 x3 x4 x1 x2 ) 3 PICK 3 PICK ;
: CELL+ ( a-addr1 -- a-addr2 ) 1 CELLS + ;
: CELL- ( a-addr1 -- a-addr2 ) 1 CELLS - ;
: CHARS ( n1 -- n2 ) ;
: CHAR+ ( c-addr1 -- c-addr2 ) 1 CHARS + ;
: 2! ( x1 x2 a-addr -- ) SWAP OVER ! CELL+ ! ;
: 2@ ( a-addr -- x1 x2 ) DUP CELL+ @ SWAP @ ;
: MOVE ( addr1 addr2 u -- ) CMOVE ;
: 2>R ( x1 x2 -- ) ( R: -- x1 x2 ) IMMEDIATE ['] SWAP , ['] >R , ['] >R , ;
: 2R> ( -- x1 x2 ) ( R: x1 x2 -- ) IMMEDIATE ['] R> , ['] R> , ['] SWAP , ;
: 2R@ ( -- x1 x2 ) ( R: x1 x2 -- x1 x2 )
    2R> 2DUP 2>R ;
: ABS   ( n -- u)
    DUP 0< IF NEGATE THEN ;

: DO IMMEDIATE COMPILE-ONLY ( -- here 0 )
    ['] (DO) ,
    HERE 0
    ; 

: ?DO IMMEDIATE COMPILE-ONLY ( -- here 1 )
    ['] 2DUP ,
    ['] <> ,
    ['] 0BRANCH ,
    0 ,
    ['] (DO) ,
    HERE 1
    ;

: RESOLVE-DO ( here 0|1 --  )
    IF ( ?DO )
        DUP HERE - ,
        2 CELLS - HERE OVER - SWAP !
    ELSE ( DO )
        HERE - ,
    THEN ;

: LOOP IMMEDIATE COMPILE-ONLY ( here 0|1 -- )
    ['] (LOOP) , 
    RESOLVE-DO
    ;

: +LOOP  IMMEDIATE COMPILE-ONLY ( here 0|1 -- )
    ['] (+LOOP) , 
    RESOLVE-DO
    ;

: CFA>
    LATEST @    ( start at LATEST dictionary entry )
    BEGIN
        ?DUP        ( while link pointer is not null )
    WHILE
        2DUP SWAP   ( cfa curr curr cfa )
        < IF        ( current dictionary entry < cfa? )
            NIP     ( leave curr dictionary entry on the stack )
            EXIT
        THEN
        @       ( follow link pointer back )
    REPEAT
    DROP        ( restore stack )
    0       ( sorry, nothing found )
;

: SEE
    WORD (FIND) ( find the dictionary entry to decompile )
	DUP 0=
	IF
	  EXIT
	THEN
    ( Now we search again, looking for the next word in the dictionary.  This gives us
      the length of the word that we will be decompiling.  (Well, mostly it does). )
    HERE        ( address of the end of the last compiled word )
    LATEST @    ( word last curr )
    BEGIN
        2 PICK      ( word last curr word )
        OVER        ( word last curr word curr )
        <>      ( word last curr word<>curr? )
    WHILE           ( word last curr )
        NIP     ( word curr )
        DUP @       ( word curr prev (which becomes: word last curr) )
    REPEAT

    DROP        ( at this point, the stack is: start-of-word end-of-word )
    SWAP        ( end-of-word start-of-word )

    ( begin the definition with : NAME [IMMEDIATE] )
    ':' EMIT SPACE DUP ID. SPACE
    DUP ?IMMEDIATE IF ." IMMEDIATE " THEN
	DUP ?COMPILE-ONLY IF ." COMPILE-ONLY " THEN
    >DFA        ( get the data address, ie. points after DOCOL | end-of-word start-of-data )

    ( now we start decompiling until we hit the end of the word )
    BEGIN       ( end start )
        2DUP >
    WHILE
        DUP @       ( end start codeword )

        CASE
        ['] LIT OF      ( is it LIT ? )
            4 + DUP @       ( get next word which is the integer constant )
            .           ( and print it )
        ENDOF
        ['] LITSTRING OF        ( is it LITSTRING ? )
            [ CHAR S ] LITERAL EMIT '"' EMIT SPACE ( print S"<space> )
            4 + DUP @       ( get the length word )
            SWAP 4 + SWAP       ( end start+4 length )
            2DUP TELL       ( print the string )
            '"' EMIT SPACE      ( finish the string with a final quote )
            + ALIGNED       ( end start+4+len, aligned )
            4 -         ( because we're about to add 4 below )
        ENDOF
        ['] 0BRANCH OF      ( is it 0BRANCH ? )
            ." 0BRANCH ( "
            4 + DUP @       ( print the offset )
            .
            ." ) "
        ENDOF
        ['] BRANCH OF       ( is it BRANCH ? )
            ." BRANCH ( "
            4 + DUP @       ( print the offset )
            .
            ." ) "
        ENDOF
        ['] (LOOP) OF       ( is it (LOOP) ? )
            ." (LOOP) ( "
            4 + DUP @       ( print the offset )
            .
            ." ) "
        ENDOF
        ['] (+LOOP) OF      ( is it (+LOOP) ? )
            ." (+LOOP) ( "
            4 + DUP @       ( print the offset )
            .
            ." ) "
        ENDOF
        ['] ['] OF          ( is it ['] (BRACKET_TICK) ? )
            ." ['] "
            4 + DUP @       ( get the next codeword )
            CFA>            ( and force it to be printed as a dictionary entry )
            ID. SPACE
        ENDOF
        ['] EXIT OF     ( is it EXIT? )
            ( We expect the last word to be EXIT, and if it is then we don't print it
              because EXIT is normally implied by ;.  EXIT can also appear in the middle
              of words, and then it needs to be printed. )
            2DUP            ( end start end start )
            4 +         ( end start end start+4 )
            <> IF           ( end start | we're not at the end )
                ." EXIT "
            THEN
        ENDOF
                    ( default case: )
            DUP         ( in the default case we always need to DUP before using )
            CFA>            ( look up the codeword to get the dictionary entry )
            ID. SPACE       ( and print it )
        ENDCASE

        4 +     ( end start+4 )
    REPEAT

    ';' EMIT CR

    2DROP       ( restore stack )
;

: :NONAME
    0 0 HEADER, 
    HERE        ( current DP value is the address of the codeword, ie. the xt )
    DOCOL,    ( compile DOCOL (the codeword) )
    ]       ( go into compile mode )
;

: ' ( "<spaces>name" -- xt )
    WORD (FIND) >CFA
;

( Print a stack trace by walking up the return stack. )
: PRINT-STACK-TRACE
    RSP@                ( start at caller of this function )
    BEGIN
        DUP R0 4- <     ( RSP < R0 )
    WHILE
        DUP @           ( get the return stack entry )
        CASE
        ['] EXCEPTION-MARKER 4+ OF  ( is it the exception stack frame? )
            ." CATCH ( DSP="
            4+ DUP @ U.     ( print saved stack pointer )
            ." ) "
        ENDOF
                        ( default case )
            DUP
            CFA>          
            ?DUP IF         ( and print it )
                2DUP            ( dea addr dea )
                ID.         ( print word from dictionary entry )
                [ CHAR + ] LITERAL EMIT
                SWAP >DFA 4+ - .    ( print offset )
            THEN
        ENDCASE
        4+          ( move up the stack )
    REPEAT
    DROP
    CR
;

: R/O ( -- fam ) O_RDONLY ;
: R/W ( -- fam ) O_RDWR ;


HEX

( Equivalent to the NEXT macro  0xfb04f85b )
: NEXT IMMEDIATE COMPILE-ONLY 5B C, F8 C, 04 C, FB C, ;

: ;CODE IMMEDIATE COMPILE-ONLY
    [COMPILE] NEXT      ( end the word with NEXT macro )
    ALIGN           ( machine code is assembled in bytes so isn't necessarily aligned at the end )
    LATEST @ DUP
    HIDDEN          ( unhide the word )
    DUP >DFA SWAP >CFA !    ( change the codeword to point to the data area )
    [COMPILE] [     ( go back to immediate mode )
;

( The ARM registers )
: r0 IMMEDIATE 1 ;
: r1 IMMEDIATE 2 ;
: r2 IMMEDIATE 4 ;
: r3 IMMEDIATE 8 ;
: r4 IMMEDIATE 10 ;
: r5 IMMEDIATE 20 ;
: r6 IMMEDIATE 40 ;
: r7 IMMEDIATE 80 ;

( ARM stack instructions )
: PUSH IMMEDIATE COMPILE-ONLY B400 + C, ;
: POP IMMEDIATE COMPILE-ONLY BC00 + C, ;


DECIMAL

HEX \ 5B C, F8 C, 04 C, FB C,
: =NEXT     ( addr -- next? )
       DUP C@ 5B <> IF DROP FALSE EXIT THEN
    1+ DUP C@ F8 <> IF DROP FALSE EXIT THEN
    1+ DUP C@ 04 <> IF DROP FALSE EXIT THEN
    1+     C@ FB <> IF      FALSE EXIT THEN
    TRUE
;
DECIMAL

( (INLINE) is the lowlevel inline function. )
: (INLINE)  ( cfa -- )
    @           ( remember codeword points to the code )
    BEGIN           ( copy bytes until we hit NEXT macro )
        DUP =NEXT NOT
    WHILE
        DUP C@ C,
        1+
    REPEAT
    DROP
;

HEX

: INLINE IMMEDIATE COMPILE-ONLY
    WORD (FIND)     ( find the word in the dictionary )
    >CFA            ( codeword )

    DUP @ FFFF AND 47B8 = IF    ( check codeword <> DOCOL (ie. not a FORTH word) )
        ." Cannot INLINE FORTH words" CR ABORT
    THEN

    (INLINE)
;


: UNUSEDRAM    ( -- n )
    5000       ( get end of data segment )
    HERE        ( get current position in data segment )
    FFFF
    AND
    -
    4 /     ( returns number of cells )
;

 
: UNUSEDFLASH    ( -- n )
    8010000
    FLASH @        ( get current position in data segment )
    -
    4 /     ( returns number of cells )
;

DECIMAL

: WELCOME
        ." SFORTH VERSION " VERSION . CR
        ." RAM:" UNUSEDRAM . ." CELLS REMAINING" CR
        ." FLASH:" UNUSEDFLASH  . ." CELLS REMAINING" CR
;

\ MULTITASKING
    
\ @   TASK <name>   ( stackSize returnStackSize -- )
\ @     initialize task and put it in round robin loop.
\ @     name when called returns the address of the created task.
: TASK CREATE
	   ALIGN                 \  ---
	   HERE                  \ ( -- HERE )
       ['] GOTO ,            \ SLEEP
       UP DUP @ ,            \ FOLLOWING
       !                     \ ( HERE UP{following} -- )
       2DUP + 1+             \ ( stackSize returnStackSize SP+RP+DSP )
       HERE SWAP
       CELLS ALLOT           \ ( stackSize returnStackSize HERE )
       ROT  OVER             \ ( returnStackSize  HERE stackSize HERE )
       SWAP 1- CELLS +       \ ( returnStackSize  HERE TOS )
       DUP ROT !             \ ( returnStackSize  TOS )
       DUP ROT 1+ 1+ CELLS + \ ( TOS returnStackSize+TOS+DSP )
       SWAP !                \ ( ... -- )
	   DOES>
	   ALIGNED 
;

\ @   SLEEP ( tid -- )
\ @     sleep  task.
: SLEEP ['] GOTO
        SWAP !
;

\ @   AWAKE ( tid -- )
\ @     awake task.
: AWAKE ['] WAKE
        SWAP !
;

\ @   ACTIVATE  ( tid -- )
\ @     link the following definition to task.
: ACTIVATE COMPILE-ONLY
           DUP CELL+ CELL+ @ DUP @ \ ( tid DSP RSP{TOS} ) get RSP
           CELL- DUP R> SWAP !     \ ( tid DSP RSP{TOS} ) store fpc at RSP
           OVER !                  \ ( tid DSP )
		   CELL+ 0 SWAP !          \ store RSP on the stack and tos = 0 
           AWAKE  
;

\ @   TASKS ( -- )
\ @     list current tasks.


\ @@@ SEMAPHORES
\ @@    : WAIT ( addr -- ) 
\ @@         BEGIN PAUSE DUP C@ UNTIL         \ wait for nonzero = available 
\ @@         0 SWAP ! ;                       \ make it zero = unavailable

\ @@ : SIGNAL ( addr -- ) 
\ @@         1 SWAP ! ;                       \ make it nonzero = available

\ @@@ messaging
\ @@ : SEND ( message taskadr -- ) 
\ @@         MYTASK 
\ @@         OVER SENDER LOCAL       get adrs of destination's SENDER 
\ @@         BEGIN 
\ @@         PAUSE                   loop with PAUSE, 
\ @@         DUP @                   until his SENDER is zero 
\ @@         0= UNTIL 
\ @@         !                       store my adrs in his SENDER 
\ @@         MESSAGE LOCAL ! ;       store the message in his MESSAGE

\ @@ : RECEIVE ( -- message taskadr ) 
\ @@         BEGIN 
\ @@         PAUSE                   loop with PAUSE, 
\ @@         SENDER @                until my SENDER is nonzero 
\ @@         UNTIL 
\ @@         MESSAGE @               get the message from my MESSAGE 
\ @@         SENDER @                get his task adr from my SENDER 
\ @@         0 SENDER ! ;            indicate mailbox empty & ready
