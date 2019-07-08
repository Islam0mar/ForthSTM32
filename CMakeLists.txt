cmake_minimum_required(VERSION 3.0)

# the name of the target operating system
#
INCLUDE(CMakeForceCompiler) 

set(CMAKE_SYSTEM_NAME      Generic)
set(CMAKE_SYSTEM_VERSION   1)
set(CMAKE_SYSTEM_PROCESSOR arm-eabi)

# which compilers to use for C and C++
# CMAKE_FORCE_C_COMPILER(arm-none-eabi-gcc GNU)
# CMAKE_FORCE_CXX_COMPILER(arm-none-eabi-g++ GNU)

set(CMAKE_C_COMPILER       arm-none-eabi-gcc)
set(CMAKE_CXX_COMPILER     arm-none-eabi-g++)
set(CMAKE_ASM_COMPILER     arm-none-eabi-as)
set(CMAKE_LINKER           arm-none-eabi-ld)
set(CMAKE_OBJCOPY     	   arm-none-eabi-objcopy)
set(CMAKE_OBJDUMP          arm-none-eabi-objdump)
set(CMAKE_SIZE             arm-none-eabi-size)
set(CMAKE_ASM_LINK_EXECUTABLE "<CMAKE_LINKER> <LINK_FLAGS> <OBJECTS> -o <TARGET> <LINK_LIBRARIES>")
# project
project(forth ASM)

#enable_language(ASM-ATT)
set(PROJECT_PATH "${CMAKE_CURRENT_SOURCE_DIR}")
# Bring the headers into the project
include_directories(include)
# flags
set(LINKER_SCRIPT ${CMAKE_SOURCE_DIR}/STM32F103C8T6.ld)
# The file(GLOB...) allows for wildcard additions:
file(GLOB SOURCES "${PROJECT_PATH}/src/*.s")
set(EXECUTABLE_OUTPUT_PATH "${PROJECT_PATH}/bin")
set(CMAKE_BINARY_DIR "${PROJECT_PATH}/bin")
#set_source_files_properties(main.s PROPERTIES COMPILE_FLAGS "-x assembler-with-cpp")

# linker
set(CMAKE_EXE_LINKER_FLAGS "-v -T ${LINKER_SCRIPT}")
#set(CMAKE_EXE_LINKER_FLAGS "-nostartfiles -Wl,--gc-sections -mthumb -mcpu=cortex-m3" CACHE INTERNAL "exe link flags")

set(CMAKE_C_FLAGS "-mthumb -mcpu=cortex-m3 -fno-builtin -Wall -std=gnu99 -ffreestanding -fdata-sections -ffunction-sections")
set(CMAKE_CXX_FLAGS "-mthumb -mcpu=cortex-m3 -fno-builtin -Wall std=c++11 -ffreestanding  -fdata-sections -ffunction-sections")
set(CMAKE_ASM_FLAGS "-mimplicit-it=always -gdb3 -mthumb -mcpu=cortex-m3")

set(STARTUP src/startupSTM32F103C8T6.s)
#set(CMAKE_VERBOSE_MAKEFILE ON)
add_executable(${PROJECT_NAME}.elf ${SOURCES} ${STARTUP} ${LINKER_SCRIPT} )

set(LIST_FILE ${PROJECT_SOURCE_DIR}/bin/${PROJECT_NAME}.list)
set(HEX_FILE ${PROJECT_SOURCE_DIR}/bin/${PROJECT_NAME}.hex)
set(BIN_FILE ${PROJECT_SOURCE_DIR}/bin/${PROJECT_NAME}.bin)
add_custom_command(TARGET ${PROJECT_NAME}.elf POST_BUILD
COMMAND ${CMAKE_OBJDUMP} -D $<TARGET_FILE:${PROJECT_NAME}.elf> >${LIST_FILE}
COMMAND ${CMAKE_OBJCOPY} -Oihex $<TARGET_FILE:${PROJECT_NAME}.elf> ${HEX_FILE}
COMMAND ${CMAKE_OBJCOPY} -Obinary $<TARGET_FILE:${PROJECT_NAME}.elf> ${BIN_FILE}
COMMAND ${CMAKE_SIZE} -A -x -t $<TARGET_FILE:${PROJECT_NAME}.elf>
COMMENT "Building ${LIST_FILE} \nBuilding ${HEX_FILE} \nBuilding ${BIN_FILE}")

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)

# upload
# /* st-flash write forth.bin 0x08000000 */

# debugg
# openocd -f interface/stlink-v2.cfg -c "transport select hla_swd" -f target/stm32f1x.cfg

# arm-none-eabi-gdb -tui --command=attach.gdb forth.elf
# i r "info register" , i r r1
# continue

# generate asm from C/C++ 
# arm-none-eabi-gcc -S -fverbose-asm -Ofast -o os.s system_stm32f1xx.c -I../Drivers/CMSIS/Device/ST/STM32F1xx/Include  -DSTM32F103xB -I../Drivers/CMSIS/Include -mthumb -mcpu=cortex-m3
