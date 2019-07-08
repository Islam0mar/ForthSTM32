\ 16 CONSTANT OVERSAMPLENR
38 2 CELL-MATRIX hotEndTable
   1 OVERSAMPLENR * 40950 1023 */ 5 + 10 / 0 0 hotEndTable ! 350 0 1 hotEndTable !
  28 OVERSAMPLENR * 40950 1023 */ 5 + 10 / 1 0 hotEndTable ! 250 1 1 hotEndTable ! \ top rating 250C
  31 OVERSAMPLENR * 40950 1023 */ 5 + 10 / 2 0 hotEndTable ! 245 2 1 hotEndTable !
  35 OVERSAMPLENR * 40950 1023 */ 5 + 10 / 3 0 hotEndTable ! 240 3 1 hotEndTable !
  39 OVERSAMPLENR * 40950 1023 */ 5 + 10 / 4 0 hotEndTable ! 235 4 1 hotEndTable !
  42 OVERSAMPLENR * 40950 1023 */ 5 + 10 / 5 0 hotEndTable ! 230 5 1 hotEndTable !
  44 OVERSAMPLENR * 40950 1023 */ 5 + 10 / 6 0 hotEndTable ! 225 6 1 hotEndTable !
  49 OVERSAMPLENR * 40950 1023 */ 5 + 10 / 7 0 hotEndTable ! 220 7 1 hotEndTable !
  53 OVERSAMPLENR * 40950 1023 */ 5 + 10 / 8 0 hotEndTable ! 215 8 1 hotEndTable !
  62 OVERSAMPLENR * 40950 1023 */ 5 + 10 / 9 0 hotEndTable ! 210 9 1 hotEndTable !
  71 OVERSAMPLENR * 40950 1023 */ 5 + 10 / 10 0 hotEndTable ! 205 10 1 hotEndTable ! \ fitted graphically
  78 OVERSAMPLENR * 40950 1023 */ 5 + 10 / 11 0 hotEndTable ! 200 11 1 hotEndTable ! \ fitted graphically
  94 OVERSAMPLENR * 40950 1023 */ 5 + 10 / 12 0 hotEndTable ! 190 12 1 hotEndTable !
 102 OVERSAMPLENR * 40950 1023 */ 5 + 10 / 13 0 hotEndTable ! 185 13 1 hotEndTable !
 116 OVERSAMPLENR * 40950 1023 */ 5 + 10 / 14 0 hotEndTable ! 170 14 1 hotEndTable !
 143 OVERSAMPLENR * 40950 1023 */ 5 + 10 / 15 0 hotEndTable ! 160 15 1 hotEndTable !
 183 OVERSAMPLENR * 40950 1023 */ 5 + 10 / 16 0 hotEndTable ! 150 16 1 hotEndTable !
 223 OVERSAMPLENR * 40950 1023 */ 5 + 10 / 17 0 hotEndTable ! 140 17 1 hotEndTable !
 270 OVERSAMPLENR * 40950 1023 */ 5 + 10 / 18 0 hotEndTable ! 130 18 1 hotEndTable !
 318 OVERSAMPLENR * 40950 1023 */ 5 + 10 / 19 0 hotEndTable ! 120 19 1 hotEndTable !
 383 OVERSAMPLENR * 40950 1023 */ 5 + 10 / 20 0 hotEndTable ! 110 20 1 hotEndTable !
 413 OVERSAMPLENR * 40950 1023 */ 5 + 10 / 21 0 hotEndTable ! 105 21 1 hotEndTable !
 439 OVERSAMPLENR * 40950 1023 */ 5 + 10 / 22 0 hotEndTable ! 100 22 1 hotEndTable !
 484 OVERSAMPLENR * 40950 1023 */ 5 + 10 / 23 0 hotEndTable !  95 23 1 hotEndTable !
 513 OVERSAMPLENR * 40950 1023 */ 5 + 10 / 24 0 hotEndTable !  90 24 1 hotEndTable !
 607 OVERSAMPLENR * 40950 1023 */ 5 + 10 / 25 0 hotEndTable !  80 25 1 hotEndTable !
 664 OVERSAMPLENR * 40950 1023 */ 5 + 10 / 26 0 hotEndTable !  70 26 1 hotEndTable !
 781 OVERSAMPLENR * 40950 1023 */ 5 + 10 / 27 0 hotEndTable !  60 27 1 hotEndTable !
 810 OVERSAMPLENR * 40950 1023 */ 5 + 10 / 28 0 hotEndTable !  55 28 1 hotEndTable !
 849 OVERSAMPLENR * 40950 1023 */ 5 + 10 / 29 0 hotEndTable !  50 29 1 hotEndTable !
 914 OVERSAMPLENR * 40950 1023 */ 5 + 10 / 30 0 hotEndTable !  45 30 1 hotEndTable !
 914 OVERSAMPLENR * 40950 1023 */ 5 + 10 / 31 0 hotEndTable !  40 31 1 hotEndTable !
 935 OVERSAMPLENR * 40950 1023 */ 5 + 10 / 32 0 hotEndTable !  35 32 1 hotEndTable !
 954 OVERSAMPLENR * 40950 1023 */ 5 + 10 / 33 0 hotEndTable !  30 33 1 hotEndTable !
 970 OVERSAMPLENR * 40950 1023 */ 5 + 10 / 34 0 hotEndTable !  25 34 1 hotEndTable !
 978 OVERSAMPLENR * 40950 1023 */ 5 + 10 / 35 0 hotEndTable !  22 35 1 hotEndTable !
1008 OVERSAMPLENR * 40950 1023 */ 5 + 10 / 36 0 hotEndTable !   3 36 1 hotEndTable !
1023 OVERSAMPLENR * 40950 1023 */ 5 + 10 / 37 0 hotEndTable !   0 37 1 hotEndTable ! \ to allow internal 0 degrees C

\ ?FLASH

( raw -- T )
: hotEndTemp 38 0
			 DO
			   DUP I 0 hotEndTable @
			   <= IF I DUP 0= IF ." Error" 2DROP UNLOOP
									 EXIT THEN
					 DUP DUP 0 hotEndTable @ SWAP 1 hotEndTable @
					 ROT 1- DUP 0 hotEndTable @ SWAP 1 hotEndTable @
					 ( x x2 y2 x1 y1 )
					 2DUP >R >R
					 ROT - -ROT SWAP - ROT ( dy dx x ) 
					 R> - ROT  * SWAP / R> + ( temp )
					 UNLOOP EXIT THEN
			 LOOP
;

			 
