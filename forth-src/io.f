\ I/O pin primitives

0x40010800 CONSTANT GPIO_BASE
      0x00 CONSTANT GPIO.CRL   \ reset 0x44444444 port Conf Register Low
      0x04 CONSTANT GPIO.CRH   \ reset 0x44444444 port Conf Register High
      0x08 CONSTANT GPIO.IDR   \ RO              Input Data Register
      0x0C CONSTANT GPIO.ODR   \ reset 0         Output Data Register
      0x10 CONSTANT GPIO.BSRR  \ reset 0         port Bit Set/Reset Reg
      0x14 CONSTANT GPIO.BRR   \ reset 0         port Bit Reset Register

: bit ( u -- u )  \ turn a bit position into a single-bit mask
  1 SWAP LSHIFT ;

: io ( port# pin# -- pin )  \ combine port AND pin into single int
  SWAP 8 LSHIFT OR ;
: io# ( pin -- u )  \ convert pin to bit position
  0x1F AND   ;
: io-mask ( pin -- u )  \ convert pin to bit mask
  io# bit   ;
: io-port ( pin -- u )  \ convert pin to port number (A=0, B=1, etc)
  8 RSHIFT  ;
: io-base ( pin -- addr )  \ convert pin to GPIO base address
  0xF00 AND 2 LSHIFT GPIO_BASE +   ;

: (io@)  (   pin -- pin* addr )
  DUP io-mask SWAP io-base GPIO.IDR  +  ;
: (ioc!) (   pin -- pin* addr )
  DUP io-mask SWAP io-base GPIO.BRR  +  ;
: (ios!) (   pin -- pin* addr )
  DUP io-mask SWAP io-base GPIO.BSRR +  ;
: (iox!) (   pin -- pin* addr )
  DUP io-mask SWAP io-base GPIO.ODR  +  ;
: (io!)  ( f pin -- pin* addr )
  SWAP 0= 0x10 AND + DUP io-mask SWAP io-base GPIO.BSRR + ;

: io@ ( pin -- f )  \ get pin value (0 or -1)
  (io@) @ AND ;
: ioc! ( pin -- )  \ clear pin to low
  (ioc!)  ! ;
: ios! ( pin -- )  \ set pin to high
  (ios!)  ! ;
: iox! ( pin -- )  \ toggle pin, not interrupt safe
  (iox!) DUP @ ROT XOR SWAP ! ;
: io! ( f pin -- )  \ set pin value
  (io!)   ! ;

0b0000 CONSTANT IMODE-ADC    \ input, analog
0b0100 CONSTANT IMODE-FLOAT  \ input, floating
0b1000 CONSTANT IMODE-PULL   \ input, pull-up/down

0b0001 CONSTANT OMODE-PP     \ output, push-pull
0b0101 CONSTANT OMODE-OD     \ output, open drain
0b1001 CONSTANT OMODE-AF-PP  \ alternate function, push-pull
0b1101 CONSTANT OMODE-AF-OD  \ alternate function, open drain

0b01 CONSTANT OMODE-SLOW  \ add to OMODE-* for 2 MHz iso 10 MHz drive
0b10 CONSTANT OMODE-FAST  \ add to OMODE-* for 50 MHz iso 10 MHz drive

: io-mode! ( mode pin -- )  \ set the CNF AND MODE bits for a pin
  DUP -ROT DUP io-base GPIO.CRL + OVER 8 AND 1 RSHIFT + >R ( R: crl/crh )
  io# 7 AND 4 * ( mode shift )
  0xF OVER LSHIFT INVERT ( mode shift mask )
  RSP@ @ AND -ROT LSHIFT OR SWAP  0xF AND DUP  7 > IF 8 - THEN
  4 * 0xF SWAP LSHIFT DUP ROT AND SWAP R> DUP @ ROT INVERT AND ROT OR SWAP ! ;

: io-modes! ( mode pin mask -- )  \ shorthAND to config multiple pins of a port
  16 0 DO
    I bit OVER AND IF
      >R  2DUP ( mode pin mode pin R: mask ) 0xF BIC I OR io-mode!  R>
    THEN
  LOOP 2DROP DROP ;

: io. ( pin -- )  \ display readable GPIO registers associated with a pin
  CR
  DECIMAL
    ." PIN " DUP io#  DUP .  10 < IF SPACE THEN
   ." PORT " HEX DUP io-port [CHAR] A + EMIT
   io-base
   BASE @
   HEX
   SWAP
  ."   CRL " DUP @ . 4 +
   ."  CRH " DUP @ . 4 +
   ."  IDR " DUP @ .  4 +
."   ODR " DUP @ . DROP BASE ! ;
