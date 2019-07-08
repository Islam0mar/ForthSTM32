: quadArc ( xstart xend xpin ypin r )
  DUP NEGATE dx ! 0  dy ! ( xstart xend xpin ypin r )
  2 SWAP 2* - ( xstart xend xpin ypin err )
  BEGIN
	dx @ 0<
  WHILE
	( xstart xend xpin ypin err )
	DUP dy @ <= IF DUP 1+ dy @ 1+ DUP dy ! 2* +
				   dx @ DUP 7 PICK >= SWAP 6 PICK <= AND
				   IF 2 PICK #Ysteps step THEN
				ELSE DUP
				THEN
	( xstart xend xpin ypin err err* )
	SWAP dx @ > OVER dy @ > OR IF 1+ dx @ 1+ DUP dx ! 2* +
								  dx @ DUP 6 PICK >= SWAP 5 PICK <= AND								  
								  IF 2 PICK #Xsteps step THEN	
							   THEN
	( xstart xend  xpin ypin err* )
  REPEAT
  2DROP 2DROP DROP
;

: quadrantBresenham ( xstart xend ystart yend r CW QUAD -- ) \ Bresenham's circle Algorithm
  \ cw 1|0
  \ (x,y)
  \ (y,-x) FIRST-QUAD CW
  \ (-x,y) FIRST-QUAD CCW
  \ (x,y) SECOND-QUAD CW
  \ (-y,-x) SECOND-QUAD CCW
  \ (-y,x) THIRD-QUAD CW
  \ (x,-y) THIRD-QUAD CCW
  \ (y,x) FOURTH-QUAD CW
  \ (-x,-y) FOURTH-QUAD CCW

  ( xstart xend r CW QUAD -- )
  CASE
	1 OF Xm.Dpin ioc! Ym.Dpin ios!
		 0<> ( CW ) IF >R >R >R 2DROP R> R> R>
					   #Ysteps #Xsteps TO #Ysteps TO #Xsteps
					   Ym.Spin Xm.Spin ROT quadArc
					   #Ysteps #Xsteps TO #Ysteps TO #Xsteps
					   ( xstart xend xpin ypin r )
					ELSE ( CCW ) NIP NIP
						 Xm.Spin Ym.Spin ROT quadArc
						 ( xstart xend xpin ypin r )
					THEN
	  ENDOF
	2 OF 0<> ( CW ) IF NIP NIP
					   Xm.Dpin ios! Ym.Dpin ios!
					   Xm.Spin Ym.Spin ROT quadArc
					   ( xstart xend xpin ypin r )
					ELSE ( CCW ) >R >R >R 2DROP R> R> R> 
						 Xm.Dpin ioc! Ym.Dpin ioc!
						 #Ysteps #Xsteps TO #Ysteps TO #Xsteps
						 Ym.Spin Xm.Spin ROT quadArc
						 #Ysteps #Xsteps TO #Ysteps TO #Xsteps
						 ( xstart xend xpin ypin r )
					THEN
	  ENDOF
	
	3 OF Xm.Dpin ios! Ym.Dpin ioc!
		 0<> ( CW ) IF >R >R >R 2DROP R> R> R>
					   #Ysteps #Xsteps TO #Ysteps TO #Xsteps
					   Ym.Spin Xm.Spin ROT quadArc
					   #Ysteps #Xsteps TO #Ysteps TO #Xsteps
					   ( xstart xend xpin ypin r )
					ELSE ( CCW ) NIP NIP
						 Xm.Spin Ym.Spin ROT quadArc
						 ( xstart xend xpin ypin r )
					THEN
	  ENDOF
	( default case: 4 )
	>R 0<> ( CW ) IF  >R >R >R 2DROP R> R> R> 
					  Xm.Dpin ioc! Ym.Dpin ioc!
					  Xm.Spin Ym.Spin ROT quadArc
					  ( xstart xend xpin ypin r )
				  ELSE ( CCW ) NIP NIP
					   Xm.Dpin ios! Ym.Dpin ios!
					   #Ysteps #Xsteps TO #Ysteps TO #Xsteps
					   Ym.Spin Xm.Spin ROT quadArc
					   #Ysteps #Xsteps TO #Ysteps TO #Xsteps
					   ( xstart xend xpin ypin r )
				  THEN
	R>
  ENDCASE
;
