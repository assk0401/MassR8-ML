#!/bin/sh
#
# Create a Apptainer container from an existing image of the built software
# environment, but with the source, data and build (analysis) directories
# directly within the host file system. This script is assumed to be run in
# the top project source directory (that has 'README.md' and
# 'paper.tex'). If not, use the '--source-dir' option to specify where the
# Maneage'd project source is located.
#
# Usage:
#
#   - When you are at the top Maneage'd project directory, you can run this
#     script like the example below. Just set all the '/PATH/TO/...'
#     directories. See the items below for optional values.
#
#          ./reproduce/software/containers/apptainer.sh \
#                      --build-dir=/PATH/TO/BUILD/DIRECTORY \
#                      --software-dir=/PATH/TO/SOFTWARE/TARBALLS
#
#     - Non-mandatory options:
#
#         - If you already have the input data that is necessary for your
#           project's, use the '--input-dir' option to specify its location
#           on your host file system. Otherwise the necessary analysis
#           files will be downloaded directly into the build
#           directory. Note that this is only necessary when '--build-only'
#           is not given.
#
#         - The '--software-dir' is only useful if you want to build a
#           container. Even in that case, it is not mandatory: if not
#           given, the software tarballs will be downloaded (thus requiring
#           internet).
#
#     - To avoid having to set them every time you want to start the
#       apptainer environment, you can put this command (with the proper
#       directories) into a 'run.sh' script in the top Maneage'd project
#       source directory and simply execute that. The special name 'run.sh'
#       is in Maneage's '.gitignore', so it will not be included in your
#       git history by mistake.
#
# Known problems:
#
# Copyright (C) 2025-2025 Mohammad Akhlaghi <mohammad@akhlaghi.org>
# Copyright (C) 2025-2025 Giacomo Lorenzetti <glorenzetti@cefca.es>
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
jobs=
quiet=0
source_dir=
build_only=
base_name=""
shm_size=20gb
scriptname="$0"
project_name=""
project_shell=0
container_shell=0
base_os=debian:stable-slim

print_help() {
    # Print the output.
    cat <<EOF
Usage: $scriptname [OPTIONS]

Top-level script to build and run a Maneage'd project within Apptainer.

 Host OS directories (to be mounted in the container):
  -b, --build-dir=STR      Dir. to build in (only analysis in host).
  -i, --input-dir=STR      Dir. of input datasets (optional).
  -s, --software-dir=STR   Directory of necessary software tarballs.
      --source-dir=STR     Directory of source code (default: 'pwd -P').

 Apptainer images
      --base-os=STR        Base OS name (default: '$base_os').
      --base-name=STR      Base OS apptainer image (a '.sif' file).
      --project-name=STR   Project's apptainer image (a '.sif' file).

 Interactive shell
      --project-shell      Open the project's shell within the container.
      --container-shell    Open the container shell.

 Operating mode:
      --quiet              Do not print informative statements.
  -?, --help               Give this help list.
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
  --quiet)               quiet=1;                                                                   shift;;
  --quiet=*)             on_off_option_error --quiet;;
  -j|--jobs)             jobs="$2";                                  check_v "$1" "$jobs";          shift;shift;;
  -j=*|--jobs=*)         jobs="${1#*=}";                             check_v "$1" "$jobs";          shift;;
  -j*)                   jobs=$(echo "$1" | sed -e's/-j//');         check_v "$1" "$jobs";          shift;;
  --build-only)          build_only=1;                                                              shift;;
  --build-only=*)        on_off_option_error --build-only;;
  --shm-size)            shm_size="$2";                              check_v "$1" "$shm_size";      shift;shift;;
  --shm-size=*)          shm_size="${1#*=}";                         check_v "$1" "$shm_size";      shift;;
  -'?'|--help)           print_help; exit 0;;
  -'?'*|--help=*)        on_off_option_error --help -?;;

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
        printf "exist\n"
        exit 1;
    fi
fi

# Set the default project and base-OS image names (inside the build
# directory).
if [ x"$base_name" = x ]; then base_name=$build_dir/maneage-base.sif; fi
if [ x"$project_name" = x ]; then project_name=$build_dir/maneaged.sif; fi





