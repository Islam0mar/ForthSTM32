@ (a b exp -- a*b )
    defcode "FIX32_MUL",9,,FIX32_MUL
    pop {r0-r1}
    smull       r1, r0, r1, r0
    lsrs        r1, r1, tos
    rsb         tos, tos, #32
    lsl         r0, r0, tos
    adc         tos, r1, r0
    NEXT

@ (a b c exp -- c+a*b )
	defcode "FIX32_MLA",9,,FIX32_MLA
    pop {r0-r2}
    smull       r2, r1, r2, r1
    lsrs        r2, r2, tos
    rsb         tos, tos, #32
    lsl         r1, r1, tos
    adc         r2, r2, r1
    add         tos, r2, r0
    NEXT

@ (a b c exp -- c-a*b )
	defcode "FIX32_MLS",9,,FIX32_MLS
	pop {r0-r2}
    smull       r2, r1, r2, r1
    lsrs        r2, r2, tos
    rsb         tos, tos, #32
    lsl         r1, r1, tos
    adc         r2, r2, r1
    sub         tos, r0, r2
    NEXT


@ (a exp -- 1/a )
	defcode "FIX32_INV",9,,FIX32_INV
    pop {r0}
    @ Splits the input number to the magnitude and sign part. The magnitude part
@ is passed to the Newton-Raphson method, because the current implementation
@ only takes positive numbers. The sign part will be used to restore the sign
@ of the obtained estimate.

        asr         r4, r0, #31
        eor         r0, r0, r4
        sub         r0, r0, r4

@ Normalizes the magnitude part of the input value to the range from one-half
@ to one at the Q32 fixed-point format. Then, calculates the denormalization
@ shift which is used to scale the result to the required fixed-point format.

        clz         r5, r0
        lsl         r0, r0, r5
        rsb         r5, r5, #62
        sub         r5, r5, tos, lsl #1

@ Looks up on the nine most significant bits of the input value to determine
@ the initial nine-bit Q8 estimate to its reciprocal. Since the leading bit
@ of the input value is always set, it is not used during lookup. The ninth
@ bit of the reciprocal is always set too, so the lookup table stores only
@ the eight bits, while the ninth bit is restored by software.

        ldr         r1, =fix32_inv_table
        lsr         r2, r0, #23
        sub         r2, r2, #256
        ldrb        r1, [r1, r2]
        add         r1, r1, #256

@ Performs the first Newton-Raphson iteration, producing a rough estimate
@ to the required reciprocal value. The estimate will be in the Q16 fixed-
@ point format.

        mul         r2, r1, r1
        umull       r3, r2, r0, r2
        rsb         r2, r2, r1, lsl #9

@ Performs the second Newton-Raphson iteration, producing the Q30 estimate
@ to the reciprocal of the input value. The second to last instruction also
@ clears the carry flag to make the subsequent rounding work properly.

        umull       r1, r3, r2, r2
        movs        r1, r1, lsr #2
        adc         r1, r1, r3, lsl #30
        umull       r1, r0, r1, r0
        adds        r0, r0, r1, lsr #31
        rsb         r0, r0, r2, lsl #15

@ Using the calculated denormalization shift, denormalizes the reciprocal
@ to the required fixed-point format, rounds the result, and restores its
@ sign. To make the rounding work properly when the denormalization shift
@ is zero, the carry flag must be cleared.

        lsrs        r0, r0, r5
        adc         r0, r0, #0
        eor         r0, r0, r4
        sub         tos, r0, r4
    NEXT

@ (a b exp -- a/b )
	defcode "FIX32_DIV",9,,FIX32_DIV
	pop {r0-r1}
    @ Splits the divisor to the magnitude and sign parts. The magnitude part goes
@ to the Newton-Raphson method, as it can only take positive values. The sign
@ part is combined with the dividend.

        tst         r0, r0
        negmi       r1, r1
        negmi       r0, r0

@ Normalizes the divisor to the range from one-half to one at the Q32 fixed
@ point representation. Finds the normalization shift which will be used to
@ scale the final result to the required fixed-point representation.

        clz         r5, r0
        lsl         r0, r0, r5
        rsb         r5, r5, #62
        sub         r5, r5, tos

