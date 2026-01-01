#!/bin/sh
#
# Create a Docker container from an existing image of the built software
# environment, but with the source, data and build (analysis) directories
# directly within the host file system. This script is assumed to be run in
# the top project source directory (that has 'README.md' and
# 'paper.tex'). If not, use the '--source-dir' option to specify where the
# Maneage'd project source is located.
#
# Usage:
#
#   - When you are at the top Maneage'd project directory, run this script
#     like the example below. Just set the build directory location on your
#     system. See the items below for optional values to optimize the
#     process (avoid downloading for exmaple).
#
#        ./reproduce/software/shell/docker.sh --shm-size=20gb \
#                    --build-dir=/PATH/TO/BUILD/DIRECTORY
#
#   - Non-mandatory options:
#
#       - If you already have the input data that is necessary for your
#         project, use the '--input-dir' option to specify its location
#         on your host file system. Otherwise the necessary analysis
#         files will be downloaded directly into the build
#         directory. Note that this is only necessary when '--build-only'
#         is not given.
#
#       - If you already have the necessary software tarballs that are
#         necessary for your project, use the '--software-dir' option to
#         specify its location on your host file system only when
#         building the container. No problem if you don't have them, they
#         will be downloaded during the configuration phase.
#
#   - To avoid having to set them every time you want to start the
#     apptainer environment, you can put this command (with the proper
#     directories) into a 'run.sh' script in the top Maneage'd project
#     source directory and simply execute that. The special name 'run.sh'
#     is in Maneage's '.gitignore', so it will not be included in your
#     git history by mistake.
#
# Known problems:
#
#   - As of 2025-04-06 the log file containing the output of the 'docker
#     build' command that configures the Maneage'd project does not keep
#     all the output (which gets clipped by Docker). with a "[output
#     clipped, log limit 2MiB reached]" message. We need to find a way to
#     fix this (so nothing gets clipped: useful for debugging).
#
# Copyright (C) 2021-2026 Mohammad Akhlaghi <mohammad@akhlaghi.org>
#
# This script is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation, either version 3 of the License, or (at your
# option) any later version.
#
# This script is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General
# Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this script.  If not, see <http://www.gnu.org/licenses/>.





# Script settings
# ---------------
# Stop the script if there are any errors.
set -e





# Default option values
jobs=0
quiet=0
source_dir=
build_only=
image_file=""
shm_size=20gb
scriptname="$0"
project_shell=0
container_shell=0
project_name=maneaged
base_name=maneage-base
base_os=debian:stable-slim

print_help() {
    # Print the output.
    cat <<EOF
Usage: $scriptname [OPTIONS]

Top-level script to build and run a Maneage'd project within Docker.

 Host OS directories (to be mounted in the container):
  -b, --build-dir=STR      Dir. to build in (only analysis in host).
  -i, --input-dir=STR      Dir. of input datasets (optional).
  -s, --software-dir=STR   Directory of necessary software tarballs.
      --source-dir=STR     Directory of source code (default: 'pwd -P').

 Docker images
      --base-os=STR        Base OS name (default: '$base_os').
      --base-name=STR      Base OS docker image (default: $base_name).
      --project-name=STR   Project's docker image (default: $project_name).
      --image-file=STR     [Docker only] Load (if given file exists), or
                           save (if given file does not exist), the image.
                           For saving, the given name has to have an
                           '.tar.gz' suffix.

 Interactive shell
      --project-shell      Open the project's shell within the container.
      --container-shell    Open the container shell.

 Operating mode:
  -q, --quiet              Do not print informative statements.
  -?, --help               Give this help list.
      --shm-size=STR       Passed to 'docker build' (default: $shm_size).
  -j, --jobs=INT           Number of threads to use in each phase.
      --build-only         Just build the container, don't run it.

Mandatory or optional arguments to long options are also mandatory or
optional for any corresponding short options.

Maneage URL: https://maneage.org

Report bugs to mohammad@akhlaghi.org
EOF
}

