/**
  *************** (C) COPYRIGHT 2016 STMicroelectronics ************************
  * @file      startup_stm32f103xb.s
  * @author    MCD Application Team
  * @version   V4.1.0
  * @date      29-April-2016
  * @brief     STM32F103xB Devices vector table for Atollic toolchain.
  *            This module performs:
  *                - Set the initial SP
  *                - Set the initial PC == Reset_Handler,
  *                - Set the vector table entries with the exceptions ISR address
  *                - Configure the clock system   
  *                - Branches to main in the C library (which eventually
  *                  calls main()).
  *            After Reset the Cortex-M3 processor is in Thread mode,
  *            priority is Privileged, and the Stack is set to Main.
  ******************************************************************************
  */

    .syntax unified
    .cpu cortex-m3
    .fpu softvfp
    .thumb
	.thumb_func
    .global __stack_start__
    .global __stack_end__
    .global g_pfnVectors
    .global Default_Handler
	.align 2
/* start address for the initialization values of the .data section.
defined in linker script */
.4byte __data_load
/* start address for the .data section. defined in linker script */
.4byte __data_start
/* end address for the .data section. defined in linker script */
.4byte __data_end__
/* start address for the .bss section. defined in linker script */
.4byte __bss_start__
/* end address for the .bss section. defined in linker script */
.4byte __bss_end__

.equ  BootRAM, 0xF108F85F
/**
 * @brief  This is the code that gets called when the processor first
 *          starts execution following a reset event. Only the absolutely
 *          necessary set is performed, after which the application
 *          supplied main() routine is called.
 * @param  None
 * @retval : None
*/

  .section .text.Reset_Handler
  .weak Reset_Handler
  .type Reset_Handler, %function
Reset_Handler:

    .extern main
/* Copy the data segment initializers from flash to SRAM */
  movs r1, #0
  b LoopCopyDataInit

CopyDataInit:
  ldr r3, =__data_load
  ldr r3, [r3, r1]
  str r3, [r0, r1]
  adds r1, r1, #4

LoopCopyDataInit:
  ldr r0, =__data_start
  ldr r3, =__data_end__
  adds r2, r0, r1
  cmp r2, r3
  bcc CopyDataInit
  ldr r2, =__bss_start__
  b LoopFillZerobss
/* Zero fill the bss segment. */
FillZerobss:
    movs r3, #0
    str r3, [r2], #4

LoopFillZerobss:
  ldr r3, =__bss_end__
  cmp r2, r3
  bcc FillZerobss

/* Call the clock system intitialization function.*/
    bl  SystemInit
/* Call static constructors */
    /*bl __libc_init_array*/
/* Call the application's entry point.*/
    bl main
    bx lr
.size Reset_Handler, .-Reset_Handler

/**
 * @brief  This is the code that gets called when the processor receives an
 *         unexpected interrupt.  This simply enters an infinite loop, preserving
 *         the system state for examination by a debugger.
 *
 * @param  None
 * @retval : None
*/
    .section .text.Default_Handler,"ax",%progbits
Default_Handler:
Infinite_Loop:
  b Infinite_Loop
  .size Default_Handler, .-Default_Handler
/******************************************************************************
*
* The minimal vector table for a Cortex M3.  Note that the proper constructs
* must be placed on this to ensure that it ends up at physical address
* 0x0000.0000.
*
******************************************************************************/
  .section .isr_vector,"a",%progbits
  .type g_pfnVectors, %object
  .size g_pfnVectors, .-g_pfnVectors


g_pfnVectors:

  .4byte __stack_end__
  .4byte Reset_Handler
  .4byte NMI_Handler
  .4byte HardFault_Handler
  .4byte MemManage_Handler
  .4byte BusFault_Handler
  .4byte UsageFault_Handler
  .4byte 0
  .4byte 0
  .4byte 0
  .4byte 0
  .4byte SVC_Handler
  .4byte DebugMon_Handler
  .4byte 0
  .4byte PendSV_Handler
  .4byte SysTick_Handler
