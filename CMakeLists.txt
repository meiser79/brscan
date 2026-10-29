cmake_minimum_required(VERSION 3.5)

project(brscan)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake")

find_package(Sane REQUIRED)
find_package(LibUSB REQUIRED)
find_package(JPEG REQUIRED)

add_library(brscandec SHARED
	libbrscandec/brother_bugchk.c
	libbrscandec/brother_scandec.c
	libbrscandec/brother_chreso.c)
set_target_properties(brscandec PROPERTIES SOVERSION 1)
# Ghidra decompilation uses undefined8/undefined4 generics that mismatch
# pointer vs integer types. These are semantically correct on LP64
# (pointers and uint64_t are both 8 bytes). GCC 14+ treats these as errors.
target_compile_options(brscandec PRIVATE
	-Wno-incompatible-pointer-types
	-Wno-int-conversion
	-Wno-pointer-sign)

add_library(brcolm SHARED
	libbrcolm/brcolm.c)
set_target_properties(brcolm PROPERTIES SOVERSION 1)

add_library(sane-brother SHARED
	libsane-brother/brother.c
	libsane-brother/brother_advini.c
	libsane-brother/brother_brscan4.c
	libsane-brother/brother_bugchk.c
	libsane-brother/brother_cmatch.c
	libsane-brother/brother_color.c
	libsane-brother/brother_devaccs.c
	libsane-brother/brother_devinfo.c
	libsane-brother/brother_log.c
	libsane-brother/brother_mfccmd.c
	libsane-brother/brother_misc.c
	libsane-brother/brother_modelinf.c
	libsane-brother/brother_netdev.c
	libsane-brother/brother_scanner.c
	libsane-brother/sane_strstatus.c
	libsane-brother/sanei_config.c
	libsane-brother/sanei_constrain_value.c
	libsane-brother/sanei_init_debug.c)
# stubs.c provides sane_init→sane_brother_init wrappers.
# Compiled as a plain C file without BACKEND_NAME to avoid macro conflicts.
add_library(sane-brother-stubs OBJECT libsane-brother/stubs.c)
target_include_directories(sane-brother-stubs PRIVATE ${SANE_INCLUDE_DIR})
set_target_properties(sane-brother-stubs PROPERTIES POSITION_INDEPENDENT_CODE ON)
target_include_directories(sane-brother PRIVATE
	${CMAKE_CURRENT_SOURCE_DIR}/include
	${CMAKE_CURRENT_SOURCE_DIR}/libbrscandec
	${CMAKE_CURRENT_SOURCE_DIR}/libbrcolm
	${SANE_INCLUDE_DIR}
	${LIBUSB_INCLUDE_DIR}
	${JPEG_INCLUDE_DIRS})
target_compile_definitions(sane-brother PRIVATE BACKEND_NAME=brother BRSANESUFFIX=2 V_MAJOR=1 V_MINOR=0)
target_link_libraries(sane-brother dl pthread usb ${LIBUSB_LIBRARIES} ${JPEG_LIBRARIES} sane-brother-stubs)
set_target_properties(sane-brother PROPERTIES SOVERSION 1)

add_executable(brsaneconfig
        brsaneconfig/brsaneconfig.c)
target_include_directories(brsaneconfig PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}/libsane-brother)
target_compile_definitions(brsaneconfig PRIVATE BRSANESUFFIX=2)
target_link_libraries(brsaneconfig sane-brother)
# BRSANESUFFIX=2 tool name, like Brother's brsaneconfig2/3/4
set_target_properties(brsaneconfig PROPERTIES OUTPUT_NAME brsaneconfig2)

# BRSANESUFFIX=2 code uses suffixed names (libbrscandec2.so, Brsane2.ini,
# brsanenetdevice2.cfg, brsaneconfig2). The suffixed name is always the
# real file and the plain name a symlink to it. The libraries are the
# exception only in that CMake already owns libbrscandec.so -> .so.1,
# so the "2" name links straight to the .so.1 file.
# The symlinks are created in the build tree and installed like regular
# files, so they appear in the install log, honour DESTDIR, and a failure
# stops the configure step.
set(BRSCAN_LINK_DIR ${CMAKE_CURRENT_BINARY_DIR}/symlinks)
file(MAKE_DIRECTORY ${BRSCAN_LINK_DIR})
function(brscan_symlink target name)
  file(REMOVE ${BRSCAN_LINK_DIR}/${name})
  execute_process(COMMAND ${CMAKE_COMMAND} -E create_symlink ${target} ${BRSCAN_LINK_DIR}/${name}
                  RESULT_VARIABLE rc)
  if(rc)
    message(FATAL_ERROR "cannot create symlink ${name} -> ${target}")
  endif()
