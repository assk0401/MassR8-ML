Reproducible source for XXXXXXXXXXXXXXXXX
-------------------------------------------------------------------------

Copyright (C) 2018-2025 Mohammad Akhlaghi <mohammad@akhlaghi.org>\
See the end of the file for license conditions.

This is the reproducible project source for the paper titled "**XXX XXXXX
XXXXXX**", by XXXXX XXXXXX, YYYYYY YYYYY and ZZZZZZ ZZZZZ that is published
in XXXXX XXXXX.

To reproduce the results and final paper, the only dependency is a minimal
Unix-based building environment including a C and C++ compiler (already
available on your system if you have ever built and installed a software
from source) and a downloader (Wget or cURL). Note that **Git is not
mandatory**: if you don't have Git to run the first command below, go to
the URL given in the command on your browser, and download the project's
source (there is a button to download a compressed tarball of the
project). If you have received this source from arXiv or Zenodo (without
any `.git` directory inside), please see the "Building project tarball"
section below.

```shell
$ git clone XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
$ cd XXXXXXXXXXXXXXXXXX
$ ./project configure
$ ./project make
```

This paper is made reproducible using Maneage (MANaging data linEAGE). To
learn more about its purpose, principles and technicalities, please see
`README-hacking.md`, or the Maneage webpage at https://maneage.org.





### Building the project

This project was designed to have as few dependencies as possible without
requiring root/administrator permissions.

