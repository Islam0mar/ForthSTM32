VARIABLE posX \ 0
VARIABLE posY \ 0
VARIABLE posZ \ 0
\ extruder

VARIABLE CW

VARIABLE absMode 
\ absolute (true) or incremental (false) 
\  programming model; TRUE

160 CONSTANT stepX/mm 
160 CONSTANT stepY/mm 
44 CONSTANT stepZ/mm 
\ extruder
70 CONSTANT stepE/mm 

: pos@ ( -- x y z e )
  posX @ posY @ posZ @ posE @ 
;

: pos+ ( x1 y1 z1 e1 -- x2 y2 z2 e2 )
  posE @ + >R 
  posZ @ + ROT ( yy zz xx )
  posX @ + ROT ( zz xx yy )
  posY @ + ROT ( xx yy zz )
  R> ( xx yy zz ee )
;

: pos! ( x y z e -- )
  posE !
  posZ !
  posY !
  posX !
;

\ Inverse Kinematics - turns XYZ object coordinates [mm] 
\  into steps s1,s2 & s3 [steps]
\ currently limited to integer input of 
\  < sqrt(2^32 - 1 = 65,535 mm =~ 65 metres
: IK ( x y z e -- s1 s2 s3 s4 )
  \ translate object coordinates into machine coordinates
  >R
  stepZ/mm * -ROT
  stepY/mm * -ROT
  stepX/mm * -ROT
  R> stepE/mm *
  ( stepX stepY stepZ stepE )
;

\ Forward Kinematics - turns lengths of steps 
\  into XYZ object coordinates
: FK ( s1 s2 s3 s4 -- x y z e )
  >R
  stepZ/mm / -ROT
  stepY/mm / -ROT
  stepX/mm / -ROT
  R> stepE/mm /
  ( x y z e )
;

\ PARSE INPUT DATA
: PARSE
  WORD
;

\ parse next code and integer
: cint ( b u -- c n )
  OVER C@ ROT ROT ( c b u )
  1- SWAP 1+ SWAP NUMBER
  0<> IF  ." PARSE ERROR" QUIT THEN
;

: moreParam?
  KEY ';' = IF 0 EXIT THEN
  FIFO_get @ 1- FIFO_SIZE 1- AND
  FIFO_get !
  1
;

: line ( x y z e )
  posE @ >R posE ! ( x y z )
  DUP posZ @ - DUP 0> IF 1 moveZ
				  ELSE DUP 0< IF -1 moveZ 
						  ELSE DROP THEN
					  THEN
  ( x y z )
  posZ !
  ( x1 y1 )
  posX @ posY @ ( x1 y1 x0 y0) 2SWAP ( x0 y0 x1 y1 )
  2DUP posY ! posX !
  ( x0 y0 x1 y1 )
  lineBresenham
  R> posE @ + posE !
;

: arc ( xx yy I J ee )
  posE @ DUP >R SWAP - posE ! ( x y Ioffset Joffset )
  >R 2 PICK + R> 2 PICK +
  ( x y I J )
  2DUP >R >R
  SWAP >R - ABS DUP DUP * ( x y dy^2 )
  ROT R> - ABS DUP DUP * ( y dy^2 x dx^2 )
  >R -ROT R>
  ( x y dy^2 dx^2 )
  ( a src dst -- a'dst' )
  0 4 FIX32_CONV
  SWAP 0 4 FIX32_CONV
  + 4 FIX32_SQRT
  0x8 +
  4 0 FIX32_CONV
  ( x y R )
  CW @
  ( xend yend R dir )
  posY @ R> - posX @ R> - 
  ( xend yend R dir x y )
  posE @ Esteps !
  arcBresenham ( xstart r dir x y -- )
  R> posE @ + posE !
;
\ GCODES

: G00 \ move in a straight line
  absMode @ IF
    pos@ ELSE
    0 0 0 0 THEN ( xx yy zz ee )
  BEGIN PARSE
      cint ( xx yy zz ee c n )
      OVER ( 'F'= ) 0x46 = IF 1000000 ( usec )
							  360 ( degree ) * 32 ( μsteps/step ) *
							  2 52163 *  16604 ( pi ) ( RPM )
							  6 ( sec/10min )  18 ( 10degree/step )
							  * * */  U/ TO stepFreq ! DROP ELSE
      OVER ( 'E'= ) 0x45 = IF \ replace e on stack with n
        stepE/mm * NIP NIP ELSE
      OVER ( 'Z'= ) 0x5A = IF 
        \ replace z on stack with n
        stepZ/mm * NIP SWAP >R NIP R> ELSE
      OVER ( 'Y'= ) 0x59 = IF 
        \ replace y on stack with n
        stepY/mm * NIP SWAP >R SWAP >R NIP R> R> ELSE
      OVER ( 'X'= ) 0x58 = IF 
        \ replace x on stack with n
        stepX/mm * NIP SWAP >R SWAP >R SWAP >R NIP R> R> R> ELSE
      2DROP \ ignore unknown char
    THEN THEN THEN THEN THEN
    ( xx yy zz ee ) 
    moreParam? WHILE
  REPEAT
  absMode @ NOT IF
    pos+
  THEN
  line
;
: G01 G00 ;
: G0 G00 ;
: G1 G00 ;

: G02 \ Controlled Arc Move
  absMode @ IF
  pos@ ELSE
  0 0 0 0 THEN ( xx yy zz ee )
  NIP
  0 0 ROT
  ( xx yy I J ee )
  BEGIN PARSE 
      cint ( xx yy I J ee c n )
      OVER ( 'F'= ) 0x46 = IF 1000000 ( usec )
							  360 ( degree ) * 32 ( μsteps/step ) *
							  2 52163 *  16604 ( pi ) ( RPM )
							  6 ( sec/10min )  18 ( 10degree/step )
							  * * */  U/ TO stepFreq ! DROP ELSE
      OVER ( 'E'= ) 0x45 = IF \ replace e on stack with n
        stepE/mm * NIP NIP ELSE
      OVER ( 'J'= ) 0x4A = IF 
        \ replace J on stack with n
        stepY/mm * NIP SWAP >R NIP R> ELSE
      OVER ( 'I'= ) 0x49 = IF 
        \ replace I on stack with n
        stepX/mm * NIP SWAP >R SWAP >R NIP R> R> ELSE
      OVER ( 'Y'= ) 0x59 = IF 
        \ replace Y on stack with n
        stepY/mm * NIP SWAP >R SWAP >R SWAP >R NIP R> R> R> ELSE
	  OVER ( 'X'= ) 0x58 = IF
		\ replace X on stack with n
		stepX/mm * NIP SWAP >R SWAP >R SWAP >R NIP R> R> R> ELSE
      2DROP \ ignore unknown char
      THEN THEN THEN THEN THEN THEN
	  ( xx yy I J ee )
    moreParam? WHILE
  REPEAT
  absMode @ NOT IF
	-ROT ( x y e i j) >R >R
	0 SWAP ( x y 0 e)
    pos+
	NIP
	R> R> ( x y e i j )
	ROT
  THEN
  ( xx yy I J ee )
  arc
;

: G2 \ G2 Xnnn Ynnn Innn Jnnn Ennn Fnnn CW
  1 CW !
  G02
;
: G3 \ G3 Xnnn Ynnn Innn Jnnn Ennn Fnnn CCW
  0 CW !
  G02
;

\ G4: Dwell Pause the machine for a period of time. 
: G4
  PARSE cint
  OVER 0x50 ( 'P' ) = IF NIP 1000 * DELAY_US
					  ELSE OVER 0x53 ( 'S' ) = IF NIP 1000000 *
												  DELAY_US
											   THEN
					  ELSE 2DROP
					  THEN
;

: G20; \ set input to be in inches
  CR ." \ sorry, input must be in mm"
;
: G20  G20; ; \ just in case no semicolon  
  
\ doesn't do anything, so can simply be ignored  
\ : G21; \ set input to be in millimeters
\   ;
\ : G21 G21; ; \ just in case no semicolon

: G28 \ self-check and move to home
  \ 2do: self-check
  0 0 0 0 line \ no extrusion
  0 posE ! \ reset extruder position
;

: G90; \ absolute mode
  -1 absMode !
;
: G90 G90; ; \ just in case no semicolon

: G91; \ relative (or incremental) mode
  0 absMode !
;
: G91 G91; ; \ just in case no semicolon

: G92 \ set current position to values
  \ and re-map the object origin accordingly
  \ does not validate IF the virtual move is valid
  BEGIN 0x20 word ( b u ) 
    2DUP >R >R 
    DUP 0= IF 2DROP ELSE
      cint ( c n )
      OVER ( 'E'= ) 0x45 = IF posE ! DROP ELSE
      OVER ( 'Z'= ) 0x5A = IF 
        DUP posZ @ - objz +!   posZ !  DROP ELSE
      OVER ( 'Y'= ) 0x59 = IF 
        DUP posY @ - objy +!   posY !  DROP ELSE
      OVER ( 'X'= ) 0x58 = IF 
        DUP posX @ - objx +!   posX !  DROP ELSE
      2DROP \ ignore unknown char
    THEN THEN THEN THEN
    THEN
    R> R> ( b u ) moreParam? while  
    repeat
  ;

: M114 \ current status, diagnostic
  CR
  ." \ Object: X" posX @ 1 U.R
  space ." ,Y" posY @ 1 U.R  space ." ,Z" posZ @ 1 U.R
  space ." ,E" posE @ 1 U.R  space ." ,F" xyzeRate @ 1 U.R
  CR
  ." \ Offsets from machine origin ("
  objx ? ." ," objy ? ." ," objz ? ." )"
  CR
  ." \ Motors: M1=( 0, 0, 0) M2=(" x2 ? 
  ." , 0, 0) M3=(" x3 ? ." ," y3 ? ." , 0)"
  ;


\ Non-standard GCODE commands
: init_ ( -- )
  \ " AVAGO" UID 0x!
  setvars
  
  \ ready motors
  motorsOn
  
  \ change interpreter OVER for GCODE
  ' GEV 'EVAL !
  FILE \ prompt for new line with ascii VT
;
