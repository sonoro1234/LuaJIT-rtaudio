PROJECT(rtaudio_ffi)
cmake_minimum_required(VERSION 3.13)
#set(CMAKE_SHARED_LIBRARY_PREFIX "")
#first take care of RtAudio CMake
if (WIN32)
	set(RTAUDIO_API_DS ON CACHE INTERNAL "use windows ds!")
	set(RTAUDIO_API_ASIO ON CACHE INTERNAL "use windows asio!")
	set(RTAUDIO_API_WASAPI ON CACHE INTERNAL "use windows wasapi!")
endif(WIN32)

if (APPLE)
    set(RTAUDIO_API_CORE ON CACHE INTERNAL "use OSX_CORE!")
endif (APPLE)

if (UNIX AND NOT APPLE)
	set(RTAUDIO_API_OSS ON CACHE INTERNAL "AUDIO_LINUX_OSS!")
	set(RTAUDIO_API_ALSA ON CACHE INTERNAL "AUDIO_LINUX_ALSA!")
	set(RTAUDIO_API_PULSE ON CACHE INTERNAL "AUDIO_LINUX_PULSE!")
	set(RTAUDIO_API_JACK ON CACHE INTERNAL "AUDIO_UNIX_JACK!")
endif ()

set(RTAUDIO_BUILD_TESTING OFF CACHE INTERNAL "dont build tests!")
set(RTAUDIO_BUILD_STATIC_LIBS OFF CACHE INTERNAL "dont compile library static lib.")

add_subdirectory(rtaudio EXCLUDE_FROM_ALL)
set_target_properties(rtaudio PROPERTIES PREFIX "")

add_custom_target(rtaudio_ffi ALL)
add_dependencies(rtaudio_ffi rtaudio)

install(TARGETS rtaudio
              RUNTIME DESTINATION  ${LUAJIT_BIN}
              LIBRARY DESTINATION  ${LUAJIT_BIN}
              #ARCHIVE DESTINATION  ${LUAJIT_BIN}
              )
INSTALL(FILES rtaudio_ffi.lua rtAudioPlayer.lua DESTINATION ${LUAJIT_BIN}/lua)


