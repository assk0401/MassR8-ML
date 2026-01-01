#!/bin/sh
#
# Necessary preparations/configurations for the reproducible project.
#
# Copyright (C) 2018-2026 Mohammad Akhlaghi <mohammad@akhlaghi.org>
# Copyright (C) 2021-2026 Raul Infante-Sainz <infantesainz@gmail.com>
# Copyright (C) 2022-2026 Pedram Ashofteh Ardakani <pedramardakani@pm.me>
#
# This script is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This script is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this script.  If not, see <http://www.gnu.org/licenses/>.





# Script settings
# ---------------
# Stop the script if there are any errors.
set -e





# Project-specific settings
# -------------------------
#
# The variables defined here may be different between different
# projects. Ideally, they should be detected automatically, but we haven't
# had the chance to implement it yet (please help if you can!). Until then,
# please set them based on your project (if they differ from the core
# branch).

# If equals 1, a message will be printed, showing the nano-seconds since
# previous step: useful with '-e --offline --nopause --quiet' to find
# bottlenecks for speed optimization. Speed is important because this
# script is called automatically every time by the container scripts.
check_elapsed=0

# In case a fortran compiler is necessary to check.
need_gfortran=0





# Internal source directories
# ---------------------------
#
# These are defined to help make this script more readable.
topdir="$(pwd)"
optionaldir="/optional/path"
cdir=reproduce/software/config










# Notice for top of generated files
# ---------------------------------
#
# In case someone opens the files output from the configuration scripts in
# a text editor and wants to edit them, it is important to let them know
# that their changes are not going to be permenant.
create_file_with_notice ()
{
    if printf "# IMPORTANT: " > "$1"
    then
        # These commands may look messy, but the produced comments in the
        # file are the main goal and they are readable. (without having to
        # break our source-code line length).
        printf "file can be RE-WRITTEN after './project "      >> "$1"
        printf "configure'.\n"                                 >> "$1"
        printf "#\n"                                           >> "$1"
        printf "# This file was created during configuration " >> "$1"
        printf "('./project configure').\n"                    >> "$1"
        printf "# Therefore, it is not under version control " >> "$1"
        printf "and any manual changes\n"                      >> "$1"
        printf "# to it will be over-written when the "        >> "$1"
        printf "project is re-configured.\n"                   >> "$1"
        printf "#\n"                                           >> "$1"
    else
        echo; echo "Can't write to $1"; echo;
        exit 1
    fi
}





# Get absolute address
# --------------------
#
# Since the build directory will go into a symbolic link, we want it to be
# an absolute address. With this function we can make sure of that.
absolute_dir ()
{
    address="$1"
    if stat "$address" 1> /dev/null; then
        echo "$(cd "$(dirname "$1")" && pwd )/$(basename "$1")"
    else
        echo "$optionaldir"
    fi
}





# Check file permission handling (POSIX-compatibility)
# ----------------------------------------------------
#
# Check if a 'given' directory handles permissions as expected.
#
# This is to prevent a known bug in the NTFS filesystem that prevents
# proper installation of Perl, and probably some other packages. This
# function receives the directory as an argument and then, creates a dummy
# file, and examines whether the given directory handles the file
# permissions as expected.
#
# Returns '0' if everything is fine, and '255' otherwise. Choosing '0' is
# to mimic the '$ echo $?' behavior, while choosing '255' is to prevent
# misunderstanding 0 and 1 as true and false.
#
# ===== CAUTION! ===== #
#
# Since there is a 'set -e' before running this function, the whole script
# stops and exits IF the 'check_permission' (or any other function) returns
# anything OTHER than '0'! So, only use this function as a test. Here's a
# minimal example:
#
#     if $(check_permission $some_directory) ; then
#       echo "yay"; else "nay";
#     fi ;
check_permission ()
{
    # Make a 'junk' file, activate its executable flag and record its
    # permissions generally.
    local junkfile="$1"/check_permission_tmp_file
    rm -f "$junkfile"
    echo "Don't let my short life go to waste" > "$junkfile"
    chmod +x "$junkfile"
    local perm_before=$(ls -l "$junkfile" | awk '{print $1}')

    # Now, remove the executable flag and record the permissions.
    chmod -x "$junkfile"
    local perm_after=$(ls -l "$junkfile" | awk '{print $1}')

    # Clean up before leaving the function
    rm -f "$junkfile"

    # If the permissions are equal, the filesystem doesn't allow
    # permissions.
    if [ $perm_before = $perm_after ]; then
        # Setting permission FAILED
        return 1
    else
        # Setting permission SUCCESSFUL
        return 0
    fi
}





# Check if there is enough free space available in the build directory
# --------------------------------------------------------------------
#
# Use this function to check if there is enough free space in a
# directory. It is meant to be passed to the 'if' statement in the
# shell. So if there is enough space, it returns 0 (which translates to
# TRUE), otherwise, the funcion returns 1 (which translates to FALSE).
#
# Expects to be called with two arguments, the first is the threshold and
# the second is the desired directory. The 'df' function checks the given
# path to see where it is mounted on, and how much free space there is on
# that partition (in units of 1024 bytes).
#
# synopsis:
# $ free_space_warning <acceptable_threshold> <path-to-check>
#
# example:
# To check if there is 5MB of space available in /path/to/check
# call the command with arguments as shown below:
# $ free_space_warning 5000 /path/to/check/free/space
free_space_warning()
{
    fs_threshold=$1
    fs_destpath="$2"
    return $(df -P "$fs_destpath" \
                | awk 'FNR==2 {if($4>'$fs_threshold') print 1; \
                               else                   print 0; }')
}