on_off_option_error() {
    if [ "x$2" = x ]; then
        echo "$scriptname: '$1' doesn't take any values"
    else
        echo "$scriptname: '$1' (or '$2') doesn't take any values"
    fi
    exit 1
}

check_v() {
    if [ x"$2" = x ]; then
        printf "$scriptname: option '$1' requires an argument. "
        printf "Try '$scriptname --help' for more information\n"
        exit 1;
    fi
}

while [ $# -gt 0 ]
do
  case $1 in

  # OS directories
  -b|--build-dir)        build_dir="$2";                              check_v "$1" "$build_dir";    shift;shift;;
  -b=*|--build-dir=*)    build_dir="${1#*=}";                         check_v "$1" "$build_dir";    shift;;
  -b*)                   build_dir=$(echo    "$1" | sed -e's/-b//');  check_v "$1" "$build_dir";    shift;;
  -i|--input-dir)        input_dir="$2";                              check_v "$1" "$input_dir";    shift;shift;;
  -i=*|--input-dir=*)    input_dir="${1#*=}";                         check_v "$1" "$input_dir";    shift;;
  -i*)                   input_dir=$(echo    "$1" | sed -e's/-i//');  check_v "$1" "$input_dir";    shift;;
  -s|--software-dir)     software_dir="$2";                           check_v "$1" "$software_dir"; shift;shift;;
  -s=*|--software-dir=*) software_dir="${1#*=}";                      check_v "$1" "$software_dir"; shift;;
  -s*)                   software_dir=$(echo "$1" | sed -e's/-s//');  check_v "$1" "$software_dir"; shift;;
  --source-dir)          source_dir="$2";                             check_v "$1" "$source_dir";   shift;shift;;
  --source-dir=*)        source_dir="${1#*=}";                        check_v "$1" "$source_dir";   shift;;

  # Container options.
  --base-name)           base_name="$2";                              check_v "$1" "$base_name";    shift;shift;;
  --base-name=*)         base_name="${1#*=}";                         check_v "$1" "$base_name";    shift;;
  --project-name)        project_name="$2";                           check_v "$1" "$project_name"; shift;shift;;
  --project-name=*)      project_name="${1#*=}";                      check_v "$1" "$project_name"; shift;;

  # Interactive shell.
  --project-shell)       project_shell=1;                                                           shift;;
  --project_shell=*)     on_off_option_error --project-shell;;
  --container-shell)     container_shell=1;                                                         shift;;
  --container_shell=*)   on_off_option_error --container-shell;;

  # Operating mode
  -q|--quiet)            quiet=1;                                                                   shift;;
  -q*|--quiet=*)         on_off_option_error --quiet;;
  -j|--jobs)             jobs="$2";                                  check_v "$1" "$jobs";          shift;shift;;
  -j=*|--jobs=*)         jobs="${1#*=}";                             check_v "$1" "$jobs";          shift;;
  -j*)                   jobs=$(echo "$1" | sed -e's/-j//');         check_v "$1" "$jobs";          shift;;
  --build-only)          build_only=1;                                                              shift;;
  --build-only=*)        on_off_option_error --build-only;;
  --shm-size)            shm_size="$2";                              check_v "$1" "$shm_size";      shift;shift;;
  --shm-size=*)          shm_size="${1#*=}";                         check_v "$1" "$shm_size";      shift;;
  -'?'|--help)           print_help; exit 0;;
  -'?'*|--help=*)        on_off_option_error --help -?;;

  # Output file
  --image-file)           image_file="$2";                           check_v "$1" "$image_file";    shift;shift;;
  --image-file=*)         image_file="${1#*=}";                      check_v "$1" "$image_file";    shift;;

  # Unrecognized option:
  -*) echo "$scriptname: unknown option '$1'"; exit 1;;
 esac