endfunction()
brscan_symlink(libbrscandec.so.1 libbrscandec2.so)
brscan_symlink(libbrcolm.so.1 libbrcolm2.so)
brscan_symlink(Brsane2.ini Brsane.ini)
brscan_symlink(brsanenetdevice2.cfg brsanenetdevice.cfg)
brscan_symlink(brsaneconfig2 brsaneconfig)

install(TARGETS brsaneconfig brscandec brcolm)
install(PROGRAMS ${BRSCAN_LINK_DIR}/brsaneconfig DESTINATION bin)
install(FILES ${BRSCAN_LINK_DIR}/libbrscandec2.so ${BRSCAN_LINK_DIR}/libbrcolm2.so DESTINATION lib)
install(TARGETS sane-brother LIBRARY DESTINATION /usr/lib/sane)

install(FILES libbrcolm/GrayCmData/BHminiFB/brmfgray.bin DESTINATION /usr/share/sane/brother/GrayCmData/BHminiFB)
install(FILES libbrcolm/GrayCmData/YL4/brmfgray.bin DESTINATION /usr/share/sane/brother/GrayCmData/YL4)
install(FILES libbrcolm/GrayCmData/BHL2FB/brmsi06f.bin DESTINATION /usr/share/sane/brother/GrayCmData/BHL2FB)
install(FILES libbrcolm/GrayCmData/ZLe/brmfgray.bin DESTINATION /usr/share/sane/brother/GrayCmData/ZLe)
install(FILES libbrcolm/GrayCmData/BHL2/brmsi06.bin DESTINATION /usr/share/sane/brother/GrayCmData/BHL2)
install(FILES libbrcolm/GrayCmData/ZL2FB/brmsl07f.bin libbrcolm/GrayCmData/ZL2FB/brmsl07f.cm DESTINATION /usr/share/sane/brother/GrayCmData/ZL2FB)
install(FILES libbrcolm/GrayCmData/ZL2/brmsl07.bin DESTINATION /usr/share/sane/brother/GrayCmData/ZL2)
install(FILES libbrcolm/GrayCmData/BHLFB/brmfgray.bin DESTINATION /usr/share/sane/brother/GrayCmData/BHLFB)
install(FILES libbrcolm/GrayCmData/YL4FB/brlutcm.dat libbrcolm/GrayCmData/YL4FB/brmfgray.bin DESTINATION /usr/share/sane/brother/GrayCmData/YL4FB)
install(FILES libbrcolm/GrayCmData/BHL/brmfgray.bin DESTINATION /usr/share/sane/brother/GrayCmData/BHL)
install(FILES libbrcolm/GrayCmData/BHMFB/brmfgray.bin DESTINATION /usr/share/sane/brother/GrayCmData/BHMFB)
install(FILES libbrcolm/GrayCmData/ZLeFB/brlutcm.dat libbrcolm/GrayCmData/ZLeFB/brmfgray.bin DESTINATION /usr/share/sane/brother/GrayCmData/ZLeFB)

install(FILES data/Brsane.ini DESTINATION /usr/share/sane/brother RENAME Brsane2.ini)
install(FILES data/brsanenetdevice.cfg DESTINATION /usr/share/sane/brother RENAME brsanenetdevice2.cfg)
install(FILES ${BRSCAN_LINK_DIR}/Brsane.ini ${BRSCAN_LINK_DIR}/brsanenetdevice.cfg
        DESTINATION /usr/share/sane/brother)

option(BRSCAN_BUILD_TESTS "Build brscan unit tests" OFF)
if(BRSCAN_BUILD_TESTS)
  enable_testing()
  if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/ThirdParty/googletest/CMakeLists.txt")
    message(FATAL_ERROR "BRSCAN_BUILD_TESTS=ON requires ThirdParty/googletest; run git submodule update --init --recursive")
  endif()
  set(INSTALL_GTEST OFF CACHE BOOL "" FORCE)
  set(BUILD_GMOCK OFF CACHE BOOL "" FORCE)
  add_subdirectory(ThirdParty/googletest)

  add_executable(test_brscan4_reference
    tests/unit/test_brscan4_reference.cpp
    libsane-brother/brother_brscan4.c)
  target_include_directories(test_brscan4_reference PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/libsane-brother)
  target_link_libraries(test_brscan4_reference gtest_main)
  add_test(NAME brscan4_reference COMMAND test_brscan4_reference)

  add_executable(test_brscan4_color_reference
    tests/unit/test_brscan4_color_reference.cpp)
  target_compile_definitions(test_brscan4_color_reference PRIVATE
    BRSCAN_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}")
  target_link_libraries(test_brscan4_color_reference gtest_main)
  add_test(NAME brscan4_color_reference COMMAND test_brscan4_color_reference)
endif()

