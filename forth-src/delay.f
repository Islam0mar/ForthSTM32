0xE000E010 CONSTANT STK_CTRL
STK_CTRL 0x4 + CONSTANT STK_LOAD
STK_CTRL 0x8 + CONSTANT STK_VAL
STK_CTRL 0xC + CONSTANT STK_CALIB

: INIT-SYSTICK
  STK_CTRL DUP @ 7 OR SWAP !
  0x1C20 STK_LOAD ! \ 100us
  0 STK_VAL !
;

: START
  S" TIME" HEADER,
  DODOES, 0 ,    ( append DOCOL the codeword field of this word )
  HERE
  1 CELLS ALLOT   ( allocate 1 cell of memory )
  S" sysTick" HEADER,
  HERE OVER
  DOCOL,
  ['] REG! ,
  ['] LIT , 1 ,
  ['] LIT , , \ time
  ['] +! ,
  ['] REG@ ,
  ['] EXITISR ,

  1+ SysTick_Handler !

  S" DELAY_US" HEADER,
  DOCOL,
  ['] LIT , DUP ,
  ['] @ ,
  HERE SWAP
  ['] PAUSE ,
  ['] 2DUP ,
  ['] LIT , ,
  ['] @ ,  ['] - ,
  ['] ABS , ['] SWAP ,
  ['] LIT , 100 ,
  ['] / , ['] >= ,
  ['] 0BRANCH ,   
  HERE - ,	
  ['] 2DROP ,
  ['] EXIT ,
  
  INIT-SYSTICK
;

