#!/bin/bash

# Script to convert all files (tarballs in any format; just recognized
# by 'tar') within an 'odir' to a unified '.tar.lz' format.
#
# The inputs are assumed to be formatted with 'NAME_VERSION', and only for
# the names, we are currently assuming '.tar.*' (for the 'sed'
# command). Please modify/generalize accordingly.
#
# It will unpack the source in a certain empty directory with the
# 'tmpunpack' suffix, and rename the top directory to the requested format
# of NAME-VERSION also. So irrespective of the name of the top original
# tarball directory, the resulting tarball's top directory will have a name
# formatting of NAME-VERSION.
#
# Discussion: https://savannah.nongnu.org/task/?15699
#
# Copyright (C) 2022-2025 Mohammad Akhlaghi <mohammad@akhlaghi.org>
# Copyright (C) 2022-2025 Pedram Ashofteh Ardakani <pedramardakani@pm.me>
# Released under GNU GPLv3+

# Abort the script in case of an error.
set -e





# Default arguments
odir=
idir=
quiet=
basedir=$PWD
scriptname=$0


# The --help output
print_help() {
    cat <<EOF
Usage: $scriptname [OPTIONS]

Low-level script to create maneage-standard tarballs.
  -o, --output-dir         Target directory to write the packed tarballs.
                           Current: $odir
  -i, --input-dir          Directory containing original tarballs.
                           Current: $idir
  -q, --quiet              Suppress logging information. Only print the
                           final packed file and its sha512sum.
Maneage URL: https://maneage.org

Report bugs: https://savannah.nongnu.org/bugs/?group=reproduce
EOF
}





# Functions to check option values and complain if necessary.
on_off_option_error() {
    if [ x"$2" = x ]; then
        echo "$scriptname: '$1' doesn't take any values"
    else
        echo "$scriptname: '$1' (or '$2') doesn't take any values"
    fi
    exit 1
}

check_v() {
    if [ x"$2" = x ]; then
        cat <<EOF
$scriptname: option '$1' requires an argument. Try '$scriptname --help' for more information
EOF
        exit 1;
    fi
}

option_given_and_valid() {
    dirname="$1"
    optionlong="$2"
    optionshort="$3"
    if [ x"$dirname" = x ]; then
	cat <<EOF
$scriptname: no '--$optionlong' (or '-$optionshort') given: use this for identifying the directory containing the input tarballs
EOF
	exit 1
    else
	dirname=$(echo "$dirname" | sed 's|/$||'); # Remove possible trailing slash
	if [ ! -d "$dirname" ]; then
	    cat <<EOF
$scriptname: '$dirname' that is given to '--$optionlong' (or '-$optionshort') couldn't be opened
EOF
	    exit 1
	else
	    outdir=$(realpath $dirname)
	fi
    fi
    ogvout=$outdir
}





# Parse the arguments
while [ $# -gt 0 ]
do
    case $1 in
	# Input and Output directories
        -i|--input-dir)      idir="$2";                           check_v "$1" "$idir"; shift;shift;;
        -i=*|--input-dir=*)  idir="${1#*=}";                      check_v "$1" "$idir"; shift;;
        -i*)                 idir=$(echo "$1" | sed -e's/-i//');  check_v "$1" "$idir"; shift;;
        -o|--output-dir)     odir="$2";                           check_v "$1" "$odir"; shift;shift;;
        -o=*|--output-dir=*) odir="${1#*=}";                      check_v "$1" "$odir"; shift;;
        -o*)                 odir=$(echo "$1" | sed -e's/-o//');  check_v "$1" "$odir"; shift;;

	# Operating mode options
        -?|--help)        print_help; exit 0;;
        -'?'*|--help=*)   on_off_option_error --help -?;;
        -q|--quiet)       quiet=1; shift;;
        -q*|--quiet=*)    on_off_option_error --quiet -q;;
	*)  echo "$scriptname: unknown option '$1'"; exit 1;;
  esac
done





# Basic sanity checks
#
# Make sure the input and output directories are given. Also extract
# the absolute path to input and output directories and remove any
# possible trailing '/'. Working with a relative path is a great
# source of confusion and unwanted side-effects like moving/removing
# files by accident.
option_given_and_valid "$idir" "input-dir"  "i" && idir=$ogvout
option_given_and_valid "$odir" "output-dir" "o" && odir=$ogvout





# Unpack and pack all files in the '$idir'
# ----------------------------------------
allfiles=$(ls $idir | sort)

# Let user know number of tarballs if its not in quiet mode
if [ -z $quiet ]; then
    nfiles=$(ls $idir | wc -l)
    echo "Found $nfiles file(s) in '$idir/'"
fi

# Process all files
for f in $allfiles; do

    # Extract the name and version (while replacing any possible '_' with
    # '-' because some software separate name and version with '_').
    name=$(echo $(basename $f) \
	       | sed -e 's/.tar.*//' -e's/_/-/')

    # Skip previously packed files
    if [ -f $odir/$name.tar.lz ]; then

        # Print the info message if not in quiet mode
        if [ -z $quiet ]; then
            echo "$scriptname: $odir/$name.tar.lz: already present in output directory"
        fi

        # skip this file
        continue
    else

        # Print the info message if not in quiet mode
        if [ -z $quiet ]; then
            echo "$scriptname: processing '$idir/$f'"
        fi
    fi

    # Create a temporary directory name
    tmpdir=$odir/$name-tmpunpack

    # If the temporary directory exists, mkdir will throw an error. The
    # developer needs to intervene manually to fix the issue.
    mkdir $tmpdir





    # Move into the temporary directory
    # ---------------------------------
    #
    # The default output directory for all the following commands: $tmpdir
    cd $tmpdir

    # Unpack
    tar -xf $idir/$f

    # Make sure the unpacked tarball is contained within a directory with
    # the clean program name
    if [ ! -d "$name" ]; then
        mv * $name/
    fi

    # Put the current date on all the files because some packagers will not
    # add dates to their release tarballs, resulting in dates of the
    # Unix-time zero'th second (1970-01-01 at 00:00:00)!
    touch $(find "$name"/ -type f)

    # Pack with recommended options
    tar -c -Hustar --owner=root --group=root \
        -f $name.tar $name/
    lzip -9 $name.tar

    # Move the compressed file from the temporary directory to the target
    # output directory
    mv $name.tar.lz $odir/

    # Print the sha512sum along with the filename for a quick reference
    echo $(sha512sum $odir/$name.tar.lz)

    # Clean up the temporary directory
    rm -rf $tmpdir
done
