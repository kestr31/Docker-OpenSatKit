# OpenSatKit Packed In a Docker Container

## 0. Introduction

- This repository is for building docker image containing [OpenSatKit(OSK)](https://github.com/OpenSatKit/OpenSatKit) and [minicom](https://help.ubuntu.com/community/Minicom) inside.
- Image is based on Ubuntu 18.04 due to dependency issues related to build of QT4 apps.
- Use of container will help resolving dependency matters caused by Ubuntu distro versions.

## 1. Building a Container

- You need following prequisites for building this project:
  - AMD64 Linux PC with [docker](https://docs.docker.com/engine/install/ubuntu/) installed (Including [WSL2](https://learn.microsoft.com/en-us/windows/wsl/install)).
  - Basic knowledges about Linux settings and shell commands.
- **Build process is not necessary for using a docker container.**
  - You can download prebuilt image from the [docker hub](https://hub.docker.com/repository/docker/kestr3l/opensatkit/general).
<br/>

- In Order to build a OSK docker image, do following:
  - First, clone this repository.
  - Then, move to directory to cloned repo. and run following command:
    - *Tag of an image can be changed based on your need*.

```shell
DOCKER_BUILDKIT=1 docker build --no-cache \
--build-arg BASEIMAGE=ubuntu \
--build-arg BASETAG=18.04 \
--build-arg OSK_VERSION=v2.5 \
-t kestr3l/opensatkit:v2.5 \
-f Dockerfile .
```

- List of arguments used in the build are as following:
  - Currently, only `OSK_VERSION` is changeable.
  - Change it based on your need. Check [list of tags](https://github.com/OpenSatKit/OpenSatKit/tags) of OSK.

|ARGUMENT|DESCRIPTION|DEFAULT|CHANGEABLE|
|:-|:-|:-:|:-:|
|`BASEIMAGE`|Name of docker base image to be used|[ubuntu](https://hub.docker.com/_/ubuntu)|X|
|`BASETAG`|Tag of docker base image to be used|[18.04](https://hub.docker.com/_/ubuntu/tags?page=1&name=18.04)|X|
|`OSK_VERSION`|Version of OSK to be installed inside a container|[v2.5](https://github.com/OpenSatKit/OpenSatKit/tree/v2.5)|O|

## 2. Running a Container

- Since the docker image uses GUI, you need to run `xhost +` before creating a container.
- There are two ways of running a container: `docker run` and `docker-compose`.

### 2.1 `docker run` command

- Use following command for running a container.
  - Add `bash` at the end if you don't want to autostart COSMOS.
  - Since it has `--rm`, container will be deleted on exit.

```shell
docker run -it --rm \
   -e DISPLAY=$DISPLAY \
   -e WAYLAND_DISPLAY=$WAYLAND_DISPLAY \
   -e QT_NO_MITSHM=1 \
   -e XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR \
   -v /tmp/.X11-unix:/tmp/.X11-unix \
   --device /dev/ttyUSB0 \
   --net host \
   --ipc host \
   --gpus all \
   --privileged \
   --name OpenSatKit \
   kestr3l/opensatkit:18.04-v2.5-mod
```

### 2.2 `docker-compose` command

- **You must have [`docker-compose` installed](https://docs.docker.com/compose/install/other/) on your system**.
- To run a container with `docker-compose`, following values of the host must be known:
  - *Three environment variables*.
  - *One serial device name connected to the host*.

|VARNAME|DESCRIPTION|EXAMPLE VALUE|SEARCH COMMAND|
|:-|:-|:-|:-|
|`DISPLAY`|Display connected to the host's X server(X11)|`:0`|echo $DISPLAY|
|`WAYLAND_DISPLAY`|Display connected to the host's Wayland server<br/>(Only for Desktop Environments using Wayland)|`wayland-0`|echo $WAYLAND_DISPLAY|
|`XDG_RUNTIME_DIR`|Directory for user-specific, non-essential runtime files|`/run/user/1000/`|echo $XDG_RUNTIME_DIR|
|`ttyUSB*`|Name of a serial device connected by USB|`ttyUSB0`|dmesg \| grep tty|

- **You must check values of your system and should modify is based on your environment**.
- You can also refer to comments written in `docker-compose.yml`.

### 2.3 Running a `minicom`

- After running a container, use following commmand to use minicom:
  - Name of conatiner may vary baed on modifications you made on the container name

```shell
docker exec -it OpenSatKit minicom -s
```

- minicom configuration will appear on a terminal.
- Modify `Serial port setup`. There are two values you should check:
  - `Serial Device`: Name of serial device mapped to the container
  - `Hardware Flow Control`: **Must be off**, otherwise, keyboard input won't work
- After the setup, choose `Exit` and serial data will start to be shown.

## 3. License

- COSMOS is a product of Ball Corportation and it is [distributed under AGPLv3 license](https://github.com/BallAerospace/COSMOS).
- Assets of COSMOS included in OSK and following parts of `Dockerfile` is derived from [`BallAerospace/COSMOS`](https://github.com/BallAerospace/COSMOS).
  - APT dependencies on `requirements.txt`
    - Removed `libgstreamer0.10-dev` and `libgstreamer-plugins-base0.10-dev` due to deprecation on Ubuntu 18.04
  - Installation of Ruby 2.5.8 using [rbenv/rbenv](https://github.com/rbenv/rbenv)
    - Modification of `rbenv` and `ruby-build` repository's name to clone

## 4.  References

1. [OpenSatKit/OpenSatKit - github.com](https://github.com/OpenSatKit/OpenSatKit)
2. [BallAerosapce/COSMOS - github.com](https://github.com/BallAerospace/COSMOS)
3. [Install Docker Engine on Ubuntu - docker docs](https://docs.docker.com/engine/install/ubuntu/)
4. [Install the Compose standalone - docker docs](https://docs.docker.com/compose/install/other/)
5. [XDG Base Directory Specification - freedesktop.org](https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html)