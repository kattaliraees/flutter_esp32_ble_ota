# CMAKE generated file: DO NOT EDIT!
# Generated by "Unix Makefiles" Generator, CMake Version 3.18

# Delete rule output on recipe failure.
.DELETE_ON_ERROR:


#=============================================================================
# Special targets provided by cmake.

# Disable implicit rules so canonical targets will work.
.SUFFIXES:


# Disable VCS-based implicit rules.
% : %,v


# Disable VCS-based implicit rules.
% : RCS/%


# Disable VCS-based implicit rules.
% : RCS/%,v


# Disable VCS-based implicit rules.
% : SCCS/s.%


# Disable VCS-based implicit rules.
% : s.%


.SUFFIXES: .hpux_make_needs_suffix_list


# Command-line flag to silence nested $(MAKE).
$(VERBOSE)MAKESILENT = -s

#Suppress display of executed commands.
$(VERBOSE).SILENT:

# A target that is always out of date.
cmake_force:

.PHONY : cmake_force

#=============================================================================
# Set environment variables for the build.

# The shell in which to execute make rules.
SHELL = /bin/sh

# The CMake executable.
CMAKE_COMMAND = /usr/local/Cellar/cmake/3.18.4/bin/cmake

# The command to remove a file.
RM = /usr/local/Cellar/cmake/3.18.4/bin/cmake -E rm -f

# Escaping for special characters.
EQUALS = =

# The top-level source directory on which CMake was run.
CMAKE_SOURCE_DIR = /Users/apple/esp-idf/components/bootloader/subproject

# The top-level build directory on which CMake was run.
CMAKE_BINARY_DIR = /Users/apple/Raees/flutter_esp32_ble_ota/firmware_esp32_ota/build/bootloader

# Utility rule file for size-files.

# Include the progress variables for this target.
include CMakeFiles/size-files.dir/progress.make

CMakeFiles/size-files: bootloader.elf
	/Users/apple/.espressif/python_env/idf4.4_py3.9_env/bin/python /Users/apple/esp-idf/tools/idf_size.py --files /Users/apple/Raees/flutter_esp32_ble_ota/firmware_esp32_ota/build/bootloader/bootloader.map

size-files: CMakeFiles/size-files
size-files: CMakeFiles/size-files.dir/build.make

.PHONY : size-files

# Rule to build all files generated by this target.
CMakeFiles/size-files.dir/build: size-files

.PHONY : CMakeFiles/size-files.dir/build

CMakeFiles/size-files.dir/clean:
	$(CMAKE_COMMAND) -P CMakeFiles/size-files.dir/cmake_clean.cmake
.PHONY : CMakeFiles/size-files.dir/clean

CMakeFiles/size-files.dir/depend:
	cd /Users/apple/Raees/flutter_esp32_ble_ota/firmware_esp32_ota/build/bootloader && $(CMAKE_COMMAND) -E cmake_depends "Unix Makefiles" /Users/apple/esp-idf/components/bootloader/subproject /Users/apple/esp-idf/components/bootloader/subproject /Users/apple/Raees/flutter_esp32_ble_ota/firmware_esp32_ota/build/bootloader /Users/apple/Raees/flutter_esp32_ble_ota/firmware_esp32_ota/build/bootloader /Users/apple/Raees/flutter_esp32_ble_ota/firmware_esp32_ota/build/bootloader/CMakeFiles/size-files.dir/DependInfo.cmake --color=$(COLOR)
.PHONY : CMakeFiles/size-files.dir/depend
