# Build the project's dependencies (programs and libraries).
#
# ------------------------------------------------------------------------
#                      !!!!! IMPORTANT NOTES !!!!!
#
# This Makefile will be run by the initial './project configure' script. It
# is not included into the project afterwards.
#
# This Makefile builds the high-level (optional) software in Maneage that
# users can choose for different projects. It thus assumes that the
# low-level tools (like GNU Tar and etc) are already build by 'basic.mk'.
#
# ------------------------------------------------------------------------
#
# Copyright (C) 2018-2026 Mohammad Akhlaghi <mohammad@akhlaghi.org>
# Copyright (C) 2019-2026 Raul Infante-Sainz <infantesainz@gmail.com>
#
# This Makefile is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This Makefile is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this Makefile.  If not, see <http://www.gnu.org/licenses/>.

# Top level environment (same as 'basic.mk')
include .build/software/config/LOCAL.conf
include reproduce/software/make/build-rules.mk
include reproduce/software/config/versions.conf
include reproduce/software/config/checksums.conf

# The optional URLs of software. Note that these may need the software
# version, so it is important that they be loaded after 'versions.conf'.
include reproduce/software/config/urls.conf

# Configurations specific to this Makefile
include reproduce/software/config/TARGETS.conf
include reproduce/software/config/texlive-packages.conf

# Basic directories (similar to 'basic.mk').
lockdir = $(BDIR)/software/locks
tdir    = $(BDIR)/software/tarballs
ddir    = $(BDIR)/software/build-tmp
idir    = $(BDIR)/software/installed
ibdir   = $(BDIR)/software/installed/bin
ildir   = $(BDIR)/software/installed/lib
iidir   = $(BDIR)/software/installed/include
ibidir  = $(BDIR)/software/installed/version-info/proglib

# Basic directories (specific to this Makefile).
il64dir  = $(BDIR)/software/installed/lib64
iidir    = $(BDIR)/software/installed/include
shsrcdir = "$(shell pwd)"/reproduce/software/shell
dtexdir  = "$(shell pwd)"/reproduce/software/bibtex
patchdir = "$(shell pwd)"/reproduce/software/patches
itidir   = $(BDIR)/software/installed/version-info/tex
ictdir   = $(BDIR)/software/installed/version-info/cite
ipydir   = $(BDIR)/software/installed/version-info/python
ircrandir    = $(BDIR)/software/installed/version-info/r-cran
ilibrcrandir = $(BDIR)/software/installed/lib/R/library

# Special files.
makewshell = $(ibdir)/make-with-shell





# Targets to build.
ifeq ($(strip $(all_highlevel)),1)

  # Set it to build all programs. Pay attention to special software:
  #
  # Versions as variables (for example minizip): they have the same as the
  # version as others and the version number is actually a variable. So
  # we'll need to filter it out, then add it in the end: minizip (has same
  # version as zlib)
  #
  # Packages that are installed in the same recipe as others shouldn't be
  # included here because there is no explicit target for them: they will
  # be built as part of the other package.
  targets-proglib := $(filter-out minizip-% lapack-% ghostscript-fonts-%, \
      $(shell awk '/^# CLASS:(PYTHON|R-CRAN)/{good=0} \
                   good==1 && !/^#/ && $$1 ~ /-version$$/ { \
                       printf("%s %s ", $$1, $$3)} \
                   /^# CLASS:HIGHLEVEL/{good=1}' \
                  reproduce/software/config/versions.conf \
              | sed 's/version //g')) \
      minizip-$(minizip-version)

  # List all existing Python packages.
  targets-python := $(shell \
    awk '/^# CLASS:PYTHON-START/{good=1} good; \
         /^# CLASS:PYTHON-END/{good=0}' \
         reproduce/software/config/versions.conf \
        | awk '!/^#/' \
        | sed 's/-version = /-/g')

  # List all existing R-CRAN packages.
  targets-r-cran := $(shell \
    awk '/^# CLASS:R-CRAN-START/{good=1} good; \
         /^# CLASS:R-CRAN-END/{good=0}' \
         reproduce/software/config/versions.conf \
        | awk '!/^#/' \
        | sed 's/-version = /-/g')
else

  # Append the version of each software package to its name. We are using a Make
  # feature where a variable name is defined with another variable.
  targets-python := $(foreach p,$(top-level-python),$(p)-$($(p)-version))
  targets-r-cran := $(foreach p,$(top-level-r-cran),$(p)-$($(p)-version))
  targets-proglib := $(foreach p,$(top-level-programs),$(p)-$($(p)-version))

endif

# Disable the TeXLive target if `--offline`
ifneq ($(strip $(offline)),1)
  target-texlive := $(itidir)/texlive
endif

# Ultimate Makefile target. The recipe is '@echo > /dev/null' so Make does
# not print "make: Nothing to be done for 'all'."
all: $(foreach p, $(targets-proglib), $(ibidir)/$(p)) \
     $(foreach p, $(targets-python), $(ipydir)/$(p)) \
     $(foreach p, $(targets-r-cran),  $(ircrandir)/$(p)) \
     $(target-texlive); @echo > /dev/null

# Define the shell environment
# ----------------------------
#
# Other basic environment settings: We are only including the host
# operating system's PATH environment variable (after our own!) for the
# compiler and linker. For the library binaries and headers, we are only
# using our internally built libraries.
#
# To investigate:
#
#    1) Set SHELL to '$(ibdir)/env - NAME=VALUE $(ibdir)/bash' and set all
#       the parameters defined bellow as 'NAME=VALUE' statements before
#       calling Bash. This will enable us to completely ignore the user's
#       native environment.
#
#    2) Add '--noprofile --norc' to '.SHELLFLAGS' so doesn't load the
#       user's environment.
#
#    3) Add the '-u' flag so that an error occurs if an environment
#       variable is empty; this reduces the chance of catastrophic
#       file removal with 'rm -fr ../../$${FORGOT_TO_DEFINE_THIS}'.
#
# Shell settings similar to 'basic.mk':
.ONESHELL:
export PATH := $(ibdir)
export CCACHE_DISABLE := 1
export SHELL := $(ibdir)/bash
.SHELLFLAGS := --noprofile --norc -ec
export LDFLAGS := $(rpath_command) -L$(ildir)
export PKG_CONFIG_LIBDIR := $(ildir)/pkgconfig
export PKG_CONFIG_PATH := $(ildir)/pkgconfig:$(idir)/share/pkgconfig

# Disable built-in rules (which are not needed here!)
.SUFFIXES:

# Settings specific to this Makefile.
export CC := $(ibdir)/gcc
export CXX := $(ibdir)/g++
export F77 := $(ibdir)/gfortran
export LD_RUN_PATH := $(ildir):$(il64dir)
export LD_LIBRARY_PATH := $(ildir):$(il64dir)

# See description of '-Wno-nullability-completeness' in
# 'reproduce/software/shell/configure.sh'.
ifeq ($(on_mac_os),yes)
  noccwarnings=-Wno-nullability-completeness
endif
export CPPFLAGS := -I$(idir)/include $(noccwarnings)

# In macOS, if a directory exists in both 'C_INCLUDE_PATH' and 'CPPFLAGS'
# it will be ignored in 'CPPFLAGS' (which has higher precedence). So, we
# should not define 'C_INCLUDE_PATH' on macOS. This happened with clang
# (Apple LLVM version 10.0.0, clang-1000.11.45.5)
ifneq ($(on_mac_os),yes)
export C_INCLUDE_PATH     := $(iidir)
export CPLUS_INCLUDE_PATH := $(iidir)
endif

# Recipe startup script, see 'reproduce/software/shell/bashrc.sh'.
export PROJECT_STATUS := configure_highlevel
export BASH_ENV := $(shell pwd)/reproduce/software/shell/bashrc.sh

# Until we build our own C library, without this, our GCC won't be able to
# compile anything! Note that on most systems (in particular
# non-Debian-based), 'sys_cpath' will be empty.
export CPATH := $(sys_cpath)

# RPATH is automatically written in macOS, so 'DYLD_LIBRARY_PATH' is
# ultimately redundant. But on some systems, even having a single value
# causes crashs (see bug #56682). So we'll just give it no value at all.
export DYLD_LIBRARY_PATH :=

# On Debian-based OSs, the basic C libraries are in a target-specific
# location, not in standard places. Until we merge the building of the C
# library, it is thus necessary to include this location here. On systems
# that don't need it, 'sys_library_path' is just empty. This is necessary
# for 'ld'.
#
# If this variable is not defined, it will be interpretted as the current
# directory. In this case, when the program source has a 'specs' directory,
# GCC will crash because it expects it to be special file.
ifeq ($(strip $(sys_library_path)),)
export LIBRARY_PATH := $(ildir)
else
export LIBRARY_PATH := $(ildir):$(sys_library_path)
endif

# Building flags:
#
# C++ flags: when we build GCC, the C++ standard library needs to link with
# libiconv. So it is necessary to generically include '-liconv' for all C++
# builds.
ifeq ($(host_cc),0)
export CXXFLAGS          := -liconv
endif

# Custom installation prefix for software that can cause conflicts with
# others, to avoid crowding the to Maneage installed software directory,
# we'll put them all in a 'custom' directory.
idircustom = $(idir)/custom
$(idircustom):; mkdir $@

# Servers to use as backup. Maneage already has some fixed servers that can
# be used to download software tarballs. They are in a configuation
# file. But we give precedence to the "user" backup servers.
#
# One important "user" server (which the user doesn't actually give, but is
# found at configuration time in 'configure.sh') is Zenodo (see the
# description in 'configure.sh' for more on why this depends on
# configuration time).
#
# Afer putting everything together, we use the first server as the
# reference for all software if their '-url' variable isn't defined (in
# 'reproduce/software/config/urls.conf').
downloadwrapper = ./reproduce/analysis/bash/download-multi-try.sh
maneage_backup_urls := $(shell awk '!/^#/{printf "%s ", $$1}' \
                               reproduce/software/config/servers-backup.conf)
backupservers_all = $(user_backup_urls) $(maneage_backup_urls)
topbackupserver = $(word 1, $(backupservers_all))
backupservers = $(filter-out $(topbackupserver),$(backupservers_all))





# Import rules to build specialized software
include reproduce/software/make/xorg.mk
include reproduce/software/make/python.mk
include reproduce/software/make/r-cran.mk











# Libraries
# ---------
#
# We would prefer to build static libraries, but some compilers like LLVM
# don't have static capabilities, so they'll only build dynamic/shared
# libraries. Therefore, we can't use the easy '.a' suffix for static
# libraries as targets and there are different conventions for shared
# library names.
$(ibidir)/apachelog4cxx-$(apachelog4cxx-version): \
                        $(ibidir)/cmake-$(cmake-version) \
                        $(ibidir)/expat-$(expat-version) \
                        $(ibidir)/apr-util-$(apr-util-version) \
                        $(ibidir)/automake-$(automake-version)
	tarball=apache-log4cxx-$(apachelog4cxx-version).tar.lz
	$(call import-source, $(apachelog4cxx-url), $(apachelog4cxx-checksum))
	$(call cbuild, apache-log4cxx-$(apachelog4cxx-version), static)
	echo "Apache log4cxx $(apachelog4cxx-version)" > $@

$(ibidir)/apr-$(apr-version):
	tarball=apr-$(apr-version).tar.lz
	$(call import-source, $(apr-url), $(apr-checksum))
	$(call gbuild, apr-$(apr-version), ,--disable-static)
	echo "Apache Portable Runtime $(apr-version)" > $@

$(ibidir)/apr-util-$(apr-util-version): $(ibidir)/apr-$(apr-version)
	tarball=apr-util-$(apr-util-version).tar.lz
	$(call import-source, $(apr-util-url), $(apr-util-checksum))
	$(call gbuild, apr-util-$(apr-util-version), , \
	               --disable-static \
	               --with-apr=$(idir) \
	               --with-openssl=$(idir) \
	               --with-crypto )
	echo "Apache Portable Runtime Utility $(apr-util-version)" > $@

