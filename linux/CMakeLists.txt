cmake_minimum_required(VERSION 3.10)
project(opennotes LANGUAGES CXX)

set(BINARY_NAME "opennotes")

cmake_policy(SET CMP0079 NEW)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_subdirectory(flutter)

add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
)

target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK)
target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")
