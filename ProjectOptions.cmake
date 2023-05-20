include(cmake/SystemLink.cmake)
include(cmake/LibFuzzer.cmake)
include(CMakeDependentOption)
include(CheckCXXCompilerFlag)


macro(clunk_24_supports_sanitizers)
  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND NOT WIN32)
    set(SUPPORTS_UBSAN ON)
  else()
    set(SUPPORTS_UBSAN OFF)
  endif()

  if((CMAKE_CXX_COMPILER_ID MATCHES ".*Clang.*" OR CMAKE_CXX_COMPILER_ID MATCHES ".*GNU.*") AND WIN32)
    set(SUPPORTS_ASAN OFF)
  else()
    set(SUPPORTS_ASAN ON)
  endif()
endmacro()

macro(clunk_24_setup_options)
  option(clunk_24_ENABLE_HARDENING "Enable hardening" ON)
  option(clunk_24_ENABLE_COVERAGE "Enable coverage reporting" OFF)
  cmake_dependent_option(
    clunk_24_ENABLE_GLOBAL_HARDENING
    "Attempt to push hardening options to built dependencies"
    ON
    clunk_24_ENABLE_HARDENING
    OFF)

  clunk_24_supports_sanitizers()

  if(NOT PROJECT_IS_TOP_LEVEL OR clunk_24_PACKAGING_MAINTAINER_MODE)
    option(clunk_24_ENABLE_IPO "Enable IPO/LTO" OFF)
    option(clunk_24_WARNINGS_AS_ERRORS "Treat Warnings As Errors" OFF)
    option(clunk_24_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(clunk_24_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" OFF)
    option(clunk_24_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(clunk_24_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" OFF)
    option(clunk_24_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(clunk_24_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(clunk_24_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(clunk_24_ENABLE_CLANG_TIDY "Enable clang-tidy" OFF)
    option(clunk_24_ENABLE_CPPCHECK "Enable cpp-check analysis" OFF)
    option(clunk_24_ENABLE_PCH "Enable precompiled headers" OFF)
    option(clunk_24_ENABLE_CACHE "Enable ccache" OFF)
  else()
    option(clunk_24_ENABLE_IPO "Enable IPO/LTO" ON)
    option(clunk_24_WARNINGS_AS_ERRORS "Treat Warnings As Errors" ON)
    option(clunk_24_ENABLE_USER_LINKER "Enable user-selected linker" OFF)
    option(clunk_24_ENABLE_SANITIZER_ADDRESS "Enable address sanitizer" ${SUPPORTS_ASAN})
    option(clunk_24_ENABLE_SANITIZER_LEAK "Enable leak sanitizer" OFF)
    option(clunk_24_ENABLE_SANITIZER_UNDEFINED "Enable undefined sanitizer" ${SUPPORTS_UBSAN})
    option(clunk_24_ENABLE_SANITIZER_THREAD "Enable thread sanitizer" OFF)
    option(clunk_24_ENABLE_SANITIZER_MEMORY "Enable memory sanitizer" OFF)
    option(clunk_24_ENABLE_UNITY_BUILD "Enable unity builds" OFF)
    option(clunk_24_ENABLE_CLANG_TIDY "Enable clang-tidy" ON)
    option(clunk_24_ENABLE_CPPCHECK "Enable cpp-check analysis" ON)
    option(clunk_24_ENABLE_PCH "Enable precompiled headers" OFF)
    option(clunk_24_ENABLE_CACHE "Enable ccache" ON)
  endif()

  if(NOT PROJECT_IS_TOP_LEVEL)
    mark_as_advanced(
      clunk_24_ENABLE_IPO
      clunk_24_WARNINGS_AS_ERRORS
      clunk_24_ENABLE_USER_LINKER
      clunk_24_ENABLE_SANITIZER_ADDRESS
      clunk_24_ENABLE_SANITIZER_LEAK
      clunk_24_ENABLE_SANITIZER_UNDEFINED
      clunk_24_ENABLE_SANITIZER_THREAD
      clunk_24_ENABLE_SANITIZER_MEMORY
      clunk_24_ENABLE_UNITY_BUILD
      clunk_24_ENABLE_CLANG_TIDY
      clunk_24_ENABLE_CPPCHECK
      clunk_24_ENABLE_COVERAGE
      clunk_24_ENABLE_PCH
      clunk_24_ENABLE_CACHE)
  endif()

  clunk_24_check_libfuzzer_support(LIBFUZZER_SUPPORTED)
  if(LIBFUZZER_SUPPORTED AND (clunk_24_ENABLE_SANITIZER_ADDRESS OR clunk_24_ENABLE_SANITIZER_THREAD OR clunk_24_ENABLE_SANITIZER_UNDEFINED))
    set(DEFAULT_FUZZER ON)
  else()
    set(DEFAULT_FUZZER OFF)
  endif()

  option(clunk_24_BUILD_FUZZ_TESTS "Enable fuzz testing executable" ${DEFAULT_FUZZER})

endmacro()

macro(clunk_24_global_options)
  if(clunk_24_ENABLE_IPO)
    include(cmake/InterproceduralOptimization.cmake)
    clunk_24_enable_ipo()
  endif()

  clunk_24_supports_sanitizers()

  if(clunk_24_ENABLE_HARDENING AND clunk_24_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR clunk_24_ENABLE_SANITIZER_UNDEFINED
       OR clunk_24_ENABLE_SANITIZER_ADDRESS
       OR clunk_24_ENABLE_SANITIZER_THREAD
       OR clunk_24_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    message("${clunk_24_ENABLE_HARDENING} ${ENABLE_UBSAN_MINIMAL_RUNTIME} ${clunk_24_ENABLE_SANITIZER_UNDEFINED}")
    clunk_24_enable_hardening(clunk_24_options ON ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()
endmacro()

macro(clunk_24_local_options)
  if(PROJECT_IS_TOP_LEVEL)
    include(cmake/StandardProjectSettings.cmake)
  endif()

  add_library(clunk_24_warnings INTERFACE)
  add_library(clunk_24_options INTERFACE)

  include(cmake/CompilerWarnings.cmake)
  clunk_24_set_project_warnings(
    clunk_24_warnings
    ${clunk_24_WARNINGS_AS_ERRORS}
    ""
    ""
    ""
    "")

  if(clunk_24_ENABLE_USER_LINKER)
    include(cmake/Linker.cmake)
    configure_linker(clunk_24_options)
  endif()

  include(cmake/Sanitizers.cmake)
  clunk_24_enable_sanitizers(
    clunk_24_options
    ${clunk_24_ENABLE_SANITIZER_ADDRESS}
    ${clunk_24_ENABLE_SANITIZER_LEAK}
    ${clunk_24_ENABLE_SANITIZER_UNDEFINED}
    ${clunk_24_ENABLE_SANITIZER_THREAD}
    ${clunk_24_ENABLE_SANITIZER_MEMORY})

  set_target_properties(clunk_24_options PROPERTIES UNITY_BUILD ${clunk_24_ENABLE_UNITY_BUILD})

  if(clunk_24_ENABLE_PCH)
    target_precompile_headers(
      clunk_24_options
      INTERFACE
      <vector>
      <string>
      <utility>)
  endif()

  if(clunk_24_ENABLE_CACHE)
    include(cmake/Cache.cmake)
    clunk_24_enable_cache()
  endif()

  include(cmake/StaticAnalyzers.cmake)
  if(clunk_24_ENABLE_CLANG_TIDY)
    clunk_24_enable_clang_tidy(clunk_24_options ${clunk_24_WARNINGS_AS_ERRORS})
  endif()

  if(clunk_24_ENABLE_CPPCHECK)
    clunk_24_enable_cppcheck(${clunk_24_WARNINGS_AS_ERRORS} "" # override cppcheck options
    )
  endif()

  if(clunk_24_ENABLE_COVERAGE)
    include(cmake/Tests.cmake)
    clunk_24_enable_coverage(clunk_24_options)
  endif()

  if(clunk_24_WARNINGS_AS_ERRORS)
    check_cxx_compiler_flag("-Wl,--fatal-warnings" LINKER_FATAL_WARNINGS)
    if(LINKER_FATAL_WARNINGS)
      # This is not working consistently, so disabling for now
      # target_link_options(clunk_24_options INTERFACE -Wl,--fatal-warnings)
    endif()
  endif()

  if(clunk_24_ENABLE_HARDENING AND NOT clunk_24_ENABLE_GLOBAL_HARDENING)
    include(cmake/Hardening.cmake)
    if(NOT SUPPORTS_UBSAN 
       OR clunk_24_ENABLE_SANITIZER_UNDEFINED
       OR clunk_24_ENABLE_SANITIZER_ADDRESS
       OR clunk_24_ENABLE_SANITIZER_THREAD
       OR clunk_24_ENABLE_SANITIZER_LEAK)
      set(ENABLE_UBSAN_MINIMAL_RUNTIME FALSE)
    else()
      set(ENABLE_UBSAN_MINIMAL_RUNTIME TRUE)
    endif()
    clunk_24_enable_hardening(clunk_24_options OFF ${ENABLE_UBSAN_MINIMAL_RUNTIME})
  endif()

endmacro()