@ Looks up on the nine most significant bits of the divisor to determine the
@ initial nine-bit Q8 estimate to its recr4rocal. Because the leading bit of
@ the divisor is always set, it is not used to access the table. The leading
@ bit of a recr4rocal is always set too, so the lookup table stores only its
@ eight least significand bits, the ninth bit is restored by software.

        ldr         r4, =fix32_inv_table
        lsr         r2, r0, #23
        sub         r2, r2, #256
        ldrb        r4, [r4, r2]
        add         r4, r4, #256

@ Performs the first Newton-Raphson iteration, producing the Q16 estimate
@ to the multr4licative inverse of the divisor.

        mul         r2, r4, r4
        umull       r3, r2, r0, r2
        rsb         r2, r2, r4, lsl #9

@ Performs the second Newton-Raphson iteration, producing the Q30 estimate
@ to the multr4licative inverse of the divisor.

        umull       r4, r3, r2, r2
        movs        r4, r4, lsr #2
        adc         r4, r4, r3, lsl #30
        umull       r3, r4, r0, r4
        add         r4, r4, r3, lsr #31
        rsb         r4, r4, r2, lsl #15

@ Multr4lies the absolute value of a dividend by the multr4licative inverse
@ of a divisor. On the next step the resulting product will be denormalized
@ to get the actual quotient.

        smull       r1, r0, r1, r4

@ Performs the denormalization by arithmetically shifting the product from
@ the previous step to the right. Because the number of bits to be shifted
@ can be greater than 32, the operation is performed in two steps. The code
@ below partially shifts the quotient to reduce the number of places to be
@ shifted to no more than 32.

        subs        r5, r5, #32
        movgt       r1, r0
        asrgt       r0, r0, #31
        addle       r5, r5, #32

@ Now, when the number of bits to be shifted is less than or equal to 32,
@ the code below finally denormalizes the quotient and rounds the result.

        lsrs        r1, r1, r5
        rsb         r5, r5, #32
        lsl         r0, r0, r5
        adc         tos, r1, r0
    NEXT
	
@ (a exp -- a^-0.5 )
	defcode "FIX32_ISQRT",11,,FIX32_ISQRT
	pop {r0}
			clz         r4, r0
        lsl         r0, r4

@ Calculates the denormalization shift that will be used to scale the result
@ to the required fixed-point representation.

        sub         r1, tos, tos, lsl #2
        rsb         r4, r4, #94
        add         r4, r4, r1
        lsrs        r4, r4, #1

