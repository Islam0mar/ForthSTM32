( for blue pill boards )
VARIABLE posE \ 0
PA0 CONSTANT Xm.Spin
PA1 CONSTANT Xm.Dpin
PA2 CONSTANT Ym.Spin
PA3 CONSTANT Ym.Dpin
PA4 CONSTANT Zm.Spin
PA5 CONSTANT Zm.Dpin
PA6 CONSTANT Em.Spin
PA7 CONSTANT Em.Dpin


\ drv8825 DATA-SHEET SLVSA73F–APRIL2010–REVISEDJULY2014 ti.com page 19
\ 120  ( RPM ) 360 ( degree ) * 32 ( μsteps/step ) * 6 ( sec/10min )  18 ( 10degree/step ) * / 
100 VALUE stepFreq
1 VALUE #Xsteps
1 VALUE #Ysteps

( pin step -- )
: step
  0
  DO
    DUP ios! \ on
    stepFreq DELAY_US
    DUP ioc! \ off
    stepFreq DELAY_US
  LOOP
  DROP
;

: moveZ ( steps -1|1)
  1 = IF Zm.Dpin ios!
	  ELSE Zm.Dpin ioc!
	  THEN
  Zm.Spin
  SWAP
  0
  DO
    DUP ios! \ on
    stepFreq 2/ DELAY_US
    DUP ioc! \ off
    stepFreq 2/ DELAY_US
  LOOP
  DROP
;

\ VARIABLE Xsteps
\ VARIABLE Ysteps
\ VARIABLE Zsteps
VARIABLE Esteps
\ 0 Xpos !
\ 0 Ypos !
\ 0 Zpos !
\ 0 Epos !

\ 50 50 TASK Xm
\ 50 50 TASK Ym
\ 50 50 TASK Zm
50 50 TASK Em

\ : Xm& Xm ACTIVATE
\ 	  BEGIN
\ 		Xsteps @ DUP
\ 		0< IF Xm.Dpin ioc!  \ negative
\ 		   ELSE Xm.Dpin ios! \ postive
\ 		   THEN
\ 		ABS
\ 		Xm.Spin SWAP step
\ 		PAUSE
		
\ 		0
\ 	  UNTIL
\ ;

\ : Ym& Ym ACTIVATE
\ 	  BEGIN
\ 		Ysteps @ DUP
\ 		0< IF Ym.Dpin ioc!  \ negative
\ 		   ELSE Ym.Dpin ios! \ postive
\ 		   THEN
\ 		ABS
\ 		Ym.Spin SWAP step
\ 		PAUSE
		
\ 		0
\ 	  UNTIL
\ ;

\ : Zm& Zm ACTIVATE
\ 	  BEGIN
\ 		Zsteps @ DUP
\ 		0< IF Zm.Dpin ioc!  \ negative
\ 		   ELSE Zm.Dpin ios! \ postive
\ 		   THEN
\ 		ABS
\ 		Zm.Spin SWAP step
\ 		PAUSE
		
\ 		0
\ 	  UNTIL
\ ;

: Em& Em ACTIVATE
	  Em.Dpin ios! \ postive
	  BEGIN
		Em.Spin
		Esteps @
		DUP 0<> IF 0
				   DO
					 DUP ios! \ on
					 stepFreq 2/ DELAY_US
					 DUP ioc! \ off
					 stepFreq 2/ DELAY_US
				   LOOP
				ELSE DROP
				THEN
		DROP
		PAUSE
		
		0
	  UNTIL
;

\ ( -- )

: motors.init OMODE-PP Xm.Spin io-mode!
			  OMODE-PP Xm.Dpin io-mode!
			  OMODE-PP Ym.Spin io-mode!
			  OMODE-PP Ym.Dpin io-mode!
			  OMODE-PP Zm.Spin io-mode!
			  OMODE-PP Zm.Dpin io-mode!
			  OMODE-PP Em.Spin io-mode!
			  OMODE-PP Em.Dpin io-mode!
			  \ Xm&
			  \ Ym&
			  \ Zm&
			  Em&
