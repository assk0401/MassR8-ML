# Maneage'd projects in Docker

Copyright (C) 2021-2026 Mohammad Akhlaghi <mohammad@akhlaghi.org>\
See the end of the file for license conditions.

For an introduction on containers, see the "Building in containers" section
of the `README.md` file within the top-level directory of this
project. Here, we focus on Docker with a simple checklist on how to use the
`docker.sh` script that we have already prepared in this directory for easy
usage in a Maneage'd project.





## Building your Maneage'd project in Docker

Through the steps below, you will create a Docker image that will only
contain the software environment and keep the project source and built
analysis files (data and PDF) on your host operating system. This enables
you to keep the size of the image to a minimum (only containing the built
software environment) to easily move it from one computer to another.

 0. Add your user to the `docker` group: `usermod -aG docker
    USERNAME`. This is only necessary once on an operating system.

 1. Start the Docker daemon (root permissions required). If the operating
    system uses systemd you can use the command below. If you want the
    Docker daemon to be available after a reboot also (so you don't have to
    restart it after turning off your computer), run this command again but
    replacing `start` with `enable` (this is not recommended if you don't
    regularly use Docker: it will slow the boot time of your OS).

    ```shell
    systemctl start docker
    ```

 2. Using your favorite text editor, create a `run.sh` in your top Maneage
    directory (as described in the comments at the start of the `docker.sh`
    script in this directory). Just activate `--build-only` on the first
    run so it doesn't go onto doing the analysis and just sets up the
    software environment. Set the respective directory(s) based on your
    filesystem (the software directory is optional). The `run.sh` file name
    is already in `.gitignore` (because it contains local directories), so
    Git will ignore it and it won't be committed by mistake.

 3. After the setup is complete, remove the `--build-only` and run the
    command below to confirm that `maneage-base` (the OS of the container)
    and `maneaged` (your project's full Maneage'd environment) images are
    available. If you want different names for these images, add the
    `--project-name` and `--base-name` options to the `docker.sh` call.

    ```shell
    docker image list
    ```

 4. You are now ready to do your analysis by removing the `--build-only`
    option.





## Script usage tips

The `docker.sh` script introduced above has many options allowing certain
customizations that you can see when running it with the `--help`
option. The tips below are some of the more useful scenarios that we have
encountered so far.

### Docker image in a single file

In case you want to store the image as a single file as backup or to move
to another computer. For such cases, run the `docker.sh` script with the
`--image-file` option (for example `--image-file=myproj.tar.gz`). After
moving the file to the other system, run `docker.sh` with the same option.

When the given file to `docker.sh` already exists, it will only be used for
loading the environment. When it doesn't exist, the script will save the
image into it.





## Docker usage tips

Below are some useful Docker usage scenarios that have proved to be
relevant for us in Maneage'd projects.

### Saving and loading an image as a file

Docker keeps its images in hard to access (by humans) location on the
operating system. Very much like Git, but with much less elegance: the
place is shared by all users and projects of the system. So they are not
easy to archive for usage on another system at a low-level. But it does
have an interface (`docker save`) to copy all the relevant files within an
image into a tar ball that you can archive externally. There is also a
separate interface to load the tarball back into docker (`docker load`).

Both of these have been implemented as the `--image-file` option of the
`docker.sh` script. If you want to save your Maneage'd image into an image,
simply give the tarball name to this option. Alternatively, if you already
have a tarball and want to load it into Docker, give it to this option once
(until you "clean up", as explained below). In fact, docker images take a
lot of space and it is better to "clean up" regularly. And the only way you
can clean up safely is through saving your needed images as a file.

### Cleaning up

Docker has stored many large files in your operating system that can drain
valuable storage space. The storage of the cached files are usually orders
of magnitudes larger than what you see in `docker image list`! So after
doing your work, it is best to clean up all those files. If you feel you
may need the image later, you can save it in a single file as mentioned
above and delete all the un-necessary cached files. Afterwards, when you
load the image, only that image will be present with nothing extra.

The easiest and most powerful way to clean up everything in Docker is the
two commands below. The first will close all open containers. The second
will remove all stopped containers, all networks not used by at least one
container, all images without at least one container associated to them,
and all build cache.

```shell
docker ps -a -q | xargs docker rm
docker system prune -a
```

If you only want to delete the existing used images, run the command
below. But be careful that the cache is the largest storage consumer! So
the command above is the solution if your OS's root partition is close to
getting filled.

```shell
docker images -a -q | xargs docker rmi -f
```


### Preserving the state of an open container

All interactive changes in a container will be deleted as soon as you exit
it. This is a very good feature of Docker in general! If you want to make
persistent changes, you should do it in the project's plain-text source and
commit them into your project's online Git repository. But in certain
situations, it is necessary to preserve the state of an interactive
container. To do this, you need to `commit` the container (and thus save it
as a Docker "image"). To do this, while the container is still running,
open another terminal and run these commands:

```shell
# These two commands should be done in another terminal
docker container list

# Get the 'XXXXXXX' of your desired container from the first column above.
# Give the new image a name by replacing 'NEW-IMAGE-NAME'.
docker commit XXXXXXX NEW-IMAGE-NAME
```


### Interactive tests on built container

If you later want to start a container with the built image and enter it in
interactive mode (for example for temporary tests), run the following
command. Just replace `NAME` with the same name you specified when building
the project. You can always exit the container with the `exit` command
(note that all your changes will be discarded once you exit, see below if
you want to preserve your changes after you exit).

```shell
docker run -it NAME
```


### Copying files from the Docker image to host operating system

Except for the mounted directories, the Docker environment's file system is
indepenent of your host operating system. One easy way to copy files to and
from an open container is to use the `docker cp` command (very similar to
the shell's `cp` command).

```shell
docker cp CONTAINER:/file/path/within/container /host/path/target
```



## Copyright information

This file is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option)
any later version.

This file is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
more details.

You should have received a copy of the GNU General Public License along
with this file.  If not, see <https://www.gnu.org/licenses/>.
