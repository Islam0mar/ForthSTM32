\ simple one-shot ADC
0x40021004 CONSTANT RCC_CFGR
0x40021000 0x18 + CONSTANT RCC-APB2ENR
0x40012400 CONSTANT ADC1
    ADC1 0x00 + CONSTANT ADC1-SR
    ADC1 0x04 + CONSTANT ADC1-CR1
    ADC1 0x08 + CONSTANT ADC1-CR2
    ADC1 0x0C + CONSTANT ADC1-SMPR1
    ADC1 0x10 + CONSTANT ADC1-SMPR2
    ADC1 0x2C + CONSTANT ADC1-SQR1
    ADC1 0x30 + CONSTANT ADC1-SQR2
    ADC1 0x34 + CONSTANT ADC1-SQR3
    ADC1 0x4C + CONSTANT ADC1-DR

: adc-calib ( -- )  \ perform an ADC calibration cycle
  2 bit ADC1-CR2 DUP @ ROT OR SWAP !  BEGIN 2 bit ADC1-CR2 @ AND 0= UNTIL ;

: adc-once ( -- u )  \ read ADC value once
  0 bit ADC1-CR2 DUP @ ROT OR SWAP !  \ set ADON to start ADC
  BEGIN 1 bit ADC1-SR @ AND UNTIL  \ wait UNTIL EOC set
  ADC1-DR @ ;

: adc-init ( -- )  \ initialise ADC
  15 bit RCC_CFGR DUP @ ROT OR SWAP !
  9 bit RCC-APB2ENR DUP @ ROT OR SWAP !  \ set ADC1EN
  23 bit  \ set TSVREFE for vRefInt use
   0 bit OR ADC1-CR2 DUP @ ROT OR SWAP !  \ set ADON to enable ADC
  \ 7.5 cycles sampling time is enough for 18 kΩ to ground, measures as zero
  \ even 239.5 cycles is not enough for 470 kΩ, it still leaves 70 mV residual
  0b111 21 LSHIFT ADC1-SMPR1 DUP @ ROT OR SWAP ! \ set SMP17 to 239.5 cycles for vRefInt
  0b110110110 ADC1-SMPR2 DUP @ ROT OR SWAP ! \ set SMP0/1/2 to 71.5 cycles, i.e. 83 µs/conv
  adc-once DROP ;

: adc# ( pin -- n )  \ convert pin number to adc index
\ nasty way to map the pins (a "c," table offset lookup might be simpler)
\   PA0..7 => 0..7, PB0..1 => 8..9, PC0..5 => 10..15
  DUP io# SWAP  io-port ?DUP IF 1 LSHIFT + 6 + THEN ;

: adc ( pin -- u )  \ read ADC value
\ IMODE-ADC over io-mode!
\ nasty way to map the pins (a "c," table offset lookup might be simpler)
\   PA0..7 => 0..7, PB0..1 => 8..9, PC0..5 => 10..15
  adc# ADC1-SQR3 !  adc-once ;


: adc-vcc ( -- mv )  \ return estimated Vcc, based on 1.2V internal bandgap
3300 1200 17 ADC1-SQR3 ! adc-once */ ;
