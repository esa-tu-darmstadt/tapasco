cmake_minimum_required(VERSION 3.5.1 FATAL_ERROR)
include($ENV{TAPASCO_HOME_RUNTIME}/cmake/Tapasco.cmake NO_POLICY_SCOPE)
project (image-processing)

if(NOT TARGET tapasco)
find_package(TapascoTLKM REQUIRED)
find_package(TapascoCommon REQUIRED)
find_package(TapascoPlatform REQUIRED)
find_package(Tapasco REQUIRED)
endif(NOT TARGET tapasco)

find_package(PNG)
find_package (Threads)

add_executable (imgproc imgproc.cpp cliparser.cpp stringtools.cpp ${CMAKE_CURRENT_BINARY_DIR}/CImg/CImg.h)
target_include_directories(imgproc PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/)
set_tapasco_defaults(imgproc)
target_link_libraries (imgproc PRIVATE tapasco tlkm platform tapasco-common ${CMAKE_THREAD_LIBS_INIT} PNG::PNG)

add_executable (print_status print_status.cpp)
set_tapasco_defaults(print_status)
target_link_libraries (print_status PRIVATE tapasco tlkm platform tapasco-common ${CMAKE_THREAD_LIBS_INIT})

target_compile_definitions(imgproc PRIVATE -Dcimg_display=0)

IF(PNG_FOUND)
    target_compile_definitions(imgproc PRIVATE -Dcimg_use_png)
ENDIF()

add_custom_command(OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/CImg/CImg.h
  COMMAND rm -rf ${CMAKE_CURRENT_BINARY_DIR}/CImg
  COMMAND wget -O ${CMAKE_CURRENT_BINARY_DIR}/CImg.zip "http://cimg.eu/files/CImg_latest.zip"
  COMMAND unzip ${CMAKE_CURRENT_BINARY_DIR}/CImg.zip
  COMMAND mv "${CMAKE_CURRENT_BINARY_DIR}/CImg-*" ${CMAKE_CURRENT_BINARY_DIR}/CImg
  COMMAND rm -f ${CMAKE_CURRENT_BINARY_DIR}/CImg.zip
  )
