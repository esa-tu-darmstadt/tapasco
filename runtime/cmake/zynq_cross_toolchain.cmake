cmake_minimum_required(VERSION 3.0.0 FATAL_ERROR)

set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)

find_program(GNUEABIHF_GCC arm-linux-gnueabihf-gcc)
if(${GNUEABIHF_GCC} MATCHES "GNUEABIHF_GCC-NOTFOUND")
    set(CMAKE_C_COMPILER arm-linux-gnu-gcc)
else()
    set(CMAKE_C_COMPILER arm-linux-gnueabihf-gcc)
endif()

find_program(GNUEABIHF_GPP arm-linux-gnueabihf-g++)
if(${GNUEABIHF_GPP} MATCHES "GNUEABIHF_GPP-NOTFOUND")
    set(CMAKE_CXX_COMPILER arm-linux-gnu-g++)
else()
    set(CMAKE_CXX_COMPILER arm-linux-gnueabihf-g++)
endif()
