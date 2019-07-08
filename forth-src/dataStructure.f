
: BEGIN-STRUCTURE  \ -- addr 0 ; -- size
  CREATE
  HERE 0 0 ,      \ mark stack, lay dummy
  DOES> @             \ -- rec-len
;

: END-STRUCTURE  \ addr n --
   SWAP ! ;          \ set len

: +FIELD  \ ( n1 n2 "<spaces>name" -- n3 ) ; Exec: addr -- 'addr
  CREATE OVER , +
  DOES> @ +
;

: FIELD:    ( n1 "name" -- n2 ; addr1 -- addr2 )
  ALIGNED 1 CELLS +FIELD ;
: CFIELD:   ( n1 "name" -- n2 ; addr1 -- addr2 )
  1 CHARS   +FIELD ;


\ BEGIN-STRUCTURE point \ -- a-addr 0 ; -- lenp
\    FIELD: p.x             \ -- a-addr cell
\    FIELD: p.y             \ -- a-addr cell*2
\ END-STRUCTURE
\ BEGIN-STRUCTURE rect    \ -- a-addr 0 ; -- lenr
\    point +FIELD r.tlhc    \ -- a-addr cell*2
\    point +FIELD r.brhc    \ -- a-addr cell*4
\ END-STRUCTURE

\ array
: ARRAY ( n -- ) ( i -- addr)
     CREATE CELLS ALLOT
     DOES> CELLS + ;
\ 100 array foo              \ Make an array with 100 CELLS

\ matrix
: CELL-MATRIX
  CREATE ( width height "name" ) OVER ,  * CELLS ALLOT
  DOES> ( x y -- addr ) DUP CELL+ >R  @ * + CELLS R> + ;

\ 5 5 cell-matrix test
\ 36 0 0 test !
\ 0 0 test @ .  \ 36

 : BUFFER: \ u "<name>" -- ; -- addr
\ Create a buffer of u address units whose address is returned at run time.
   CREATE ALLOT
 ;

 \ RECT BUFFER: NEW-RECT ( outside STRUCT it leaves the offset )