$(ibidir)/atlas-$(atlas-version):

	tarball=lapack-$(lapack-version).tar.lz
	$(call import-source, $(lapack-url), $(lapack-checksum))

	tarball=atlas-$(atlas-version).tar.lz
	$(call import-source, $(atlas-url), $(atlas-checksum))

#	Get the operating system specific features (how to get CPU
#	frequency and the library suffixes). To make the steps more
#	readable, the different library version suffixes are named with a
#	single character: 's' for no version in the name, 'm' for the major
#	version suffix, and 'f' for the full version suffix.  GCC in Mac OS
#	doesn't work. To work around this issue, on Mac systems we force
#	ATLAS to use 'clang' instead of 'gcc'.
	if [ x$(on_mac_os) = xyes ]; then
	  s=dylib
	  m=3.dylib
	  f=3.6.1.dylib
	  core=$$(sysctl hw.cpufrequency | awk '{print $$2/1000000}')
	  clangflag="--force-clang=$(ibdir)/clang"
	else
	  s=so
	  m=so.3
	  f=so.3.6.1
	  clangflag=
	  core=$$(cat /proc/cpuinfo | grep "cpu MHz" \
	              | head -n 1                    \
	              | sed "s/.*: \([0-9.]*\).*/\1/")
	fi

#	See if the shared libraries should be build for a single CPU thread
#	or multiple threads.
	N=$$(nproc)
	srcdir=$$(pwd)/reproduce/software/make
	if [ $$N = 1 ]; then
	  sharedmk=$$srcdir/atlas-single.mk
	else
	  sharedmk=$$srcdir/atlas-multiple.mk
	fi

#	The linking step here doesn't recognize the '-Wl' in the
#	'rpath_command'.
	export LDFLAGS=-L$(ildir)
	cd $(ddir)
	tar -xf $(tdir)/atlas-$(atlas-version).tar.lz \
	    --no-same-owner --no-same-permissions
	cd ATLAS
	$(shsrcdir)/prep-source.sh $(ibdir)
	rm -rf build
	mkdir build
	cd build
	../configure -b 64 -D c -DPentiumCPS=$$core \
	             --with-netlib-lapack-tarfile=$(tdir)/lapack-$(lapack-version).tar.lz \
	             --cripple-atlas-performance \
	             -Fa alg -fPIC --shared $$clangflag \
	             --prefix=$(idir)

#	Static build.
	make

