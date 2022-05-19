set(AMNESIA_TOOLCHAIN_DIR "${CMAKE_CURRENT_LIST_DIR}")
message(STATUS "[Amnesia]Build System Root : ${AMNESIA_TOOLCHAIN_DIR}")
include("${AMNESIA_TOOLCHAIN_DIR}/vendor/ios-cmake/ios.toolchain.cmake")

macro(am_init AUTHOR_NAME)
  set(CPACK_PACKAGE_DIRECTORY "${CMAKE_BINARY_DIR}")
  set(CPACK_GENERATOR "DEB")
  set(CPACK_DEBIAN_PACKAGE_MAINTAINER "${AUTHOR_NAME}")
  set(CMAKE_MACOSX_BUNDLE NO) # Otherwise everything is installed as an .app
endmacro()