/*  .4byte WWDG_IRQHandler
  ;; .4byte PVD_IRQHandler
  ;; .4byte TAMPER_IRQHandler
  ;; .4byte RTC_IRQHandler
  ;; .4byte FLASH_IRQHandler
  ;; .4byte RCC_IRQHandler
  ;; .4byte EXTI0_IRQHandler
  ;; .4byte EXTI1_IRQHandler
  ;; .4byte EXTI2_IRQHandler
  ;; .4byte EXTI3_IRQHandler
  ;; .4byte EXTI4_IRQHandler
  ;; .4byte DMA1_Channel1_IRQHandler
  ;; .4byte DMA1_Channel2_IRQHandler
  ;; .4byte DMA1_Channel3_IRQHandler
  ;; .4byte DMA1_Channel4_IRQHandler
  ;; .4byte DMA1_Channel5_IRQHandler
  ;; .4byte DMA1_Channel6_IRQHandler
  ;; .4byte DMA1_Channel7_IRQHandler
  ;; .4byte ADC1_2_IRQHandler
  ;; .4byte USB_HP_CAN1_TX_IRQHandler
  ;; .4byte USB_LP_CAN1_RX0_IRQHandler
  ;; .4byte CAN1_RX1_IRQHandler
  ;; .4byte CAN1_SCE_IRQHandler
  ;; .4byte EXTI9_5_IRQHandler
  ;; .4byte TIM1_BRK_IRQHandler
  ;; .4byte TIM1_UP_IRQHandler
  ;; .4byte TIM1_TRG_COM_IRQHandler
  ;; .4byte TIM1_CC_IRQHandler
  ;; .4byte TIM2_IRQHandler
  ;; .4byte TIM3_IRQHandler
  ;; .4byte TIM4_IRQHandler
  ;; .4byte I2C1_EV_IRQHandler
  ;; .4byte I2C1_ER_IRQHandler
  ;; .4byte I2C2_EV_IRQHandler
  ;; .4byte I2C2_ER_IRQHandler
  ;; .4byte SPI1_IRQHandler
  ;; .4byte SPI2_IRQHandler
  ;; .4byte USART1_IRQHandler
  ;; .4byte USART2_IRQHandler
  ;; .4byte USART3_IRQHandler
  ;; .4byte EXTI15_10_IRQHandler
  ;; .4byte RTC_Alarm_IRQHandler
  ;; .4byte USBWakeUp_IRQHandler
  ;; .4byte 0
  ;; .4byte 0
  ;; .4byte 0
  ;; .4byte 0
  ;; .4byte 0
  ;; .4byte 0
  ;; .4byte 0
  ;; .4byte BootRAM  */  /* @0x108. This is for boot in RAM mode for
							/*STM32F10x Medium Density devices. */
	.global g_pfnVectors_end