#	Currently the shared libraries have problems on macOS.
	if [ "x$(on_mac_os)" != xyes ]; then
	     cd lib
	     make -f $$sharedmk
	     cd ..
	     for l in lib/*.$$s*; do patchelf --set-rpath $(ildir) $$l; done
	     cp -d lib/*.$$s* $(ildir)
	     ln -fs $(ildir)/libblas.$$s  $(ildir)/libblas.$$m
	     ln -fs $(ildir)/libf77blas.$$s $(ildir)/libf77blas.$$m
	     ln -fs $(ildir)/liblapack.$$f  $(ildir)/liblapack.$$s
	     ln -fs $(ildir)/liblapack.$$f  $(ildir)/liblapack.$$m
	   fi

#	Install the libraries.
	make install

#	We need to check the existance of 'libptlapack.a', but we can't do
#	this in the '&&' steps above (it will conflict). So we'll do the
#	check after seeing if 'libtatlas.so' is installed, then we'll
#	finalize the build (delete the untarred directory).
	if [ "x$(on_mac_os)" != xyes ]; then \
	  [ -e lib/libptlapack.a ] && cp lib/libptlapack.a $(ildir); \
	  cd $(ddir); \
	  rm -rf ATLAS; \
	fi

#	We'll check the full installation with the static library (not
#	currently building shared library on Mac.
	if [ -f $(ildir)/libatlas.a ]; then \
	  echo "ATLAS $(atlas-version)" > $@; \
	fi

# Boost doesn't use the standard GNU Build System.
$(ibidir)/boost-$(boost-version): \
                $(ibidir)/python-$(python-version) \
                $(ibidir)/openmpi-$(openmpi-version)
	tarball=boost-$(boost-version).tar.lz
	$(call import-source, $(boost-url), $(boost-checksum))
	unpackdir=boost-$(boost-version)
	rm -rf $(ddir)/$$unpackdir
	topdir=$(pwd)
	cd $(ddir)
	tar -xf $(tdir)/$$tarball --no-same-owner --no-same-permissions
	cd $$unpackdir
	$(shsrcdir)/prep-source.sh $(ibdir)
	./bootstrap.sh --prefix=$(idir) --with-libraries=all \
	               --with-python=python3
	echo "using mpi ;" > project-config.jam
	./b2 stage threading=multi link=shared --prefix=$(idir) -j$(numthreads)
	./b2 install threading=multi link=shared --prefix=$(idir) -j$(numthreads)
	cd $$topdir
	rm -rf $(ddir)/$$unpackdir
	echo "Boost $(boost-version)" > $@

$(ibidir)/cfitsio-$(cfitsio-version):

#	Download the tarball
	tarball=cfitsio-$(cfitsio-version).tar.lz
	$(call import-source, $(cfitsio-url), $(cfitsio-checksum))

#	CFITSIO hard-codes '@rpath' inside the shared library on Mac
#	systems. So we need to change it to our library installation
#	path. It doesn't affect GNU/Linux, so we'll just do it in any case
#	to keep things clean.
	topdir=$(pwd); cd $(ddir)
	tar -xf $(tdir)/$$tarball --no-same-owner --no-same-permissions
	customtar=cfitsio-$(cfitsio-version)-custom.tar.gz
	cd cfitsio-$(cfitsio-version)
	sed -i -e's|@rpath|$(ildir)|g' configure
	cd ..
	tar cf $$customtar cfitsio-$(cfitsio-version)
	cd $$topdir

#	Continue the standard build on the customized tarball. Note that
#	with the installation of CFITSIO, 'fpack' and 'funpack' are not
#	installed by default. Because of that, they are added explicity.
#
#	Note that older versions of CFITSIO (before 4.4.0) require a
#	specific 'shared' target for the building of the shared libraries.
	export gbuild_tar=$(ddir)/$$customtar
	$(call gbuild, cfitsio-$(cfitsio-version), , \
	               --enable-sse2 --enable-reentrant \
	               --with-bzip2=$(idir), , \
	               make fpack funpack)
	rm $$customtar
	echo "CFITSIO $(cfitsio-version)" > $@

$(ibidir)/cairo-$(cairo-version): \
                $(ibidir)/libxt-$(libxt-version) \
                $(ibidir)/pixman-$(pixman-version) \
                $(ibidir)/libpng-$(libpng-version) \
                $(ibidir)/freetype-$(freetype-version)
	tarball=cairo-$(cairo-version).tar.lz
	$(call import-source, $(cairo-url), $(cairo-checksum))
	$(call gbuild, cairo-$(cairo-version), static, \
	               --with-x=yes, -j$(numthreads) V=1)
	echo "Cairo $(cairo-version)" > $@

# Eigen is just headers! So it doesn't need to be compiled. Once unpacked
# it has a checksum after 'eigen-eigen', so we'll just use a '*' to choose
# the unpacked directory.
$(ibidir)/eigen-$(eigen-version):
	tarball=eigen-$(eigen-version).tar.lz
	$(call import-source, $(eigen-url), $(eigen-checksum))
	rm -rf $(ddir)/eigen-eigen-*
	topdir=$(pwd); cd $(ddir)
	tar -xf $(tdir)/$$tarball --no-same-owner --no-same-permissions
	cd eigen-$(eigen-version)
	if ! [ -d $(iidir)/eigen3 ]; then mkdir $(iidir)/eigen3; fi
	cp -r Eigen/* $(iidir)/eigen3/         # Some expect 'eigen3'.
	ln -s $(iidir)/eigen3 $(iidir)/Eigen   # Others expect 'Eigen'.
	cd $$topdir
	rm -rf $(ddir)/eigen-$(eigen-version)
	echo "Eigen $(eigen-version)" > $@

# GNU Emacs is an advanced text editor (among many other things!), so it
# isn't directly related to the analysis phase of a project. However, it
# can be useful during the development of a project on systems that don't
# have it natively. So probably after the project is finished and is ready
# for publication, you can remove it from 'TARGETS.conf'.
#
# However, the full Emacs build has a very large number of dependencies
# which aren't necessary in many scenarios so we are disabling everything
# except the core Emacs functionality (using '--without-all') and we are
# also disabling all graphic user interface features (using '--without-x').
$(ibidir)/emacs-$(emacs-version):
	tarball=emacs-$(emacs-version).tar.lz
	$(call import-source, $(emacs-url), $(emacs-checksum))
	$(call gbuild, emacs-$(emacs-version), static, \
	               --without-all --without-x \
	               --without-gnutls --with-ns=no, \
	               -j$(numthreads) V=1)
	echo "GNU Emacs $(emacs-version)" > $@

$(ibidir)/expat-$(expat-version):
	tarball=expat-$(expat-version).tar.lz
	$(call import-source, $(expat-url), $(expat-checksum))
	$(call gbuild, expat-$(expat-version), static)
	echo "Expat $(expat-version)" > $@

$(ibidir)/fftw-$(fftw-version):

#	Prepare the source tarball.
	tarball=fftw-$(fftw-version).tar.lz
	$(call import-source, $(fftw-url), $(fftw-checksum))

#	FFTW's single and double precision libraries must be built
#	independently: for the the single-precision library, we need to add
#	the '--enable-float' option. We will build this first, then the
#	default double-precision library.
#
#	There are Intel-specific optimizations that can be enabled by
#	adding the following two options to 'confop'
#
#           --enable-avx --enable-sse2
#
#	However, they cause crashs on non-Intel processors (has been
#	confirmed in ARM's aarch64). So in the generic scenario they are
#	removed. Checking how these optimizations affect the numeric
#	accuracy of the result (and thus optionally adding them for
#	Intel-based processors) should be studied before they are
#	optionally added for Intel-based CPUs (and ignored for others).
	confop="--enable-shared --enable-threads"
	$(call gbuild, fftw-$(fftw-version), static, \
	               $$confop --enable-float)
	$(call gbuild, fftw-$(fftw-version), static, \
	               $$confop)
	cp $(dtexdir)/fftw.tex $(ictdir)/
	echo "FFTW $(fftw-version) \citep{fftw}" > $@

$(ibidir)/freetype-$(freetype-version): $(ibidir)/libpng-$(libpng-version)
#	As of version 2.13.2, FreeType doesn't account for the 'SHELL'
#	environment variable. The issue has been reported to the
#	developers. But until future versions, the work-around was
#	discoverd to be setting the 'GNUMAKE' environment variable so it
#	includes 'SHELL'.
	export GNUMAKE="$(makewshell)"
	tarball=freetype-$(freetype-version).tar.lz
	$(call import-source, $(freetype-url), $(freetype-checksum))
	$(call gbuild, freetype-$(freetype-version), static)
	echo "FreeType $(freetype-version)" > $@

$(ibidir)/gperf-$(gperf-version):
	tarball=gperf-$(gperf-version).tar.lz
	$(call import-source, $(gperf-url), $(gperf-checksum))
	$(call gbuild, gperf-$(gperf-version), static)
	echo "GNU gperf $(gperf-version)" > $@

$(ibidir)/gsl-$(gsl-version):
	tarball=gsl-$(gsl-version).tar.lz
	$(call import-source, $(gsl-url), $(gsl-checksum))
	$(call gbuild, gsl-$(gsl-version), static)
	echo "GNU Scientific Library $(gsl-version)" > $@

$(ibidir)/hdf5-$(hdf5-version): $(ibidir)/openmpi-$(openmpi-version)
	export CC=mpicc
	export FC=mpif90
	tarball=hdf5-$(hdf5-version).tar.lz
	$(call import-source, $(hdf5-url), $(hdf5-checksum))
	$(call gbuild, hdf5-$(hdf5-version), static, \
	               --enable-parallel \
	               --enable-fortran, \
	               -j$(numthreads) V=1)
	echo "HDF5 library $(hdf5-version)" > $@

# HEALPix includes the source of its C, C++, Python (and several other
# languages) libraries within one tarball. We will include the Python
# installation only when any other Python module is requested (in
# 'TARGETS.conf').
#
# Note that the default './configure' script is an interactive script which
# is hard to automate. So we need to go into the 'autotools' directory of
# the 'C' and 'cxx' directories and configure the GNU Build System (with
# 'autoreconf', which uses 'autoconf' and 'automake') to easily build the
# HEALPix C/C++ libraries in batch mode.
ifeq ($(strip $(targets-python)),)
healpix-python-dep =
else
healpix-python-dep = $(ipydir)/matplotlib-$(matplotlib-version) \
                     $(ipydir)/astropy-$(astropy-version)
endif
$(ibidir)/healpix-$(healpix-version): $(healpix-python-dep) \
                  $(ibidir)/cfitsio-$(cfitsio-version) \
                  $(ibidir)/autoconf-$(autoconf-version) \
                  $(ibidir)/automake-$(automake-version)
	tarball=healpix-$(healpix-version).tar.lz
	$(call import-source, $(healpix-url), $(healpix-checksum))
	if [ x"$(healpix-python-dep)" = x ]; then
	   pycommand1="echo no-healpy-because-no-other-python"
	   pycommand2="echo no-healpy-because-no-other-python"
	else
	   pycommand1="python setup.py build"
	   pycommand2="python setup.py install"
	fi
	rm -rf $(ddir)/Healpix_$(healpix-version)
	topdir=$(pwd); cd $(ddir);
	tar -xf $(tdir)/$$tarball --no-same-owner --no-same-permissions
	cd Healpix_$(healpix-version)
	$(shsrcdir)/prep-source.sh $(ibdir)
	cd src/C/autotools
	autoreconf --install
	./configure --prefix=$(idir)
	make V=1 -j$(numthreads) SHELL=$(ibdir)/bash
	make install
	cd ../../cxx/autotools/
	autoreconf --install
	./configure --prefix=$(idir)

#	With CFITSIO 4.0, the 'CFITSIO_VERSION' macro has three
#	components. But this version of Healpix doesn't yet account for
#	this.
	sed -i -e's/CFITSIO_VERSION/fitsversion/' cxxsupport/fitshandle.cc

#	Continue with the building.
	make V=1 -j$(numthreads) SHELL=$(ibdir)/bash
	make install
	cd ../../healpy
	$$pycommand1
	$$pycommand2
	cd $$topdir
	rm -rf $(ddir)/Healpix_$(healpix-version)
	cp $(dtexdir)/healpix.tex $(ictdir)/
	echo "HEALPix $(healpix-version) \citep{healpix}" > $@

$(ibidir)/libbsd-$(libbsd-version): $(ibidir)/libmd-$(libmd-version)
	tarball=libbsd-$(libbsd-version).tar.lz
	$(call import-source, $(libbsd-url), $(libbsd-checksum))
	if [ x$(on_mac_os) = xyes ]; then
	  echo "" > $@
	else
	  export LDFLAGS="-L$(idirlibmd)/lib $$LDFLAGS"
	  export CPPFLAGS="-I$(idirlibmd)/include $$CPPFLAGS"
	  $(call gbuild, libbsd-$(libbsd-version), static,,V=1)
	  echo "Libbsd $(libbsd-version)" > $@
	fi

$(ibidir)/libidn-$(libidn-version):
	tarball=libidn-$(libidn-version).tar.lz
	$(call import-source, $(libidn-url), $(libidn-checksum))
	$(call gbuild, libidn-$(libidn-version), static, \
	               --disable-doc, -j$(numthreads) V=1)
	echo "Libidn $(libidn-version)" > $@

$(ibidir)/libjpeg-$(libjpeg-version):
	tarball=libjpeg-$(libjpeg-version).tar.lz
	$(call import-source, $(libjpeg-url), $(libjpeg-checksum))
	$(call gbuild, libjpeg-$(libjpeg-version), static,,V=1)
	echo "Libjpeg $(libjpeg-version)" > $@

# libmd is a set of "message digest" functions that are available in in the
# C library of BSD-based systems, but not others (like GNU-based
# systems). It includes hash functions like MD5 and SHAs.
#
# Libmd is being installed in a non-standard location because its headers
# (like 'md5.h') will conflict with similarly named headers by the system
# during the building of Binutils later! So any program that needs libmd's
# headers or libraries (like 'libbsd'), should add this special location to
# its CPPFLAGS and LDFLAGS.
idirlibmd=$(idircustom)/libmd
$(ibidir)/libmd-$(libmd-version): | $(idircustom)
	tarball=libmd-$(libmd-version).tar.lz
	$(call import-source, $(libmd-url), $(libmd-checksum))
	if [ x$(on_mac_os) = xyes ]; then
	  echo "" > $@
	else
	  export gbuild_prefix=$(idirlibmd)
	  $(call gbuild, libmd-$(libmd-version), static,,V=1)
	  echo "Libmd $(libmd-version)" > $@
	fi

$(ibidir)/libnsl-$(libnsl-version): \
                 $(ibidir)/libtirpc-$(libtirpc-version) \
                 $(ibidir)/rpcsvc-proto-$(rpcsvc-proto-version)
	tarball=libnsl-$(libnsl-version).tar.gz
	$(call import-source, $(libnsl-url), $(libnsl-checksum))
	$(call gbuild, libnsl-$(libnsl-version), static, \
	               --sysconfdir=$(idir)/etc)
	echo "Libnsl $(libnsl-version)" > $@

$(ibidir)/libpaper-$(libpaper-version): \
                   $(ibidir)/automake-$(automake-version)

#	Download the tarball.
	tarball=libpaper-$(libpaper-version).tar.lz
	$(call import-source, $(libpaper-url), $(libpaper-checksum))

#	Unpack, build the configure system, build and install.
	cd $(ddir)
	tar -xf $(tdir)/$$tarball --no-same-owner --no-same-permissions
	unpackdir=libpaper-$(libpaper-version)
	cd $$unpackdir
	$(shsrcdir)/prep-source.sh $(ibdir)
	autoreconf -fi
	./configure --prefix=$(idir) --sysconfdir=$(idir)/etc \
	            --disable-static
	make
	make install
	cd ..
	rm -rf $$unpackdir

#	Post-processing: according to Linux From Scratch, libpaper expects
#	that packages will install files into this directory and
#	'paperconfig' is a script which will invoke 'run-parts' if
#	'/etc/libpaper.d' exists
	mkdir -vp $(idir)/etc/libpaper.d
	sed -e's|MANEAGESHELL|$(SHELL)|' $(shsrcdir)/run-parts.in \
	    > $(ibdir)/run-parts
	chmod +x $(ibdir)/run-parts
	echo "Libpaper $(libpaper-version)" > $@

$(ibidir)/libpng-$(libpng-version):

#	The option '-DPNG_ARM_NEON_OPT=0' prevents an arm64 'neon' library
#	from being required at compile time.
	tarball=libpng-$(libpng-version).tar.lz
	$(call import-source, $(libpng-url), $(libpng-checksum))
	$(call gbuild, libpng-$(libpng-version), static, \
	               CFLAGS="-DPNG_ARM_NEON_OPT=0")
	echo "Libpng $(libpng-version)" > $@

$(ibidir)/libtiff-$(libtiff-version): $(ibidir)/libjpeg-$(libjpeg-version)
	tarball=libtiff-$(libtiff-version).tar.lz
	$(call import-source, $(libtiff-url), $(libtiff-checksum))
	$(call gbuild, libtiff-$(libtiff-version), static, \
	               --disable-jbig \
	               --disable-webp \
	               --disable-zstd \
	               --disable-libdeflate )
	echo "Libtiff $(libtiff-version)" > $@

$(ibidir)/libtirpc-$(libtirpc-version):
	tarball=libtirpc-$(libtirpc-version).tar.bz2
	$(call import-source, $(libtirpc-url), $(libtirpc-checksum))
	$(call gbuild, libtirpc-$(libtirpc-version), static, \
	               --disable-gssapi, V=1)
	echo "libtirpc $(libtirpc-version)" > $@

# Metastore is used (through a Git hook) to restore the source modification
# dates of files after a Git checkout. Another Git hook saves all file
# metadata just before a commit (to allow restoration after a
# checkout). Since this project is managed in Makefiles, file modification
# dates are critical to not having to redo the whole analysis after
# checking out between branches.
#
# Note that we aren't using the standard version of Metastore, but a fork
# of it that is maintained in this repository:
#    https://gitlab.com/makhlaghi/metastore-fork
#
# Libbsd is not necessary on macOS systems, because macOS is already a
# BSD-based distribution. But on GNU/Linux systems, it is necessary.
$(ibidir)/metastore-$(metastore-version): \
                    $(ibidir)/libbsd-$(libbsd-version)

#	Download the tarball.
	tarball=metastore-$(metastore-version).tar.lz
	$(call import-source, $(metastore-url), $(metastore-checksum))

#	Metastore doesn't have any './configure' script. So we'll just call
#	'pwd' as a place-holder for the './configure' command.
#
#	File attributes are also not available on some systems, since the
#	main purpose here is modification dates (and not attributes), we'll
#	also set the 'NO_XATTR' flag.
#
#	After installing Metastore, write the relevant hooks into this
#	system's Git hooks, while setting the system-specific
#	directories/files.
#
#	Note that the metastore -O and -G options used in this template are
#	currently only available in a fork of 'metastore' hosted at:
#	https://github.com/mohammad-akhlaghi/metastore
#
#	Checking for presence of '.git'. When the project source is
#	downloaded from a non-Git source (for example from arXiv), there is
#	no '.git' directory to work with. So until we find a better
#	solution, avoid the step to to add the Git hooks.
	current_dir=$$(pwd); \
	$(call gbuild, metastore-$(metastore-version), static,, \
	               NO_XATTR=1 V=1,,pwd,PREFIX=$(idir))

#	Correct RPATH when necessary.
	if [ -f $(ibdir)/patchelf ]; then
	  $(ibdir)/patchelf --set-rpath $(ildir) $(ibdir)/metastore
	fi

#	If this project is being built in a directory version controlled
#	by Git, copy the hooks into the Git configuation.
	if [ -f $(ibdir)/metastore ]; then
	  if [ -d .git ]; then
	    user=$$(whoami)
	    group=$$(groups | awk '{print $$1}')
	    cd $$current_dir
	    for f in pre-commit post-checkout; do
	       sed -e's|@USER[@]|'$$user'|g' \
	           -e's|@GROUP[@]|'$$group'|g' \
	           -e's|@BINDIR[@]|$(ibdir)|g' \
	           -e's|@TOP_PROJECT_DIR[@]|'$$current_dir'|g' \
	           reproduce/software/shell/git-$$f > .git/hooks/$$f
	       chmod +x .git/hooks/$$f
	    done
	  fi
	  echo "Metastore (forked) $(metastore-version)" > $@
	else
	  echo; echo; echo
	  echo "*****************"
	  echo "metastore couldn't be installed!"
	  echo
	  echo "Its used for preserving timestamps on Git commits."
	  echo "Its useful for development, not simple running of "
	  echo "the project. So we won't stop the configuration "
	  echo "because it wasn't built."
	  echo "*****************"
	  echo "" > $@
	fi

# The Ninja build system (https://ninja-build.org) is also known as simply
# "Ninja". But other package managers (for example Debian) use
# "ninja-build" (the old "ninja" name has become obsolete there). Also,
# their own URL is called "ninja-build". So we use the same convention in
# Maneage.
$(ibidir)/ninjabuild-$(ninjabuild-version): $(ibidir)/cmake-$(cmake-version)
	tarball=ninjabuild-$(ninjabuild-version).tar.lz
	$(call import-source, $(ninjabuild-url), $(ninjabuild-checksum))
	cd $(ddir)
	tar -xf $(tdir)/$$tarball --no-same-owner --no-same-permissions
	cd ninjabuild-$(ninjabuild-version)
	cmake -Bbuild-cmake
	cmake --build build-cmake -j$(numthreads)
	./build-cmake/ninja_test
	cp -pv build-cmake/ninja $(ibdir)/
	cd ..
	rm -rf ninjabuild-$(ninjabuild-version)
	echo "Ninja build system $(ninjabuild-version)" > $@

$(ibidir)/openblas-$(openblas-version):
	tarball=openblas-$(openblas-version).tar.lz
	$(call import-source, $(openblas-url), $(openblas-checksum))
	if [ x$(on_mac_os) = xyes ]; then export CC=clang; fi
	cd $(ddir)
	tar -xf $(tdir)/$$tarball --no-same-owner --no-same-permissions
	cd openblas-$(openblas-version)
	$(shsrcdir)/prep-source.sh $(ibdir)
	make -j$(numthreads)
	make PREFIX=$(idir) install
	cd ..
	rm -rf openblas-$(openblas-version)
	echo "OpenBLAS $(openblas-version)" > $@

$(ibidir)/openmpi-$(openmpi-version):
	tarball=openmpi-$(openmpi-version).tar.lz
	$(call import-source, $(openmpi-url), $(openmpi-checksum))
	$(call gbuild, openmpi-$(openmpi-version), static, \
	               --with-pmix=internal \
	               --with-hwloc=internal \
	               --without-verbs, \
	               -j$(numthreads) V=1)
	echo "Open MPI $(openmpi-version)" > $@

# IMPORTANT NOTE: The build instructions for OpenSSH are defined here, but
# it is best that it not be prerequisite of any program and thus not built
# within the project because of all the security issues it may cause. Only
# enable/build it in a project with caution, and if there is no other
# solution (for example to disable SSH in a program that may ask for it.
$(ibidir)/openssh-$(openssh-version):
	tarball=openssh-$(openssh-version).tar.gz
	$(call import-source, $(openssh-url), $(openssh-checksum))
	$(call gbuild, openssh-$(openssh-version), static, \
	               --with-privsep-path=$(ibdir)/.ssh_privsep \
	               --with-privsep-user=nobody \
	               --with-md5-passwords \
	               --with-ssl-engine \
	               , -j$(numthreads) V=1)
	echo "OpenSSH $(openssh-version)" > $@

$(ibidir)/pixman-$(pixman-version):
	tarball=pixman-$(pixman-version).tar.lz
	$(call import-source, $(pixman-url), $(pixman-checksum))
	$(call gbuild, pixman-$(pixman-version), static, , \
	               -j$(numthreads) V=1)
	echo "Pixman $(pixman-version)" > $@

$(ibidir)/rpcsvc-proto-$(rpcsvc-proto-version):
#	'libintl' is installed as part of GNU Gettext in
#	'basic.mk'. rpcsvc-proto needs to link with it on macOS.
	if [ x$(on_mac_os) = xyes ]; then
	  export CC=clang
	  export CXX=clang++
	  export LDFLAGS="-lintl $$LDFLAGS"
	fi

#	Download the tarball and build rpcsvc-proto.
	tarball=rpcsvc-proto-$(rpcsvc-proto-version).tar.xz
	$(call import-source, $(rpcsvc-proto-url), $(rpcsvc-proto-checksum))
	$(call gbuild, rpcsvc-proto-$(rpcsvc-proto-version), static)
	echo "rpcsvc $(rpcsvc-proto-version)" > $@

$(ibidir)/tides-$(tides-version):
	tarball=tides-$(tides-version).tar.gz
	$(call import-source, $(tides-url), $(tides-checksum))
	$(call gbuild, tides-$(tides-version), static,\
	               --with-gmp=$(idir) --with-mpfr=$(idir))
	cp $(dtexdir)/tides.tex $(ictdir)/
	echo "TIDES $(tides-version) \citep{tides}" > $@

$(ibidir)/valgrind-$(valgrind-version):
	tarball=valgrind-$(valgrind-version).tar.lz
	$(call import-source, $(valgrind-url), $(valgrind-checksum))
	$(call gbuild, valgrind-$(valgrind-version), static)
	echo "Valgrind $(valgrind-version)" > $@

$(ibidir)/yaml-$(yaml-version):
	tarball=yaml-$(yaml-version).tar.gz
	$(call import-source, $(yaml-url), $(yaml-checksum))
	$(call gbuild, yaml-$(yaml-version), static)
	echo "LibYAML $(yaml-version)" > $@





# Libraries with special attention on Mac OS
# ------------------------------------------
#
# Libgit2 and WCSLIB don't set their installation path, or don't do it
# properly, in their finally installed shared libraries. But since we are
# linking everything (including OpenSSL and its dependencies) dynamically,
# we need to also make a shared libraries and can't use static
# libraries. So for Mac OS systems we have to correct their addresses
# manually.
#
# For example, Libgit2 page recommends doing a static build, especially for
# Mac systems (with '-DBUILD_SHARED_LIBS=OFF'): "It’s highly recommended
# that you build libgit2 as a static library for Xcode projects. This
# simplifies distribution significantly, as the resolution of dynamic
# libraries at runtime can be extremely problematic.". This is a major
# problem we have been having so far with Mac systems:
# https://libgit2.org/docs/guides/build-and-link
# On macOS system, 'libgit2' complains about not finding '_iconv*'
# functions! But apparently 'libgit2' has its own implementation of libiconv
# that it uses if it can't find libiconv on macOS. So, to fix this problem
# it is necessary to use the option '-DUSE_ICONV=OFF' in the configure step.
$(ibidir)/libgit2-$(libgit2-version): $(ibidir)/cmake-$(cmake-version)
	tarball=libgit2-$(libgit2-version).tar.lz
	$(call import-source, $(libgit2-url), $(libgit2-checksum))
	$(call cbuild, libgit2-$(libgit2-version), static, \
	              -DUSE_SSH=OFF -DBUILD_CLAR=OFF \
	              -DTHREADSAFE=ON -DUSE_ICONV=OFF )
	if [ x$(on_mac_os) = xyes ]; then
	  install_name_tool -id $(ildir)/libgit2.1.9.dylib \
	                        $(ildir)/libgit2.1.9.dylib
	fi
	echo "Libgit2 $(libgit2-version)" > $@

$(ibidir)/wcslib-$(wcslib-version): $(ibidir)/cfitsio-$(cfitsio-version)

#	Import the tarball.
	tarball=wcslib-$(wcslib-version).tar.lz
	$(call import-source, $(wcslib-url), $(wcslib-checksum))

#	Build WCSLIB while disabling some features:
#	- Fortran is disabled because as of May 2023, on macOS systems
#	  where we do not install GCC (and thus a standard 'gfortran'), the
#	  LLVM Fortran compiler is not complete and will cause a crash. If
#	  you use the Fortran features of WCSLIB, feel free to remove
#	  '--disable-fortran', but be careful with portability on other
#	  systems. Hopefully some time in the future, GCC will also be
#	  install-able on macOS within Maneage or LLVM's 'gfortran' will
#	  also be complete and will not cause a crash.
#	- PGPLOT is disabled because it has many manual steps in its
#	  installation. Therefore, we currently do not build PGPlots in
#	  Maneage. Once (if) it is added, we can remove '--without-pgplot'.
	$(call gbuild, wcslib-$(wcslib-version), , \
	               LIBS="-pthread -lcurl -lm" \
	               --without-pgplot \
	               --disable-fortran \
                       --with-cfitsiolib=$(ildir) \
                       --with-cfitsioinc=$(idir)/include)
	if [ x$(on_mac_os) = xyes ]; then
	  install_name_tool -id $(ildir)/libwcs.$(wcslib-version).dylib \
	                        $(ildir)/libwcs.$(wcslib-version).dylib
	fi
	echo "WCSLIB $(wcslib-version)" > $@










# Programs
# --------
#
# Astrometry-net contains a lot of programs. We need to specify the
# installation directory and the Python executable (by default it will look
# for /usr/bin/python).
#
# An optional dependency is 'netpbm' but it has many dependencies and a
# crazy build system. So, it is not in the default preprequisites. If you
# need it you can add it as a prerequisite and pray that it will work.
#
# A consequence of not having 'netpbm' is that for obtaining the
# astrometric solution of one image using 'solve-field', it is necessary to
# build a catalog of sources with image coordinates and flux (x,y,flux) in
# advance. The catalog has to be sorted by flux. Finally, when invoking
# 'solve-field', the width and heigh of the original image have to be
# provided.
#
# More explicitly, raw basic steps using Gnuastro:
#
# - Obtain a catalog with image coordinates and flux (x,y,brightness):
#   $ astnoisechisel img.fits -o det.fits
#   $ astsegment det.fits -o seg.fits
#   $ astmkcatalog seg.fits --clumpscat --x --y --brightness -o cat-raw.fits
#
# - Sort by flux:
#   $ asttable cat-raw.fits --hdu 2 --sort brightness --descending \
#              --output cat.fits
#
# - Get the x-size and y-size from the header:
#   $ xsize=$(astfits img.fits --keyvalue NAXIS1 --quiet)
#   $ ysize=$(astfits img.fits --keyvalue NAXIS2 --quiet)
#
# - Run 'solve-field' to obtain the astrometric solution:
#   $ solve-field cat.fits --width $xsize --height $ysize [--other-parameters]
$(ibidir)/astrometrynet-$(astrometrynet-version): \
                        $(ibidir)/gsl-$(gsl-version) \
                        $(ibidir)/swig-$(swig-version) \
                        $(ipydir)/numpy-$(numpy-version) \
                        $(ibidir)/cairo-$(cairo-version) \
                        $(ibidir)/libpng-$(libpng-version) \
                        $(ibidir)/wcslib-$(wcslib-version) \
                        $(ipydir)/astropy-$(astropy-version) \
                        $(ibidir)/cfitsio-$(cfitsio-version) \
                        $(ibidir)/libjpeg-$(libjpeg-version)

#	Import the tarball
	tarball=astrometry.net-$(astrometrynet-version).tar.lz
	$(call import-source, $(astrometrynet-url), $(astrometrynet-checksum))

#	We are modifying the Makefile in two steps because on Mac OS system
#	we do not have '/proc/cpuinfo' nor 'free'. Since this is only for
#	the 'report.txt', this changes do not causes problems in running
#	'astrometrynet'
	cd $(ddir)
	rm -rf astrometry.net-$(astrometrynet-version)
	tar -xf $(tdir)/$$tarball --no-same-owner --no-same-permissions
	cd astrometry.net-$(astrometrynet-version)
	$(shsrcdir)/prep-source.sh $(ibdir)
	sed -e 's|cat /proc/cpuinfo|echo "Ignoring CPU info"|' \
	    -e 's|-free|echo "Ignoring RAM info"|' Makefile > Makefile.tmp
	mv Makefile.tmp Makefile
	make
	make py
	make extra
	make install INSTALL_DIR=$(idir) PYTHON_SCRIPT="$(ibdir)/python"
	cd ..
	rm -rf astrometry.net-$(astrometrynet-version)
	cp $(dtexdir)/astrometrynet.tex $(ictdir)/
	echo "Astrometry.net $(astrometrynet-version) \citep{astrometrynet}" > $@

$(ibidir)/autoconf-$(autoconf-version):
	tarball=autoconf-$(autoconf-version).tar.lz
	$(call import-source, $(autoconf-url), $(autoconf-checksum))
	$(call gbuild, autoconf-$(autoconf-version), static, ,V=1)
	echo "GNU Autoconf $(autoconf-version)" > $@

$(ibidir)/automake-$(automake-version): $(ibidir)/autoconf-$(autoconf-version)
	tarball=automake-$(automake-version).tar.lz
	$(call import-source, $(automake-url), $(automake-checksum))
	$(call gbuild, automake-$(automake-version), static, ,V=1)
	echo "GNU Automake $(automake-version)" > $@

# cdsclient is a set of software written in c to interact with astronomical
# database servers. It is a dependency of 'scamp' to be able to download
# reference catalogues.
#
# NOTE: we do not use a convencional 'gbuild' installation because the
# programs are scripts and we need to touch them before installing.
# Otherwise this software will be re-built each time the configure step is
# invoked.
$(ibidir)/cdsclient-$(cdsclient-version):
	tarball=cdsclient-$(cdsclient-version).tar.lz
	$(call import-source, $(cdsclient-url), $(cdsclient-checksum))
	cd $(ddir)
	tar -xf $(tdir)/$$tarball --no-same-owner --no-same-permissions
	cd cdsclient-$(cdsclient-version)
	$(shsrcdir)/prep-source.sh $(ibdir)
	touch *
	./configure --prefix=$(idir)
	make
	make install
	cd ..
	rm -rf cdsclient-$(cdsclient-version)
	echo "cdsclient $(cdsclient-version)" > $@

# CMake can be built with its custom './bootstrap' script and has no
# dependencies beyond the basic Maneage software.
$(ibidir)/cmake-$(cmake-version):

#	Import the tarball
	tarball=cmake-$(cmake-version).tar.lz
	$(call import-source, $(cmake-url), $(cmake-checksum))

#	On Mac systems, the build complains about 'clang' specific
#	features, so we can't use our own GCC build here.
	if [ x$(on_mac_os) = xyes ]; then
	  export CC=clang
	  export CXX=clang++
	fi

#	CMake wants a single executable for 'MAKE', so we can't use 'make
#	SHELL=$(SHELL) and we have defined this script.
	export MAKE="$(makewshell)"

#	Go into the unpacked directory and prepare CMake.
	cd $(ddir)
	rm -rf cmake-$(cmake-version)
	tar -xf $(tdir)/$$tarball --no-same-owner --no-same-permissions
	cd cmake-$(cmake-version)
	$(shsrcdir)/prep-source.sh $(ibdir)

#	Bootstrap, build and install CMake:
#	- With the '--no-system-libs' option, CMake builds and statically
#	  links all the libraries it needs. Even though some of those (like
#	  liblzma, libcurl, zlib or bzip2) are within Maneage, we
#	  discovered that CMake can get confused and use out-of-Maneage
#	  libraries (https://savannah.nongnu.org/bugs/?63043).
	./bootstrap --no-qt-gui \
	            --prefix=$(idir) \
	            --no-system-libs \
	            --parallel=$(numthreads)
	$(makewshell) VERBOSE=1 LIBS="$$LIBS -lssl -lcrypto -lz" \
	              -j$(numthreads)
	$(makewshell) install

#	Clean up.
	cd ..
	rm -rf cmake-$(cmake-version)
	echo "CMake $(cmake-version)" > $@

$(ibidir)/flex-$(flex-version): $(ibidir)/bison-$(bison-version)
	tarball=flex-$(flex-version).tar.lz
	$(call import-source, $(flex-url), $(flex-checksum))
	$(call gbuild, flex-$(flex-version), static, \
	       --with-libiconv-prefix=$(idir) \
	       --with-libintl-prefix=$(idir) \
	       --disable-dependency-tracking, \
	       V=1 -j$(numthreads))
	echo "Flex $(flex-version)" > $@

$(ibidir)/gdb-$(gdb-version): $(ibidir)/python-$(python-version)
	tarball=gdb-$(gdb-version).tar.lz
	export configure_in_different_directory=1;
	$(call import-source, $(gdb-url), $(gdb-checksum))
	$(call gbuild, gdb-$(gdb-version),,,V=1 -j$(numthreads))
	echo "GNU Project Debugger (GDB) $(gdb-version)" > $@

$(ibidir)/ghostscript-$(ghostscript-version): \
                      $(ibidir)/libxt-$(libxt-version) \
                      $(ibidir)/expat-$(expat-version) \
                      $(ibidir)/libidn-$(libidn-version) \
                      $(ibidir)/libpng-$(libpng-version) \
                      $(ibidir)/libtiff-$(libtiff-version) \
                      $(ibidir)/libpaper-$(libpaper-version)

#	Download the standard collection of Ghostscript fonts.
	tarball=ghostscript-fonts-std-$(ghostscript-fonts-std-version).tar.lz
	$(call import-source, $(ghostscript-fonts-std-url), \
	                      $(ghostscript-fonts-std-checksum))

#	Download the extra GNU fonts for Ghostscript.
	tarball=ghostscript-fonts-gnu-$(ghostscript-fonts-gnu-version).tar.lz
	$(call import-source, $(ghostscript-fonts-gnu-url), \
	                      $(ghostscript-fonts-gnu-checksum))

#	Download the tarball
	tarball=ghostscript-$(ghostscript-version).tar.lz
	$(call import-source, $(ghostscript-url), $(ghostscript-checksum))

#	On macOS we use the system compiler and linker. The system linker
#	there doesn't support '--copy-dt-needed-entries', while the one on
#	Linux crashes if we remove it. So we only activate it on macOS.
	ldflags=""
	if [ x$(on_mac_os) = xno ]; then
	     ldflags="LDFLAGS=-Wl,--copy-dt-needed-entries"
	fi

#	Unpack it and configure Ghostscript. The option
#	'-DPNG_ARM_NEON_OPT=0' prevents an arm64 'neon' library from being
#	required at compile time.
	cd $(ddir)
	tar -xf $(tdir)/$$tarball --no-same-owner --no-same-permissions
	cd ghostscript-$(ghostscript-version)
	$(shsrcdir)/prep-source.sh $(ibdir)
	./configure $$ldflags \
	            --disable-cups \
	            --prefix=$(idir) \
	            --enable-dynamic \
	            --disable-compile-inits \
	            --disable-hidden-visibility \
	            CFLAGS="-DPNG_ARM_NEON_OPT=0"

#	Build and install the program and the shared libraries.
	make    V=1 -j$(numthreads)
	make so V=1 -j$(numthreads)
	make install
	make soinstall

#	Install headers and set PostScript (PS) headers to point there.
	install -v -m644 base/*.h $(iidir)/ghostscript
	ln -sfvn $(iidir)/ghostscript $(iidir)/ps

#	Install the fonts.
	tar -xvf $(tdir)/ghostscript-fonts-std-$(ghostscript-fonts-std-version).tar.lz \
	    -C $(idir)/share/ghostscript --no-same-owner --no-same-permissions
	tar -xvf $(tdir)/ghostscript-fonts-gnu-$(ghostscript-fonts-gnu-version).tar.lz \
	    -C $(idir)/share/ghostscript --no-same-owner --no-same-permissions
	fc-cache -v $(idir)/share/ghostscript/fonts/
	echo; echo "Ghostscript fonts added to Fontconfig."; echo;

#	Clean up and write the output target.
	cd ..
	rm -rf ghostscript-$(ghostscript-version)
	echo "GPL Ghostscript $(ghostscript-version)" > $@

# Gnuastro can optionally depend on libgit2, but it is not included as a
# dependency here for the two reasons below. If you would like to have it,
# add it as a dependency (its build instruction and dependencies are here
# already), then remove the '--without-libgit2' configure option) and also
# comment the following two generic configuration lines: 'outfitsnocommit'
# and 'outfitsnoconfig'.
#   - Within Maneage, we have everything under Git already and users are
#     expected to include the version in all their products.
#   - libgit2 can only be built with CMake (which takes extremely long to
#     compile: possibly even longer than GCC!).
#   - Maneage is often run on HPCs that can have network connections
#     between the storage and processer and the necessary libgit2
#     operations on every created file can have a performance impact.
$(ibidir)/gnuastro-$(gnuastro-version): \
                   $(ibidir)/gsl-$(gsl-version) \
                   $(ibidir)/wcslib-$(wcslib-version) \
                   $(ibidir)/libjpeg-$(libjpeg-version) \
                   $(ibidir)/libtiff-$(libtiff-version) \
                   $(ibidir)/ghostscript-$(ghostscript-version)

#	Generic installation.
	tarball=gnuastro-$(gnuastro-version).tar.lz
	$(call import-source, $(gnuastro-url), $(gnuastro-checksum))
	$(call gbuild, gnuastro-$(gnuastro-version), static, \
	               --without-libgit2, -j$(numthreads))
	cp $(dtexdir)/gnuastro.tex $(ictdir)/

#	Generally, besides the Git commit, we are also disabling the
#	default mode of printing any type of metadata and versions of
#	dependencies in output headers (through the installation-wide
#	configuration file). This is done because within a large pipeline,
#	Gnuastro is used to create many intermediate files (that are
#	deleted shortly after being created) and it is not worth the
#	overhread to keep this information in those intermediate products:
#	it is the pipeline's responsibility to put them in the final
#	outputs. We recommend to use the Gnuastro Fits program's keyword
#	writing options to add as much contextual metadata on your final
#	products as possible. Some tips:
#	  - The creation date is not good (because it is not reproducible
#	    and will make simple validation hard). The project's Commit
#	    should be used instead.
#	  - Define a keyword to keep the public URL of the repository of
#	    the Maneage'd project. In this way, a person who gets your
#	    final product can easily check that for all the information
#	    (including software versions and configuration options).
	gconf=$(idir)/etc/gnuastro/gnuastro.conf
	echo ""                       >> $$gconf
	echo "# Maneage specific (see Gnuastro build rule for details)." \
	                              >> $$gconf
	echo " outfitsnocommit   = 1" >> $$gconf
	echo " outfitsnoconfig   = 1" >> $$gconf
	echo " outfitsnodate     = 1" >> $$gconf
	echo " outfitsnoversions = 1" >> $$gconf

#	Final target.
	echo "GNU Astronomy Utilities $(gnuastro-version) \citep{gnuastro}" > $@

$(ibidir)/icu-$(icu-version): $(ibidir)/python-$(python-version)

#	First, we need to remove any possibly existing ICU installation
#	because it can cause conflicts during a new configuration
#	(especially if a new version is to replace the old one).
	for i in data i18n io test tu uc; do
	  rm -fv $(ildir)/libicu$$i.*;
	done

#	Prepare the tarball, unpack, build and install ICU (some
#	customizations are necessary, so we're not using 'gbuild').
	tarball=icu-$(icu-version).tar.lz
	$(call import-source, $(icu-url), $(icu-checksum))
	cd $(ddir)
	tar -xf $(tdir)/$$tarball --no-same-owner --no-same-permissions
	unpackdir=icu-$(icu-version)
	cd $$unpackdir
	$(shsrcdir)/prep-source.sh $(ibdir)
	cd icu4c/source
	./configure --enable-static --prefix=$(idir)
	make -j$(numthreads) V=1
	make install
	cd $(ddir)
	rm -rf $$unpackdir
	echo "ICU $(icu-version)" > $@

$(ibidir)/imagemagick-$(imagemagick-version): \
                      $(ibidir)/zlib-$(zlib-version) \
                      $(ibidir)/libjpeg-$(libjpeg-version) \
                      $(ibidir)/libtiff-$(libtiff-version) \
                      $(ibidir)/ghostscript-$(ghostscript-version)
	tarball=ImageMagick-$(imagemagick-version).tar.lz
	$(call import-source, $(imagemagick-url), $(imagemagick-checksum))
	$(call gbuild, ImageMagick-$(imagemagick-version), static, \
	               --without-x \
	               --with-gslib \
	               --disable-openmp \
	               --with-libstdc=$(ildir), \
	               V=1 -j$(numthreads))

#	On macOS, an executable and several libraries are not properly
#	linked with the Ghostscript library (libgs), so we need to fix it
#	manually.
	if [ x$(on_mac_os) = xyes ]; then
	  gsversion=$$(echo $(ghostscript-version) \
	                    | awk -F'.' '{print $$1"."$$2}')
	  libMagicks=$$(ls -l $(ildir)/libMagick*.dylib  \
	                   | awk '/^-/{print $$NF}')
	  libMagicks_all="$(ibdir)/magick $$libMagicks"
	  for f in $$libMagicks_all; do \
	      install_name_tool -change libgs.dylib.$$gsversion \
	      $(ildir)/libgs.dylib.$$gsversion $$f; done
	fi
	echo "ImageMagick $(imagemagick-version)" > $@

# 'imfit' doesn't use the traditional 'configure' and 'make' to install
# itself.  Instead of that, it uses 'scons'. As a consequence, the
# installation is manually done by decompressing the tarball, and running
# 'scons' with the necessary flags. Despite of that, it is necessary to
# replace the default searching paths in this script by our installation
# paths. This is done with 'sed', replacing each ocurrence of '/usr/local'
# by '$(idir)'. After that, each compiled program ('imfit', 'imfit-mcmc'
# and 'makeimage') is copied into the installation directory and an 'rpath'
# is added.
$(ibidir)/imfit-$(imfit-version): \
                $(ibidir)/gsl-$(gsl-version) \
                $(ibidir)/fftw-$(fftw-version) \
                $(ibidir)/scons-$(scons-version) \
                $(ibidir)/cfitsio-$(cfitsio-version)

#	Prepare the source.
	tarball=imfit-$(imfit-version).tar.gz
	$(call import-source, $(imfit-url), $(imfit-checksum))

#	If the C library is in a non-standard location.
	if ! [ x$(SYS_CPATH) = x ]; then
	  headerpath="--header-path=$(SYS_CPATH)"
	fi

#	Unpack and build imfit and its accompanying programs.
	cd $(ddir)
	unpackdir=imfit-$(imfit-version)
	rm -rf $$unpackdir
	tar -xf $(tdir)/$$tarball --no-same-owner --no-same-permissions
	cd $$unpackdir
	$(shsrcdir)/prep-source.sh $(ibdir)
	sed -i 's|/usr/local|$(idir)|g' SConstruct
	sed -i 's|/usr/include|$(idir)/include|g' SConstruct
	sed -i 's|.append(|.insert(0,|g' SConstruct
	scons --no-openmp --no-nlopt \
	      --cc=$(ibdir)/gcc --cpp=$(ibdir)/g++ \
	      --header-path=$(idir)/include $$headerpath \
	      --lib-path=$(idir)/lib imfit
	cp imfit $(ibdir)
	scons --no-openmp --no-nlopt \
	      --cc=$(ibdir)/gcc --cpp=$(ibdir)/g++ \
	      --header-path=$(idir)/include $$headerpath \
	      --lib-path=$(idir)/lib imfit-mcmc
	cp imfit-mcmc $(ibdir)
	scons --no-openmp --no-nlopt \
	      --cc=$(ibdir)/gcc --cpp=$(ibdir)/g++ \
	      --header-path=$(idir)/include $$headerpath \
	      --lib-path=$(idir)/lib makeimage
	cp makeimage $(ibdir)
	cp $(dtexdir)/imfit.tex $(ictdir)/
	if [ -f $(ibdir)/patchelf ]; then
	  for p in imfit imfit-mcmc makeimage; do
	      patchelf --set-rpath $(ildir) $(ibdir)/$$p
	  done
	fi
	cp $(dtexdir)/imfit.tex $(ictdir)/
	cd ..
	rm -rf $$unpackdir
	echo "Imfit $(imfit-version) \citep{imfit2015}" > $@

# Minizip 1.x is actually distributed within zlib. It doesn't have its own
# independent tarball. So we need a custom build, which include the GNU
# Autotools (Autoconf and Automake). Note that Minizip 2.x isn't like this
# any more and has its own independent tarball, but currently the programs
# that depend on Minizip need Minizip 1.x. The instructions to build
# minizip were taken from Arch GNU/Linux.
#
# About deleting the final crypt.h file after installation, see
# https://bugzilla.redhat.com/show_bug.cgi?id=1424609
$(ibidir)/minizip-$(minizip-version): $(ibidir)/automake-$(automake-version)
	tarball=zlib-$(zlib-version).tar.lz
	$(call import-source, $(zlib-url), $(zlib-checksum))
	cd $(ddir)
	unpackdir=minizip-$(minizip-version)
	rm -rf $$unpackdir
	mkdir $$unpackdir
	tar -xf $(tdir)/$$tarball -C$$unpackdir --strip-components=1 \
	    --no-same-owner --no-same-permissions
	cd $$unpackdir
	$(shsrcdir)/prep-source.sh $(ibdir)
	./configure --prefix=$(idir)
	make
	cd contrib/minizip
	cp Makefile Makefile.orig
	cp ../README.contrib readme.txt
	autoreconf --install
	./configure --prefix=$(idir)
	make
	cd ../../
	make test
	cd contrib/minizip
	make -f Makefile.orig test
	make install
	rm $(iidir)/minizip/crypt.h
	cd ../../..
	rm -rf $$unpackdir
	echo "Minizip $(minizip-version)" > $@

# The Astromatic software packages (including missfits, sextractor, swarp
# and others) need the '-fcommon' flag to compile properly on GCC 10 and
# after. Previous to GCC 10, it was the default, but from GCC 10, the
# default is '-fno-common'. This is known by the author (as SExtractor
# issue 12: https://github.com/astromatic/sextractor/issues/12) and will
# hopefully be fixed in the future.
$(ibidir)/missfits-$(missfits-version):
	tarball=missfits-$(missfits-version).tar.gz
	$(call import-source, $(missfits-url), $(missfits-checksum))
	$(call gbuild, missfits-$(missfits-version), static, \
	        CFLAGS="-fcommon")
	cp $(dtexdir)/missfits.tex $(ictdir)/
	echo "MissFITS $(missfits-version) \citep{missfits}" > $@

# Netpbm is an optional prerequisite of Astrometry-net, it contains a lot
# of programs.  This program has a crazy dialogue installation which is
# override using the printf statment. Each '\n' is a new question that the
# installation process ask to the user. We give all answers with a pipe to
# the scripts (configure and install). The questions are different
# depending on the system (tested on GNU/Linux and Mac OS).
$(ibidir)/netpbm-$(netpbm-version): \
                 $(ibidir)/flex-$(flex-version) \
                 $(ibidir)/libpng-$(libpng-version) \
                 $(ibidir)/libx11-$(libx11-version) \
                 $(ibidir)/libjpeg-$(libjpeg-version) \
                 $(ibidir)/libtiff-$(libtiff-version) \
                 $(ibidir)/libxml2-$(libxml2-version)
	tarball=netpbm-$(netpbm-version).tar.lz
	$(call import-source, $(netpbm-url), $(netpbm-checksum))

#	Answers to the configuration questions.
	if [ x$(on_mac_os) = xyes ]; then
	  answers='\n\n$(ildir)\n\n\n\n\n\n$(ildir)/include\n\n$(ildir)/include\n\n$(ildir)/include\nnone\n\n'
	else
	  answers='\n\n\n\n\n\n\n\n\n\n\n\n\nnone\n\n\n'
	fi

#	Go into the temporary directory and unpack the tarball.
	cd $(ddir)
	unpackdir=netpbm-$(netpbm-version)
	rm -rf $$unpackdir
	tar -xf $(tdir)/$$tarball --no-same-owner --no-same-permissions
	cd $$unpackdir
	$(shsrcdir)/prep-source.sh $(ibdir)

#	As of NetPBM 10.73.39 and Flex 2.6.4-410-74a89fd (commit 74a89fd in
#	Flex's Git that is 410 commits after version 2.6.4), there is the
#	following line: 'if (0) yyunput(0, NULL);'. It will cause a crash
#	and is just to avoid compiler warnings! So we are setting the
#	'yyunput(0, NULL);' to the redundant 'yyunput(0, NULL);' to let the
#	compilation finish!
	awk '$$1=="if" && $$2=="(0)"{inif=1} \
	     {if(inif==1 && $$1=="yyunput(0,") \
	        print "{int a=1;}"; else print $$0}' \
	    converter/pbm/thinkjettopbm.l > thinkjettopbm.tmp
	mv thinkjettopbm.tmp converter/pbm/thinkjettopbm.l

#	Pass the answers to the configure script then build and install it.
	printf "$$answers" | ./configure
	make
	rm -rf $(ddir)/$$unpackdir/install
	make package pkgdir=$(ddir)/$$unpackdir/install
	printf "$(ddir)/$$unpackdir/install\n$(idir)\n\n\nN\n\n\n\n\nN\n\n" \
	       | ./installnetpbm
	cd ..
	rm -rf $$unpackdir
	echo "Netpbm $(netpbm-version)" > $@

$(ibidir)/patch-$(patch-version):
	tarball=patch-$(patch-version).tar.gz
	$(call import-source, $(patch-url), $(patch-checksum))
	$(call gbuild, patch-$(patch-version), static, ,V=1)
	echo "GNU Patch $(patch-version)" > $@

$(ibidir)/pcre-$(pcre-version):
	tarball=pcre-$(pcre-version).tar.gz
	$(call import-source, $(pcre-url), $(pcre-checksum))
	$(call gbuild, pcre-$(pcre-version), static, \
	               --enable-pcretest-libreadline \
	               --enable-unicode-properties \
	               --includedir=$(iidir)/pcre \
	               --enable-pcregrep-libbz2 \
	               --enable-pcregrep-libz \
	               , V=1 -j$(numthreads))
	echo "Perl Compatible Regular Expressions $(pcre-version)" > $@

# On macOS 12.3 Monterey with AppleClang 13.1.6.13160021, Plplot 5.15.0
# needs the 'finite' function of 'math.h' which has been deprecated in
# macOS. By manually adding "#define finite isfinite" in 'math.h' like
# below, we fixed this problem but still it can't find 'exit' during the
# configuration phase so we stopped trying to port it to macOS. It means
# that on macOS Plplot is not available. For other OSs it should be fine.
# On macOS, the file 'tmath.h' can be found with 'xcrun --show-sdk-path'.
#
#	cp /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include/math.h \
#	   $(iidir)/math.h
#	awk '{if($$0 ~ /#define isinf\(x\)/) {print "#define finite isfinite"; print $$0} else print $$0 }' \
#            $(iidir)/math.h > $(iidir)/math-tmp.h
#	mv $(iidir)/math-tmp.h $(iidir)/math.h
$(ibidir)/plplot-$(plplot-version): \
          $(ibidir)/cairo-$(cairo-version) \
          $(ibidir)/freetype-$(freetype-version)
	tarball=plplot-$(plplot-version).tar.lz
	$(call import-source, $(plplot-url), $(plplot-checksum))
	$(call cbuild, plplot-$(plplot-version), static, \
                       -DDEFAULT_NO_BINDINGS:BOOL=ON \
                       -DENABLE_cxx:BOOL=ON \
	               -DENABLE_fortran:BOOL=ON \
	               -DDEFAULT_NO_QT_DEVICES:BOOL=ON)
	echo "PLplot $(pcre-version)" > $@

# SCAMP documentation says ATLAS is a mandatory prerequisite for using
# SCAMP. We have ATLAS into the project but there are some problems with the
# libraries that are not yet solved. However, we tried to install it with
# the option --enable-openblas and it worked (same issue happened with
# 'sextractor'.
#
# Plplot in SCAMP cannot be built for macOS. See comments on top of Plplot.
# But if you are not using macOS and want to enable plots, follow the
# steps below:
#
#  1. Add '$(ibidir)/plplot-$(plplot-version)' to the prerequisites
#  2. Remove the option '--enable-plplot=no' from the call of 'gbuild'
$(ibidir)/scamp-$(scamp-version): \
                $(ibidir)/fftw-$(fftw-version) \
                $(ibidir)/openblas-$(openblas-version) \
                $(ibidir)/cdsclient-$(cdsclient-version)
	tarball=scamp-$(scamp-version).tar.lz
	$(call import-source, $(scamp-url), $(scamp-checksum))

#	See comment above 'missfits' for '-fcommon'.
	$(call gbuild, scamp-$(scamp-version), static, \
	           CFLAGS="-fcommon" \
                   --enable-threads \
                   --enable-openblas \
                   --enable-plplot=no \
                   --with-fftw-libdir=$(idir) \
                   --with-fftw-incdir=$(idir)/include \
                   --with-openblas-libdir=$(ildir) \
                   --with-openblas-incdir=$(idir)/include)
	cp $(dtexdir)/scamp.tex $(ictdir)/
	echo "SCAMP $(scamp-version) \citep{scamp}" > $@

# Since 'scons' doesn't use the traditional GNU installation with 'configure'
# and 'make' it is installed manually using 'python'. After 'scons' is
# installed, there is a file, '$(ildir)/scons/SCons/Platform/posix.py', that
# contains several hard coded paths like '/usr/local'. This is bad because it
# causes later problems in the installation of other programs (e.g., 'imfit').
# As a consequence, at the end of the installation we replace the
# '/usr/local' by the one Maneage uses: '$(idir)'. Only one of these paths
# is replaced, the first one: '/usr/local'.
$(ibidir)/scons-$(scons-version): $(ibidir)/python-$(python-version)

#	Prepare the tarball
	tarball=scons-$(scons-version).tar.gz
	$(call import-source, $(scons-url), $(scons-checksum))

#	Unpack and enter the source directory
	cd $(ddir)
	unpackdir=scons-$(scons-version)
	rm -rf $$unpackdir
	tar -xf $(tdir)/$$tarball --no-same-owner --no-same-permissions
	cd $$unpackdir
	$(shsrcdir)/prep-source.sh $(ibdir)

#	Unfortuantely SCons hard-codes its search PATH in its source (to
#	use POSIX operating system defaults)! So the only way to modify it
#	is to edit the source manually! Instead of using SED to replace a
#	fixed string, we are using AWK to replace the value. This is done
#	because in future versions, they may suddenly change the order, and
#	the fixed string won't match with SED. But with AWK, we can be
#	fully ignorant to their default value, and just change the value of
#	the known variable. Some technical notes:
#          - In the shell, the single quote is used to separate AWK's
#	     environment from the shell, we are using '\47' instead of the
#	     single quote.
#          - In Python (the source we are editing) indentation is
#            meaningful, but SPACE is a delimiter in AWK and AWK will
#            remove leading/trailing SPACE from its values. So we'll
#            manually inseart the necessary number of spaces before the
#            modified line.
	awk '{ if($$1=="env[\47ENV\47][\47PATH\47]") \
	         {$$3="\47'$(ibdir)'\47"; print "    "$$0} \
	       else print}' engine/SCons/Platform/posix.py > posix-edited.py
	mv posix-edited.py engine/SCons/Platform/posix.py

#	Install SCons
	python setup.py install
	cd ..
	rm -rf $$unpackdir
	echo "SCons $(scons-version)" > $@

# Sextractor crashes complaining about not linking with some ATLAS
# libraries. But we can override this issue since we have OpenBLAS
# installed, it is just necessary to explicity tell sextractor to use it in
# the configuration step.
$(ibidir)/sextractor-$(sextractor-version): \
                     $(ibidir)/fftw-$(fftw-version) \
                     $(ibidir)/openblas-$(openblas-version)
#	Import the source.
	tarball=sextractor-$(sextractor-version).tar.lz
	$(call import-source, $(sextractor-url), $(sextractor-checksum))

#	Unpack the tarball and enter the directory.
	unpackdir=sextractor-$(sextractor-version)
	cd $(ddir)
	rm -rf $$unpackdir
	tar -xf $(tdir)/$$tarball --no-same-owner --no-same-permissions
	cd $$unpackdir

#	See comment above 'missfits' for '-fcommon'.
	./configure --prefix="$(idir)" \
	            CFLAGS="-fcommon" \
	            --enable-threads \
	            --enable-openblas \
	            --libdir=$(ildir) \
	            --includedir=$(iidir) \
	            --with-openblas-libdir=$(ildir) \
	            --with-openblas-incdir=$(iidir)

#	On macOS we need to manually change 'finite' to 'isfinite' in the
#	header file 'src/levmar/compiler.h'. Until this problem is
#	hopefully fixed in next releases, we are doing it manually using
#	'sed'.  Consequently we are not installing it using 'gbuild'. Once
#	this is fixed upstream, we can use the standard 'gbuild'.
	sed -i -e's|define LM_FINITE finite |define LM_FINITE isfinite |' \
	    src/levmar/compiler.h

#	Build, install and delete the temporary files.
	make V=1
	make install
	cd ..
	rm -rf $$unpackdir

#	Make links for other possibly used names, copy citation and build
#	the final target.
	ln -fs $(ibdir)/sex $(ibdir)/sextractor
	ln -fs $(ibdir)/sex $(ibdir)/source-extractor
	cp $(dtexdir)/sextractor.tex $(ictdir)/
	echo "SExtractor $(sextractor-version) \citep{sextractor}" > $@

$(ibidir)/swarp-$(swarp-version): $(ibidir)/fftw-$(fftw-version)
	tarball=swarp-$(swarp-version).tar.lz
	$(call import-source, $(swarp-url), $(swarp-checksum))

#	See comment above 'missfits' for '-fcommon'.
	$(call gbuild, swarp-$(swarp-version), static, \
	               CFLAGS="-fcommon" \
                       --enable-threads)
	cp $(dtexdir)/swarp.tex $(ictdir)/
	echo "SWarp $(swarp-version) \citep{swarp}" > $@

$(ibidir)/swig-$(swig-version):

#	Option --without-pcre was a suggestion once the configure step was
#	tried and it failed. It was not recommended but it works!  pcr is a
#	dependency of swig
	tarball=swig-$(swig-version).tar.lz
	$(call import-source, $(swig-url), $(swig-checksum))
	$(call gbuild, swig-$(swig-version), static, \
	               --without-pcre --without-tcl)
	echo "Swig $(swig-version)" > $@

# The disables:
#   For macOS:
#       --disable-dependency-tracking
#       --disable-silent-rules
#       --disable-ipcrm
#       --disable-ipcs
#   Because they need root:
#       --disable-mount
#       --disable-wall
#       --disable-su
#   Because they fail on older kernels (tested on Linux 2.6.32)
#   and they need root (to actually use; so are not relevant to
#   Maneage):
#       --disable-swapon
#       --disable-unshare
#       --disable-libmount
#       --disable-mountpoint
#       --enable-libmount-support-mtab
#
# NOTE ON INSTALLATION DIRECTORY: Util-linux libraries are relatively
# low-level and may cause conflicts with system libraries (especilly when
# we don't build the C compiler in Maneage). The precise conflict that
# triggered this was building CMake on macOS (it was expecting the host's
# uuid library, but would crash because of conflicts with the installed
# 'uuid.h' headers of Maneage's 'util-linux'.
#
# Since many programs don't actually need 'util-linux' libraries, to avoid
# low-level conflicts, we will install util-linux in a unique top-level
# directory and put symbolic links of its binaries in the main
# '$(ibdir)'. If any program does need 'util-linux' libraries, they can
# simply add the proper directories to the environment variables, see
# 'fontconfig' for example.
$(ibidir)/util-linux-$(util-linux-version): \
                     $(ibidir)/autoconf-$(autoconf-version) \
                     $(ibidir)/automake-$(automake-version) \
                     | $(idircustom)

#	Import the source.
	tarball=util-linux-$(util-linux-version).tar.lz
	$(call import-source, $(util-linux-url), $(util-linux-checksum))

#	Unpack the source and set it to install in a special directory (as
#	explained above). As shown below, later, we'll put a symbolic link
#	of all the necessary binaries in the main '$(idir)/bin'.
	cd $(ddir)
	tar -xf $(tdir)/$$tarball --no-same-owner --no-same-permissions
	cd util-linux-$(util-linux-version)
	$(shsrcdir)/prep-source.sh $(ibdir)

#       If a patch is necessary, apply it.
	if [ -f $(patchdir)/util-linux-$(util-linux-version)-macos.patch ]; then
	  cp $(patchdir)/util-linux-$(util-linux-version)-macos.patch \
	     util-linux-$(util-linux-version)-macos.patch
	  git apply util-linux-$(util-linux-version)-macos.patch
	fi

#	The 'mkswap' feature needs low-level file system and kernel headers
#	that are not always available (in particular on older Linux
#	kernels). Also, creating SWAP space will need root permissions, so
#	its not something a Maneager may need! Unfortunately there is no
#	configuration option to disable this so we'll have to disable it
#	manually by commenting the relevant files in the
#	'configure.ac'.
	sed -e's|UL_BUILD_INIT(\[mkswap\], \[yes\])|UL_BUILD_INIT(\[mkswap\], \[no\])|' \
	    -i configure.ac

#	'autogen.sh' checks for dependencies, but 'flex' (that is not built
#	in Maneage) is not needed when compiling from tarball (see:
#	https://github.com/util-linux/util-linux/pull/2531#issuecomment-1798020594)
	sed -i '/flex/d' autogen.sh
	./autogen.sh

#	Having updated 'configure.ac', we need to re-generate the
#	'./configure' script with 'autoreconf' (which is part of Autoconf
#	and needs Automake; hence why they are dependencies.
	autoreconf -f

#	Configure Util-linux
	export CONFIG_SHELL=$(ibdir)/bash
	./configure --prefix=$(idircustom)/util-linux \
	            --disable-dependency-tracking \
	            --enable-libmount-support-mtab \
	            --disable-silent-rules \
	            --disable-liblastlog2 \
	            --disable-mountpoint \
	            --disable-libmount \
	            --disable-unshare \
	            --without-systemd \
	            --enable-libuuid \
	            --disable-swapon \
	            --disable-mount \
	            --disable-ipcrm \
	            --disable-ipcs \
	            --disable-wall \
	            --disable-su

#	Build and install it.
	make V=1 -j$(numthreads)
	make install

#	Put a symbolic link to installed programs in main installation
#	directory. If 'sbin' exists in the main installation directory, put
#	util-linux's 'sbin/' directory there too.
	ln -sf $(idircustom)/util-linux/bin/* $(ibdir)/
	if [ -d $(idir)/sbin ]; then
	  ln -sf $(idircustom)/util-linux/sbin/* $(idir)/sbin
	else
	  ln -sf $(idircustom)/util-linux/sbin/* $(idir)/bin
	fi

#	Clean up and write the main target.
	cd ../
	rm -rf util-linux-$(util-linux-version)
	echo "util-Linux $(util-linux-version)" > $@

$(ibidir)/xlsxio-$(xlsxio-version): \
                 $(ibidir)/cmake-$(cmake-version) \
                 $(ibidir)/expat-$(expat-version) \
                 $(ibidir)/minizip-$(minizip-version)
	tarball=xlsxio-$(xlsxio-version).tar.gz
	$(call import-source, $(xlsxio-url), $(xlsxio-checksum))
	if [ x$(on_mac_os) = xyes ]; then
	  export CC=clang
	  export CXX=clang++
	  export LDFLAGS="$$LDFLAGS -lbz2"
	else
	  export LDFLAGS="$$LDFLAGS -lbz2 -lbsd"
	fi
	$(call cbuild, xlsxio-$(xlsxio-version), static, \
	       -DMINIZIP_DIR:PATH=$(idir) \
	       -DMINIZIP_LIBRARIES=$(idir) \
	       -DMINIZIP_INCLUDE_DIRS=$(iidir))
	echo "Correcting internal linking of XLSX I/O executables..."
	if [ "x$(on_mac_os)" = xyes ]; then
	  for f in $(ibdir)/xlsxio_* $(ildir)/libxlsxio_*.dylib; do
	    install_name_tool -change  libxlsxio_read.dylib \
	                      $(ildir)/libxlsxio_read.dylib $$f
	    install_name_tool -change  libxlsxio_write.dylib \
	                      $(ildir)/libxlsxio_write.dylib $$f
	  done
	else
	  for f in $(ibdir)/xlsxio_* $(ildir)/libxlsxio_*.so; do
	     patchelf --set-rpath $(ildir) $$f
	  done
	fi
	echo "Deleting XLSX I/O example files..."
	rm $(ibdir)/example_xlsxio_*
	echo "XLSX I/O $(xlsxio-version)" > $@

# VIM is a text editor which doesn't directly affect processing but can be
# useful in projects during its development, for more see the comment above
# GNU Emacs.
$(ibidir)/vim-$(vim-version):
	tarball=vim-$(vim-version).tar.lz
	$(call import-source, $(vim-url), $(vim-checksum))
	cd $(ddir)
	tar -xf $(tdir)/$$tarball --no-same-owner --no-same-permissions
	unpackdir=vim-$(vim-version)
	cd $(ddir)/$$unpackdir
	$(shsrcdir)/prep-source.sh $(ibdir)
	export CFLAGS="-std=gnu17 $$CFLAGS"
	./configure --prefix=$(idir) \
	            --disable-canberra \
	            --enable-multibyte \
	            --disable-netbeans \
	            --disable-fontset \
	            --disable-gpm \
	            --disable-acl \
	            --disable-gui \
	            --with-x=no
	make -j$(numthreads)
	make install
	cd ..
	rm -rf $$unpackdir
	echo "VIM $(vim-version)" > $@

$(ibidir)/unzip-$(unzip-version): $(ibidir)/gzip-$(gzip-version)
	tarball=unzip-$(unzip-version).tar.lz
	$(call import-source, $(unzip-url), $(unzip-checksum))
	$(call gbuild, unzip-$(unzip-version), static,, \
	               -f unix/Makefile generic \
	               CFLAGS="-DBIG_MEM -DMMAP",,pwd, \
	               -f unix/Makefile generic \
	               BINDIR=$(ibdir) MANDIR=$(idir)/man/man1 )
	echo "Unzip $(unzip-version)" > $@

$(ibidir)/zip-$(zip-version): $(ibidir)/gzip-$(gzip-version)
	tarball=zip-$(zip-version).tar.lz
	$(call import-source, $(zip-url), $(zip-checksum))
	$(call gbuild, zip-$(zip-version), static,, \
	               -f unix/Makefile generic \
	               CFLAGS="-DBIG_MEM -DMMAP",,pwd, \
	               -f unix/Makefile generic \
	               BINDIR=$(ibdir) MANDIR=$(idir)/man/man1 )
	echo "Zip $(zip-version)" > $@





# Since we want to avoid complicating the PATH, we are putting a symbolic
# link of all the TeX Live executables in $(ibdir). But symbolic links are
# hard to track for Make (as a target). Also, TeX in general is optional
# for the project (the processing is the main target, not the generation of
# the final PDF). So we'll make a simple ASCII file called
# 'texlive-ready-tlmgr' and use its contents to mark if we can use it or
# not.
#
# TeX Live mirror
# ---------------
#
# The automatic mirror finding fails sometimes. So we'll manually set it to
# use a fixed mirror. I first tried the LaTeX root webpage
# ('ftp.dante.de'), however, it is far too slow (when I tested it). The
# 'rit.edu' server seems to be a good alternative (given the importance of
# NY on the internet infrastructure).
texlive-url=http://mirrors.rit.edu/CTAN/systems/texlive/tlnet
$(itidir)/texlive-ready-tlmgr: reproduce/software/config/texlive.conf

	tarball=install-tl-unx.tar.gz
	$(call import-source, $(texlive-url), NO-CHECK-SUM)

#	Unpack, enter the directory, and install based on the given
#	configuration (prerequisite of this rule).
	@topdir=$$(pwd)
	cd $(ddir)
	rm -rf install-tl-*
	tar -xf $(tdir)/install-tl-unx.tar.gz \
	    --no-same-owner --no-same-permissions
	cd install-tl-*
	$(shsrcdir)/prep-source.sh $(ibdir)
	sed -e's|@installdir[@]|$(idir)|g' \
	    "$$topdir"/reproduce/software/config/texlive.conf \
	    > texlive.conf

#	We do not build TeXLive from source and for its installation it
#	downloads components from the web internally; and those components
#	can use '/bin/sh' (which will need '$(sys_library_sh_path)').
	export LD_LIBRARY_PATH="$(sys_library_sh_path):$$LD_LIBRARY_PATH"

#	TeX Live's installation may fail due to any reason. But TeX Live is
#	optional (only necessary for building the final PDF). So we don't
#	want the configure script to fail if it can't run.  Possible error
#	messages will be saved into 'log.txt' and if it fails, 'log.txt'
#	will be checked to see if the error is due to the different version
#	of the current tarball and the TeXLive server or something else.
#
#	The problem with versions is this: each installer tarball (that is
#	downloaded and a user may backup) is for a specific version of
#	TeXLive (specified by year, usually around April). So if a user has
#	an old tarball, but the CTAN server has been updated, the script
#	will fail with a message like this:
#
#	      =============================================================
#	      ./install-tl: The TeX Live versions of the local installation
#	      and the repository being accessed are not compatible:
#	              local: 2019
#	         repository: 2020
#	      Perhaps you need to use a different CTAN mirror?
#	      (For more, see the output of install-tl --help, especially the
#	      -repository option.  Online via https://tug.org/texlive/doc.)
#	      =============================================================
#
#	To address this problem, when this happens, we simply download a
#	the most recent tarball, and if it succeeds, we will build TeXLive
#	using that. The old tarball will be preserved, but will have an
#	'-OLD' suffix after it.
	if ./install-tl --profile=texlive.conf -repository \
	                $(texlive-url) 2> log.txt; then

#	  Put a symbolic link of the TeX Live executables in 'ibdir' to
#	  avoid all the complexities of its sub-directories and additions
#	  to PATH.
	  ln -fs $(idir)/texlive/maneage/bin/*/* $(ibdir)/