done





# Sanity checks
# -------------
#
# Make sure that the build directory is given and that it exists.
if [ x$build_dir = x ]; then
    printf "$scriptname: '--build-dir' not provided, this is the location "
    printf "that all built analysis files will be kept on the host OS\n"
    exit 1;
else
    if ! [ -d $build_dir ]; then
        printf "$scriptname: '$build_dir' (value to '--build-dir') doesn't "
        printf "exist\n"; exit 1;
    fi
fi

# The temporary directory to place the Dockerfile.
tmp_dir="$build_dir"/temporary-docker-container-dir




# Directory preparations
# ----------------------
#
# If the host operating system has '/dev/shm', then give Docker access
# to it also for improved speed in some scenarios (like configuration).
if [ -d /dev/shm ]; then shm_mnt="-v /dev/shm:/dev/shm";
else                     shm_mnt=""; fi

# If the following directories do not exist within the build directory,
# create them to make sure the '--mount' commands always work and
# that any file. Ideally, the 'input' directory should not be under the 'build'
# directory, but if the user hasn't given it then they don't care about
# potentially deleting it later (Maneage will download the inputs), so put
# it in the build directory.
analysis_dir="$build_dir"/analysis
if ! [ -d $analysis_dir ]; then mkdir $analysis_dir; fi

# If no '--source-dir' was given, set it to the output of 'pwd -P' (to get
# the path without potential symbolic links) in the running directory.
if [ x"$source_dir" = x ]; then source_dir=$(pwd -P); fi

# Only when an an input directory is given, we need the respective 'mount'
# option for the 'docker run' command.
input_dir_mnt=""
if ! [ x"$input_dir" = x ]; then
    input_dir_mnt="-v $input_dir:/home/maneager/input"
fi

# Number of threads to build software (taken from 'configure.sh').
if [ x"$jobs" = x0 ]; then
    if type nproc > /dev/null 2> /dev/null; then
        numthreads=$(nproc --all);
    else
        numthreads=$(sysctl -a | awk '/^hw\.ncpu/{print $2}')
        if [ x"$numthreads" = x ]; then numthreads=1; fi
    fi
else
    numthreads=$jobs
fi