# Directory preparations
# ----------------------
#
# If the host operating system has '/dev/shm', then give Apptainer access
# to it also for improved speed in some scenarios (like configuration).
if [ -d /dev/shm ]; then
     shm_mnt="--mount type=bind,src=/dev/shm,dst=/dev/shm";
else shm_mnt="";
fi

# If the following directories do not exist within the build directory,
# create them to make sure the '--mount' commands always work and
# that any file. Ideally, the 'input' directory should not be under the 'build'
# directory, but if the user hasn't given it then they don't care about
# potentially deleting it later (Maneage will download the inputs), so put
# it in the build directory.
analysis_dir="$build_dir"/analysis
if ! [ -d $analysis_dir ]; then mkdir $analysis_dir; fi
analysis_dir_mnt="--mount type=bind,src=$analysis_dir,dst=/home/maneager/build/analysis"

# If no '--source-dir' was given, set it to the output of 'pwd -P' (to get
# the direct path without potential symbolic links) in the running directory.
if [ x"$source_dir" = x ]; then source_dir=$(pwd -P); fi
source_dir_mnt="--mount type=bind,src=$source_dir,dst=/home/maneager/source"

# Only when an an input directory is given, we need the respective 'mount'
# option for the 'apptainer run' command.
input_dir_mnt=""
if ! [ x"$input_dir" = x ]; then
    input_dir_mnt="--mount type=bind,src=$input_dir,dst=/home/maneager/input"
fi

# If no '--jobs' has been specified, use the maximum available jobs to the
# operating system.
if [ x$jobs = x ]; then jobs=$(nproc); fi

# [APPTAINER-ONLY] Optional mounting option for the software directory.
software_dir_mnt=""
if ! [ x"$software_dir" = x ]; then
    software_dir_mnt="--mount type=bind,src=$software_dir,dst=/home/maneager/tarballs-software"
fi

