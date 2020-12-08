# ForthSTM32

Forth targetting stm32f103 in assembly. It used code and ideas from {[jonesforth](https://github.com/nornagon/jonesforth), eforth, Bill Muench, Starting FORTH}.

## Features

- It supports round-robin multitasking through `WAKE`/`SLEEP` forth words.
- It has been used to parse subset of G-Code on my 3D-printer. see forth code for reference [G-CODE.f](https://github.com/Islam0mar/ForthSTM32/blob/master/forth-src/G-CODE.f).
- Mostly self documenting as proted from [jonesforth](https://github.com/nornagon/jonesforth).


## TODO

- [ ] Add SEMAPHORES SIGNAL messaging They are defined--stolen-- here, [multi.org](https://github.com/Islam0mar/ForthSTM32/blob/master/multi.org)
- [ ] Complete [G-CODE.f](https://github.com/Islam0mar/ForthSTM32/blob/master/forth-src/G-CODE.f) parser.
- [ ] Write lisp inside forth.
- [ ] Upload videos.
- [ ] Rewrite in C to be more portable [ForthSTM32C](https://github.com/Islam0mar/ForthSTM32C), but making it ansi-C99 and indirected threaded isn't efficient or I can't figure it out.
- [ ] Rewrite compile to FLASH --without pre-initializing all code blocks to 1--

## Copyright

Copyright (c) 2019 Islam Omar (io1131@fayoum.edu.eg)

## License

Licensed under the MIT License.
