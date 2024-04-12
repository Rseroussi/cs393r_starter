# FROM registry.hub.docker.com/library/ros:noetic

# # install apt deps
# RUN apt-get update && \
#     apt-get install -y git libgflags-dev libpopt-dev \
#                        libgoogle-glog-dev liblua5.1-0-dev \
#                        libboost-all-dev libqt5websockets5-dev \
#                        python-is-python3 libeigen3-dev sudo tmux

# # install ros apt deps
# RUN apt-get install -y ros-noetic-tf ros-noetic-angles
FROM nvidia/cuda:11.8.0-runtime-ubuntu22.04 AS base

# install language
RUN apt-get update && apt-get install -y \
  locales \
  && locale-gen en_US.UTF-8 \
  && update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 \
  && rm -rf /var/lib/apt/lists/*
ENV LANG en_US.UTF-8

# install timezone
RUN ln -fs /usr/share/zoneinfo/UTC /etc/localtime \
  && apt-get update \
  && apt-get install -y tzdata \
  && dpkg-reconfigure --frontend noninteractive tzdata \
  && rm -rf /var/lib/apt/lists/*

# update packages
RUN apt-get update && apt-get -y upgrade \
    && rm -rf /var/lib/apt/lists/*

# install basic utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    gnupg2 \
    iproute2 \
    iputils-ping \
    lsb-release \
    nmap \
    net-tools \
    software-properties-common \
    sudo \
    wget \
    && rm -rf /var/lib/apt/lists/*

# install ROS 2
RUN sudo add-apt-repository universe \
  && curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key -o /usr/share/keyrings/ros-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null \
  && apt-get update && apt-get install -y --no-install-recommends \
    ros-humble-ros-base \
    python3-argcomplete \
  && rm -rf /var/lib/apt/lists/*

ENV ROS_DISTRO=humble
ENV AMENT_PREFIX_PATH=/opt/ros/humble
ENV COLCON_PREFIX_PATH=/opt/ros/humble
ENV LD_LIBRARY_PATH=/opt/ros/humble/lib
ENV PATH=/opt/ros/humble/bin:$PATH
ENV PYTHONPATH=/opt/ros/humble/lib/python3.10/site-packages

FROM base AS dev

# install common utilities
RUN apt-get update && apt-get install -y --no-install-recommends \
  bash-completion \
  build-essential \
  cmake \
  gdb \
  git \
  openssh-client \
  python3-argcomplete \
  python3-pip \
  ros-dev-tools \
  ros-humble-ament-* \
  vim \
  && rm -rf /var/lib/apt/lists/*

# initialize rosdep database 
RUN rosdep init || echo "rosdep already initialized"

ARG USERNAME=ros2-dev
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# create a non-root user
RUN groupadd --gid $USER_GID $USERNAME \
  && useradd -s /bin/bash --uid $USER_UID --gid $USER_GID -m $USERNAME \
  && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME\
  && chmod 0440 /etc/sudoers.d/$USERNAME \
  && rm -rf /var/lib/apt/lists/*

# set up autocompletion for user
RUN apt-get update && apt-get install -y git-core bash-completion \
  && echo "if [ -f /opt/ros/${ROS_DISTRO}/setup.bash ]; then source /opt/ros/${ROS_DISTRO}/setup.bash; fi" >> /home/$USERNAME/.bashrc \
  && echo "if [ -f /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash ]; then source /usr/share/colcon_argcomplete/hook/colcon-argcomplete.bash; fi" >> /home/$USERNAME/.bashrc \
  && rm -rf /var/lib/apt/lists/* 

ENV AMENT_CPPCHECK_ALLOW_SLOW_VERSIONS=1

FROM dev AS full

# install ROS 2 desktop
RUN apt-get update && apt-get install -y --no-install-recommends \
  ros-humble-desktop \
  && rm -rf /var/lib/apt/lists/*

FROM full AS gazebo

# install gazebo
RUN sudo wget https://packages.osrfoundation.org/gazebo.gpg -O /usr/share/keyrings/pkgs-osrf-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/pkgs-osrf-archive-keyring.gpg] http://packages.osrfoundation.org/gazebo/ubuntu-stable $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/gazebo-stable.list > /dev/null \
  && apt-get update && apt-get install -q -y --no-install-recommends \
    ignition-fortress \
  && rm -rf /var/lib/apt/lists/*

FROM gazebo AS gazebo-nvidia

# expose the nvidia driver to allow opengl
RUN apt-get update \
 && apt-get install -y -qq --no-install-recommends \
  libglvnd0 \
  libgl1 \
  libglx0 \
  libegl1 \
  libxext6 \
  libx11-6

# env vars for the nvidia-container-runtime
ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES graphics,utility,compute
ENV QT_X11_NO_MITSHM 1

FROM gazebo-nvidia AS turtlebot4

# install turtlebot packages
RUN apt-get update && apt-get install -qq -y --no-install-recommends \
    ros-humble-turtlebot4-bringup \
    ros-humble-turtlebot4-description \
    ros-humble-turtlebot4-msgs \
    ros-humble-turtlebot4-navigation \
    ros-humble-turtlebot4-node \
    ros-humble-turtlebot4-simulator \
    && rm -rf /var/lib/apt/lists/*

ARG WORKSPACE

RUN echo "if [ -f ${WORKSPACE}/install/setup.bash ]; then source ${WORKSPACE}/install/setup.bash; fi" >> /home/${USERNAME}/.bashrc

# install apt deps
# RUN apt-get update && \
#     apt-get install -y git libgflags-dev libpopt-dev \
#                        libgoogle-glog-dev liblua5.1-0-dev \
#                        libboost-all-dev libqt5websockets5-dev \
#                        python-is-python3 libeigen3-dev sudo tmux

# ARG HOST_UID
# RUN useradd dev -m -s /bin/bash -u $HOST_UID -G sudo
# USER dev
# WORKDIR /home/dev
# RUN rosdep update

# clone deps
RUN git clone https://github.com/ut-amrl/amrl_maps.git && \
    git clone https://github.com/ut-amrl/amrl_msgs.git && \
    git clone https://github.com/ut-amrl/ut_automata.git --recurse-submodules

# set up .bashrc
RUN echo "source /opt/ros/humble/setup.sh\n" \
"export ROS2_PACKAGE_PATH=\$ROS2_PACKAGE_PATH:~/ut_automata\n" \
"export ROS2_PACKAGE_PATH=\$ROS2_PACKAGE_PATH:~/cs393r_starter_ros2\n" \
"export ROS2_PACKAGE_PATH=\$ROS2_PACKAGE_PATH:~/amrl_maps\n" \
"export ROS2_PACKAGE_PATH=\$ROS2_PACKAGE_PATH:~/amrl_msgs" >> ~/.profile
RUN echo "source /opt/ros/humble/setup.bash\n" \
"export ROS2_PACKAGE_PATH=\$ROS2_PACKAGE_PATH:~/ut_automata\n" \
"export ROS2_PACKAGE_PATH=\$ROS2_PACKAGE_PATH:~/cs393r_starter_ros2\n" \
"export ROS2_PACKAGE_PATH=\$ROS2_PACKAGE_PATH:~/amrl_maps\n" \
"export ROS2_PACKAGE_PATH=\$ROS_2PACKAGE_PATH:~/amrl_msgs" >> ~/.bashrc


# build deps
RUN /bin/bash -lc "cd amrl_msgs && make"
RUN /bin/bash -lc "cd ut_automata && make"

# add launcher
# ENV CS393R_DOCKER_CONTEXT 1
# COPY --chown=dev:dev ./tmux_session.sh /home/dev/tmux_session.sh
# RUN chmod u+x /home/dev/tmux_session.sh
# CMD [ "/home/dev/tmux_session.sh" ]
# ENTRYPOINT [ "/bin/bash", "-l", "-c" ]