# Since the container is read-only and is run with the '--contain' option
# (which makes an empty '/tmp'), we need to make a dedicated directory for
# the container to be able to write to. This is necessary because some
# software (Biber in particular on the default branch or Ghostscript) need
# to write there! See https://github.com/plk/biber/issues/494. We'll keep
# the directory on the host OS within the build directory, but as a hidden
# file (since it is not necessary in other types of build and ultimately
# only contains temporary files of programs that need it).
toptmp=$build_dir/.docker-tmp-$(whoami)
if ! [ -d $toptmp ]; then mkdir $toptmp; fi
chmod -R +w $toptmp/ # Some software remove writing flags on /tmp files.
if ! [ x"$( ls -A $toptmp )" = x ]; then rm -r "$toptmp"/*; fi

# [DOCKER-ONLY] Make sure the user is a member of the 'docker' group. This
# is needed only for Linux, given that other systems uses other strategies.
# (See: https://stackoverflow.com/a/70385997)
kernelname=$(uname -s)
if [ x$kernelname = xLinux ]; then
    glist=$(groups $(whoami) | awk '/docker/')
    if [ x"$glist" = x ]; then
        printf "$scriptname: you are not a member of the 'docker' group "
        printf "You can run the following command as root to fix this: "
        printf "'usermod -aG docker $(whoami)'\n"
        exit 1
    fi
fi

# [DOCKER-ONLY] Function to check the temporary directory for building the
# base operating system docker image. It is necessary that this directory
# be empty because Docker will inherit the sub-directories of the directory
# that the Dockerfile is located in.
tmp_dir_check () {
    if [ -d $tmp_dir ]; then
        printf "$scriptname: '$tmp_dir' already exists, please "
        printf "delete it and re-run this script. This is a temporary "
        printf "directory only necessary when building a Docker image "
        printf "and gets deleted automatically after a successful "
        printf "build. The fact that it remains hints at a problem "
        printf "in a previous attempt to build a Docker image\n"
        exit 1
    else
        mkdir $tmp_dir
    fi
}





# Base operating system
# ---------------------
#
# If the base image does not exist, then create it. If it does, inform the
# user that it will be used.
if docker image list | grep $base_name &> /dev/null; then
    if [ $quiet = 0 ]; then
        printf "$scriptname: info: base OS docker image ('$base_name') "
        printf "already exists and will be used. If you want to build a "
        printf "new base OS image, give a new name to '--base-name'. "
        printf "To remove this message run with '--quiet'\n"
    fi
else

    # In case an image file is given, load the environment from that (no
    # need to build the environment from scratch).
    if ! [ x"$image_file" = x ] && [ -f "$image_file" ]; then
        docker load --input $image_file
    else

        # Build the temporary directory.
        tmp_dir_check

        # Build the Dockerfile.
        uid=$(id -u)
        cat <<EOF > $tmp_dir/Dockerfile
FROM $base_os
RUN useradd -ms /bin/sh --uid $uid maneager; \\
    printf '123\n123' | passwd maneager; \\
    printf '456\n456' | passwd root
RUN apt update; apt install -y gcc g++ wget; echo 'export PS1="[\[\033[01;31m\]\u@\h \W\[\033[32m\]\[\033[00m\]]# "' >> ~/.bashrc
USER maneager
WORKDIR /home/maneager
RUN mkdir build; mkdir build/analysis; echo 'export PS1="[\[\033[01;35m\]\u@\h \W\[\033[32m\]\[\033[00m\]]$ "' >> ~/.bashrc
EOF

        # Build the base-OS container and delete the temporary directory.
        curdir="$(pwd)"
        cd $tmp_dir
        docker build ./ \
               -t $base_name \
               --shm-size=$shm_size
        cd "$curdir"
        rm -rf $tmp_dir
    fi
fi





# Maneage software configuration
# ------------------------------
#
# Having the base operating system in place, we can now construct the
# project's docker file.
intbuild=/home/maneager/build
if docker image list | grep $project_name &> /dev/null; then
    if [ $quiet = 0 ]; then
        printf "$scriptname: info: project's image ('$project_name') "
        printf "already exists and will be used. If you want to build a "
        printf "new project image, give a new name to '--project-name'. "
        printf "To remove this message run with '--quiet'\n"
    fi
else

    # Build the temporary directory.
    tmp_dir_check
    df=$tmp_dir/Dockerfile

    # The only way to mount a directory inside the Docker build environment
    # is the 'RUN --mount' command. But Docker doesn't recognize things
    # like symbolic links. So we need to copy the project's source under
    # this temporary directory.
    sdir=source
    mkdir $tmp_dir/$sdir
    dsr=/home/maneager/source-raw
    cp -r $source_dir/* $source_dir/.git $tmp_dir/$sdir

    # Start constructing the Dockerfile.
    #
    # Note on the printf's '\x5C\n' part: this will print out as a
    # backslash at the end of the line to allow easy human readability of
    # the Dockerfile (necessary for debugging!).
    echo "FROM $base_name" > $df
    printf "RUN --mount=type=bind,source=$sdir,target=$dsr \x5C\n" >> $df

    # If a software directory was given, copy it and add its line.
    tsdir=tarballs-software
    dts=/home/maneager/tarballs-software
    if ! [ x"$software_dir" = x ]; then

        # Make the directory to host the software and copy the contents
        # that the user gave there.
        mkdir $tmp_dir/$tsdir
        cp -r "$software_dir"/* $tmp_dir/$tsdir/
        printf "    --mount=type=bind,source=$tsdir,target=$dts \x5C\n" >> $df
    fi

    # Construct the rest of the 'RUN' command.
    printf "    cp -r $dsr /home/maneager/source; \x5C\n"          >> $df
    printf "    cd /home/maneager/source; \x5C\n"                  >> $df
    printf "    ./project configure --jobs=$jobs \x5C\n"           >> $df
    printf "              --build-dir=$intbuild \x5C\n"            >> $df
    printf "              --input-dir=/home/maneager/input \x5C\n" >> $df
    printf "              --software-dir=$dts; \x5C\n"             >> $df

    # We are deleting the '.build/software/tarballs' directory because this
    # directory is not relevant for the analysis of the project. But in
    # case any tarball was downloaded, it will consume space within the
    # container.
    printf "    rm -rf .build/software/tarballs; \x5C\n" >> $df

    # We are deleting the source directory becaues later (at 'docker run'
    # time), the 'source' will be mounted directly from the host operating
    # system.
    printf "    cd /home/maneager; \x5C\n" >> $df
    printf "    rm -rf source\n" >> $df

    # Build the Maneage container and delete the temporary directory. The
    # '--progress plain' option is for Docker to print all the outputs
    # (otherwise, it will only print a very small part!).
    cd $tmp_dir
    docker build ./ -t $project_name \
           --progress=plain \
           --shm-size=$shm_size \
           --no-cache \
           2>&1 | tee build.log
    cd ..
    rm -rf $tmp_dir
fi

# If the user wants to save the container (into a file that does not
# exist), do it here. If the file exists, it will only be used for creating
# the container in the previous stages.
if ! [ x"$image_file" = x ] && ! [ -f "$image_file" ]; then

    # Save the image into a tarball
    tarname=$(echo $image_file | sed -e's|.gz$||')
    if [ $quiet = 0 ]; then
        printf "$scriptname: info: saving docker image to '$tarname'"
    fi
    docker save -o $tarname $project_name

    # Compress the saved image
    if [ $quiet = 0 ]; then
        printf "$scriptname: info: compressing to '$image_file' (can "
        printf "take +10 minutes, but volume decreases by more than half!)"
    fi
    gzip --best $tarname
fi

# If the user just wanted to build the base operating system, abort the
# script here.
if ! [ x"$build_only" = x ]; then
    if [ $quiet = 0 ]; then
        printf "$scriptname: info: Maneaged project has been configured "
        printf "successfully in the '$project_name' image"
    fi
    exit 0
fi





# Run the analysis within the Maneage'd container
# -----------------------------------------------
#
# The startup command of the container is managed though the 'shellopt'
# variable that starts here.
shellopt=""
sobase="/bin/bash -c 'cd source; "
sobase="$sobase ./project configure --build-dir=$intbuild "
sobase="$sobase --existing-conf --no-pause --offline --quiet && "
sobase="$sobase ./project MODE --build-dir=$intbuild"
if [ $container_shell = 1 ] || [ $project_shell = 1 ]; then

    # The interactive flag is necessary for both these scenarios.
    interactiveopt="-it"

    # With '--project-shell' we need 'shellopt', the MODE just needs to be
    # set to 'shell'.
    if [ $project_shell = 1 ]; then
        shellopt="$(echo $sobase | sed -e's|MODE|shell|');'"
    fi

# No interactive shell requested, just run the project.
else
    interactiveopt=""
    shellopt="$(echo $sobase | sed -e's|MODE|make|') --jobs=$jobs;'"
fi

# Execute Docker. The 'eval' is because the 'shellopt' variable contains a
# single-quote that the shell should "evaluate".
eval docker run --read-only \
            -v "$analysis_dir":/home/maneager/build/analysis \
            -v "$source_dir":/home/maneager/source \
            -v $toptmp:/tmp \
            $input_dir_mnt \
            $shm_mnt \
            $interactiveopt \
            $project_name \
            $shellopt