# [APPTAINER-ONLY] Since the container is read-only and is run with the
# '--contain' option (which makes an empty '/tmp'), we need to make a
# dedicated directory for the container to be able to write to. This is
# necessary because some software (Biber in particular on the default
# branch) need to write there! See https://github.com/plk/biber/issues/494.
# We'll keep the directory on the host OS within the build directory, but
# as a hidden file (since it is not necessary in other types of build and
# ultimately only contains temporary files of programs that need it).
toptmp=$build_dir/.apptainer-tmp-$(whoami)
if ! [ -d $toptmp ]; then mkdir $toptmp; fi
rm -rf $toptmp/*               # So previous runs don't affect this run.





# Maneage'd Apptainer SIF container
# ---------------------------------
#
# Build the base operating system using Maneage's './project configure'
# step.
if [ -f $project_name ]; then
    if [ $quiet = 0 ]; then
        printf "$scriptname: info: project's image ('$project_name') "
        printf "already exists and will be used. If you want to build a "
        printf "new project image, give a new name to '--project-name'. "
        printf "To remove this message run with '--quiet'\n"
    fi
else

    # Build the basic definition, with just Debian and gcc/g++
    if [ -f $base_name ]; then
        if [ $quiet = 0 ]; then
            printf "$scriptname: info: base OS docker image ('$base_name') "
            printf "already exists and will be used. If you want to build a "
            printf "new base OS image, give a new name to '--base-name'. "
            printf "To remove this message run with '--quiet'\n"
        fi
    else

        base_def=$build_dir/base.def
        cat <<EOF > $base_def
Bootstrap: docker
From: $base_os

%post
  apt-get update && apt-get install -y gcc g++
EOF
        # Build the base operating system container and delete the
        # temporary definition file.
        apptainer build $base_name $base_def
        rm $base_def
    fi

    # Build the Maneage definition file.
    #   - About the '$jobs' variable: this definition file is temporarily
    #     built and deleted immediately after the SIF file is created. So
    #     instead of using Apptainer's more complex '{{ jobs }}' format to
    #     pass an argument, we simply write the value of the configure
    #     script's '--jobs' option as a shell variable here when we are
    #     building that file.
    #   - About the removal of Maneage'd tarballs: we are doing this so if
    #     Maneage has downloaded tarballs during the build they do not
    #     unecessarily bloat the container. Even when the user has given a
    #     software tarball directory, they will all be symbolic links that
    #     aren't valid when the user runs the container (since we only
    #     mount the software tarballs at build time).
    maneage_def=$build_dir/maneage.def
    cat <<EOF > $maneage_def
Bootstrap: localimage
From: $base_name

%setup
  mkdir -p \${APPTAINER_ROOTFS}/home/maneager/input
  mkdir -p \${APPTAINER_ROOTFS}/home/maneager/source
  mkdir -p \${APPTAINER_ROOTFS}/home/maneager/build/analysis
  mkdir -p \${APPTAINER_ROOTFS}/home/maneager/tarballs-software

%post
  cd /home/maneager/source
  ./project configure --jobs=$jobs \\
                      --input-dir=/home/maneager/input \\
                      --build-dir=/home/maneager/build \\
                      --software-dir=/home/maneager/tarballs-software
  rm /home/maneager/build/software/tarballs/*

%runscript
  cd /home/maneager/source
  if   [ x"\$maneage_apptainer_stat" = xshell ]; then \\
     ./project shell; \\
  elif [ x"\$maneage_apptainer_stat" = xrun   ]; then \\
     if [ x"\$maneage_jobs" = x ]; then \\
       ./project make; \\
     else \\
       ./project make --jobs=\$maneage_jobs; \\
     fi; \\
  else \\
     printf "$scriptname: '\$maneage_apptainer_stat' (value "; \\
     printf "to 'maneage_apptainer_stat' environment variable) "; \\
     printf "is not recognized: should be either 'shell' or 'run'"; \\
     exit 1; \\
  fi
EOF

    # Build the maneage container. The last two are arguments (where order
    # matters). The first few are options where order does not matter (so
    # we have sorted them by line length).
    apptainer build \
              $shm_mnt \
              $input_dir_mnt \
              $source_dir_mnt \
              $analysis_dir_mnt \
              $software_dir_mnt \
              --ignore-fakeroot-command \
              \
              $project_name \
              $maneage_def

    # Clean up.
    rm $maneage_def
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





# Run the Maneage'd container
# ---------------------------
#
# Set the high-level Apptainer operational mode.
if [ $container_shell = 1 ]; then
    aopt="shell"
elif [ $project_shell = 1 ]; then
    aopt="run --env maneage_apptainer_stat=shell"
else
    aopt="run --env maneage_apptainer_stat=run --env maneage_jobs=$jobs"
fi

# Build the hostname from the name of the SIF file of the project name.
hstname=$(echo "$project_name" \
              | awk 'BEGIN{FS="/"}{print $NF}' \
              | sed -e's|.sif$||')

# Execute Apptainer:
#
#   - We are not using '--unsquash' (to run within a sandbox) because it
#     loads the full multi-gigabyte container into RAM (which we usually
#     need for data processing). The container is read-only and we are
#     using the following two options instead to ensure that we have no
#     influence from outside the container. (description of each is from
#     the Apptainer manual)
#       --contain: use minimal /dev and empty other directories (e.g. /tmp
#         and $HOME) instead of sharing filesystems from your host.
#       --cleanenv: clean environment before running container".
#
#   - We are not mounting '/dev/shm' since Apptainer prints a warning that
#     it is already mounted (apparently does not need it at run time).
#
#   --no-home and --home: the first ensures that the 'HOME' variable is
#     different from the user's home on the host operating system, the
#     second sets it to a directory we specify (to keep things like
#     '.bash_history').
apptainer $aopt \
          --no-home \
          --contain \
          --cleanenv \
          --home $toptmp \
          $input_dir_mnt \
          $source_dir_mnt \
          $analysis_dir_mnt \
          --workdir $toptmp \
          --hostname $hstname \
          --cwd /home/maneager/source \
          \
          $project_name