g_pfnVectors_end:	
/*******************************************************************************
*
* Provide weak aliases for each Exception handler to the Default_Handler.
* As they are weak aliases, any function with the same name will override
* this definition.
*
*******************************************************************************/

  .weak NMI_Handler
  .thumb_set NMI_Handler,Default_Handler

  .weak HardFault_Handler
  .thumb_set HardFault_Handler,Default_Handler

  .weak MemManage_Handler
  .thumb_set MemManage_Handler,Default_Handler

  .weak BusFault_Handler
  .thumb_set BusFault_Handler,Default_Handler

  .weak UsageFault_Handler
  .thumb_set UsageFault_Handler,Default_Handler

  .weak SVC_Handler
  .thumb_set SVC_Handler,Default_Handler

  .weak DebugMon_Handler
  .thumb_set DebugMon_Handler,Default_Handler

  .weak PendSV_Handler
  .thumb_set PendSV_Handler,Default_Handler

  .weak SysTick_Handler
  .thumb_set SysTick_Handler,Default_Handler

  .weak WWDG_IRQHandler
  .thumb_set WWDG_IRQHandler,Default_Handler

  .weak PVD_IRQHandler
  .thumb_set PVD_IRQHandler,Default_Handler

  .weak TAMPER_IRQHandler
  .thumb_set TAMPER_IRQHandler,Default_Handler

  .weak RTC_IRQHandler
  .thumb_set RTC_IRQHandler,Default_Handler

  .weak FLASH_IRQHandler
  .thumb_set FLASH_IRQHandler,Default_Handler

  .weak RCC_IRQHandler
  .thumb_set RCC_IRQHandler,Default_Handler

  .weak EXTI0_IRQHandler
  .thumb_set EXTI0_IRQHandler,Default_Handler

  .weak EXTI1_IRQHandler
  .thumb_set EXTI1_IRQHandler,Default_Handler

  .weak EXTI2_IRQHandler
  .thumb_set EXTI2_IRQHandler,Default_Handler

  .weak EXTI3_IRQHandler
  .thumb_set EXTI3_IRQHandler,Default_Handler

  .weak EXTI4_IRQHandler
  .thumb_set EXTI4_IRQHandler,Default_Handler

  .weak DMA1_Channel1_IRQHandler
  .thumb_set DMA1_Channel1_IRQHandler,Default_Handler

  .weak DMA1_Channel2_IRQHandler
  .thumb_set DMA1_Channel2_IRQHandler,Default_Handler

  .weak DMA1_Channel3_IRQHandler
  .thumb_set DMA1_Channel3_IRQHandler,Default_Handler

  .weak DMA1_Channel4_IRQHandler
  .thumb_set DMA1_Channel4_IRQHandler,Default_Handler

  .weak DMA1_Channel5_IRQHandler
  .thumb_set DMA1_Channel5_IRQHandler,Default_Handler

  .weak DMA1_Channel6_IRQHandler
  .thumb_set DMA1_Channel6_IRQHandler,Default_Handler

  .weak DMA1_Channel7_IRQHandler
  .thumb_set DMA1_Channel7_IRQHandler,Default_Handler

  .weak ADC1_2_IRQHandler
  .thumb_set ADC1_2_IRQHandler,Default_Handler

  .weak USB_HP_CAN1_TX_IRQHandler
  .thumb_set USB_HP_CAN1_TX_IRQHandler,Default_Handler

  .weak USB_LP_CAN1_RX0_IRQHandler
  .thumb_set USB_LP_CAN1_RX0_IRQHandler,Default_Handler

  .weak CAN1_RX1_IRQHandler
  .thumb_set CAN1_RX1_IRQHandler,Default_Handler

  .weak CAN1_SCE_IRQHandler
  .thumb_set CAN1_SCE_IRQHandler,Default_Handler

  .weak EXTI9_5_IRQHandler
  .thumb_set EXTI9_5_IRQHandler,Default_Handler

  .weak TIM1_BRK_IRQHandler
  .thumb_set TIM1_BRK_IRQHandler,Default_Handler

  .weak TIM1_UP_IRQHandler
  .thumb_set TIM1_UP_IRQHandler,Default_Handler

  .weak TIM1_TRG_COM_IRQHandler
  .thumb_set TIM1_TRG_COM_IRQHandler,Default_Handler

  .weak TIM1_CC_IRQHandler
  .thumb_set TIM1_CC_IRQHandler,Default_Handler

  .weak TIM2_IRQHandler
  .thumb_set TIM2_IRQHandler,Default_Handler

  .weak TIM3_IRQHandler
  .thumb_set TIM3_IRQHandler,Default_Handler

  .weak TIM4_IRQHandler
  .thumb_set TIM4_IRQHandler,Default_Handler

  .weak I2C1_EV_IRQHandler
  .thumb_set I2C1_EV_IRQHandler,Default_Handler

  .weak I2C1_ER_IRQHandler
  .thumb_set I2C1_ER_IRQHandler,Default_Handler

  .weak I2C2_EV_IRQHandler
  .thumb_set I2C2_EV_IRQHandler,Default_Handler

  .weak I2C2_ER_IRQHandler
  .thumb_set I2C2_ER_IRQHandler,Default_Handler

  .weak SPI1_IRQHandler
  .thumb_set SPI1_IRQHandler,Default_Handler

  .weak SPI2_IRQHandler
  .thumb_set SPI2_IRQHandler,Default_Handler

  .weak USART1_IRQHandler
  .thumb_set USART1_IRQHandler,Default_Handler

  .weak USART2_IRQHandler
  .thumb_set USART2_IRQHandler,Default_Handler

  .weak USART3_IRQHandler
  .thumb_set USART3_IRQHandler,Default_Handler

  .weak EXTI15_10_IRQHandler
  .thumb_set EXTI15_10_IRQHandler,Default_Handler

  .weak RTC_Alarm_IRQHandler
  .thumb_set RTC_Alarm_IRQHandler,Default_Handler

  .weak USBWakeUp_IRQHandler
  .thumb_set USBWakeUp_IRQHandler,Default_Handler 

   .align
/************************ (C) COPYRIGHT STMicroelectronics *****END OF FILE****/
