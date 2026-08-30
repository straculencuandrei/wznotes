cmake_minimum_required(VERSION 3.14)
project(wznotes LANGUAGES CXX)

# Set the application-level name here.
set(BINARY_NAME "wznotes")

cmake_policy(SET CMP0079 NEW)
cmake_policy(SET CMP0063 NEW)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_definitions(
  -DUNICODE
  -D_UNICODE
  -D_ALLOW_STRING_ITERATOR_CONVERSIONS
  -D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS
  -D_SILENCE_ALL_CXX23_DEPRECATION_WARNINGS
  -D_SILENCE_ALL_CXX20_DEPRECATION_WARNINGS
  -D_SILENCE_ALL_MS_EXT_DEPRECATION_WARNINGS
)

# Standard CMake settings for Flutter plugins and application.
macro(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE /W4 /wd"4100" /permissive)
  target_compile_options(${TARGET} PRIVATE /EHsc)
  target_compile_definitions(${TARGET} PRIVATE
    "UNICODE"
    "_UNICODE"
    "_HAS_EXCEPTIONS=0"
    "_ALLOW_STRING_ITERATOR_CONVERSIONS"
    "_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS"
    "_SILENCE_ALL_CXX23_DEPRECATION_WARNINGS"
    "_SILENCE_ALL_CXX20_DEPRECATION_WARNINGS"
    "_SILENCE_ALL_MS_EXT_DEPRECATION_WARNINGS"
    "$<$<CONFIG:Debug>:_DEBUG>"
  )
endmacro()

set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")

# Flutter framework and wrapper build.
add_subdirectory(${FLUTTER_MANAGED_DIR})

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")

# Generated plugin build.
set(PLUGIN_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter/ephemeral/.plugin_symlinks")
set(GENERATED_PLUGINS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
include("${GENERATED_PLUGINS_DIR}/generated_plugins.cmake")

# === Installation ===
# Support files are copied into place next to the executable, so that it can
# run in place.
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "${CMAKE_BINARY_DIR}/runner/$<CONFIG>" CACHE PATH "..." FORCE)
endif()

set(INSTALL_BUNDLE_DATA true)

if(INSTALL_BUNDLE_DATA)
  install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
    COMPONENT Runtime)

  install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${CMAKE_INSTALL_PREFIX}/data"
    COMPONENT Runtime)

  install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${CMAKE_INSTALL_PREFIX}"
    COMPONENT Runtime)

  if(PLUGIN_BUNDLED_LIBRARIES)
    install(FILES "${PLUGIN_BUNDLED_LIBRARIES}"
      DESTINATION "${CMAKE_INSTALL_PREFIX}" COMPONENT Runtime)
  endif()

  install(DIRECTORY "${PROJECT_BUILD_DIR}/flutter_assets"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/data" COMPONENT Runtime)

  install(FILES "${AOT_LIBRARY}"
    DESTINATION "${CMAKE_INSTALL_PREFIX}/data" COMPONENT Runtime
    CONFIGURATIONS Release;Profile;RelWithDebInfo;MinSizeRel)
endif()
