include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


include(CheckCXXSourceCompiles)


macro(exploration_supports_sanitizers)
  # Emscripten doesn't support sanitizers
  if(EMSCRIPTEN)
    set(SUPPORTS_UBSAN OFF)
    set(SUPPORTS_ASAN OFF)
  elseif((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)

    message(STATUS "Sanity checking UndefinedBehaviorSanitizer, it should be supported on this platform")
    set(TEST_PROGRAM "int main() { return 0; }")

    # Check if UndefinedBehaviorSanitizer works at link time
    set(CMAKE_REQUIRED_FLAGS "-fsanitize=undefined")
    set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=undefined")
    check_cxx_source_compiles("${TEST_PROGRAM}" HAS_UBSAN_LINK_SUPPORT)

    if(HAS_UBSAN_LINK_SUPPORT)
      message(STATUS "UndefinedBehaviorSanitizer is supported at both compile and link time.")
      set(SUPPORTS_UBSAN ON)
    else()
      message(WARNING "UndefinedBehaviorSanitizer is NOT supported at link time.")
      set(SUPPORTS_UBSAN OFF)
    endif()
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    if (NOT WIN32)
      message(STATUS "Sanity checking AddressSanitizer, it should be supported on this platform")
      set(TEST_PROGRAM "int main() { return 0; }")

      # Check if AddressSanitizer works at link time
      set(CMAKE_REQUIRED_FLAGS "-fsanitize=address")
      set(CMAKE_REQUIRED_LINK_OPTIONS "-fsanitize=address")
      check_cxx_source_compiles("${TEST_PROGRAM}" HAS_ASAN_LINK_SUPPORT)

      if(HAS_ASAN_LINK_SUPPORT)
        message(STATUS "AddressSanitizer is supported at both compile and link time.")
        set(SUPPORTS_ASAN ON)
      else()
        message(WARNING "AddressSanitizer is NOT supported at link time.")
        set(SUPPORTS_ASAN OFF)
      endif()
    else()
      set(SUPPORTS_ASAN ON)
    endif()
  endif()
endmacro()

macro(exploration_setup_options)
  option(exploration_ENABLE_HARDENING "Enable hardening" ON)
  option(exploration_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    exploration_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    exploration_ENABLE_HARDENING
    OFF)

  exploration_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR exploration_PACKAGING_MAINTAINER_MODE)
    option(exploration_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(exploration_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(exploration_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(exploration_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(exploration_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(exploration_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(exploration_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(exploration_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(exploration_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(exploration_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(exploration_ENABLE_PCH "Enable precompiled headers" OFF)
    option(exploration_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(exploration_ENABLE_IPO "Enable IPO/LTO" ON)
    option(exploration_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(exploration_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(exploration_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(exploration_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(exploration_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(exploration_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(exploration_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(exploration_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(exploration_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(exploration_ENABLE_PCH "Enable precompiled headers" OFF)
    option(exploration_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      exploration_ENABLE_IPO
      exploration_WARNINGS_AS_ERRORS
      exploration_ENABLE_SANITIZER_ADDRESS
      exploration_ENABLE_SANITIZER_LEAK
      exploration_ENABLE_SANITIZER_UNDEFINED
      exploration_ENABLE_SANITIZER_THREAD
      exploration_ENABLE_SANITIZER_MEMORY
      exploration_ENABLE_UNITY_BUILD
      exploration_ENABLE_CLANG_TIDY
      exploration_ENABLE_CPPCHECK
      exploration_ENABLE_COVERAGE
      exploration_ENABLE_PCH
      exploration_ENABLE_CACHE)
  endif()

  exploration_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (exploration_ENABLE_SANITIZER_ADDRESS OR exploration_ENABLE_SANITIZER_THREAD OR exploration_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(exploration_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(exploration_global_options)
  if(exploration_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    exploration_enable_ipo()
  endif()

  exploration_supports_sanitizers()

  if(exploration_ENABLE_HARDENING AND exploration_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR exploration_ENABLE_SANITIZER_UNDEFINED
       OR exploration_ENABLE_SANITIZER_ADDRESS
       OR exploration_ENABLE_SANITIZER_THREAD
       OR exploration_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${exploration_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${exploration_ENABLE_SANITIZER_UNDEFINED}")
    exploration_enable_hardening(exploration_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(exploration_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(exploration_warnings INTERFACE)
  add_library(exploration_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  exploration_set_project_warnings(
    exploration_warnings
    ${exploration_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  include(cmake/Linker.cmake)
  # Must configure each target with linker options, we're avoiding setting it globally for now

  if(NOT EMSCRIPTEN)
    include(cmake/Sanitizers.cmake)
    exploration_enable_sanitizers(
      exploration_options
      ${exploration_ENABLE_SANITIZER_ADDRESS}
      ${exploration_ENABLE_SANITIZER_LEAK}
      ${exploration_ENABLE_SANITIZER_UNDEFINED}
      ${exploration_ENABLE_SANITIZER_THREAD}
      ${exploration_ENABLE_SANITIZER_MEMORY})
  endif()

  set_target_properties(exploration_options PROPERTIES UNITY_BUILD ${exploration_ENABLE_UNITY_BUILD})

  if(exploration_ENABLE_PCH)
    target_precompile_headers(
      exploration_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(exploration_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    exploration_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(exploration_ENABLE_CLANG_TIDY)
    exploration_enable_clang_tidy(exploration_options ${exploration_WARNINGS_AS_ERRORS})
  endif()

  if(exploration_ENABLE_CPPCHECK)
    exploration_enable_cppcheck(${exploration_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(exploration_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    exploration_enable_coverage(exploration_options)
  endif()

  if(exploration_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(exploration_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(exploration_ENABLE_HARDENING AND NOT exploration_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR exploration_ENABLE_SANITIZER_UNDEFINED
       OR exploration_ENABLE_SANITIZER_ADDRESS
       OR exploration_ENABLE_SANITIZER_THREAD
       OR exploration_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    exploration_enable_hardening(exploration_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