1. Necessary dependencies:

   1.1: Minimal software building tools like C compiler, Make, and other
        tools found on any Unix-like operating system (GNU/Linux, BSD, Mac
        OS, and others). All necessary dependencies will be built from
        source (for use only within this project) by the `./project
        configure` script (next step).

   1.2: (OPTIONAL) Tarball of dependencies. If they are already present (in
        a directory given at configuration time), they will be
        used. Otherwise, a downloader (`wget` or `curl`) will be necessary
        to download any necessary tarball. The necessary tarballs are also
        collected in the archived project on
        [https://doi.org/10.5281/zenodo.XXXXXXX](XXXXXXX). Just unpack that
        tarball and you should see all the tarballs of this project's
        software. When `./project configure` asks for the "software tarball
        directory", give the address of the unpacked directory that has all
        the tarballs. [[TO AUTHORS: UPLOAD THE SOFTWARE TARBALLS WITH YOUR
        DATA AND PROJECT SOURCE TO ZENODO OR OTHER SIMILAR SERVICES. THEN
        ADD THE DOI/LINK HERE. DON'T FORGET THAT THE SOFTWARE ARE A
        CRITICAL PART OF YOUR WORK'S REPRODUCIBILITY.]]

2. Configure the environment (top-level directories in particular) and
   build all the necessary software for use in the next step. It is
   recommended to set directories outside the current directory. Please
   read the description of each necessary input clearly and set the best
   value. Note that the configure script also downloads, builds and locally
   installs (only for this project, no root privileges necessary) many
   programs (project dependencies). So it may take a while to complete.

     ```shell
     $ ./project configure
     ```

3. Run the following command to reproduce all the analysis and build the
   final `paper.pdf` on `8` threads. If your CPU has a different number of
   threads, change the number (you can see the number of threads available
   to your operating system by running `./.local/bin/nproc`)

     ```shell
     $ ./project make -j8
     ```










### Building project tarball (possibly from arXiv)

If the paper is also published on arXiv, it is highly likely that the
authors also uploaded/published the full project there along with the LaTeX
sources. If you have downloaded (or plan to download) this source from
arXiv, some minor extra steps are necessary as listed below. This is
because this tarball is mainly tailored to automatic creation of the final
PDF without using Maneage (only calling LaTeX, not using the './project'
command)!

You can directly run 'latex' on this directory and the paper will be built
with no analysis (all necessary built products are already included in the
tarball). One important feature of the tarball is that it has an extra
`Makefile` to allow easy building of the PDF paper without worring about
the exact LaTeX and bibliography software commands.



#### Only building PDF using tarball (no analysis)

1. If you got the tarball from arXiv and the arXiv code for the paper is
   1234.56789, then the downloaded source will be called `1234.56789` (no
   suffix). However, it is actually a `.tar.gz` file. So take these steps
   to unpack it to see its contents.

     ```shell
     $ arxiv=1234.56789
     $ mv $arxiv $arxiv.tar.gz
     $ mkdir $arxiv
     $ cd $arxiv
     $ tar xf ../$arxiv.tar.gz
     ```

2. No matter how you got the tarball, if you just want to build the PDF
   paper, simply run the command below. Note that this won't actually
   install any software or do any analysis, it will just use your host
   operating system (assuming you already have a LaTeX installation and all
   the necessary LaTeX packages) to build the PDF using the already-present
   plots data.

   ```shell
   $ make              # Build PDF in tarball without doing analysis
   ```

3. If you want to re-build the figures from scratch, you need to make the
   following corrections to the paper's main LaTeX source (`paper.tex`):
   uncomment (remove the starting `%`) the line containing
   `\newcommand{\makepdf}{}`, see the comments above it for more.



#### Building full project from tarball (custom software and analysis)

As described above, the tarball is mainly geared to only building the final
PDF. A few small tweaks are necessary to build the full project from
scratch (download necessary software and data, build them and run the
analysis and finally create the final paper).

1. If you got the tarball from arXiv, before following the standard
   procedure of projects described at the top of the file above (using the
   `./project` script), its necessary to set its executable flag because
   arXiv removes the executable flag from the files (for its own security).

     ```shell
     $ chmod +x project
     ```

2. Make the following changes in two of the LaTeX files so LaTeX attempts
   to build the figures from scratch (to make the tarball; it was
   configured to avoid building the figures, just using the ones that came
   with the tarball).

   - `paper.tex`: uncomment (remove the starting `%`) of the line
     containing `\newcommand{\makepdf}{}`, see the comments above it for
     more.

   - `tex/src/preamble-pgfplots.tex`: set the `tikzsetexternalprefix`
     variable value to `tikz/`, so it looks like this:
     `\tikzsetexternalprefix{tikz/}`.

3. Remove extra files. In order to make sure arXiv can build the paper
   (resolve conflicts due to different versions of LaTeX packages), it is
   sometimes necessary to copy raw LaTeX package files in the tarball
   uploaded to arXiv. Later, we will implement a feature to automatically
   delete these extra files, but for now, the project's top directory
   should only have the following contents (where `reproduce` and `tex` are
   directories). You can safely remove any other file/directory.

     ```shell
     $ ls
     COPYING  paper.tex  project  README-hacking.md  README.md  reproduce/  tex/
     ```










### Building on older systems (+10 year old compilers)

Maneage builds almost all its software itself. But to do that, it needs a C
and C++ compiler on the host. The C++ standard in particular is updated
regularly. Therefore, gradually the basic software packages (that are used
to build the internal Maneage C compiler and other necessary tools) will
start using the newer language features in their newer versions. As a
result, if a host doesn't update its compiler for more than a decade, some
of the basic software may not get built.

Note that this is only a problem for the "basic" software of Maneage (that
are used to build Maneage's own C compiler), not the high-level (or
science) software. On GNU/Linux systems, the high-level software get built
with Maneage's own C compiler. Therefore once Maneage's C compiler is
built, you don't need to worry about the versions of the high-level
software.

One solution to such cases is to downgrade the versions of the basic
software that can't be built. For example, when building Maneage in August
2022 on a old Debian GNU/Linux system from 2010 (with GCC 4.4.5 and GNU C
Library 2.11.3 and Linux kernel 2.6.32-5 on an amd64 architecture), the
following low-level packages needed to be downgraded to slightly earlier
versions.

| Program name                  | 2022-08 version | Version for old system |
|:------------------------------|:---------------:|:----------------------:|
| PatchELF                      |       0.13      |        0.9             |
| GNU Binutils                  |       2.39      |        2.37            |
| GNU Compiler Collection (GCC) |      12.1.0     |       10.2.0           |

As you can see above, fortunately most basic software in Maneage respect
+10 year old compilers and are build-able there. So your higher-level
science software should be buildable with out changing their versions. It
is _highly improbable_ that these downgrades will affect your final science
result.










### Building on ARM

As of 2021-10-13, very little testing of Maneage has been done on arm64
(tested in [aarch64](https://en.wikipedia.org/wiki/AArch64)). However,
_some_ testing has been done on [the
PinePhone](https://en.wikipedia.org/wiki/PinePhone), running
[Debian/Mobian](https://wiki.mobian-project.org/doku.php?id=pinephone). In
principle default Maneage branch (not all high-level software have been
tested) should run fully (configure + make) from the raw source to the
final verified pdf. Some issues that you might need to be aware of are
listed below.

#### Older packages

In old packages that may be still needed and that have an old
`config.guess` file (e.g. from 2002, such as fftw2-2.1.5-4.2, that are not
in the base Maneage branch) may crash during the build. A workaround is to
provide an updated (e.g. 2018) 'config.guess' file (automake --add-missing
--force-missing --copy) in 'reproduce/software/patches/' and copy it over
the old file during the build of the package.

#### An un-killable running job

Vampires may be a problem on the pinephone/aarch64. A "vampire" is defined
here as a job that is in the "R" (running) state, using nearly 95-100% of a
cpu, for an extremely long time (hours), without producing any output to
its log file, and is immune to being killed by the user or root with 'kill
-9'. A reboot and relaunch of the './project configure --existing-conf'
command is the only solution currently known (as of 2021-10-13) for
vampires. These are known to have occurred with linux-image-5.13-sunxi64.


#### RAM/swap space

Adding atleast 3 Gb of swap space (man swapon, man mkswap, man dd) on the
eMMC may help to reduce the chance of having errors due to the lack of RAM.


#### Time scale

On the PinePhone v1.2b, apart from the time wasted by vampires, expect
roughly 24 hours' wall time in total for the full 'configure' phase. The
default 'maneage' example calculations, diagrams and pdf production are
light and should be very fast.










### Building in containers

Containers are a common way to build projects in an independent filesystem
and an almost independent operating system without the overhead (in size
and speed) of a virtual machine. As a result, containers allow easy
movement of built projects from one system to another without
rebuilding. However, they are still large binary files (+1 Gigabytes) and
may not be usable in the future (for example with new software versions not
reading old images or old/new kernel issues). Containers are thus good for
execution/testing phases of a project, but shouldn't be what you archive
for the long term!

It is therefore very important that if you want to save and move your
maneaged project within containers, be sure to commit all your project's
source files and push them to your external Git repository (you can do
these within the container as explained below). This way, you can always
recreate the container with future technologies too. Generally, if you are
developing within a container, its good practice to recreate it from
scratch every once in a while, to make sure you haven't forgot to include
parts of your work in your project's version-controlled source. In the
sections below we also describe how you can use the container **only for
the software environment** and keep your data and project source on your
host.

If you have the necessary software tarballs and input data (optional
features described below) you can disable internet. In this situation, the
configuration and analysis will be exactly reproduced, the final LaTeX
macros will be created, and all results will be verified
successfully. However, no final `paper.pdf` will be created to
visualize/combine everything in one easy-to-read file. Until [task
15267](https://savannah.nongnu.org/task/?15267) is complete, Maneage only
needs internet to install TeXLive packages (using TeXLive's own package
manager `tlmgr`) in the `./project configure` phase. This won't stop the
configuration (since all the analysis can still be reproduced). We are
working on completing this task as soon as possible, but until then, if you
want to disable internet *and* you want to build the final PDF, please
disable internet after the configuration phase. Note that only the
necessary TeXLive packages are installed (~350 MB), not the full TeXLive
collection!

The container technologies that Maneage has been tested on an documentation
exists in this project (with the `reproduce/software/containers` directory)
are listed below. See the respective `README-*.md` file in that directory
for the details:

  - [Apptainer](https://apptainer.org): useful in high performance
    computing (HPC) facilities (where you do not have root
    permissions). Apptainer is fully free and open source software.
    Apptainer containers can only be created and used on GNU/Linux
    operating systems, but are stored as files (easy to manage).

  - [Docker](https://www.docker.com): requires root access, but useful on
    virtual private servers (VPSs). Docker images are stored and managed by
    a root-level daemon, so you can only manage them through its own
    interface. A docker container build on a GNU/Linux host can also be
    executed on Windows or macOS. However, while the Docker engine and its
    command-line interface on GNU/Linux are free and open source software,
    its desktop application (with a GUI and components necessary for
    Windows or macOS) is not (requires payment for large companies).





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
