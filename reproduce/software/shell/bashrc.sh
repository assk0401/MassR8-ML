# Bash startup file for better control of project environment.
#
# To have better control over the environment of each analysis step (Make
# recipe), besides having environment variables (directly included from
# Make), it may also be useful to have a Bash startup file (this file). All
# of the Makefiles set this file as the 'BASH_ENV' environment variable, so
# it is loaded into all the Make recipes within the project.
#
# The special 'PROJECT_STATUS' environment variable is defined in every
# top-level Makefile of the project. It defines the the state of the Make
# that is calling this script. It can have three values:
#
#    configure_basic
#    ---------------
#       When doing basic configuration, therefore the executed steps cannot
#       make any assumptions about the version of Bash (or any other
#       program). Therefore it is important for any step in this step to be
#       highly portable.
#
#    configure_highlevel
#    -------------------
#       When building the higher-level programs, so the versions of the
#       most basic tools are set and you may safely assume certain
#       features.
#
#    make
#    ----
#       When doing the project's analysis: all software have known
#       versions.
#
#    shell
#    -----
#       When the user has activated the interactive shell (with './project
#       shell').
#
#
# Copyright (C) 2019-2025 Mohammad Akhlaghi <mohammad@akhlaghi.org>
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





# Interactive mode settings. We don't want these within the pipeline
# because they are useless there (for example the introduction message or
# prompt) and can un-necessarily slow down the running jobs (recall that
# the shell is executed at the start of each recipe).
if [ x$PROJECT_STATUS = xshell ]; then

    # A small introductory message.
    echo "----------------------------------------------------------------------"
    echo "Welcome to the Maneage interactive shell for this project, running"
    echo " $(sh --version | awk 'NR==1')"
    echo
    echo "This shell's home directory is the project's build directory:"
    echo " HOME: $HOME"
    echo
    echo "This shell's startup file is in the project's source directory:"
    echo " $PROJECT_RCFILE"
    echo
    echo "To return to your host shell, run the 'exit' command."
    echo "----------------------------------------------------------------------"

    # To activate colors in generic commands.
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'

    # Add the Git branch information to the command prompt only when Git is
    # present. Also set the command-prompt color to purple for normal users
    # and red when the root is running it.
    if git --version &> /dev/null; then
        parse_git_branch() {
	    git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
        }
    else
        parse_git_branch() { echo &> /dev/null; }
    fi
    if [ x$(whoami) = xroot ]; then
        export PS1="[\[\033[01;31m\]\u@\h \W\[\033[32m\]\$(parse_git_branch)\[\033[00m\]]# "
    else
        export PS1="[\[\033[01;35m\]maneage@\h \W\[\033[32m\]\$(parse_git_branch)\[\033[00m\]]$ "
    fi
fi
