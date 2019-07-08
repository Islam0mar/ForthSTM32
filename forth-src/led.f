PC13 CONSTANT led.pin ( for blue pill boards )
\ PA1 CONSTANT led.pin ( for hytiny boards )

\ set output mode, push-pull driver
: led.init   OMODE-PP led.pin io-mode! ;
: led.on     led.pin ioc! ; \ LED lights up when port low
: led.off    led.pin ios! ;
: led.toggle led.pin iox! ;


IMODE-ADC PB0 io-mode!
OMODE-PP OMODE-FAST OR PB1 io-mode!
adc-init
adc-calib
PB1 ioc!

PB0 adc OVERSAMPLENR * hotEndTemp .





 