;
motors.init
VARIABLE dx
VARIABLE dy
\ x0,y1,x0,y1 units are in steps
: lineBresenham ( x0 y0 x1 y1 -- ) \ Bresenham's Line Algorithm
  1 PICK 4 PICK - 2* DUP dx ! ( x0 y0 x1 y1 2dx -- )
  0< IF Xm.Dpin ioc! dx @ NEGATE dx !
	 ELSE Xm.Dpin ios!
	 THEN ( x0 y0 x1 y1  -- )
  DUP 3 PICK - 2* DUP dy ! ( x0 y0 x1 y1 2dy -- )
  0< IF Ym.Dpin ioc! dy @ NEGATE dy !
	 ELSE Ym.Dpin ios!
	 THEN ( x0 y0 x1 y1  -- )
  
  dx @ dy @ 2DUP > IF SWAP 2/ - ( x0 y0 x1 y1 fraction  )
					  >R DROP SWAP DROP - ABS ( fraction n )
					  R> SWAP
					  0
					  posE @ Esteps !  
					  DO ( fraction )
						DUP 0 >= IF Ym.Spin #Ysteps step
									dx @ - (  fraction  )
								 THEN
						Xm.Spin #Xsteps step
						dy @ + ( fraction  )
					  LOOP
					  
				   ELSE SWAP 2/ - ( x0 y0 x1 y1 fraction  )
						>R SWAP DROP ROT DROP - ABS 
						R> SWAP ( fraction n )
						0
						posE @ Esteps !
						DO
						  DUP 0 >= IF Xm.Spin #Xsteps step
									  dy @ - (  fraction  )
								   THEN
						  Ym.Spin #Ysteps step
						  dx @ + ( fraction  )
						LOOP
				   THEN
  DROP
;

\ void IC(int xm, int ym, int r,int direction) 
: arcBresenham ( xend yend r dir x y )
  \ int binrep = 0;
  \ Fxy,Dx,Dy;
  ( xend yend r dir x y )
  BEGIN
	2DUP DUP * SWAP DUP * + 4 PICK DUP * -
	0 >= IF 4
		 ELSE 0 THEN
	( xend yend r dir x y  binrep )
	3 PICK 0<> IF 8 + THEN
	( xend yend r dir x y  binrep )
   	2 PICK 2*
	0 >= IF 1+ 1+ THEN
	1 PICK 2*
	0 >= IF 1+ THEN
	( xend yend r dir x y  binrep )
	CASE
	  ( xend yend r dir x y)
	  0 OF 1-
		   Ym.Dpin ioc!
		   Ym.Spin #Ysteps step
		ENDOF
	  1 OF >R 1- R>
		   Xm.Dpin ioc!
		   Xm.Spin #Xsteps step
		ENDOF
	  2 OF >R 1+ R>
		   Xm.Dpin ios!
		   Xm.Spin #Xsteps step
		ENDOF
	  3 OF 1+
		   Ym.Dpin ios!
		   Ym.Spin #Ysteps step
		ENDOF
	  4 OF >R 1+ R>
		   Xm.Dpin ios!
		   Xm.Spin #Xsteps step
		ENDOF
	  5 OF 1-
		   Ym.Dpin ioc!
		   Ym.Spin #Ysteps step
		ENDOF
	  6 OF 1+
		   Ym.Dpin ios!
		   Ym.Spin #Ysteps step
		ENDOF
	  7 OF >R 1- R>
		   Xm.Dpin ioc!
		   Xm.Spin #Xsteps step
		ENDOF
	  8 OF >R 1- R>
		   Xm.Dpin ioc!
		   Xm.Spin #Xsteps step
		ENDOF
	  9 OF 1+
		   Ym.Dpin ios!
		   Ym.Spin #Ysteps step
		ENDOF
	  10 OF 1-
			Ym.Dpin ioc!
			Ym.Spin #Ysteps step
		 ENDOF
	  11 OF >R 1+ R>
			Xm.Dpin ios!
			Xm.Spin #Xsteps step
		 ENDOF
	  12 OF 1+
			Ym.Dpin ios!
			Ym.Spin #Ysteps step
		 ENDOF
	  13 OF >R 1+ R>
			Xm.Dpin ios!
			Xm.Spin #Xsteps step
		 ENDOF
	  14 OF >R 1- R>
			Xm.Dpin ioc!
			Xm.Spin #Xsteps step
		 ENDOF
	  15 OF 1-
			Ym.Dpin ioc!
			Ym.Spin #Ysteps step
		 ENDOF
	ENDCASE
	( xend yend r dir x y )
	2DUP 6 PICK = SWAP  7 PICK = AND
  UNTIL
  ( xend yend r dir x y )
  2DROP 2DROP 2DROP
;