#	  Register that the build was successful.
	  echo "TeX Live is ready." > $@

#	The build failed!
	else
#	  Print on the command line the error messages during the
#	  installation.
	  cat log.txt

#	  Look for words 'repository:' and 'local:' in 'log.txt' and make
#	  sure that two lines are returned. Note that we need to check for
#	  two lines because one of them may exist, but another may not (in
#	  this case, its not a version conflict scenario).
	  version_check=$$(grep -w 'repository:\|local:' log.txt | wc -l)

#	  If these words exists and two lines are found, there is a
#	  conflict with the main TeXLive version in the tarball and on the
#	  server. So it is necessary to move the old tarball and download
#	  the new one to install it.
	  if [ x"$$version_check" = x2 ]; then

#	    Go back to the top project directory, don't remove the tarball,
#	    just rename it.
	    cd $$topdir
	    mv $(tdir)/install-tl-unx.tar.gz $(tdir)/install-tl-unx-OLD.tar.gz

#	    Download using the script specially defined for this job. If
#	    the download of new tarball success, install it (same lines
#	    than above). If not, record the fail into the target.
	    url=http://mirror.ctan.org/systems/texlive/tlnet
	    tarballurl=$$url/install-tl-unx.tar.gz
	    touch $(lockdir)/download
	    downloader="wget --no-use-server-timestamps -O"
	    if $(downloadwrapper) "$$downloader" \
	                          $(lockdir)/download \
	                          $$tarballurl \
	                          "$(tdir)/install-tl-unx.tar.gz" \
                                 "$(backupservers)"; then
	      cd $(ddir)
	      rm -rf install-tl-*
	      tar -xf $(tdir)/install-tl-unx.tar.gz \
	          --no-same-owner --no-same-permissions
	      cd install-tl-*
	      $(shsrcdir)/prep-source.sh $(ibdir)
	      sed -e's|@installdir[@]|$(idir)|g' \
	          $$topdir/reproduce/software/config/texlive.conf \
	          > texlive.conf
	      if ./install-tl --profile=texlive.conf -repository \
	                      $(texlive-url); then
	        ln -fs $(idir)/texlive/maneage/bin/*/* $(ibdir)/
	        echo "TeX Live is ready." > $@
	      else
	        echo "NOT!" > $@                  # Building failed.
	      fi
	    else
	      echo "NOT!" > $@                    # Download failed.
	    fi
	  else
	    echo "NOT!" > $@                      # Error was not version.
	  fi
	fi

#	Clean up
	cd ..
	rm -rf install-tl-*





# To keep things modular and simple, we'll break up the installation of TeX
# Live itself (only very basic TeX and LaTeX) and the installation of its
# necessary packages into two packages.
#
# Note that we do not build the TeXLive executables (like Biber) from
# source. So in case they need special libraries, we can't choose the
# library version here (for example see [1] and [2]). In such cases there
# is no solution but to manually add the location necessary library to
# LD_LIBRARY_PATH when calling the respective LaTeX command in
# 'reproduce/analysis/make/paper.mk'. Fortunately as of Biber 2.20, it does
# not depend on anything except the C library (all dependencies are now
# statically linked), so problems [1] and [2] will not happen. But this can
# generally happen for any other tool/OS, so it is important to build
# TeXLive from source as soon as possible [3].
#      [1] https://github.com/plk/biber/issues/445
#      [2] https://savannah.nongnu.org/bugs/index.php?63175
#      [3] https://savannah.nongnu.org/task/?15267
$(itidir)/texlive: reproduce/software/config/texlive-packages.conf \
                   $(itidir)/texlive-ready-tlmgr

#	To work with TeX live installation, we'll need the internet.
	@res=$$(cat $(itidir)/texlive-ready-tlmgr)
	if [ x"$$res" = x"NOT!" ]; then
	  echo "" > $@
	else

#	  We do not build TeXLive from source and for its installation it
#	  downloads components from the web internally; and those
#	  components can use '/bin/sh' (which needs 'sys_library_sh_path').
	  export LD_LIBRARY_PATH="$(sys_library_sh_path)"

#	  To update itself, tlmgr needs a backup directory.
	  backupdir=$(idir)/texlive/backups
	  mkdir -p $$backupdir

#	  Before checking LaTeX packages, update tlmgr itself.
	  tlmgr option backupdir $$backupdir
	  tlmgr -repository $(texlive-url) update --self

#	  Install all the extra necessary packages. If LaTeX complains
#	  about not finding a command/file/what-ever/XXXXXX, simply run the
#	  following command to find which package its in, then add it to
#	  the 'texlive-packages' variable of the first prerequisite.
#
#	      ./.local/bin/tlmgr info XXXXXX
#
#	  We are putting a notice, because if there is no internet, 'tlmgr'
#	  just hangs waiting.
	  tlmgr install $(texlive-packages)

#	  Make a symbolic link of all the TeX Live executables in the bin
#	  directory so we don't have to modify 'PATH'.
	  ln -fs $(idir)/texlive/maneage/bin/*/* $(ibdir)/

