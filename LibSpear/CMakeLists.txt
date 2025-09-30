cmake_minimum_required(VERSION 3.20)

project(libspear CXX C)

set (CMAKE_CXX_STANDARD 20)
set (CMAKE_CXX_STANDARD_REQUIRED ON)
set (CMAKE_CXX_EXTENSIONS OFF)

set (CMAKE_C_STANDARD 99)
set (CMAKE_C_STANDARD_REQUIRED ON)
set (CMAKE_C_EXTENSIONS OFF)

set (CMAKE_USE_RELATIVE_PATHS ON)

set (SPEAR_COMPILE_OPTIONS )

if (CMAKE_CXX_COMPILER_ID STREQUAL "Clang" OR CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
  set (NICE_COMPILER ON)
else ()
  message (WARNING "Using not fully supported compiler")
endif ()

if (NICE_COMPILER)
  list (APPEND SPEAR_COMPILE_OPTIONS
    "-fPIC"
    "-pthread"
    "-Wall"
    "-Wextra"
    "-Wpointer-arith"
    "-Werror=return-type"
    "-Werror=old-style-cast"
    "-Werror=uninitialized"
    "-Werror=maybe-uninitialized"
    "-Werror=nonnull"
    "-Werror=cast-qual"
    "-Werror=cast-align"
    "-Werror=return-local-addr"
    "-Werror=date-time"
    "-Wno-type-limits"
    "-Wno-unused-parameter"
    "-Wno-missing-field-initializers"
    "-Wno-useless-cast"
  )

  if (CMAKE_BUILD_TYPE STREQUAL "Debug" OR CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo")
    list (APPEND SPEAR_COMPILE_OPTIONS
      "-Werror=null-dereference"
    )
  else ()
    list (APPEND SPEAR_COMPILE_OPTIONS
      "-Wno-null-dereference"
    )
  endif ()
endif ()

add_subdirectory(godot-cpp        godot-cpp    EXCLUDE_FROM_ALL)

include_directories("${GODOT_GDEXTENSION_DIR}")
include_directories("src")

add_library(libspear SHARED
  src/battle_manager_fast.cpp
  src/battle_mcts.cpp
  src/battle_structs.cpp
  src/register_types.cpp
  src/tile_grid_fast.cpp
)

find_package(OpenMP)
if (OpenMP_CXX_FOUND)
  target_link_libraries(libspear OpenMP::OpenMP_CXX)
else ()
  message(FATAL_ERROR "OpenMP not found")
endif ()

target_link_libraries(libspear
  godot::cpp
)


target_compile_options(libspear PUBLIC
  ${SPEAR_COMPILE_OPTIONS}
)


set_target_properties(libspear PROPERTIES PREFIX "")
# set_target_properties(libspear PROPERTIES OUTPUT_NAME "")

if (CMAKE_BUILD_TYPE STREQUAL "")
  set (BUILD_TYPE_LOWERCASE debug)
elseif (CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo")
  set (BUILD_TYPE_LOWERCASE debug)
else ()
  string(TOLOWER ${CMAKE_BUILD_TYPE} BUILD_TYPE_LOWERCASE)
endif ()
set (ARCHITECTURE "x86_64") # TODO
string(TOLOWER ${CMAKE_SYSTEM_NAME} OS_LOWERCASE)
set (EXTENSION "so")
IF (WIN32)
  set (EXTENSION "dll")
ENDIF()

set_target_properties(libspear PROPERTIES SUFFIX
  ".${OS_LOWERCASE}.template_${BUILD_TYPE_LOWERCASE}.${ARCHITECTURE}.${EXTENSION}")

add_custom_command(
  TARGET libspear POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy "$<TARGET_FILE:libspear>" "${CMAKE_CURRENT_SOURCE_DIR}/bin"
)
