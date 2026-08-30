cmake_minimum_required(VERSION 3.14)
project(opennotes LANGUAGES CXX)

set(BINARY_NAME "opennotes")

cmake_policy(SET CMP0079 NEW)

add_definitions(-DUNICODE -D_UNICODE)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_subdirectory(flutter)

add_executable(${BINARY_NAME} WIN32
  "runner/main.cpp"
  "runner/utils.cpp"
  "runner/win32_window.cpp"
  "runner/flutter_window.cpp"
  "runner/Runner.rc"
  "runner/flutter_window.h"
  "runner/main.h"
  "runner/resource.h"
  "runner/utils.h"
  "runner/win32_window.h"
)

target_link_libraries(${BINARY_NAME} PRIVATE flutter flutter_wrapper_app)
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")