@ Looks up on the eight most significant bits of the input value to determine
@ the initial ten-bit Q10 estimate to its inverse square root.

        ldr         r1, =fix32_isqrt_table
        lsr         r2, r0, #24
        sub         r2, r2, #128
        ldrh        r1, [r1, r2, lsl #1]

@ Performs the first Newton-Raphson iteration, which gives an inaccurate Q31
@ estimate to the inverse square root of the specified number.

        mul         r2, r1, r1
        umull       r3, r2, r0, r2
        rsb         r2, r2, #0x300000
        mul         r1, r2, r1

@ Performs the second Newton-Raphson iteration, which improves the accuracy
@ of the previous estimate up to an acceptable level. The result will be in
@ the same Q31 fixed-point representation.

        umull       r3, r2, r1, r1
        umull       r3, r2, r0, r2
        rsb         r2, r2, #0xc0000000
        umull       r3, r2, r1, r2
        lsl         r0, r2, #1

@ Since the denormalization shift is rounded down, we must take into account
@ its fractional part, which can be equal to one-half or zero. If it is not
@ zero, the estimate received on the previous step is corrected by square
@ root of two. The last instuction also clears the carry flag to avoid an
@ incorrect rounding in the next step.

        movw        r1, #0xf334
        movt        r1, #0xb504
        umullcs     r1, r0, r1, r0
        addscs      r0, r0, r1, lsr #31

@ Denormalizes the estimate to the required fixed-point representation and
@ rounds the result. If the denormalization shift is zero, the carry flag
@ is not updated by the shift instruction, which can cause an incorrect
@ rounding. That is why we had to clear the flag in the previous step.

        lsrs        r0, r0, r4
        adc         tos, r0, #0
    NEXT

@ (a exp -- a^0.5 )
	defcode "FIX32_SQRT",10,,FIX32_SQRT
	pop {r0}
			clz         r4, r0
        lsl         r0, r4
        add         r4, r4, #30
        sub         r4, r4, tos

@ Looks up on the eight most significant bits of the specified number to find
@ the initial ten-bit Q10 estimate to its inverse square root. If this number
@ is zero, the subtraction instruction is skr4ped to prevent an error while
@ the load operation.

        lsrs        r2, r0, #24
        subne       r2, r2, #128
        ldr         r1, =fix32_isqrt_table
        ldrh        r1, [r1, r2, lsl #1]

@ Performs the first Newton-Raphson iteration. The result is an inaccurate
@ estimate for the inverse square root of the specified number at the Q31
@ fixed-point representation.

        mul         r2, r1, r1
        umull       r3, r2, r0, r2
        rsb         r2, r2, #0x300000
        mul         r1, r2, r1

@ Performs the second Newton-Raphson iteration, which improves the accuracy
@ of the previous estimate. The result will be in the Q30 fixed-point format.

        umull       r3, r2, r1, r1
        umull       r3, r2, r0, r2
        rsb         r2, r2, #0xc0000000
        umull       r3, r1, r1, r2

@ To get the square root of the input number, multr4lies the inverse square
@ root of this number by the number itself and rounds the result. The result
@ will be a Q31 fixed-point number.

        mov         r1, r1, lsl #1
        umull       r1, r0, r1, r0
        add         r0, r0, r1, lsr #31

@ Completes the calculation of a denormalization shift. Since the shift is
@ rounded down, we must take into account its fractional part, which can be
@ equal to one-half or zero. If it is not zero, the estimate received on the
@ previous step is corrected by square root of two. The last instuction also
@ clears the carry flag to avoid an incorrect rounding in the next step.

        movs        r4, r4, lsr #1
        movw        r1, #0xf334
        movt        r1, #0xb504
        umullcs     r1, r0, r1, r0
        addscs      r0, r0, r1, lsr #31

@ Denormalizes the obtained estimate to a required fixed-point format and
@ rounds the result. If the denormalization shift is zero, the carry flag
@ is not updated by the shift instruction, which can cause an incorrect
@ rounding. That is why we had to clear the flag in the previous step.

        lsrs        r0, r0, r4
        adc         tos, r0, #0
    NEXT

@ (a exp -- sin(a) )
	defcode "FIX32_SIN",9,,FIX32_SIN
	pop {r0}
	@ Normalizes the angle to the range from zero to one-half at the Q33 fixed
@ point representation. The carry flag will indicate whether the angle was
@ in the first or the second semicircle. The obtained normalization shift
@ will be used to scale the result back to the initial fixed-point format.

        rsb         r5, tos, #33
        lsls        r0, r0, r5
        sub         r5, r5, #2

@ Normalizes the angle to the range from zero to one-quarter and splits the
@ angle bits into two parts. The upper bits determine the expansion point and
@ are used to index the lookup-table. The lower bits form an offset from the
@ expansion point.

        mov         r1, r0, asr #31
        eor         r0, r0, r1, lsl #25
        mov         r2, r0, lsr #25
        sub         r0, r0, r2, lsl #25
        rsb         r3, r2, #63

@ To evaluate a Taylor polynomial for the sine function we need to know the
@ sine and cosine values at the expansion point. Theese values are taken from
@ the lookup table. When the angle is in the second quadrant, the values are
@ swapped, which transforms the polynomial so that it approximates the cosine
@ instead of sine.

        ldr         r4, =fix32_sin_table
        ldr         r2, [r4, r2, lsl #2]
        ldr         r3, [r4, r3, lsl #2]
        eor         r3, r1

@ Converts the offset from revolutions to radians. Since the table entries
@ are pointing to the middle of the interval, the offset value is adjusted
@ by subtracting a half of the interval length.

        lsl         r0, #3
        sub         r0, #0x8000000
        movw        r4, #0xed51
        movt        r4, #0x6487
        smull       r0, r1, r4, r0

@ Calculates the last coefficient of the third-order Taylor series expansion
@ of a sine function. This coefficient can be calculated with less accuracy,
@ which eliminates the one long multr4lication.

        movw        r4, #0x1555
        asr         r0, r3, #15
        mul         r0, r0, r4

@ Calculates the other terms of the third-order Taylor series expansion of
@ a sine function. To reduce the number of multr4lications the polynomial
@ is evaluated using Horner's method.

        smull       r4, r0, r1, r0
        add         r0, r0, r2, asr #1
        smull       r4, r0, r1, r0
        sub         r0, r0, r3
        smull       r4, r0, r1, r0
        rsb         r0, r0, r2

@ Corrects the sign of the obtained estimate if the angle value was in the
@ second semicircle. Then, converts the result to the required fixed-point
@ representation and rounds the result. The second instruction makes shure
@ the carry flag is cleared. Because if the denormalization shift is zero,
@ the shift instruction will not update the carry flag, which can cause an
@ incorrect rounding.

        rsbcs       r0, r0, #0
        lsls        r4, r5, #1
        asrs        r0, r0, r5
        adc         tos, r0, #0
    NEXT

@ (a exp -- cos(a) )
	defcode "FIX32_COS",9,,FIX32_COS
    pop {r0}
    @ The code below can only work with non-negative angles. Due to the symmetry
@ of the cosine function, all that is necessary to extend the domain to the
@ negative angles is to calculate the absolute value of a specified angle.

        eor         r4, r0, r0, asr #31
        sub         r0, r4, r0, asr #31

@ Normalizes the angle to the range from zero to one-half at the Q33 fixed
@ point representation. The carry flag will indicate whether the angle was
@ in the first or the second semicircle. The obtained normalization shift
@ will be used to scale the result back to the initial fixed-point format.

        rsb         r5, tos, #33
        lsls        r0, r0, r5
        sub         r5, r5, #2

@ Normalizes the angle to the range from zero to one-quarter and splits the
@ angle bits into two parts. The upper bits define the expansion point and
@ are used to index the lookup-table. The lower bits are used as an offset
@ from the expansion point.

        mov         r1, r0, asr #31
        eor         r0, r0, r1, lsl #25
        mov         r3, r0, lsr #25
        sub         r0, r0, r3, lsl #25
        rsb         r2, r3, #63

@ To evaluate the Taylor polynomial for the cosine function we need to know
@ the cosine and sine values at the expansion point. Theese values are taken
@ from the lookup table. When the angle is in the second quadrant, the values
@ are swapped, which transforms the polynomial so that it approximates minus
@ sine instead of cosine.

        ldr         r4, =fix32_sin_table
        ldr         r2, [r4, r2, lsl #2]
        ldr         r3, [r4, r3, lsl #2]
        eor         r2, r1

@ Converts the offset from revolutions to radians. Since the table entries
@ are pointing to the middle of the interval, the offset value is adjusted
@ by subtracting a half of the interval length.

        lsl         r0, #3
        sub         r0, #0x8000000
        movw        r4, #0xed51
        movt        r4, #0x6487
        smull       r0, r1, r4, r0

@ Calculates the last coefficient of the third-order Taylor series expansion
@ of a sine function. This coefficient can be calculated with less accuracy,
@ which eliminates the one long multr4lication.

        movw        r4, #0x1555
        asr         r0, r3, #15
        mul         r0, r0, r4

@ Calculates the remaining terms of the third-order Taylor series expansion
@ of the cosine function. The polynomial is evaluated using Horner's method
@ to reduce the number of multr4lications.

        smull       r4, r0, r1, r0
        rsb         r0, r0, r2, asr #1
        smull       r4, r0, r1, r0
        add         r0, r3
        smull       r4, r0, r1, r0
        rsb         r0, r2

@ Corrects the sign of the obtained estimate if the angle value was in the
@ second semicircle. Then, converts the result to the required fixed-point
@ representation and rounds the result. The second instruction makes shure
@ the carry flag is cleared. Because if the denormalization shift is zero,
@ the shift instruction will not update the carry flag, which can cause an
@ incorrect rounding.

        rsbcs       r0, r0, #0
        lsls        r4, r5, #1
        asrs        r0, r0, r5
        adc         tos, r0, #0
    NEXT

@ (a -- abs(a) )
	defcode "FIX32_ABS",9,,FIX32_ABS
    eor         r1, tos, tos, asr #31
    sub         tos, r1, tos, asr #31
    NEXT

@ (mag sign -- mag+sign )
	defcode "FIX32_COPY",10,,FIX32_COPY
    pop {r0}
    eor         r2, r0, tos
        eor         r0, r0, r2, asr #31
        sub         tos, r0, r2, asr #31
    NEXT

@ (mag sign -- mag+sign )
	defcode "FIX32_FLIP",10,,FIX32_FLIP
    pop {r0}
    eor         r0, r0, tos, asr #31
        sub         tos, r0, tos, asr #31
    NEXT

@ (a exp -- 0.a )
	defcode "FIX32_FRAC",10,,FIX32_FRAC
    pop {r0}
    tst         r0, r0
        negmi       r0, r0
        lsr         r2, r0, tos
        lsl         r2, r2, tos
        sub         tos, r0, r2
        negmi       tos, tos
    NEXT

@ (a exp -- a.0 )
	defcode "FIX32_TRUN",10,,FIX32_TRUN
    pop {r0}
    tst         r0, r0
        negmi       r0, r0
        lsr         r0, r0, tos
        lsl         tos, r0, tos
        negmi       tos, tos
    NEXT

@ (a src dst -- a(dst) )
	defcode "FIX32_CONV",10,,FIX32_CONV
	pop {r0-r1}
	/*
	(n,e)
	k = n << (r-p)      if (r>=p)
	k = n >> (p-r)      if (p>r)
	*/
	cmp tos, r0
	subge r0, tos, r0
	lslge tos, r1, r0
	sublt r0, r0, tos
	lsrlt tos, r1, r0
    NEXT

@ (a min max  -- a(clipped) )
	defcode "FIX32_CLIP",10,,FIX32_CLIP
    pop {r0-r1}
    	mov         r2, tos
		mov 		tos, r1
        cmp         r1, r0
        movlt       tos, r0
        cmp         r1, r2
        movgt       tos, r2
    NEXT

	.global     fix32_inv_table
        .global     fix32_isqrt_table
        .global     fix32_sin_table


@ The reciprocal lookup table. The table consist of 256 eight-bit entries.
@ Each entry represents the eight least significant bits of a nine-bit Q8
@ reciprocal of a number in the range from one-half to one. The ninth bit
@ is ignored since it is always set and can be restored by software. The
@ entries are packed into 32-bit little-endian words.

        .section   .rodata
        .align

fix32_inv_table:
        .4byte      0xf9fbfdfe, 0xf1f3f5f7, 0xeaeceef0, 0xe3e5e6e8
        .4byte      0xdcdddfe1, 0xd5d7d8da, 0xced0d2d3, 0xc8c9cbcd
        .4byte      0xc2c3c5c6, 0xbcbdbfc0, 0xb6b7b9ba, 0xb0b1b3b4
        .4byte      0xaaacadae, 0xa5a6a7a9, 0x9fa1a2a3, 0x9a9c9d9e
        .4byte      0x95969899, 0x90919394, 0x8b8d8e8f, 0x8788898a
        .4byte      0x82838486, 0x7e7f8081, 0x797a7b7c, 0x75767778
        .4byte      0x71727374, 0x6d6e6f70, 0x696a6b6c, 0x65666768
        .4byte      0x61626364, 0x5d5e5f60, 0x595a5b5c, 0x56575858
        .4byte      0x52535455, 0x4f505151, 0x4b4c4d4e, 0x48494a4b
        .4byte      0x45464647, 0x42424344, 0x3f3f4041, 0x3b3c3d3e
        .4byte      0x38393a3b, 0x35363738, 0x33333435, 0x30303132
        .4byte      0x2d2e2e2f, 0x2a2b2c2c, 0x2828292a, 0x25262627
        .4byte      0x22232424, 0x20202122, 0x1d1e1e1f, 0x1b1b1c1d
        .4byte      0x18191a1a, 0x16171718, 0x14141515, 0x11121213
        .4byte      0x0f101011, 0x0d0d0e0f, 0x0b0b0c0c, 0x09090a0a
        .4byte      0x06070708, 0x04050506, 0x02030304, 0x00010102


@ The inverse square root lookup table. Each table entry is 16-bit wide and
@ represents a Q10 inverse square root of a number that is in the range from
@ one-half to one. The entries are packed into 32-bit little-endian words.

fix32_isqrt_table:
        .4byte      0x05a005a5, 0x0595059a, 0x058a058f, 0x05800585
        .4byte      0x0575057a, 0x056b0570, 0x05610566, 0x0558055d
        .4byte      0x054e0553, 0x0545054a, 0x053c0540, 0x05330538
        .4byte      0x052a052f, 0x05220526, 0x051a051e, 0x05110515
        .4byte      0x0509050d, 0x05010505, 0x04fa04fd, 0x04f204f6
        .4byte      0x04ea04ee, 0x04e304e7, 0x04dc04df, 0x04d504d8
        .4byte      0x04ce04d1, 0x04c704ca, 0x04c004c3, 0x04b904bd
        .4byte      0x04b304b6, 0x04ad04b0, 0x04a604a9, 0x04a004a3
        .4byte      0x049a049d, 0x04940497, 0x048e0491, 0x0488048b
        .4byte      0x04820485, 0x047d047f, 0x0477047a, 0x04710474
        .4byte      0x046c046f, 0x04670469, 0x04610464, 0x045c045f
        .4byte      0x0457045a, 0x04520454, 0x044d044f, 0x0448044a
        .4byte      0x04430445, 0x043e0441, 0x043a043c, 0x04350437
        .4byte      0x04300433, 0x042c042e, 0x04270429, 0x04230425
        .4byte      0x041e0420, 0x041a041c, 0x04160418, 0x04110414
        .4byte      0x040d040f, 0x0409040b, 0x04050407, 0x04010403


@ The sine lookup table. The table describes the first quarter of the sine
@ wave and consist of 64 entries, which are numbers in the Q31 fixed-point
@ format. Each number represents the sine of an angle in the first quadrant.

fix32_sin_table:
        .4byte      0x01921d20, 0x04b6195d, 0x07d95b9e, 0x0afb6805
        .4byte      0x0e1bc2e4, 0x1139f0cf, 0x145576b1, 0x176dd9de
        .4byte      0x1a82a026, 0x1d934fe5, 0x209f701c, 0x23a6887f
        .4byte      0x26a82186, 0x29a3c485, 0x2c98fbba, 0x2f875262
        .4byte      0x326e54c7, 0x354d9057, 0x382493b0, 0x3af2eeb7
        .4byte      0x3db832a6, 0x4073f21d, 0x4325c136, 0x45cd3590
        .4byte      0x4869e665, 0x4afb6c98, 0x4d8162c4, 0x4ffb654d
        .4byte      0x5269126f, 0x54ca0a4b, 0x571deefa, 0x59646498
        .4byte      0x5b9d1154, 0x5dc79d7c, 0x5fe3b38e, 0x61f1003f
        .4byte      0x63ef3290, 0x65ddfbd3, 0x67bd0fbd, 0x698c246c
        .4byte      0x6b4af279, 0x6cf934fc, 0x6e96a99d, 0x7023109a
        .4byte      0x719e2cd3, 0x7307c3d0, 0x745f9dd1, 0x75a585d0
        .4byte      0x76d94989, 0x77fab989, 0x7909a92d, 0x7a05eeae
        .4byte      0x7aef6324, 0x7bc5e290, 0x7c894bde, 0x7d3980ed
        .4byte      0x7dd6668f, 0x7e5fe494, 0x7ed5e5c7, 0x7f3857f6
        .4byte      0x7f872bf3, 0x7fc25597, 0x7fe9cbc1, 0x7ffd885b



	

