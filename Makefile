# Clang is a good compiler to use during development due to its faster compile
# times and more readable output.
# C_compiler=/usr/bin/clang
# CXX_compiler=/usr/bin/clang++

# GCC is better for release mode due to the speed of its output, and its support
# for OpenMP.
C_compiler=/usr/bin/gcc
CXX_compiler=/usr/bin/g++

#acceptable build_types: Release/Debug/Profile
build_type=Release
# build_type=Debug

.SILENT:
all: build/CMakeLists.txt.copy
	$(info Build_type is [${build_type}])
	$(MAKE) --no-print-directory -C build

docker_all: docker_build_q
	docker run --rm --volume "$(shell pwd)":/home/dev/cs393r_starter_ros2 cs393r_starter_ros2 "cd cs393r_starter_ros2 && make -j"

docker_shell: docker_build_q
	if [ $(shell docker ps -a -f name=cs393r_starter_ros2_shell | wc -l) -ne 2 ]; then docker run -dit --name cs393r_starter_ros2_shell --volume "$(shell pwd)":/home/dev/cs393r_starter_ros2 --workdir /home/dev/cs393r_starter_ros2 -p 10272:10272 cs393r_starter_ros2; fi
	docker exec -it cs393r_starter_ros2_shell bash -l

docker_stop:
	docker container stop cs393r_starter_ros2_shell
	docker container rm cs393r_starter_ros2_shell

docker_build:
	docker build --build-arg USERNAME=$(shell id -u) -t cs393r_starter_ros2 .

docker_build_q:
	docker build -q --build-arg USERNAME=$(shell id -u) -t cs393r_starter_ros2 .

docker_build_image:
	docker run --network=host --cap-add=SYS_PTRACE --security-opt=seccomp:unconfined --security-opt=apparmor:unconfined --volume=/tmp/.X11-unix:/tmp/.X11-unix --volume=/mnt/wslg:/mnt/wslg --ipc=host --gpus=all --cap-add=NET_ADMIN -it docker.io/library/cs393r_starter_ros2 
# Sets the build type to Debug.
set_debug:
	$(eval build_type=Debug)

# Ensures that the build type is debug before running all target.
debug_all: | set_debug all

clean:
	rm -rf build bin lib

build/CMakeLists.txt.copy: CMakeLists.txt Makefile
	mkdir -p build
	cd build && cmake -DCMAKE_BUILD_TYPE=$(build_type) \
		-DCMAKE_CXX_COMPILER=$(CXX_compiler) \
		-DCMAKE_C_COMPILER=$(C_compiler) ..
	cp CMakeLists.txt build/CMakeLists.txt.copy