#	  Correct any reference to '/bin/sh' within the installed LaTeX
#	  files (this is because we do no yet install LaTeX from source):
	  cdir=$$(pwd)
	  cd $(idir)/texlive
	  cd $$cdir

#	  Get all the necessary versions.
	  texlive=$$(pdflatex --version \
	                      | awk 'NR==1' \
	                      | sed 's/.*(\(.*\))/\1/' \
	                      | awk '{print $$NF}');

#	  Package names and versions. Note that all TeXLive packages
#	  don't have a version unfortunately! So we need to also read the
#	  'revision' and 'cat-date' elements and print them incase
#	  version isn't available.
	  tlmgr info $(texlive-packages) --only-installed | awk \
	       '$$1=="package:" { \
	           if(name!=0) \
	             {  \
	               if(version=="") \
	                 { \
	                   if(revision=="") \
	                     { \
	                       if(date="") printf("%s (no version)\n", name); \
	                       else printf("%s %s (date)\n", name, date); \
	                     } \
	                   else
	                     printf("%s %s (revision)\n", name, revision); \
	                 } \
	               else \
	                 printf("%s %s\n", name, version); \
	             } \
	           name=""; version=""; revision=""; date=""; \
	           if($$NF=="tex-gyre") name="texgyre"; \
	           else                 name=$$NF \
	        } \
	        $$1=="cat-date:"    {date=$$NF} \
	        $$1=="cat-version:" {version=$$NF} \
	        $$1=="revision:"    {revision=$$NF}' > $@
	fi
