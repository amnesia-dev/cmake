set(AMNESIA_TOOLCHAIN_DIR "${CMAKE_CURRENT_LIST_DIR}")
message(STATUS "[Amnesia]Build System Root : ${AMNESIA_TOOLCHAIN_DIR}")
IF(NOT DEFINED ENABLE_BITCODE)
  set(ENABLE_BITCODE NO)
ENDIF()
IF(NOT DEFINED PLATFORM)
  set(PLATFORM "OS64")
ENDIF()
IF(NOT DEFINED ENABLE_STRICT_TRY_COMPILE)
  set(ENABLE_STRICT_TRY_COMPILE NO)
ENDIF()
include("${AMNESIA_TOOLCHAIN_DIR}/vendor/ios-cmake/ios.toolchain.cmake")
# By default, ios.toolchain.cmake wrapps executables in .app bundles
# We disable global bundling here, and re-enable for individual targets later if needed
set(CMAKE_MACOSX_BUNDLE NO)

IF(COMMAND find_host_package)
  find_host_package(Perl REQUIRED)
  message(STATUS "[Amneisia]Perl Interpreter: ${PERL_EXECUTABLE}")
  # We use Python3 for a bundle of stuff when CMake is not enough.
  #   - Property-list Generation
  #   - Cross-platform wrapper around logos.pl
  find_host_package(Python3 COMPONENTS Interpreter REQUIRED)
  message(STATUS "[Amneisia]Python3 Interpreter: ${Python3_EXECUTABLE}")
  execute_process(
      COMMAND "${Python3_EXECUTABLE}" "-c" "import plistlib"
      RESULT_VARIABLE EXIT_CODE
      OUTPUT_QUIET
      COMMAND_ERROR_IS_FATAL ANY
  )
ENDIF()


macro(am_init AUTHOR_NAME)
  IF(CMAKE_GENERATOR STREQUAL Xcode)
    set(CMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED "NO")
    set(CMAKE_XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "")
    set(CMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED "NO")
  ENDIF()
  # Patch Debian Packaging
  set(CPACK_PACKAGE_DIRECTORY "${CMAKE_BINARY_DIR}")
  set(CPACK_GENERATOR "DEB")
  set(CPACK_DEBIAN_PACKAGE_MAINTAINER "${AUTHOR_NAME}")
  set(CPACK_DEBIAN_PACKAGE_ARCHITECTURE "iphoneos-arm")
  # Sysroot related patches
  include("${AMNESIA_TOOLCHAIN_DIR}/sysroot/sysroot.cmake")
  include(CPack)
endmacro()

macro(process_src SRC_LIST)
  cmake_parse_arguments(PS "" "" "SRCS" ${ARGN})
  set("${PREFIX}_SRC_LIST" "")
  foreach(SRC "${PA_SRCS}")
    file(READ ${SRC} TMPTXT)
    string(REGEX MATCH "\%hook|\%end" REG_MATCHED "${TMPTXT}")
    string(LENGTH "${REG_MATCHED}" STR_LEN)
    if(${STR_LEN} GREATER_EQUAL 0)
      # This file uses Theos and needs to be preprocessed First, we calculate
      # relative path
      file(RELATIVE_PATH REL_PA "${CMAKE_CURRENT_LIST_DIR}" "${SRC}")
      set(SRC_SUFFIX "m")
      if(REL_PA MATCHES "\.xm$")
        set(SRC_SUFFIX "mm")
      endif()
      add_custom_command(
        OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/${REL_PA}.${SRC_SUFFIX}"
        DEPENDS "${SRC}"
        COMMENT "Logos Processing ${REL_PA}"
        COMMAND
          "${PERL_EXECUTABLE}" "${AMNESIA_TOOLCHAIN_DIR}/vendor/logos/bin/logos.pl" "${SRC}" ">" "${CMAKE_CURRENT_BINARY_DIR}/${REL_PA}.${SRC_SUFFIX}"
        USES_TERMINAL VERBATIM)
      list(APPEND SRC_LIST "${CMAKE_CURRENT_BINARY_DIR}/${REL_PA}")
    else()
      list(APPEND SRC_LIST "${SRC}")
    endif()
  endforeach()
endmacro()

macro(am_add_tweak)
  cmake_parse_arguments(PA "NOSUBSTRATE" "NAME" "SRCS" ${ARGN})
  process_src("${PA_SRCS}" SRC_LIST)
  add_library("${PA_NAME}" SHARED "${SRC_LIST}" ${PA_UNPARSED_ARGUMENTS})
  if(NOT PA_NOSUBSTRATE)
    find_library(SUB_PATH substrate REQUIRED)
    target_link_libraries("${PA_NAME}" PUBLIC ${SUB_PATH})
    list(APPEND CPACK_DEBIAN_PACKAGE_DEPENDS "substrate")
    install(TARGETS "${PA_NAME}" DESTINATION "/Library/MobileSubstrate/DynamicLibraries/")
  endif()
endmacro()

macro(am_add_tool)
  cmake_parse_arguments(PA "" "NAME" "SRCS" ${ARGN})
  add_executable("${PA_NAME}" "${PA_SRCS}" ${PA_UNPARSED_ARGUMENTS})
  install(TARGETS "${PA_NAME}" DESTINATION "/usr/local/bin/")
endmacro()
