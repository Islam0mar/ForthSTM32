defcode "C2FLASH",5,,FLASH	
@@@ Unlock Flash Control
	ldr r2, =FLASH_KEYR
	ldr r3, =FLASH_KEY1
	str r3, [r2]
	ldr r3, =FLASH_KEY2
	str r3, [r2]
	
								@ Enable write
	ldr r2, =FLASH_CR
	ldr r3, [r2]
	orr r3, #FLASH_CR_PG @ Select Flash programming
	str r3, [r2]

@@ 								@ Wait for Flash BUSY Flag to be cleared
@@ 	ldr r2, =FLASH_SR

@@ 1:  	ldr r3, [r2]
@@     ands r3, #FLASH_SR_BSY
@@     bne 1b
	ldr r0, var_DP
	ldr r1, var_FLASH
	ldr r2, var_RAM
	ldr r3, [r0]
	str r3, [r2]
	ldr r3, [r1]
	str r3, [r0]

	NEXT
defcode "C2RAM",4,,DROP
@@@ Lock Flash after finishing this
	ldr r2, =FLASH_CR
	movs r3, #FLASH_CR_LOCK
	str r3, [r2]
	NEXT
