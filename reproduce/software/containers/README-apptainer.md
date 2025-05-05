# Maneage'd projects in Apptainer

Copyright (C) 2025-2025 Mohammad Akhlaghi <mohammad@akhlaghi.org>\
Copyright (C) 2025-2025 Giacomo Lorenzetti <glorenzetti@cefca.es>\
See the end of the file for license conditions.

For an introduction on containers, see the "Building in containers" section
of the `README.md` file within the top-level directory of this
project. Here, we focus on Apptainer with a simple checklist on how to use
the `apptainer-run.sh` script that we have already prepared in this
directory for easy usage in a Maneage'd project.





## Building your Maneage'd project in Apptainer

Through the steps below, you will create an Apptainer image that will only
contain the software environment and keep the project source and built
analysis files (data and PDF) on your host operating system. This enables
you to keep the size of the image to a minimum (only containing the built
software environment) to easily move it from one computer to another.

 1. Using your favorite text editor, create a `run.sh` in your top Maneage
    directory (as described in the comments at the start of the
    `apptainer.sh` script in this directory). Just add `--build-only` on
    the first run so it doesn't go onto doing the analysis and just sets up
    the software environment. Set the respective directory(s) based on your
    filesystem (the software directory is optional). The `run.sh` file name
    is already in `.gitignore` (because it contains local directories), so
    Git will ignore it and it won't be committed by mistake.

 2. Make the script executable with `chmod +x ./run.sh`, and run it with
    `./run.sh`.

 3. Once the build finishes, the build directory (on your host) will
    contain two Singularity Image Format (SIF) files listed below. You can
    move them to any other (more permanent) positions in your filesystem or
    to other computers as needed.
    * `maneage-base.sif`: image containing the base operating system that
      was used to build your project. You can safely delete this unless you
      need to keep it for future builds without internet (you can give it
      to the `--base-name` option of this script). If you want a different
      name for this, put the same option in your
    * `maneaged.sif`: image with the full software environment of your
      project. This file is necessary for future runs of your project
      within the container.

 3. To execute your project remote the `--build-only` and use `./run.sh` to
    execute it. If you want to enter your Maneage'd project shell, add the
    `--project-shell` option to the call inside `./run.sh`.





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
