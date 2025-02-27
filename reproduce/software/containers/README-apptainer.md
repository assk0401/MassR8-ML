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

 1. Using your favorite text editor, create a `apptainer-local.sh` in your
    project's top directory that contains the usage command shown at the
    top of the 'apptainer.sh' script and take the following steps:
    * Set the respective directories based on your own preferences.
    * The `--software-dir` is optional (if you don't have the source
      tarballs, Maneage will download them automatically. But that requires
      internet (which may not always be available). If you regularly build
      Maneage'd projects, you can clone the repository containing all the
      tarballs at https://gitlab.cefca.es/maneage/tarballs-software
    * Add an extra `--build-only` for the first run so it doesn't go onto
      doing the analysis and just builds the image. After it has completed,
      remove the `--build-only` and it will only run the analysis of your
      project.

 2. Once step one finishes, the build directory will contain two
    Singularity Image Format (SIF) files listed below. You can move them to
    any other (more permanent) positions in your filesystem or to other
    computers as needed.
    * `maneage-base.sif`: image containing the base operating system that
      was used to build your project. You can safely delete this unless you
      need to keep it for future builds without internet (you can give it
      to the `--base-name` option of this script). If you want a different
      name for this, put the same option in your
    * `maneaged.sif`: image with the full software environment of your
      project. This file is necessary for future runs of your project
      within the container.





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
