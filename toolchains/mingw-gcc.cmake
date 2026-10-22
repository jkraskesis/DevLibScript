set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR x86_64)
set(CMAKE_C_COMPILER x86_64-w64-mingw32-gcc)
set(CMAKE_CXX_COMPILER x86_64-w64-mingw32-g++)
set(CMAKE_RC_COMPILER x86_64-w64-mingw32-windres)

execute_process(
    COMMAND ${CMAKE_C_COMPILER} -print-file-name=libkernel32.a
    OUTPUT_VARIABLE mingw_kernel32
    OUTPUT_STRIP_TRAILING_WHITESPACE
    COMMAND_ERROR_IS_FATAL ANY
)
if(NOT IS_ABSOLUTE "${mingw_kernel32}" OR NOT EXISTS "${mingw_kernel32}")
    message(FATAL_ERROR "Cannot locate the MinGW Windows libraries")
endif()
get_filename_component(mingw_libdir "${mingw_kernel32}" DIRECTORY)
get_filename_component(mingw_root "${mingw_libdir}/.." REALPATH)
list(APPEND CMAKE_FIND_ROOT_PATH "${mingw_root}")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)
