#!/usr/bin/env sh
#
# Necessary corrections in the un-packed source of programs to make them
# portable (for example to not use '/bin/sh').
#
# Usage: Run in top source directory (will work on all files within the
#        directory that it is run in ):
#   ./prep-source.sh /FULL/ADDRESS/TO/DESIRED/BIN
#
# Copyright (C) 2024-2026 Mohammad Akhlaghi <mohammad@akhlaghi.org>
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





# Abort the script in case of an error
set -e




# Read the first argument.
bindir="$1"
if [ x"$bindir" = x ]; then
    printf "$0: no argument (location of the 'bin/' directory "
    printf "containing the 'bash' executable)\n"
    exit 1
elif ! [ -d "$bindir" ]; then
    printf "$0: the directory given as the first argument ('$bindir')"
    printf "does not exist"
fi





# Find all the files that contain the '/bin/sh' string and correct them to
# Maneage's own Bash. We are using 'while read' to read the file names line
# by line. This is necessary to account file names that include the 'SPACE'
# character (happens in CMake for example!).
#
# Note that dates are important in the source directory (files depend on
# each other), so we should read the original date and after making. We are
# also not using GNU SED's '-i' ('--in-place') option because the host OS
# may not have GNU SED.
#
# Actual situation which prompted the addition of this step: a Maneage'd
# project (with GNU Bash 5.1.8 and Readline 8.1.1) was being built on a
# system where '/bin/sh' was GNU Bash 5.2.26 and had Readline 8.2.010. The
# newer version of Bash needed the newer Readline library function(s) that
# were not available in Maneage's Readline library. Therefore, as soon as
# the basic software were built and Maneage entered the creation of
# high-level software (where we completely close-off the host environment),
# Maneage crashed with the following '/bin/sh' error:
#
#   /bin/sh: symbol lookup error: /bin/sh: undefined symbol: rl_trim_arg_from_keyseq
#
# This lead to the discovery that through '/bin/sh' the host operating
# system was leaking into our closed Maneage environment which needs to be
# closed. This needs a source-level correction because '/bin/sh' is
# hard-coded in the source code of almost all programs (their build
# scripts); and in special programs like GNU Make, GNU M4 or CMake it is
# actually hardcoded in the source code (not just build scripts).
if [ -f "$bindir/bash" ]; then shpath="$bindir"/bash
else                           shpath="$bindir"/dash
fi

# On MacOS the syntax for 'stat' is a bit different, so if we are using the
# system one on mac we need a specific syntax. The one installed by maneage
# instead uses the ordinary Linux syntax.
if [ -f "$bindir/stat" ] || [ x"$on_mac_os" = xno ]; then
  format="--format %a"
else
  format="-f %OLp"
fi

# On MacOS 'touch' wants the time expressed according to ISO8601 with a
# precision up to the seconds. We then use 'sed' to remove the information
# regarding the timezone, as the format is not accepted by 'touch'.
# LCTYPE and LANG are also required on macos systems by sed.
grep -I -r -e'/bin/sh' $(pwd)/* \
    | sed -e's|:|\t|' \
    | awk 'BEGIN{FS="\t"}{print $1}' \
    | sort \
    | uniq \
    | while read filename; do \
         tmp="$filename".tmp; \
         origtimex="$(date -Iseconds -r "$filename")"; \
         origtime=$(echo $origtimex | sed 's/.\{6\}$//'); \
         origperm=$(stat $format "$filename"); \
         LC_CTYPE=C; LANG=C; \
         sed -e's|/bin/sh|'"$shpath"'|g' "$filename" > "$tmp"; \
         mv "$tmp" "$filename"; \
         chmod $origperm "$filename"; \
         touch -d"$origtime" "$filename"; \
         echo "Corrected /bin/sh in $filename"; \
      done