# Function to empty the temporary software building directory. This can
# either be a symbolic link (to RAM) or an actual directory, so we can't
# simply use 'rm -r' (because a symbolic link is not a directory for 'rm').
empty_build_tmp() {

    # 'ls -A' does not print the '.' and '..' and the '-z' option of '['
    # checks if the string is empty or not. This allows us to only attempt
    # deleting the directory's contents if it actually has anything inside
    # of it. Otherwise, '*' will not expand and we'll get an 'rm' error
    # complaining that '$tmpblddir/*' doesn't exist. We also don't want to
    # use 'rm -rf $tmpblddir/*' because in case of a typo or while
    # debugging (if '$tmpblddir' becomes an empty string), this can
    # accidentally delete the whole root partition (or a least the '/home'
    # partition of the user).
    if ! [ x"$( ls -A $tmpblddir )" = x ]; then
        rm -r "$tmpblddir"/*
    fi
    rm -r "$tmpblddir"
}





# Function to report the elapsed time between steps (if it was activated
# above with 'check_elapsed').
elapsed_time_from_prev_step() {
    if [ $check_elapsed = 1 ]; then
        chel_now=$(date +"%N");
        chel_delta=$(echo $chel_prev $chel_now  \
                         | awk '{ delta=($2-$1)/1e6; \
                                   if(delta>0) d=delta; else d=0; \
                                   print d}')
        chel_dsum=$(echo $chel_dsum $chel_delta | awk '{print $1+$2}')
        echo $chel_counter $chel_delta "$1" \
            | awk '{ printf "Step %02d: %-6.2f [millisec]; %s\n", \
                            $1, $2, $3}'
        chel_counter=$((chel_counter+1))
        chel_prev=$(date +"%N")
    fi
}










# In already-built container
# --------------------------
#
# We need to run './project configure' at the start of every run of Maneage
# within a container (with 'shell' or 'make'). This is because we need to
# ensure the versions of all software are correct. However, the container
# filesystem (where the build/software directory is located) should be run
# as read-only when doing the analysis. So we will not be able to run some
# of the tests that require writing files or are generally not relevant
# when the container is already built (we want the configure command to be
# as fast as possible).
#
# The project source in Maneage'd containers is '/home/maneager/source'.
built_container=0
if [ "$topdir" = /home/maneager/source ] \
       && [ -f .build/software/config/hardware-parameters.tex ]; then
    built_container=1;
fi

# Initialize the elapsed time measurement parameters.
if [ $check_elapsed = 1 ]; then
    chel_dsum=0.00
    chel_counter=1
    chel_prev=$(date +"%N")
    chel_start=$(date +"%N")
fi




# Identify the running OS
# -----------------------
#
# Some features are tailored to GNU/Linux systems, while the BSD-based
# behavior is different. Initially we only tested macOS (hence the name of
# the variable), but as FreeBSD is also being inlucded in our tests. As
# more systems get used, we need to tailor these kinds of things better.
if [ $built_container = 0 ]; then
    kernelname=$(uname -s)
    if [ $pauseformsg = 1 ]; then pausesec=10; else pausesec=0; fi
    if [ x$kernelname = xLinux ]; then
        on_mac_os=no

        # Don't forget to add the respective C++ compiler below (leave 'cc' in
        # the end).
        c_compiler_list="gcc clang cc"
    elif [ x$kernelname = xDarwin ]; then
        host_cc=1
        on_mac_os=yes

        # Don't forget to add the respective C++ compiler below (leave 'cc' in
        # the end).
        c_compiler_list="clang gcc cc"
    else
        on_mac_os=no
        cat <<EOF
______________________________________________________
!!!!!!!                 WARNING                !!!!!!!

Maneage has been tested on GNU/Linux and Darwin (macOS) systems. But, it
seems that the current system is not GNU/Linux or Darwin (macOS). If you
notice any problem during the configure phase, please contact us with this
web-form:

    https://savannah.nongnu.org/support/?func=additem&group=reproduce

The configuration will continue in $pausesec seconds. To avoid the
pause on such messages use the '--no-pause' option.

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

EOF
        sleep $pausesec
    fi
    elapsed_time_from_prev_step os_identify
fi




# Collect CPU information
# -----------------------
#
# When the project is built, the type of a machine that built it also has
# to to be documented. This way, if different results or behaviors are
# observed in software-related or analysis-related phases of the project,
# it would be easier to track down the root cause. So far this is just
# later recorded as a LaTeX macro to be put in the final paper, but it
# could be used in a more systematic way to optimize/revise project
# workflow and build.
if [ $built_container = 0 ]; then
    if [ x$kernelname = xLinux ]; then
        byte_order=$(lscpu \
                         | grep 'Byte Order' \
                         | awk '{ \
                                  for(i=3;i<NF;++i) \
                                  printf "%s ", $i; \
                                  printf "%s", $NF}')
        address_sizes=$(lscpu \
                            | grep 'Address sizes' \
                            | awk '{ \
                                     for(i=3;i<NF;++i) \
                                     printf "%s ", $i; \
                                     printf "%s", $NF}')
    elif [ x$on_mac_os = xyes ]; then
        hw_byteorder=$(sysctl -n hw.byteorder)
        if   [ x$hw_byteorder = x1234 ]; then byte_order="Little Endian";
        elif [ x$hw_byteorder = x4321 ]; then byte_order="Big Endian";
        fi

        # On macOS, the way of obtaining the number of cores is different
        # between Intel or Apple M1 CPUs. Here we disinguish between Apple
        # M1 or others.
        maccputype=$(sysctl -n machdep.cpu.brand_string)
        if [ x"$maccputype" = x"Apple M1" ]; then
            address_size_physical=$(sysctl -n machdep.cpu.thread_count)
            address_size_virtual=$(sysctl -n machdep.cpu.logical_per_package)
        else
            address_size_physical=$(sysctl -n machdep.cpu.address_bits.physical)
            address_size_virtual=$(sysctl -n machdep.cpu.address_bits.virtual)
        fi
        address_sizes="$address_size_physical bits physical, "
        address_sizes+="$address_size_virtual bits virtual"
    else
        byte_order="unrecognized"
        address_sizes="unrecognized"
        cat <<EOF
______________________________________________________
!!!!!!!                 WARNING                !!!!!!!

Machine byte order and address sizes could not be recognized. You can add
the necessary steps in the 'reproduce/software/shell/configure.sh' script
(just above this error message), or contact us with this web-form:

    https://savannah.nongnu.org/support/?func=additem&group=reproduce

The configuration will continue in $pausesec seconds. To avoid the
pause on such messages use the '--no-pause' option.

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

EOF
        sleep $pausesec
    fi
    elapsed_time_from_prev_step cpu-info
fi





# Check for Xcode in macOS systems
# --------------------------------
#
# When trying to build Maneage on macOS systems, there are some problems
# related with the Xcode and Command Line Tools. As a consequnce, in order to
# avoid these error it is highly recommended to install Xcode in the host
# system.  Here, it is checked that this is the case, and if not, warn the user
# about not having Xcode already installed.
if [ $built_container = 0 ] && [ x$on_mac_os = xyes ]; then

  # 'which' isn't in POSIX, so we are using 'command -v' instead.
  xcode=$(command -v xcodebuild)
  if [ x$xcode != x ]; then
    xcode_version=$(xcodebuild -version | grep Xcode)
    echo "                                              "
    echo "$xcode_version already installed in the system"
    echo "                                              "
  else
    cat <<EOF
______________________________________________________
!!!!!!!                 WARNING                !!!!!!!

Maneage has been tested Darwin (macOS) systems with host Xcode
installation.  However, Xcode cannot be found in this system. As a
consequence, the configure step may fail at some point. If this is the
case, please install Xcode and try to run again the configure step. If the
problem still persist after installing Xcode, please contact us with this
web-form:

    https://savannah.nongnu.org/support/?func=additem&group=reproduce

The configuration will continue in $pausesec seconds. To avoid the
pause on such messages use the '--no-pause' option.

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

EOF
    sleep $pausesec
  fi
  elapsed_time_from_prev_step compiler-of-mac-os
fi





# Check for C/C++ compilers
# -------------------------
#
# To build the software, we'll need some basic tools (the C/C++ compilers
# in particular) to be present.
has_compilers=no
if [ $built_container = 0 ]; then
    for c in $c_compiler_list; do

        # Set the respective C++ compiler.
        if   [ x$c = xcc    ]; then cplus=c++;
        elif [ x$c = xgcc   ]; then cplus=g++;
        elif [ x$c = xclang ]; then cplus=clang++;
        else
            cat <<EOF
______________________________________________________
!!!!!!!                   BUG                  !!!!!!!

The respective C++ compiler executable name for the C compiler '$c' hasn't
been set! You can add it in the 'reproduce/software/shell/configure.sh'
script (just above this error message), or contact us with this web-form:

    https://savannah.nongnu.org/support/?func=additem&group=reproduce

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

EOF
            exit 1
        fi

        # Check if they exist.
        if type $c > /dev/null 2>/dev/null; then
            export CC=$c;
            if type $cplus > /dev/null 2>/dev/null; then
                export CXX=$cplus
                has_compilers=yes
                break
            fi
        fi
    done
    if [ x$has_compilers = xno ]; then
        cat <<EOF
______________________________________________________
!!!!!!!       C/C++ Compiler NOT FOUND         !!!!!!!

To build this project's software, the host system needs to have both C and
C++ compilers. The commands that were checked are listed below:

    cc, c++            Generic C/C++ compiler (possibly links to below).
    gcc, g++           Part of GNU Compiler Collection (GCC).
    clang, clang++     Part of LLVM compiler infrastructure.

If your compiler is not checked, please get in touch with the web-form
below, so we add it. We will try our best to add it soon. Until then,
please install at least one of these compilers on your system to proceed.

    https://savannah.nongnu.org/support/?func=additem&group=reproduce

NOTE: for macOS systems, the LLVM compilers that are provided in a native
Xcode install are recommended. There are known problems with GCC on macOS.

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

EOF
        exit 1
    fi
    elapsed_time_from_prev_step compiler-present
fi




# Check C compiler
# ----------------
#
# We are checking the C compiler before asking for the directories to let
# the user fix lower-level problems before giving inputs.
compilertestdir=.compiler_test_dir_please_delete
testsource=$compilertestdir/test.c
testprog=$compilertestdir/test
if [ $built_container = 0 ]; then

    # Here we check if the C compiler works properly. We'll start by
    # making a directory to keep the products.
    if ! [ -d $compilertestdir ]; then mkdir $compilertestdir; fi

    # About the "no warning" variable ('nowarnings'):
    #
    #   -Wno-nullability-completeness: on macOS Big Sur 11.2.3 and
    #    Xcode 12.4, hundreds of 'nullability-completeness' warnings
    #    are printed which can be very annoying and even hide
    #    important errors or warnings. It is also harmless for our
    #    test here, so it is generally added.
    if [ x$on_mac_os = xyes ]; then
        noccwarnings="-Wno-nullability-completeness"
    fi
    if [ $quiet = 0 ]; then
        echo; echo "Checking host C compiler ('$CC')...";
    fi
    cat > $testsource <<EOF
#include <stdio.h>
#include <stdlib.h>
int main(void){printf("Good!\n"); return EXIT_SUCCESS;}
EOF
    if $CC $noccwarnings $testsource -o$testprog && $testprog > /dev/null; then
        if [ $quiet = 0 ]; then echo "... yes"; fi
        rm $testsource $testprog
    else
        rm $testsource
        cat <<EOF

______________________________________________________
!!!!!!!        C compiler doesn't work         !!!!!!!

Host C compiler ('$CC') can't build a simple program.

A working C compiler is necessary for building the project's software.
Please use the error message above to find a good solution and re-run the
project configuration.

If you can't find a solution, please send the error message above to the
link below and we'll try to help

https://savannah.nongnu.org/support/?func=additem&group=reproduce

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

EOF
        exit 1
    fi
    elapsed_time_from_prev_step compiler-c-check
fi




# See if we need the dynamic-linker (-ldl)
# ----------------------------------------
#
# Some programs (like Wget) need dynamic loading (using 'libdl'). On
# GNU/Linux systems, we'll need the '-ldl' flag to link such programs.  But
# Mac OS doesn't need any explicit linking. So we'll check here to see if
# it is present (thus necessary) or not.
if [ $built_container = 0 ]; then
    cat > $testsource <<EOF
#include <stdio.h>
#include <dlfcn.h>
int
main(void) {
    void *handle=dlopen ("/lib/CEDD_LIB.so.6", RTLD_LAZY);
    return 0;
}
EOF
    if $CC $testsource -o$testprog 2>/dev/null > /dev/null; then
        needs_ldl=no;
    else
        needs_ldl=yes;
    fi
    elapsed_time_from_prev_step compiler-needs-dynamic-linker
fi




# See if the C compiler can build static libraries
# ------------------------------------------------
#
# We are manually only working with shared libraries: because some
# high-level programs like Wget and cURL need dynamic linking and if we
# build the libraries statically, our own builds will be ignored and these
# programs will go and find their necessary libraries on the host system.
#
# Another good advantage of shared libraries is that we can actually use
# the shared library tool of the system ('ldd' with GNU C Library) and see
# exactly where each linked library comes from. But in static building,
# unless you follow the build closely, its not easy to see if the source of
# the library came from the system or our build.
static_build=no

# Print warning if the host CC is to be used.
if [ $built_container = 0 ] && [ x$host_cc = x1 ]; then
    cat <<EOF

______________________________________________________
!!!!!!!!!!!!!!!        Warning        !!!!!!!!!!!!!!!!

The GNU Compiler Collection (GCC, including compilers for C, C++, Fortran
and etc) is not going to be built for this project. Either it is a macOS,
or you have used '--host-cc'.

The configuration will continue in $pausesec seconds. To avoid the
pause on such messages use the '--no-pause' option.

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

EOF
    sleep $pausesec
fi





# Necessary C library element positions
# -------------------------------------
#
# On some systems (in particular Debian-based OSs), the static C library
# and necessary headers in a non-standard place, and we can't build GCC. So
# we need to find them first. The 'sys/cdefs.h' header is also in a
# similarly different location.
sys_cpath=""
sys_library_path=""
if [ $built_container = 0 ] && [ x"$on_mac_os" != xyes ]; then

    # Get the GCC target name of the compiler, when its given, special
    # C libraries and headers are in a sub-directory of the host.
    gcctarget=$(gcc -v 2>&1 \
                    | tr ' ' '\n' \
                    | awk '/\-\-target/' \
                    | sed -e's/\-\-target=//')
    if [ x"$gcctarget" != x ]; then
        if [ -f /usr/lib/$gcctarget/libc.a ]; then
            export sys_library_path=/usr/lib/$gcctarget
            export sys_cpath=/usr/include/$gcctarget
        fi
    fi

    # For a check:
    #echo "sys_library_path: $sys_library_path"
    #echo "sys_cpath: $sys_cpath"
    elapsed_time_from_prev_step compiler-sys-cpath
fi





# See if a link-able static C library exists
# ------------------------------------------
#
# A static C library and the 'sys/cdefs.h' header are necessary for
# building GCC.
if [ $built_container = 0 ]; then
    if [ x"$host_cc" = x0 ]; then
        if [ $quiet = 0 ]; then
            echo; echo "Checking if static C library is available...";
        fi
        cat > $testsource <<EOF
#include <stdio.h>
#include <stdlib.h>
#include <sys/cdefs.h>
int main(void){printf("...yes\n"); return EXIT_SUCCESS;}
EOF
        cc_call="$CC $testsource $CPPFLAGS $LDFLAGS -o$testprog -static -lc"
        if $cc_call && $testprog > /dev/null; then
            gccwarning=0
            rm $testsource $testprog
            if [ $quiet = 0 ]; then echo "... yes"; fi
        else
            echo; echo "Compilation command:"; echo "$cc_call"
            rm $testsource
            gccwarning=1
            host_cc=1
            cat <<EOF

_______________________________________________________
!!!!!!!!!!!!            Warning            !!!!!!!!!!!!

The 'sys/cdefs.h' header cannot be included, or a usable static C library
('libc.a', in any directory) cannot be used with the current settings of
this system. SEE THE ERROR MESSAGE ABOVE.

Because of this, we can't build GCC. You either 1) don't have them, or 2)
the default system environment aren't enough to find them.

1) If you don't have them, your operating system provides them as separate
packages that you must manually install. Please look into your operating
system documentation or contact someone familiar with it. For example on
some Redhat-based GNU/Linux distributions, the static C library package can
be installed with this command:

    $ sudo yum install glibc-static

2) If you have 'libc.a' and 'sys/cdefs.h', but in a non-standard location (for
example in '/PATH/TO/STATIC/LIBC/libc.a' and
'/PATH/TO/SYS/CDEFS_H/sys/cdefs.h'), please run the commands below, then
re-configure the project to fix this problem.

    $ export LDFLAGS="-L/PATH/TO/STATIC/LIBC \$LDFLAGS"
    $ export CPPFLAGS="-I/PATH/TO/SYS/CDEFS_H \$LDFLAGS"
_______________________________________________________

EOF
        fi
    fi

    # Print a warning if GCC is not meant to be built.
    if [ x"$gccwarning" = x1 ]; then
        cat <<EOF

PLEASE SEE THE WARNINGS ABOVE.

Since GCC is pretty low-level, this configuration script will continue in 5
seconds and use your system's C compiler (it won't build a custom GCC). But
please consider installing the necessary package(s) to complete your C
compiler, then re-run './project configure'.

The configuration will continue in $pausesec seconds. To avoid the
pause on such messages use the '--no-pause' option.

EOF
        sleep $pausesec
    fi
    elapsed_time_from_prev_step compiler-linkable-static
fi





# Fortran compiler
# ----------------
#
# If GCC is ultimately build within the project, the user won't need to
# have a fortran compiler: we'll build it internally for high-level
# programs with GCC. However, when the host C compiler is to be used, the
# user needs to have a Fortran compiler available.
if [ $built_container = 0 ] && [ $host_cc = 1 ]; then

    # If a Fortran compiler is necessary, see if 'gfortran' exists and can
    # be used.
    if [ "x$need_gfortran" = "x1" ]; then

        # First, see if 'gfortran' exists.
        hasfc=0;
        if type gfortran > /dev/null 2>/dev/null; then hasfc=1; fi
        if [ $hasfc = 0 ]; then
            cat <<EOF
______________________________________________________
!!!!!!!      Fortran Compiler NOT FOUND        !!!!!!!

This project requires a Fortran compiler. However, the project won't/can't
build its own GCC on this system (GCC also builds the 'gfortran' Fortran
compiler). Please install 'gfortran' using your operating system's package
manager, then re-run this configure script to continue the configuration.

Currently the only Fortran compiler we check is 'gfortran'. If you have a
Fortran compiler that is not checked, please get in touch with us (with the
form below) so we add it:

  https://savannah.nongnu.org/support/?func=additem&group=reproduce
______________________________________________________

EOF
            exit 1
        fi

        # Then, see if the Fortran compiler works
        testsourcef=$compilertestdir/test.f
        echo; echo; echo "Checking host Fortran compiler...";
        echo "      PRINT *, \"... Fortran Compiler works.\"" \
             > $testsourcef
        echo "      END" >> $testsourcef
        if gfortran $testsourcef -o$testprog && $testprog; then
            rm $testsourcef $testprog
        else
            rm $testsourcef
            cat <<EOF

______________________________________________________
!!!!!!!     Fortran compiler doesn't work      !!!!!!!

Host Fortran compiler ('gfortran') can't build a simple program.

A working Fortran compiler is necessary for this project. Please use the
error message above to find a good solution in your operating system and
re-run the project configuration.

If you can't find a solution, please send the error message above to the
link below and we'll try to help

https://savannah.nongnu.org/support/?func=additem&group=reproduce
______________________________________________________

EOF
            exit 1
        fi
    fi
    elapsed_time_from_prev_step compiler-fortran
fi





# See if the linker accepts -Wl,-rpath-link
# -----------------------------------------
#
# '-rpath-link' is used to write the information of the linked shared
# library into the shared object (library or program). But some versions of
# LLVM's linker don't accept it an can cause problems.
#
# IMPORTANT NOTE: This test has to be done **AFTER** the definition of
# 'instdir', otherwise, it is going to be used as an empty string.
if [ $built_container = 0 ]; then
   cat > $testsource <<EOF
#include <stdio.h>
#include <stdlib.h>
int main(void) {return EXIT_SUCCESS;}
EOF
   if $CC $testsource -o$testprog -Wl,-rpath-link 2>/dev/null \
          > /dev/null; then
       export rpath_command="-Wl,-rpath-link=$instdir/lib"
   else
       export rpath_command=""
   fi

   # Delete the temporary directory for compiler checking.
   rm -f $testprog $testsource
   rm -r $compilertestdir
   elapsed_time_from_prev_step compiler-rpath
fi





# Paths needed by the host compiler (only for 'basic.mk')
# -------------------------------------------------------
#
# At the end of the basic build, we need to build GCC. But GCC will build
# in multiple phases, making its own simple compiler in order to build
# itself completely. The intermediate/simple compiler doesn't recognize
# some system specific locations like '/usr/lib/ARCHITECTURE' that some
# operating systems use. We thus need to tell the intermediate compiler
# where its necessary libraries and headers are.
if [ $built_container = 0 ]; then
    if [ x"$sys_library_path" != x ]; then
        if [ x"$LIBRARY_PATH" = x ]; then
            export LIBRARY_PATH="$sys_library_path"
        else
            export LIBRARY_PATH="$LIBRARY_PATH:$sys_library_path"
        fi
        if [ x"$CPATH" = x ]; then
            export CPATH="$sys_cpath"
        else
            export CPATH="$CPATH:$sys_cpath"
        fi
    fi
    elapsed_time_from_prev_step compiler-paths
fi





# Inform the user
# ---------------
#
# Print some basic information so the user gets a feeling of what is going
# on and is prepared on what will happen next.
if [ $quiet = 0 ]; then
    cat <<EOF

-----------------------------
Project's local configuration
-----------------------------

Below, some basic local settings will be requested to start building
Maneage on this system (if they haven't been specified on the
command-line). This includes the top-level directories that Maneage will
use on your system. Most are only optional and you can simply press ENTER,
without giving any value (in this case, Maneage will download the necessary
components from pre-defined webpages). It is STRONGLY recommended to read
the description above each question before answering it.

EOF
fi




# Previous configuration
# ----------------------
#
# 'LOCAL.conf' is the top-most local configuration for the project. At this
# point, if a LOCAL.conf exists within the '.build' symlink, we use it
# (instead of asking the user to interactively specify it).
rewritelconfig=yes
lconf=.build/software/config/LOCAL.conf
if [ -f $lconf ]; then
    if [ $existing_conf = 1 ]; then
        rewritelconfig=no;
    fi
fi

# Make sure the group permissions satisfy the previous configuration (if it
# exists and we don't want to re-write it).
if [ $rewritelconfig = no ]; then
    oldgroupname=$(awk '/GROUP-NAME/ {print $3; exit 0}' $lconf)
    if [ "x$oldgroupname" = "x$maneage_group_name" ]; then
        just_a_place_holder_to_avoid_not_equal_test=1;
    else
        echo "-----------------------------"
        echo "!!!!!!!!    ERROR    !!!!!!!!"
        echo "-----------------------------"
        if [ "x$oldgroupname" = x ]; then
            status="NOT configured for groups"
            confcommand="./project configure"
        else
            status="configured for '$oldgroupname' group"
            confcommand="./project configure --group=$oldgroupname"
        fi
        echo "Project was previously $status!"
        echo "Either enable re-write of this configuration file,"
        echo "or re-run this configuration like this:"
        echo
        echo "   $confcommand"; echo
        exit 1
    fi

    # Report timing of this step if necessary.
    elapsed_time_from_prev_step LOCAL-and-group-check
fi





# Build directory
# ---------------
currentdir="$(pwd)"
if [ $rewritelconfig = yes ]; then
    cat <<EOF

===============
Build directory
===============

The project's "source" (this directory) and "build" directories are treated
separately. This greatly helps in managing the many intermediate files that
are created during the build. The intermediate build files don't need to be
archived or backed up: you can always re-build them with the contents of
the source directory. The build directory also needs a fairly large amount
of free space (at least several gigabytes), while the source directory (all
plain text, ignoring the .git directory if you have it) will usually be a
megabyte or less.

The link '.build' (a symbolic link to the build directory) will be created
during this configuration. It can help encourage you to set the actual
build directory to a very different path to that of the source (the build
directory should be considered as a large volume directory of throwaway
space that can be casually deleted), while making it easy to access from
here without having to remember the particular path.

--- CAUTION ---
Do not choose any directory under the top source directory (this
directory). The build directory cannot be a subdirectory of the source.
---------------

Build directory:
  - Must be writable by running user.
  - Not a sub-directory of the source directory.
  - No meta-characters in name: SPACE ! ' @ # $ % ^ & * ( ) + ;

EOF
    bdir=
    junkname=pure-junk-974adfkj38
    while [ x"$bdir" = x ]
    do
        # Ask the user (if not already set on the command-line: 'build_dir'
        # comes from the 'project' script).
        if [ x"$build_dir" = x ]; then
            if read -p"Please enter the top build directory: " build_dir;
            then
                just_a_place_holder_to_avoid_not_equal_test=1;
            else
                printf "ERROR: shell is in non-interactive-mode and no "
                printf "build directory specified. The build directory "
                printf "(described above) is mandatory, configuration "
                printf "can't continue. Please use '--build-dir' to "
                printf "specify a build directory non-interactively"
                exit 1
            fi
        fi

        # If it exists, see if we can write in it. If not, try making it.
        if [ -d "$build_dir" ]; then
            if echo "test" > "$build_dir"/$junkname ; then
                rm -f "$build_dir"/$junkname
                instring="the already existing"
                bdir="$(absolute_dir "$build_dir")"
            else
                echo " ** Can't write in '$build_dir'";
            fi
        else
            if mkdir "$build_dir" 2> /dev/null; then
                instring="the newly created"
                bdir="$(absolute_dir "$build_dir")"
            else
                echo " ** Can't create '$build_dir'";
            fi
        fi

        # If it is given, make sure it isn't a subdirectory of the source
        # directory.
        if ! [ x"$bdir" = x ]; then
            if echo "$bdir/" \
                    | grep '^'"$currentdir/" 2> /dev/null > /dev/null; then

                # If it was newly created, it will be empty, so delete it.
                if ! [ "$(ls -A $bdir)" ]; then rm --dir "$bdir"; fi

                # Inform the user that this is not acceptable and reset
                # 'bdir'.
                bdir=
                printf " ** The build-directory cannot be under the "
                printf "source-directory."
            fi
        fi

        # If things are fine so far, make sure it does not contain a space
        # or other meta-characters which can cause problems during software
        # building.
        if ! [ x"$bdir" = x ]; then
            hasmeta=0;
            case $bdir in *['!'\@\#\$\%\^\&\*\(\)\+\;\ ]* ) hasmeta=1 ;;
            esac
            if [ $hasmeta = 1 ]; then

                # If it was newly created, it will be empty, so delete it.
                if ! [ "$(ls -A "$bdir")" ]; then rm --dir "$bdir"; fi

                # Inform the user and set 'bdir' to empty again.
                bdir=
                printf " ** Build directory should not contain "
                printf "meta-characters (like SPACE, %, \$, !, ;, or "
                printf "parenthesis, among others): they can interrup "
                printf "the build for some software."
            fi
        fi

        # If everything is still fine so far, see if we're able to
        # manipulate file permissions in the directory's filesystem and if
        # so, see if there is atleast 5GB free space.
        if ! [ x"$bdir" = x ]; then
            if ! $(check_permission "$bdir"); then
                # Unable to handle permissions well
                bdir=
                printf " ** File permissions can not be modified in "
                printf "this directory"
            else
                # Able to handle permissions, now check for 5GB free space
                # in the given partition (note that the number is in units
                # of 1024 bytes). If this is not the case, print a warning.
                if $(free_space_warning 5000000 "$bdir"); then
                    cat <<EOF

_______________________________________________________
!!!!!!!!!!!!            Warning            !!!!!!!!!!!!

Less than 5GB free space in '$bdir'. We recommend choosing another
partition. Note that the software environment alone will take roughly
4.5GB, so if your datasets are large, it will fill up very soon.

The configuration will continue in $pausesec seconds. To avoid the
pause on such messages use the '--no-pause' option.

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

EOF
                    sleep $pausesec
                fi
            fi
        fi

        # If the build directory was good, the loop will stop, if not,
        # reset 'build_dir' to blank, so it continues asking for another
        # directory and let the user know that they must select a new
        # directory.
        if [ x"$bdir" = x ]; then
            build_dir=
            echo " ** Please select another directory."
            echo ""
        else
            # Set the '.build' and '.local' symbolic links (and delete
            # possibly existing symbolic links). These commands are also
            # present in the top-level 'project' script, but they are only
            # invoked when '--build-dir' is called. When it is not called
            # (the user wants to insert the directories interactively: the
            # scenario here), the links need to be created from
            # scratch. Furthermore, in case the given directory to
            # '--build-dir' has problems (fails to pass the sanity checks
            # above), the symbolic links also need to be recreated.
            rm -f .build .local
            ln -s $bdir .build
            ln -s $bdir/software/installed .local

            # Inform the user
            echo " -- Build directory set to ($instring): '$bdir'"
        fi
    done

    # Report timing if necessary
    elapsed_time_from_prev_step build-dir

# The directory should be extracted from the existing LOCAL.conf, not from
# the command-line or in interactive mode.
else

    # Read the build directory from existing configuration file. It is
    # assumed that 'LOCAL.conf' is created by this script (above the
    # 'else') and that all the sanity checks there have already been
    # applied. We'll just check if it is empty or not.
    bdir=$(awk '$1=="BDIR" {print $3}' $lconf)
    if [ x"$bdir" = x ]; then
        printf "$scriptname: no value to 'BDIR' of '$lconf'. Please run "
        printf "the project configuration again, but without "
        printf "'--existing-conf' (or '-e')"
        exit 1
    fi
fi





# Input directory
# ---------------
if [ x"$input_dir" = x ]; then indir="$optionaldir"
else                           indir="$input_dir"
fi
if [ $rewritelconfig = yes ]; then
    cat <<EOF

----------------------------------
(OPTIONAL) Input dataset directory
----------------------------------

This project needs the dataset(s) listed in the following file:

      reproduce/analysis/config/INPUTS.conf

If you already have a copy of them on this system, please specify the
directory hosting them on this system. If they aren't present, they will be
downloaded automatically when necessary.

NOTE I: This directory is optional. If not given, or if the files can't be
found inside it, any necessary file will be downloaded directly in the
build directory and used.

NOTE II: If a directory is given, it will be used as read-only. Nothing
will be written into it, so no writing permissions are necessary.

TIP: If you have these files in multiple directories on your system and
don't want to make duplicates, you can create symbolic links to them and
put those symbolic links in the given top-level directory.

EOF
    # In case an input directory is not given, ask the user interactively.
    if [ x"$input_dir" = x ]; then

        # Read the input directory if interactive mode is enabled.
        if read -p"(OPTIONAL) Input datasets directory ($indir): " \
                inindir; then
            just_a_place_holder_to_avoid_not_equal_test=1;
        else
            cat <<EOF
______________________________________________________
!!!!!!!!!!!!!!!        Warning        !!!!!!!!!!!!!!!!

WARNING: interactive-mode seems to be disabled! If you have a local copy of
the inputs, use '--input-dir'. Otherwise, all the data will be downloaded.

The configuration will continue in $pausesec seconds. To avoid the
pause on such messages use the '--no-pause' option.

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

EOF
            sleep $pausesec
        fi
    else  # An input directory was given.
        inindir="$input_dir"
    fi

    # If the given string is not empty, write it in 'indir'.
    if [ x$inindir != x ]; then
        indir="$(absolute_dir "$inindir")"
        echo " -- Using '$indir'"
    fi

    # Report timing if necessary.
    elapsed_time_from_prev_step input-dir

# The directory should be extracted from the existing LOCAL.conf, not from
# the command-line or in interactive mode; similar to 'bdir' above.
else
    indir=$(awk '$1=="INDIR" {print $3}' $lconf)
fi






# Dependency tarball directory
# ----------------------------
if [ x"$software_dir" = x ]; then ddir=$optionaldir
else                              ddir=$software_dir
fi
if [ $rewritelconfig = yes ]; then

    # Print information.
    cat <<EOF

---------------------------------------
(OPTIONAL) Software tarball directory
---------------------------------------

To ensure an identical build environment, the project will use its own
build of the programs it needs. Therefore the tarball of the relevant
programs are necessary.

If you don't specify any directory here, or it doesn't contain the tarball
of a dependency, it is necessary to have an internet connection because the
project will download the tarballs it needs automatically.

EOF

    # Ask the user for the software directory if it is not given as an
    # option.
    if [ x"$software_dir" = x ]; then
        if read -p"(OPTIONAL) Directory of dependency tarballs ($ddir): " \
                tmpddir; then
            just_a_place_holder_to_avoid_not_equal_test=1;
        else
            cat <<EOF
______________________________________________________
!!!!!!!!!!!!!!!        Warning        !!!!!!!!!!!!!!!!

WARNING: interactive-mode seems to be disabled! If you have a local copy of
the software source tarballs, use '--software-dir'. Otherwise, all the
necessary tarballs will be downloaded.

The configuration will continue in $pausesec seconds. To avoid the
pause on such messages use the '--no-pause' option.

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

EOF
            sleep $pausesec
        fi
    else
        tmpddir="$software_dir"
    fi

    # If given, write the software directory.
    if [ x"$tmpddir" != x ]; then
        ddir="$(absolute_dir "$tmpddir")"
        echo " -- Using '$ddir'"
    fi

# The directory should be extracted from the existing LOCAL.conf, not from
# the command-line or in interactive mode; similar to 'bdir' above.
else
    indir=$(awk '$1=="DEPENDENCIES-DIR" {print $3}' $lconf)
fi
elapsed_time_from_prev_step software-dir





# Downloader
# ----------
#
# After this script finishes, we will have both Wget and cURL for
# downloading any necessary dataset during the processing. However, to
# complete the configuration, we may also need to download the source code
# of some necessary software packages (including the downloaders). So we
# need to check the host's available tool for downloading at this step.
if [ $rewritelconfig = yes ]; then
    if type wget > /dev/null 2>/dev/null; then

        # 'which' isn't in POSIX, so we are using 'command -v' instead.
        name=$(command -v wget)

        # See if the host wget has the '--no-use-server-timestamps' option
        # (for example wget 1.12 doesn't have it). If not, we'll have to
        # remove it. This won't affect the analysis of Maneage in anyway,
        # its just to avoid re-downloading if the server timestamps are
        # bad; at the worst case, it will just cause a re-download of an
        # input software source code (for data inputs, we will use our own
        # wget that has this option).
        tsname="no-use-server-timestamps"
        tscheck=$(wget --help | grep $tsname || true)
        if [ x"$tscheck" = x ]; then wgetts=""
        else                         wgetts="--$tsname";
        fi

        # By default Wget keeps the remote file's timestamp, so we'll have
        # to disable it manually.
        downloader="$name $wgetts -O";
    elif type curl > /dev/null 2>/dev/null; then
        name=$(command -v curl)

        # - cURL doesn't keep the remote file's timestamp by default.
        # - With the '-L' option, we tell cURL to follow redirects.
        downloader="$name -L -o"
    else
        cat <<EOF

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!         Warning        !!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

Couldn't find GNU Wget, or cURL on this system. These programs are used for
downloading necessary programs and data if they aren't already present (in
directories that you can specify with this configure script). Therefore if
the necessary files are not present, the project will crash.

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

EOF
        downloader="no-downloader-found"
    fi;

# The downloader should be extracted from the existing LOCAL.conf.
else
    # The value will be a command (including white spaces), so we will read
    # all the "fields" from the third to the end.
    downloader=$(awk '$1=="DOWNLOADER" { for(i=3; i<NF; i++) \
                                           printf "%s ", $i; \
                                         printf "%s", $NF }' $lconf)

    if [ x"$downloader" = x ]; then
        printf "$scriptname: no value to 'DOWNLOADER' of '$lconf'. "
        printf "Please run the project configuration again, but "
        printf "without '--existing-conf' (or '-e')"
        exit 1
    fi
fi
elapsed_time_from_prev_step downloader





# Libraries necessary for the system's shell
# ------------------------------------------
#
# In some cases (mostly the programs that Maneage doesn't yet build by
# itself), the programs may call the system's shell, not Maneage's
# shell. After we close-off the system environment from Maneage, this will
# cause a crash! To avoid such cases, we need to find the locations of the
# libraries that the shell needs and temporarily add them to the library
# search path.
#
# About the 'grep -v "(0x[^)]*)"' term (from bug 66847, see [1]): On some
# systems [2], the output of 'ldd /bin/sh' includes a line for the vDSO [3]
# that is different to the formats that are assumed, prior to this commit,
# by the algorithm in 'configure.sh' when evaluating the variable
# 'sys_library_sh_path'. This leads to a fatal syntax error in (at least)
# 'ncurses', because the option using 'sys_library_sh_path' contains an
# unquoted RAM address in parentheses.  Even if the address were quoted, it
# would still be incorrect. This 'grep command excludes candidate host path
# strings that look like RAM addresses to address the problem.
#
# [1] https://savannah.nongnu.org/bugs/index.php?66847
# [2] https://stackoverflow.com/questions/34428037/how-to-interpret-the-output-of-the-ldd-program
# [3] man vdso
if [ $built_container = 0 ]; then
    if [ x"$on_mac_os" = xyes ]; then
        sys_library_sh_path=$(otool -L /bin/sh \
                                  | awk '/\/lib/{print $1}' \
                                  | sed 's#/[^/]*$##' \
                                  | sort \
                                  | uniq \
                                  | awk '{if (NR==1) printf "%s",  $1; \
                                          else       printf ":%s", $1}')
    else
        sys_library_sh_path=$(ldd /bin/sh \
                                  | awk '{if($3!="") print $3}' \
                                  | sed 's#/[^/]*$##' \
                                  | grep -v "(0x[^)]*)" \
                                  | sort \
                                  | uniq \
                                  | awk '{if (NR==1) printf "%s",  $1; \
                                          else       printf ":%s", $1}')
    fi
    elapsed_time_from_prev_step sys-library-sh-path
fi





# When no local configuration existed, write the parameters into the local
# configuration file.
sdir=$bdir/software
sconfdir=$sdir/config
if ! [ -d "$sdir" ]; then mkdir "$sdir"; fi
if ! [ -d "$sconfdir" ]; then mkdir "$sconfdir"; fi
if [ $rewritelconfig = yes ]; then

    # Put the basic comments at the top of the file.
    create_file_with_notice $lconf

    # Write the values.
    lconfin=$cdir/LOCAL.conf.in
    sed -e's|@bdir[@]|'"$bdir"'|' \
        -e's|@indir[@]|'"$indir"'|' \
        -e's|@ddir[@]|'"$ddir"'|' \
        -e's|@sys_cpath[@]|'"$sys_cpath"'|' \
        -e's|@downloader[@]|'"$downloader"'|' \
        -e's|@groupname[@]|'"$maneage_group_name"'|' \
        -e's|@sys_library_sh_path[@]|'"$sys_library_sh_path"'|' \
        $lconfin >> $lconf
fi
elapsed_time_from_prev_step LOCAL-write





# Project's top-level built software directories
# ----------------------------------------------
#
# These directories are possibly needed by many steps of process, so to
# avoid too many directory dependencies throughout the software and
# analysis Makefiles (thus making them hard to read), we are just building
# them here
tardir="$sdir"/tarballs
instdir="$sdir"/installed
tmpblddir="$sdir"/build-tmp

# Second-level directories.
instlibdir="$instdir"/lib
instbindir="$instdir"/bin
verdir="$instdir"/version-info

# Sub-directories of version-info
itidir="$verdir"/tex
ictdir="$verdir"/cite
ipydir="$verdir"/python
ibidir="$verdir"/proglib
ircrandir="$verdir"/r-cran
if [ $built_container = 0 ]; then

    # Top-level directories.
    if ! [ -d "$tardir" ]; then mkdir "$tardir"; fi
    if ! [ -d "$instdir" ]; then mkdir "$instdir"; fi

    # Second-level directories.
    if ! [ -d "$verdir" ]; then mkdir "$verdir"; fi
    if ! [ -d "$instbindir" ]; then mkdir "$instbindir"; fi

    # Sub-directories of version-info
    if ! [ -d "$itidir" ]; then mkdir "$itidir"; fi
    if ! [ -d "$ictdir" ]; then mkdir "$ictdir"; fi
    if ! [ -d "$ipydir" ]; then mkdir "$ipydir"; fi
    if ! [ -d "$ibidir" ]; then mkdir "$ibidir"; fi
    if ! [ -d "$ircrandir" ]; then mkdir "$ircrandir"; fi

    # Some software install their libraries in '$(idir)/lib64'. But all
    # other libraries are in '$(idir)/lib'. Since Maneage's build is only
    # for a single architecture, we can set the '$(idir)/lib64' as a
    # symbolic link to '$(idir)/lib' so all the libraries are always
    # available in the same place.
    if ! [ -d "$instlibdir" ]; then mkdir "$instlibdir"; fi
    ln -fs "$instlibdir" "$instdir"/lib64

    # Wrapper over Make as a single command so it does not default to
    # '/bin/sh' during installation (needed by some programs like CMake).
    makewshell="$instbindir/make-with-shell"
    if ! [ -f "$makewshell" ]; then
        echo "$instbindir/make SHELL=$instbindir/bash \$@" > $makewshell
        chmod +x $makewshell
    fi

    # Report the execution time of this step.
    elapsed_time_from_prev_step subdirectories-of-build
fi





# Software building directory (possibly in RAM)
# ---------------------------------------------
#
# Building the software for the project will need the creation of many
# small temporary files that will ultimately be deleted. To avoid harming
# HDDs/SSDs and improve speed, it is therefore better to build them in the
# RAM when possible. The RAM of most systems today (>8GB) is large enough
# for the parallel building of the software.
#
# Set the top-level shared memory location. Currently there is only one
# standard location (for GNU/Linux OSs), so doing this check here and the
# main job below may seem redundant. However, it is written separately from
# the main code below because later, we expect to add more possible
# mounting locations (for other OSs).
if [ $built_container = 0 ]; then
    if [ -d /dev/shm ]; then     shmdir=/dev/shm
    else                         shmdir=""
    fi

    # If a shared memory mounted directory exists and has the necessary
    # conditions, set that directory to build software.
    if [ x"$shmdir" != x ]; then

        # Make sure it has enough space.
        needed_space=2000000
        available_space=$(df "$shmdir" | awk 'NR==2{print $4}')
        if [ $available_space -gt $needed_space ]; then

            # Set the Maneage-specific directory within the shared
            # memory. We'll use the names of the two parent directories to
            # the current/running directory, separated by a '-' instead of
            # '/'. We'll then appended that with the user's name (in case
            # multiple users may be working on similar project names).
            #
            # Maybe later, we can use something like 'mktemp' to add random
            # characters to this name and make it unique to every run (even
            # for a single user).
            dirname=$(pwd | sed -e's/\// /g' \
                          | awk '{l=NF-1; printf("%s-%s", $l, $NF)}')
            tbshmdir="$shmdir"/"$dirname"-$(whoami)

            # Try to make the directory if it does not yet exist. A failed
            # directory creation will be tested for a few lines later, when
            # testing for the existence and executability of a test file.
            if ! [ -d "$tbshmdir" ]; then (mkdir "$tbshmdir" || true); fi

            # Some systems may protect '/dev/shm' against the right to
            # execute programs by ordinary users. We thus need to check
            # that the device allows execution within this directory by
            # this user.
            shmexecfile="$tbshmdir"/shm-execution-check.sh
            rm -f $shmexecfile  # We also don't want any existing flags.

            # Create the file to be executed, but do not fail fatally if it
            # cannot be created. We will check a few lines later if the
            # file really exists.
            (cat > "$shmexecfile" <<EOF || true)
#!/bin/sh
a=b
EOF

            # If the file was successfully created, then make the file
            # executable and see if it runs. If not, set 'tbshmdir' to an
            # empty string so it is not used in later steps.  In any case,
            # delete the temporary file afterwards.
            #
            # We aren't adding '&> /dev/null' after the execution command
            # because it can produce false failures randomly on some
            # systems.
            if [ -e "$shmexecfile" ]; then

                # Add the executable flag.
                chmod +x "$shmexecfile"

                # The following line tries to execute the file.
                if "$shmexecfile"; then
                    # Successful execution. The colon is a "no-op" (no
                    # operation) shell command.
                    :
                else
                    tbshmdir=""
                fi
                rm "$shmexecfile"
            else
                tbshmdir=""
            fi
        fi
    else
        tbshmdir=""
    fi

    # If a shared memory directory was created, set the software building
    # directory to be a symbolic link to it. Otherwise, just build the
    # temporary build directory under the project's build directory.
    #
    # If it is a link, we need to empty its contents first, then itself.
    if [ -d "$tmpblddir" ]; then empty_build_tmp; fi

    # Now that we are sure it doesn't exist, we'll make it (either as a
    # directory or as a symbolic link).
    if [ x"$tbshmdir" = x ]; then mkdir "$tmpblddir";
    else                          ln -s "$tbshmdir" "$tmpblddir";
    fi

    # Report the time this step took.
    elapsed_time_from_prev_step temporary-software-building-dir
fi





# Inform the user that the build process is starting
# -------------------------------------------------
#
# Everything is ready, let the user know that the building is going to
# start.
if [ $quiet = 0 ]; then
    cat <<EOF

-------------------------
Building dependencies ...
-------------------------

Necessary dependency programs and libraries will be installed in

  $sdir/installed

NOTE: the built software will NOT BE INSTALLED in standard places of your
OS (so no root access is required). They are only for local usage by this
project.

TIP: you can see which software are being installed at every moment with
the following command. See "Inspecting status" section of
'README-hacking.md' for more. In short, run it in another terminal while
the project is being configured.

  $ ./project --check-config

Project's configuration will continue in $tsec seconds. To avoid the pause
on such messages use the '--no-pause' option.

-------------------------

EOF
    sleep $pausesec
fi





# Number of threads to build software
# -----------------------------------
#
# If the user hasn't manually specified the number of threads, see if we
# can deduce it from the host:
#  - On systems with GNU Coreutils we have 'nproc'.
#  - On BSD-based systems (for example FreeBSD and macOS), we have a
#    'hw.ncpu' in the output of 'sysctl'.
#  - When none of the above work, just set the number of threads to 1.
#
# This check is also used in 'reproduce/software/shell/docker.sh'.
if [ $built_container = 0 ]; then
    if [ $jobs = 0 ]; then
        if type nproc > /dev/null 2> /dev/null; then
            numthreads=$(nproc --all);
        else
            numthreads=$(sysctl -a | awk '/^hw\.ncpu/{print $2}')
            if [ x"$numthreads" = x ]; then numthreads=1; fi
        fi
    else
        numthreads=$jobs
    fi
    elapsed_time_from_prev_step num-threads
fi





# Find Zenodo URL for software downloading
# ----------------------------------------
#
# All free-software source tarballs that are potentially used in Maneage
# are also archived in Zenodo with a certain concept-DOI. A concept-DOI is
# a Zenodo terminology, meaning a fixed DOI of the project (that can have
# many sub-DOIs for different versions). By default, the concept-DOI points
# to the most recently uploaded version. However, the concept-DOI itself is
# not directly usable for downloading files. The concept-DOI will just take
# us to the top webpage of the most recent version of the upload.
#
# The problem is that as more software are added (as new Zenodo versions),
# the most recent Zenodo-URL that the concept-DOI points to, also
# changes. The most reliable solution was found to be the tiny script below
# which will download the DOI-resolved webpage, and extract the Zenodo-URL
# of the most recent version from there (using the 'coreutils' tarball as
# an example, the directory part of the URL for all the other software are
# the same). This is not done if the options '--debug' or `--offline` are
# used.
zenodourl=""
user_backup_urls=""
zenodocheck="$bdir"/software/zenodo-check.html
if [ $built_container = 0 ]; then
    if [ x$debug = x ] && [ x$offline = x ]; then
        if $downloader $zenodocheck \
                       https://doi.org/10.5281/zenodo.3883409; then
            zenodourl=$(sed -n -e'/coreutils/p' $zenodocheck \
                            | sed -n -e'/http/p' \
                            | tr ' ' '\n' \
                            | grep http \
                            | sed -e 's/href="//' -e 's|/coreutils| |' \
                            | awk 'NR==1{print $1}')
        fi
    fi
    rm -f $zenodocheck

    # Add the Zenodo URL to the user's given back software URLs. Since the
    # user can specify 'user_backup_urls' (not yet implemented as an option
    # in './project'), we'll give preference to their specified servers,
    # then add the Zenodo URL afterwards.
    user_backup_urls="$user_backup_urls $zenodourl"
    elapsed_time_from_prev_step zenodo-url
fi





# Corrections for debugging mode
# ------------------------------
#
# If the user wants to debug the software configuration, they are usually
# focused on the building of the single problematic software. Therefore,
# the default multi-threaded execution of Make with the '--keep-going'
# option are very annoying and can even hide important warnings. Recall
# that with '--keep-going', Make will continue building other targets, even
# if one target fails. When the user runs './project configure --debug',
# the 'debug' variable will not be empty and this mode will be activated.
if [ x$debug = x ]; then
  keepgoing="--keep-going"
else
  jobs=1
  numthreads=1
  keepgoing=""
fi





# Core software
# -------------
#
# Here we build the core tools that 'basic.mk' depends on: Lzip
# (compression program), GNU Make (that 'basic.mk' is written in), Dash
# (minimal Bash-like shell) and Flock (to lock files and enable serial
# operations where necessary: mostly in download).
export on_mac_os
if [ $quiet = 0 ]; then echo "Building/validating software: pre-make"; fi
./reproduce/software/shell/pre-make-build.sh \
    "$bdir" "$ddir" "$downloader" "$user_backup_urls"
elapsed_time_from_prev_step make-software-pre-make





# Basic software
# --------------
#
# Having built the core tools, we are now ready to build GCC and all its
# dependencies (the "basic" software).
if [ $quiet = 0 ]; then echo "Building/validating software: basic"; fi
.local/bin/make $keepgoing -f reproduce/software/make/basic.mk \
     sys_library_sh_path=$sys_library_sh_path \
     user_backup_urls="$user_backup_urls" \
     sys_library_path=$sys_library_path \
     rpath_command=$rpath_command \
     static_build=$static_build \
     numthreads=$numthreads \
     needs_ldl=$needs_ldl \
     on_mac_os=$on_mac_os \
     host_cc=$host_cc \
     -j$numthreads
elapsed_time_from_prev_step make-software-basic





# High-level software
# -------------------
#
# Having our custom GCC in place, we can now build the high-level (science)
# software: we are using our custom-built 'env' to ensure that nothing from
# the host environment leaks into the high-level software environment.
if [ $quiet = 0 ]; then echo "Building/validating software: high-level"; fi
.local/bin/env -i HOME=$bdir \
               .local/bin/make $keepgoing \
               -f reproduce/software/make/high-level.mk \
               sys_library_sh_path=$sys_library_sh_path \
               user_backup_urls="$user_backup_urls" \
               sys_library_path=$sys_library_path \
               rpath_command=$rpath_command \
               all_highlevel=$all_highlevel \
               static_build=$static_build \
               numthreads=$numthreads \
               on_mac_os=$on_mac_os \
               sys_cpath=$sys_cpath \
               host_cc=$host_cc \
               offline=$offline \
               -j$numthreads
elapsed_time_from_prev_step make-software-high-level





# Make sure TeX Live installed successfully
# -----------------------------------------
#
# TeX Live is managed over the internet, so if there isn't any, or it
# suddenly gets cut, it can't be built. However, when TeX Live isn't
# installed, the project can do all its processing independent of it. It
# will just stop at the stage when all the processing is complete and it is
# only necessary to build the PDF.  So we don't want to stop the project's
# configuration and building if its not present.
if [ $built_container = 0 ]; then
    if [ -f $itidir/texlive-ready-tlmgr ]; then
        texlive_result=$(cat $itidir/texlive-ready-tlmgr)
    else
        texlive_result="NOT!"
    fi
    if [ x"$texlive_result" = x"NOT!" ]; then
        cat <<EOF

______________________________________________________
!!!!!!!!!!!!!!!        Warning        !!!!!!!!!!!!!!!!

TeX Live couldn't be installed during the configuration (probably because
there were downloading problems, or you used the '--offline' option). TeX
Live is only necessary in making the final PDF (which is only done after
all the analysis has been complete). It is not used at all during the
analysis.

Therefore, if you don't need the final PDF, and just want to do the
analysis, you can safely ignore this warning and continue.

If you later have internet access and would like to add TeX Live to your
project, then please delete the following two files:

    rm .local/version-info/tex/texlive-ready-tlmgr
    rm .build/software/tarballs/install-tl-unx.tar.gz

and re-run configure:

    ./project configure -e

The configuration will continue in $pausesec seconds. To avoid the pause on
such messages use the '--no-pause' option.

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

EOF
        sleep $pausesec
    fi
    elapsed_time_from_prev_step check-tex-installation
fi





# Software information the paper
# ------------------------------
#
# After everything is installed, we'll put all the names and versions in a
# human-readable paragraph and also prepare the BibTeX citation for the
# software.
prepare_name_version ()
{
    # First see if the (possible) '*' in the input arguments corresponds to
    # anything. Note that some of the given directories may be empty (no
    # software installed).
    hasfiles=0
    for f in $@; do
        if [ -f $f ]; then hasfiles=1; break; fi;
    done

    # If there are any files, merge all the names in a paragraph.
    if [ $hasfiles = 1 ]; then

        # Count how many names there are. This is necessary to identify the
        # last element.
        num=$(.local/bin/cat $@ \
                  | .local/bin/sed '/^\s*$/d' \
                  | .local/bin/wc -l)

        # Put them all in one paragraph, while sorting them, commenting any
        # possible underscores and removing blank lines.
        .local/bin/cat $@ \
            | .local/bin/sort \
            | .local/bin/sed -e's|_|\\_|' \
            | .local/bin/awk 'NF>0 { \
                  c++; \
                  if(c==1) \
                    { \
                      if('$num'==1) printf("%s", $0); \
                      else          printf("%s", $0); \
                    } \
                  else if(c=='$num') printf(" and %s\n", $0); \
                  else printf(", %s", $0) \
                }'
    fi
}

# Relevant files
pkgver=$sconfdir/dependencies.tex
pkgbib=$sconfdir/dependencies-bib.tex

# Build the software LaTeX source but only when not in a container.
if [ $built_container = 0 ]; then

    # Import the context/sentences for placing between the list of software
    # names during their acknowledgment.
    . $cdir/software_acknowledge_context.sh

    # Report the different software in separate contexts (separating Python
    # and TeX packages from the C/C++ programs and libraries).
    proglibs=$(prepare_name_version $verdir/proglib/*)
    pymodules=$(prepare_name_version $verdir/python/*)
    texpkg=$(prepare_name_version $verdir/tex/texlive)

    # Acknowledge these software packages in a LaTeX paragraph.
    .local/bin/echo "$thank_software_introduce " > $pkgver
    .local/bin/echo "$thank_progs_libs $proglibs. "   >> $pkgver
    if [ x"$pymodules" != x ]; then
        .local/bin/echo "$thank_python $pymodules. "   >> $pkgver
    fi
    .local/bin/echo "$thank_latex $texpkg. " >> $pkgver
    .local/bin/echo "$thank_software_conclude" >> $pkgver

    # Prepare the BibTeX entries for the used software (if there are any).
    hasentry=0
    bibfiles="$ictdir/*"
    for f in $bibfiles; do if [ -f $f ]; then hasentry=1; break; fi; done;

    # Fill it in with all the BibTeX entries in this directory. We'll just
    # avoid writing any comments (usually copyright notices) and also put an
    # empty line after each file's contents to make the output more readable.
    echo "" > $pkgbib # We don't want to inherit any pre-existing content.
    if [ $hasentry = 1 ]; then
        for f in $bibfiles; do
            awk '!/^%/{print} END{print ""}' $f >> $pkgbib
        done
    fi

    # Report the time that this operation took.
    elapsed_time_from_prev_step tex-macros
fi





# Report machine architecture (has to be final created file)
# ----------------------------------------------------------
#
# This is the final file that is created in the configuration phase: it is
# used by the high-level project script to verify that configuration has
# been completed. If any other files should be created in the final statges
# of configuration, be sure to add them before this.
#
# Since harware class might include underscore, it must be replaced with
# '\_', otherwise pdftex would complain and break the build process when
# doing ./project make.
if [ $built_container = 0 ]; then
    hw_class=$(uname -m)
    hwparam="$sconfdir/hardware-parameters.tex"
    hw_class_fixed="$(echo $hw_class | sed -e 's/_/\\_/')"
    .local/bin/echo "\\newcommand{\\machinearchitecture}{$hw_class_fixed}" \
                    > $hwparam
    .local/bin/echo "\\newcommand{\\machinebyteorder}{$byte_order}" \
                    >> $hwparam
    .local/bin/echo "\\newcommand{\\machineaddresssizes}{$address_sizes}" \
                    >> $hwparam
    elapsed_time_from_prev_step hardware-params
fi





# Clean up and final notice
# -------------------------
#
# The configuration is now complete. We just need to delete the temporary
# build directory and inform the user (if '--quiet' wasn't called) on the
# next step(s).
if [ -d $tmpblddir ]; then empty_build_tmp; fi
if [ $quiet = 0 ]; then

    # Suggest the command to use.
    if [ x$maneage_group_name = x ]; then
        buildcommand="./project make -j8"
    else
        buildcommand="./project make --group=$maneage_group_name -j8"
    fi

    # Print the message.
    cat <<EOF

----------------
The project and its environment are configured with no errors.

To change the configuration later, you can re-run './project configure' or
manually edit 'reproduce/software/config/LOCAL.conf'. Just be careful with
the build-directory: its location is hard-coded in the installed software
so if you change it manually, many of the project's software will crash. If
you have to use another built-directory, just re-configure a clean project
there.

Please run the following command to start the project.
(Replace '8' with the number of CPU threads on your system)

    $buildcommand

EOF
fi


# Total time
if [ $check_elapsed = 1 ]; then
    echo $chel_dsum | awk '{printf "Total:   %-6.2f [millisec]\n", $1}'
fi
