# Build the project's Python dependencies.
#
# ------------------------------------------------------------------------
#                      !!!!! IMPORTANT NOTES !!!!!
#
# This Makefile will be loaded into 'high-level.mk', which is called by the
# './project configure' script. It is not included into the project
# afterwards.
#
# This Makefile contains instructions to build all the Python-related
# software within the project.
#
# ------------------------------------------------------------------------
#
# Copyright (C) 2019-2025 Raul Infante-Sainz <infantesainz@gmail.com>
# Copyright (C) 2019-2025 Mohammad Akhlaghi <mohammad@akhlaghi.org>
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





# Python enviroment
# -----------------
#
# The main Python environment variable is 'PYTHONPATH'. However, so far we
# have found several other Python-related environment variables on some
# systems which might interfere. To be safe, we are removing all their
# values.
export PYTHONPATH             := $(idir)/lib/python/site-packages
export PYTHONPATH2            := $(PYTHONPATH)
export PYTHONPATH3            := $(PYTHONPATH)
export _LMFILES_              :=
export LOADEDMODULES          :=
export MPI_PYTHON_SITEARCH    :=
export MPI_PYTHON2_SITEARCH   :=
export MPI_PYTHON3_SITEARCH   :=

# Python-specific installation directories.
python-major-version = $(shell echo $(python-version) | awk 'BEGIN{FS="."} \
	                            {printf "%d.%d\n", $$1, $$2}')
# This is for 'installer' (the python installer) itself:
ilibpymajorversion = $(idir)/lib/python$(python-major-version)





# Necessary programs and libraries
# --------------------------------
#
# While this Makefile is for Python programs, in some cases, we need
# certain programs (like Python itself), or libraries for the modules.
$(ibidir)/libffi-$(libffi-version):

#	Prepare the source.
	tarball=libffi-$(libffi-version).tar.lz
	$(call import-source, $(libffi-url), $(libffi-checksum))

#	Build libffi.
	$(call gbuild, libffi-$(libffi-version), , \
                       CFLAGS="-DNO_JAVA_RAW_API=1")

#	On some Fedora systems, libffi installs in 'lib64', not 'lib'. This
#	will cause problems when building setuptools later. To fix this
#	problem, we'll first check if this has indeed happened (it exists
#	under 'lib64', but not under 'lib'). If so, we'll put a copy of the
#	installed libffi libraries in 'lib'.
	if [ -f $(idir)/lib64/libffi.a ] && ! [ -f $(idir)/lib/libffi.a ]; then
	  cp $(idir)/lib64/libffi* $(ildir)/
	fi
	echo "Libffi $(libffi-version)" > $@

$(ibidir)/python-$(python-version): $(ibidir)/libffi-$(libffi-version)

#	Download the source.
	tarball=python-$(python-version).tar.lz
	$(call import-source, $(python-url), $(python-checksum))

#	On Mac systems, the build complains about 'clang' specific
#	features, so we can't use our own GCC build here.
	if [ x$(on_mac_os) = xyes ]; then
	  export CC=clang
	  export CXX=clang++
	fi

#	Unpack the tarball (see below for the necessary modification).
	cd $(ddir)
	unpackdir=python-$(python-version)
	tar -xf $(tdir)/$$tarball
	cd $$unpackdir
	$(shsrcdir)/prep-source.sh $(ibdir)

#	Python's 'setup.py' uses 'os.system' to run shell scripts. On the
#	other hand 'os.system' only runs '/bin/sh' (which has its own
#	libraries to link to and those are blocked at this level). So we
#	need to add an extra line on top of the 'os.system' funciton and
#	put '/usr/lib' in 'LD_LIBRARY_PATH' within Python's environment for
#	system calls (with 'os.putenv'). As of Python 3.13.2 the tarball no
#	longer has an 'setup.py'. But when it did, the change below was
#	necessary.
	if [ -f setup.py ]; then
	   awk '{if(/os.system\(/) \
	          { print "    os.putenv(\"LD_LIBRARY_PATH\", \"$$LD_LIBRARY_PATH:$(sys_library_sh_path)\");"; \
	            print $$0;} \
	         else print $$0}' \
	       setup.py > setup-tmp.py
	   mv setup-tmp.py setup.py
	fi

#	Do the basic installation and delete the temporary directory.
	./configure SHELL=$(ibdir)/bash \
	            --enable-optimizations \
	            --without-ensurepip \
	            --prefix="$(idir)" \
	            --with-system-ffi \
	            --enable-shared
	$(makewshell) -j$(numthreads)
	$(makewshell) install -j$(numthreads)
	cd ..
	rm -rf $$unpackdir

#	Set the necessary environment variables and finish the build.
	ln -sf $(ildir)/python$(python-major-version)  $(ildir)/python
	ln -sf $(ibdir)/python$(python-major-version)  $(ibdir)/python
	ln -sf $(iidir)/python$(python-major-version)m \
	       $(iidir)/python$(python-major-version)
	rm -rf $(ipydir)
	mkdir $(ipydir)
	echo "Python $(python-version)" > $@





# Non-pip Python module installation
# ----------------------------------
#
# Build strategy for python modules as of February 2025, for python 3.13.2.

# This strategy is mostly based on recommendations by E Schwartz
# (ztrawhcse) on #python (Libera Chat), in October 2022 and February
# 2025. Some discussions are on documented in Savannah tasks [1][2]. The
# build strategy for 'python-installer' is inspired by the gentoo script
# 'python_domodule' [3].

# Bootstrap-step: 'gpep517' [4], motivated by PEP 517 [5], together with
# 'python-installer' (module called 'installer') are built without
# dependences on other python packages apart from python itself.  The build
# rules for these two packages do python byte compilation and copy the .py
# and .pyc files into the python install directory. These two packages are
# considered to be 'frontends'.

# Once these two frontends are available, other packages that do building
# tasks, including both backends and alternative frontends or a mix of
# these (in particular: setuptools, meson [6]/ninja-build [7] , flit-core,
# and meson-python), can be built with the 'python-installer' and
# 'gpep517'.  The aims of the various build tools are diverse, include
# ecosystem resilience, reproducibility, build speed and convenience in
# building bigger packages such as numpy, scipy and astropy.

# The python.mk script now includes only three methods: the boot
# build methods of 'python-installer' and 'gpep517'; and the gpep517
# frontend. No method is provided for using 'python-installer' directly;
# it is invoked indirectly by source files of many packages, which
# also give metadata describing information for build methods.

# Why not pip? We do not build any python packages with 'pip' because we
# want to have a fully documented pipeline of (i) the original upstream
# locations of tarballs, (ii) the tarballs' checksums, and (iii) the exact
# sequence of build commands.

# For an alternative viewpoint on a python build strategy, see [8].

# Prerequisite for the pybuild script here: the package's source code
# (tarball) must already be located in the directory 'tdir'.
#
# Arguments:
#   1) Unpack command
#   2) Unpacked directory name after unpacking the tarball
#   3) site.cfg file (optional).
#   4) Official software name (for paper.tex).
#   5) Obligatory parameter: build method (see below):
#      BOOT_INSTALLER - only for 'python-installer'
#      BOOT_GPEP517 - only for 'gpep517'
#      GPEP517 - for any other python package
#
# Hooks:
#   pyhook_before: optional steps before running 'python setup.py build'
#   pyhook_after: optional steps after running 'python setup.py install'

# [1] https://savannah.nongnu.org/task/?16268
# [2] https://savannah.nongnu.org/task/?16625
# [3] https://gitweb.gentoo.org/repo/gentoo.git/tree/eclass/python-utils-r1.eclass#n646
# [4] https://pypi.org/project/gpep517
# [5] https://peps.python.org/pep-0517
# [6] https://mesonbuild.com
# [7] https://ninja-build.org
# [8] https://blog.ganssle.io/articles/2021/10/setup-py-deprecated.html


pybuild = cd $(ddir); \
	packagedir=$(strip $(2)); \
	if (printf "$$packagedir" | grep "[a-z][a-z]"); then rm -rf $$packagedir; fi; \
	printf "\nStarting to install python package with maneage pybuild rule: $(4)\n ..."; \
	if ! $(1) $(tdir)/$$tarball; then \
	  echo; echo "Tar error"; exit 1; \
	fi; \
	cd $$packagedir; \
	if [ "x$(strip $(3))" != x ]; then \
	  sed -e 's|@LIBDIR[@]|'"$(ildir)"'|' \
	      -e 's|@INCDIR[@]|'"$(idir)/include"'|' \
	      $(3) > site.cfg; \
	fi; \
	if type pyhook_before &>/dev/null; then pyhook_before; fi; \
	printf "pybuild option5 = __ %s __\n" "$(strip $(5))"; \
	if [ "x$(strip $(5))" = xBOOT_INSTALLER ]; then \
	   chmod 0644 src/installer/*.py; \
	   mkdir -p $(ilibpymajorversion)/installer; \
	   mkdir -p $(ilibpymajorversion)/installer/__pycache__ ; \
	   mkdir -p $(ilibpymajorversion)/installer/_scripts; \
	   mkdir -p $(ilibpymajorversion)/installer/_scripts/__pycache__ ; \
	   cp -pv src/installer/*.py $(ilibpymajorversion)/installer/; \
	   cp -pv src/installer/_scripts/__init__.py $(ilibpymajorversion)/installer/_scripts/; \
	   cd src/installer/; \
	   python -m compileall -o 1 -o 2 -l -f \
	       -d $(ilibpymajorversion)/installer/ .; \
	   chmod 0644 __pycache__/*.pyc; \
	   cp -pv __pycache__/*.pyc \
	        $(ilibpymajorversion)/installer/__pycache__; \
	   cd -; \
	   cd src/installer/_scripts/; \
	   python -m compileall -o 1 -o 2 -l -f \
	       -d $(ilibpymajorversion)/installer/_scripts/ __init__.py; \
	   chmod 0644 __pycache__/*.pyc; \
	   cp -pv __pycache__/*.pyc \
	        $(ilibpymajorversion)/installer/_scripts/__pycache__; \
	   cd -; \
	elif [ "x$(strip $(5))" = xBOOT_GPEP517 ]; then \
	   chmod 0644 gpep517/*.py; \
	   mkdir -p $(ilibpymajorversion)/gpep517; \
	   mkdir -p $(ilibpymajorversion)/gpep517/__pycache__ ; \
	   cp -pv gpep517/*.py $(ilibpymajorversion)/gpep517/; \
	   cd gpep517/; \
	   python -m compileall -o 1 -o 2 -l -f \
	       -d $(ilibpymajorversion)/gpep517/ .; \
	   chmod 0644 __pycache__/*.pyc; \
	   cp -pv __pycache__/*.pyc \
	        $(ilibpymajorversion)/gpep517/__pycache__; \
	   cd -; \
	elif [ "x$(strip $(5))" = xGPEP517 ]; then \
	   printf "\n\n\n=== python build method: gpep517 ====== "; pwd; \
	   printf "...............\n\n\n"; \
	   python -m gpep517 install-from-source \
	      --prefix "" \
	      --destdir $(idir) \
	      --optimize all; \
	else \
	   printf "Error: Unknown pybuild method for $$packagedir: __ $(strip $(5)) __\n"; \
	   printf "The pybuild 5th parameter should very likely be set "; \
	   printf "to GPEP517 after checking the build rule and "; \
	   printf "upgrading if needed.\n"; \
	   exit 1; \
	fi; \
	if type pyhook_after &>/dev/null; then pyhook_after; fi; \
	cd ..; \
	if (printf "$$packagedir" | grep "[a-z][a-z]"); then rm -fr $$packagedir; fi; \
	echo "$(4)" > $@





# Python modules
# ---------------


# All the necessary Python modules go here.
$(ipydir)/asn1crypto-$(asn1crypto-version): \
                     $(ipydir)/setuptools-$(setuptools-version)
	tarball=asn1crypto-$(asn1crypto-version).tar.gz
	$(call import-source, $(asn1crypto-url), $(asn1crypto-checksum))
	$(call pybuild, tar -xf, asn1crypto-$(asn1crypto-version), , \
	                Asn1crypto $(asn1crypto-version))

$(ipydir)/asteval-$(asteval-version): $(ipydir)/numpy-$(numpy-version)
	tarball=asteval-$(asteval-version).tar.gz
	$(call import-source, $(asteval-url), $(asteval-checksum))
	$(call pybuild, tar -xf, asteval-$(asteval-version), , \
	                ASTEVAL $(asteval-version))

$(ipydir)/astroquery-$(astroquery-version): \
                     $(ipydir)/astropy-$(astropy-version) \
                     $(ipydir)/keyring-$(keyring-version) \
                     $(ipydir)/requests-$(requests-version)
	tarball=astroquery-$(astroquery-version).tar.gz
	$(call import-source, $(astroquery-url), $(astroquery-checksum))
	$(call pybuild, tar -xf, astroquery-$(astroquery-version), , \
	                Astroquery $(astroquery-version))

# Astropy: points to consider about dependencies:
#
# The optional dependency 'h5py' that is necessary for writting tables in
# HDF5 format has been removed from Astropy because on macOS it cannot be
# installed.
#
# 2022-or-older dependencies:
#                  $(ibidir)/expat-$(expat-version) \
#                  $(ipydir)/jinja2-$(jinja2-version) \
#                  $(ipydir)/html5lib-$(html5lib-version) \
#                  $(ipydir)/beautifulsoup4-$(beautifulsoup4-version) \
#
# While the astropy pyproject.toml file says that the astropy build depends
# on numpy, not scipy, and does not depend on matplotlib; the
# runtime is recommended to depend on both scipy and matplotlib.
# In practice, users of astropy will generally expect scipy and matplotlib
# to be available at runtime, so we set these as prerequisites.
$(ipydir)/astropy-$(astropy-version): \
                  $(ipydir)/scipy-$(scipy-version) \
                  $(ipydir)/pyerfa-$(pyerfa-version) \
                  $(ipydir)/pyyaml-$(pyyaml-version) \
                  $(ipydir)/matplotlib-$(matplotlib-version) \
                  $(ipydir)/astropy-iers-data-$(astropy-iers-data-version) \
                  $(ipydir)/extension-helpers-$(extension-helpers-version)

#	Tarball and its preparation.
	tarball=astropy-$(astropy-version).tar.lz
	$(call import-source, $(astropy-url), $(astropy-checksum))

#	Conservatively purge old version (but not astropy_iers,
#	astropy-iers):
	rm -fvr $(idir)/lib/python*/site-packages/astropy/
	rm -fvr $(idir)/lib/python*/site-packages/astropy-[0-9]*-info/
	rm -fv $(idir)/bin/fits{diff,check,header,info,2bitmap}
	rm -fv $(idir)/bin/{samp_hub,showtable,volint,wcslint}

#	Do the basic build.
	$(call pybuild, tar -xf, astropy-$(astropy-version),,, \
	                GPEP517)
	cp -pv $(dtexdir)/astropy.tex $(ictdir)/
	echo "Astropy $(astropy-version) \citep{astropy2013,astropy2018}" > $@

$(ipydir)/astropy-iers-data-$(astropy-iers-data-version): \
                            $(ipydir)/setuptools-$(setuptools-version)
	tarball=astropy-iers-data-$(astropy-iers-data-version).tar.lz
	$(call import-source, $(astropy-iers-data-url), \
	         $(astropy-iers-data-checksum))
	$(call pybuild, tar -xf, \
	                astropy-iers-data-$(astropy-iers-data-version),,, \
	                GPEP517)
	echo "Astropy-Iers-Data $(astropy-iers-data-version)" > $@

$(ipydir)/beautifulsoup4-$(beautifulsoup4-version): \
                         $(ipydir)/soupsieve-$(soupsieve-version)
	tarball=beautifulsoup4-$(beautifulsoup4-version).tar.lz
	$(call import-source, $(beautifulsoup4-url), $(beautifulsoup4-checksum))
	$(call pybuild, tar -xf, beautifulsoup4-$(beautifulsoup4-version), , \
	                BeautifulSoup $(beautifulsoup4-version))

$(ipydir)/beniget-$(beniget-version): \
                  $(ipydir)/gpep517-$(gpep517-version) \
                  $(ipydir)/python-installer-$(python-installer-version)
	tarball=beniget-$(beniget-version).tar.lz
	$(call import-source, $(beniget-url), $(beniget-checksum))
	$(call pybuild, tar -xf, beniget-$(beniget-version), , \
	                Beniget $(beniget-version))

$(ipydir)/certifi-$(certifi-version): \
                  $(ipydir)/gpep517-$(gpep517-version) \
                  $(ipydir)/python-installer-$(python-installer-version)
	tarball=certifi-$(certifi-version).tar.gz
	$(call import-source, $(certifi-url), $(certifi-checksum))
	$(call pybuild, tar -xf, certifi-$(certifi-version), , \
	                Certifi $(certifi-version))

$(ipydir)/cffi-$(cffi-version): \
               $(ibidir)/libffi-$(libffi-version) \
               $(ipydir)/pycparser-$(pycparser-version)
	tarball=cffi-$(cffi-version).tar.lz
	$(call import-source, $(cffi-url), $(cffi-checksum))
	$(call pybuild, tar -xf, cffi-$(cffi-version), ,cffi $(cffi-version))

$(ipydir)/chardet-$(chardet-version): \
                  $(ipydir)/gpep517-$(gpep517-version) \
                  $(ipydir)/python-installer-$(python-installer-version)
	tarball=chardet-$(chardet-version).tar.gz
	$(call import-source, $(chardet-url), $(chardet-checksum))
	$(call pybuild, tar -xf, chardet-$(chardet-version), , \
	                Chardet $(chardet-version))

$(ipydir)/contourpy-$(contourpy-version): \
                     $(ipydir)/pybind11-$(pybind11-version) \
                     $(ipydir)/meson-python-$(meson-python-version)
	tarball=contourpy-$(contourpy-version).tar.lz
	$(call import-source, $(contourpy-url), $(contourpy-checksum))
	$(call pybuild, tar -xf, contourpy-$(contourpy-version), , \
	                Contourpy $(contourpy-version), GPEP517)
	echo "Contourpy $(contourpy-version)" > $@

$(ipydir)/corner-$(corner-version): $(ipydir)/matplotlib-$(matplotlib-version)
	tarball=corner-$(corner-version).tar.gz
	$(call import-source, $(corner-url), $(corner-checksum))
	$(call pybuild, tar -xf, corner-$(corner-version), , \
	                Corner $(corner-version))
	cp $(dtexdir)/corner.tex $(ictdir)/
	echo "Corner $(corner-version) \citep{corner}" > $@

$(ipydir)/cppy-$(cppy-version): \
               $(ipydir)/setuptools-scm-$(setuptools-scm-version)
	tarball=cppy-$(cppy-version).tar.lz
	$(call import-source, $(cppy-url), $(cppy-checksum))
	$(call pybuild, tar -xf, cppy-$(cppy-version), , \
	                Cppy $(cppy-version), GPEP517)

$(ipydir)/cryptography-$(cryptography-version): \
                       $(ipydir)/cffi-$(cffi-version) \
                       $(ipydir)/asn1crypto-$(asn1crypto-version) \
                       $(ipydir)/setuptools-rust-$(setuptools-rust-version)
	tarball=cryptography-$(cryptography-version).tar.lz
	$(call import-source, $(cryptography-url), $(cryptography-checksum))
	$(call pybuild, tar -xf, cryptography-$(cryptography-version), , \
	                Cryptography $(cryptography-version))

$(ipydir)/cycler-$(cycler-version): $(ipydir)/six-$(six-version)
	tarball=cycler-$(cycler-version).tar.lz
	$(call import-source, $(cycler-url), $(cycler-checksum))
	$(call pybuild, tar -xf, cycler-$(cycler-version), , \
	                Cycler $(cycler-version), GPEP517)
	echo "Cycler $(cycler-version)" > $@

$(ipydir)/cython-$(cython-version): \
                 $(ipydir)/python-installer-$(python-installer-version) \
                 $(ipydir)/gpep517-$(gpep517-version) \
                 $(ipydir)/setuptools-$(setuptools-version)
	tarball=cython-$(cython-version).tar.lz
	$(call import-source, $(cython-url), $(cython-checksum))
	$(call pybuild, tar -xf, cython-$(cython-version),,, GPEP517)
	cp -pv $(dtexdir)/cython.tex $(ictdir)/
	echo "Cython $(cython-version) \citep{cython2011}" > $@

$(ipydir)/esutil-$(esutil-version): $(ipydir)/numpy-$(numpy-version)
	export CFLAGS="-std=c++14 $$CFLAGS"
	tarball=esutil-$(esutil-version).tar.lz
	$(call import-source, $(esutil-url), $(esutil-checksum))
	$(call pybuild, tar -xf, esutil-$(esutil-version), , \
	                esutil $(esutil-version))

$(ipydir)/eigency-$(eigency-version): \
                  $(ipydir)/numpy-$(numpy-version) \
                  $(ibidir)/eigen-$(eigen-version) \
                  $(ipydir)/cython-$(cython-version)
	tarball=eigency-$(eigency-version).tar.gz
	$(call import-source, $(eigency-url), $(eigency-checksum))
	$(call pybuild, tar -xf, eigency-$(eigency-version), , \
	                eigency $(eigency-version))

$(ipydir)/emcee-$(emcee-version): \
                $(ipydir)/numpy-$(numpy-version) \
                $(ipydir)/setuptools-scm-$(setuptools-scm-version)
	tarball=emcee-$(emcee-version).tar.gz
	$(call import-source, $(emcee-url), $(emcee-checksum))
	$(call pybuild, tar -xf, emcee-$(emcee-version), , \
	                emcee $(emcee-version))

$(ipydir)/entrypoints-$(entrypoints-version): \
                      $(ipydir)/gpep517-$(gpep517-version) \
                      $(ipydir)/python-installer-$(python-installer-version)
	tarball=entrypoints-$(entrypoints-version).tar.gz
	$(call import-source, $(entrypoints-url), $(entrypoints-checksum))
	$(call pybuild, tar -xf, entrypoints-$(entrypoints-version), , \
	                EntryPoints $(entrypoints-version))

$(ipydir)/extension-helpers-$(extension-helpers-version): \
                    $(ipydir)/setuptools-scm-$(setuptools-scm-version)
	tarball=extension-helpers-$(extension-helpers-version).tar.lz
	$(call import-source, $(extension-helpers-url), \
	      $(extension-helpers-checksum))
	$(call pybuild, tar -xf, \
	                extension-helpers-$(extension-helpers-version),, \
	                Extension-Helpers $(extension-helpers-version), GPEP517)

$(ipydir)/flake8-$(flake8-version): \
                 $(ipydir)/pyflakes-$(pyflakes-version) \
                 $(ipydir)/pycodestyle-$(pycodestyle-version)
	tarball=flake8-$(flake8-version).tar.gz
	$(call import-source, $(flake8-url), $(flake8-checksum))
	$(call pybuild, tar -xf, flake8-$(flake8-version), , \
	                Flake8 $(flake8-version))

$(ipydir)/flit-core-$(flit-core-version): \
                     $(ipydir)/gpep517-$(gpep517-version) \
                     $(ipydir)/python-installer-$(python-installer-version)
	tarball=flit-core-$(flit-core-version).tar.lz
	$(call import-source, $(flit-core-url), $(flit-core-checksum))
	$(call pybuild, tar -xf, flit-core-$(flit-core-version), , \
	                Flit-core $(flit-core-version), GPEP517)

# Although cython is not an obligatory prerequisite of fonttools, we force
# it as a prerequisite for reproducibility; otherwise build parallelism may
# lead to some builds with and some builds without cython, depending on how
# many cpus the host machine has.
$(ipydir)/fonttools-$(fonttools-version): \
                     $(ipydir)/cython-$(cython-version) \
                     $(ipydir)/setuptools-$(setuptools-version)
	tarball=fonttools-$(fonttools-version).tar.lz
	$(call import-source, $(fonttools-url), $(fonttools-checksum))
	$(call pybuild, tar -xf, fonttools-$(fonttools-version), , \
	                fonttools $(fonttools-version), GPEP517)

$(ipydir)/future-$(future-version): \
                 $(ipydir)/gpep517-$(gpep517-version) \
                 $(ipydir)/python-installer-$(python-installer-version)
	tarball=future-$(future-version).tar.gz
	$(call import-source, $(future-url), $(future-checksum))
	$(call pybuild, tar -xf, future-$(future-version), , \
	                Future $(future-version))

$(ipydir)/galsim-$(galsim-version): \
                 $(ipydir)/future-$(future-version) \
                 $(ipydir)/astropy-$(astropy-version) \
                 $(ipydir)/eigency-$(eigency-version) \
                 $(ipydir)/pybind11-$(pybind11-version) \
                 $(ipydir)/lsstdesccoord-$(lsstdesccoord-version)
	tarball=galsim-$(galsim-version).tar.lz
	$(call import-source, $(galsim-url), $(galsim-checksum))
	$(call pybuild, tar -xf, galsim-$(galsim-version))
	cp $(dtexdir)/galsim.tex $(ictdir)/
	echo "Galsim $(galsim-version) \citep{galsim}" > $@

$(ipydir)/gast-$(gast-version): \
               $(ipydir)/gpep517-$(gpep517-version) \
               $(ipydir)/python-installer-$(python-installer-version)
	tarball=gast-$(gast-version).tar.lz
	$(call import-source, $(gast-url), $(gast-checksum))
	$(call pybuild, tar -xf, gast-$(gast-version), , \
	                Gast $(gast-version))

$(ipydir)/gpep517-$(gpep517-version): \
                     $(ibidir)/python-$(python-version)
	tarball=gpep517-$(gpep517-version).tar.lz
	$(call import-source, $(gpep517-url), $(gpep517-checksum))
	$(call pybuild, tar -xf, \
	                gpep517-$(gpep517-version), \
	                , \
	                gpep517 $(gpep517-version), \
	                BOOT_GPEP517)
	echo "gpep517 $(gpep517-version)" > $@

$(ipydir)/h5py-$(h5py-version): \
               $(ipydir)/six-$(six-version) \
               $(ibidir)/hdf5-$(hdf5-version) \
               $(ipydir)/numpy-$(numpy-version) \
               $(ipydir)/cython-$(cython-version) \
               $(ipydir)/mpi4py-$(mpi4py-version) \
               $(ipydir)/pypkgconfig-$(pypkgconfig-version)
	export HDF5_MPI=ON
	export HDF5_DIR=$(ildir)
	tarball=h5py-$(h5py-version).tar.gz
	$(call import-source, $(h5py-url), $(h5py-checksum))
	$(call pybuild, tar -xf, h5py-$(h5py-version), , \
	                h5py $(h5py-version))

# 'healpy' is actually installed as part of the HEALPix package. It will be
# installed with its C/C++ libraries if any other Python library is
# requested with HEALPix. So actually calling for 'healpix' (when 'healpix'
# is requested) is not necessary. But some users might not know about this
# and just ask for 'healpy'. To avoid confusion in such cases, we'll just
# set 'healpy' to be dependent on 'healpix' and not download any tarball
# for it, or write anything in the final target.
$(ipydir)/healpy-$(healpy-version): $(ibidir)/healpix-$(healpix-version)
	touch $@

$(ipydir)/html5lib-$(html5lib-version): \
                   $(ipydir)/six-$(six-version) \
                   $(ipydir)/webencodings-$(webencodings-version)
	tarball=html5lib-$(html5lib-version).tar.gz
	$(call import-source, $(html5lib-url), $(html5lib-checksum))
	$(call pybuild, tar -xf, html5lib-$(html5lib-version), , \
	                HTML5lib $(html5lib-version))

$(ipydir)/idna-$(idna-version): \
               $(ipydir)/gpep517-$(gpep517-version) \
               $(ipydir)/python-installer-$(python-installer-version)
	tarball=idna-$(idna-version).tar.gz
	$(call import-source, $(idna-url), $(idna-checksum))
	$(call pybuild, tar -xf, idna-$(idna-version), , \
	       idna $(idna-version))

$(ipydir)/jeepney-$(jeepney-version): \
                     $(ipydir)/gpep517-$(gpep517-version) \
                     $(ipydir)/python-installer-$(python-installer-version)
	tarball=jeepney-$(jeepney-version).tar.gz
	$(call import-source, $(jeepney-url), $(jeepney-checksum))
	$(call pybuild, tar -xf, jeepney-$(jeepney-version), , \
	                Jeepney $(jeepney-version))

$(ipydir)/jinja2-$(jinja2-version): $(ipydir)/markupsafe-$(markupsafe-version)
	tarball=jinja2-$(jinja2-version).tar.lz
	$(call import-source, $(jinja2-url), $(jinja2-checksum))
	$(call pybuild, tar -xf, jinja2-$(jinja2-version), , \
	                Jinja2 $(jinja2-version))

$(ipydir)/keyring-$(keyring-version): \
                  $(ipydir)/entrypoints-$(entrypoints-version) \
                  $(ipydir)/secretstorage-$(secretstorage-version) \
                  $(ipydir)/setuptools-scm-$(setuptools-scm-version)
	tarball=keyring-$(keyring-version).tar.gz
	$(call import-source, $(keyring-url), $(keyring-checksum))
	$(call pybuild, tar -xf, keyring-$(keyring-version), , \
	                Keyring $(keyring-version))

$(ipydir)/kiwisolver-$(kiwisolver-version): \
                     $(ipydir)/cppy-$(cppy-version) \
                     $(ipydir)/setuptools-scm-$(setuptools-scm-version)
	tarball=kiwisolver-$(kiwisolver-version).tar.lz
	$(call import-source, $(kiwisolver-url), $(kiwisolver-checksum))
	$(call pybuild, tar -xf, kiwisolver-$(kiwisolver-version), , \
	                Kiwisolver $(kiwisolver-version), GPEP517)
	cp -pv $(dtexdir)/kiwisolver.tex $(ictdir)/
	echo "Kiwisolver $(kiwisolver-version) \citep{cassowary2001}" > $@

$(ipydir)/lmfit-$(lmfit-version): \
                $(ipydir)/six-$(six-version) \
                $(ipydir)/scipy-$(scipy-version) \
                $(ipydir)/emcee-$(emcee-version) \
                $(ipydir)/corner-$(corner-version) \
                $(ipydir)/asteval-$(asteval-version) \
                $(ipydir)/matplotlib-$(matplotlib-version) \
                $(ipydir)/uncertainties-$(uncertainties-version)
	tarball=lmfit-$(lmfit-version).tar.gz
	$(call import-source, $(lmfit-url), $(lmfit-checksum))
	$(call pybuild, tar -xf, lmfit-$(lmfit-version), , \
	                LMFIT $(lmfit-version))

$(ipydir)/lsstdesccoord-$(lsstdesccoord-version): \
                        $(ipydir)/cffi-$(cffi-version) \
                        $(ipydir)/numpy-$(numpy-version) \
                        $(ipydir)/future-$(future-version)
	tarball=lsstdesccoord-$(lsstdesccoord-version).tar.gz
	$(call import-source, $(lsstdesccoord-url), $(lsstdesccoord-checksum))
	$(call pybuild, tar -xf, LSSTDESC.Coord-$(lsstdesccoord-version), , \
	                LSSTDESC.Coord $(lsstdesccoord-version))

$(ipydir)/markupsafe-$(markupsafe-version): \
                     $(ipydir)/gpep517-$(gpep517-version) \
                     $(ipydir)/python-installer-$(python-installer-version)
	tarball=markupsafe-$(markupsafe-version).tar.lz
	$(call import-source, $(markupsafe-url), $(markupsafe-checksum))
	$(call pybuild, tar -xf, markupsafe-$(markupsafe-version), , \
	                MarkupSafe $(markupsafe-version))

$(ipydir)/matplotlib-$(matplotlib-version): \
                     $(itidir)/texlive \
                     $(ipydir)/numpy-$(numpy-version) \
                     $(ipydir)/cycler-$(cycler-version) \
                     $(ipydir)/pillow-$(pillow-version) \
                     $(ipydir)/fonttools-$(fonttools-version) \
                     $(ipydir)/contourpy-$(contourpy-version) \
                     $(ipydir)/kiwisolver-$(kiwisolver-version) \
                     $(ipydir)/python-dateutil-$(python-dateutil-version)

#	Prepare the source.
	tarball=matplotlib-$(matplotlib-version).tar.lz
	$(call import-source, $(matplotlib-url), $(matplotlib-checksum))

#	On Mac systems, the build complains about 'clang' specific
#	features, so we can't use our own GCC build here.
	if [ x$(on_mac_os) = xyes ]; then
	  export CC=clang
	  export CXX=clang++
	fi
	$(call pybuild, tar -xf, matplotlib-$(matplotlib-version),,, GPEP517)
	cp $(dtexdir)/matplotlib.tex $(ictdir)/
	echo "Matplotlib $(matplotlib-version) \citep{matplotlib2007}" > $@

$(ipydir)/meson-$(meson-version): \
                         $(ibidir)/ninjabuild-$(ninjabuild-version) \
                         $(ipydir)/setuptools-$(setuptools-version)
	tarball=meson-$(meson-version).tar.lz
	$(call import-source, $(meson-url), $(meson-checksum))
	$(call pybuild, tar -xf, meson-$(meson-version), , \
	                Meson $(meson-version), GPEP517)
	echo "Meson $(meson-version)" > $@

# The 'meson-python' package may be helpful or requred for some packages.
$(ipydir)/meson-python-$(meson-python-version): \
                         $(ipydir)/meson-$(meson-version) \
                         $(ipydir)/packaging-$(packaging-version) \
                         $(ipydir)/pyproject-metadata-$(pyproject-metadata-version)
	tarball=meson-python-$(meson-python-version).tar.lz
	$(call import-source, $(meson-python-url), $(meson-python-checksum))
	$(call pybuild, tar -xf, meson-python-$(meson-python-version), , \
	                Meson-python $(meson-python-version), GPEP517)
	echo "Meson-Python $(meson-python-version)" > $@

$(ipydir)/mpi4py-$(mpi4py-version): \
                 $(ipydir)/gpep517-$(gpep517-version) \
                 $(ibidir)/openmpi-$(openmpi-version) \
                 $(ipydir)/python-installer-$(python-installer-version)
	tarball=mpi4py-$(mpi4py-version).tar.lz
	$(call import-source, $(mpi4py-url), $(mpi4py-checksum))
	$(call pybuild, tar -xf, mpi4py-$(mpi4py-version))
	cp $(dtexdir)/mpi4py.tex $(ictdir)/
	echo "mpi4py $(mpi4py-version) \citep{mpi4py2011}" > $@

$(ipydir)/mpmath-$(mpmath-version): \
                     $(ipydir)/gpep517-$(gpep517-version) \
                     $(ipydir)/python-installer-$(python-installer-version)
	tarball=mpmath-$(mpmath-version).tar.gz
	$(call import-source, $(mpmath-url), $(mpmath-checksum))
	$(call pybuild, tar -xf, mpmath-$(mpmath-version), , \
	                mpmath $(mpmath-version))

# Until 2025-02-22: we had 'export CFLAGS="--std=c99 $$CFLAGS"' before
# calling pybuild; but that doesn't seem to be necessary.
$(ipydir)/numpy-$(numpy-version): \
                $(ipydir)/cython-$(cython-version) \
                $(ibidir)/openblas-$(openblas-version) \
                $(ipydir)/pybind11-$(pybind11-version) \
                $(ipydir)/meson-python-$(meson-python-version)
	tarball=numpy-$(numpy-version).tar.lz
	$(call import-source, $(numpy-url), $(numpy-checksum))
	if [ x$(on_mac_os) = xyes ]; then
	  export LDFLAGS="$(LDFLAGS) -undefined dynamic_lookup -bundle"
	fi
	conf="$$(pwd)/reproduce/software/config/numpy-scipy.cfg"
	$(call pybuild, tar -xf, numpy-$(numpy-version),$$conf, \
	                Numpy $(numpy-version), GPEP517)
	cp $(dtexdir)/numpy.tex $(ictdir)/
	echo "Numpy $(numpy-version) \citep{numpy2020}" > $@

$(ipydir)/packaging-$(packaging-version): \
                    $(ipydir)/pyparsing-$(pyparsing-version)
	tarball=packaging-$(packaging-version).tar.lz
	$(call import-source, $(packaging-url), $(packaging-checksum))
	$(call pybuild, tar -xf, packaging-$(packaging-version), , \
	                Packaging $(packaging-version), GPEP517)

$(ipydir)/pexpect-$(pexpect-version): \
                  $(ipydir)/gpep517-$(gpep517-version) \
                  $(ipydir)/python-installer-$(python-installer-version)
	tarball=pexpect-$(pexpect-version).tar.gz
	$(call import-source, $(pexpect-url), $(pexpect-checksum))
	$(call pybuild, tar -xf, pexpect-$(pexpect-version), , \
	                Pexpect $(pexpect-version))

$(ipydir)/pillow-$(pillow-version): $(ibidir)/libjpeg-$(libjpeg-version) \
                 $(ipydir)/setuptools-$(setuptools-version)
	tarball=pillow-$(pillow-version).tar.lz
	$(call import-source, $(pillow-url), $(pillow-checksum))
	$(call pybuild, tar -xf, pillow-$(pillow-version), , \
	                Pillow $(pillow-version), GPEP517)

# This should normally not be used, because it's a front-end that obstructs
# reproducibility - source URL; checksum of the tarball; build rule.
# $(ipydir)/pip-$(pip-version): \
#                      $(ipydir)/python-installer-$(python-installer-version) \
#                      $(ipydir)/wheel-$(wheel-version)
# 	tarball=pip-$(pip-version).tar.gz
# 	$(call import-source, $(pip-url), $(pip-checksum))
# 	$(call pybuild, tar -xf, pip-$(pip-version), , \
# 	                PiP $(pip-version))

$(ipydir)/ply-$(ply-version): \
              $(ipydir)/gpep517-$(gpep517-version) \
              $(ipydir)/python-installer-$(python-installer-version)
	tarball=ply-$(ply-version).tar.lz
	$(call import-source, $(ply-url), $(ply-checksum))
	$(call pybuild, tar -xf, ply-$(ply-version), , \
	                ply $(ply-version))

$(ipydir)/pycodestyle-$(pycodestyle-version): \
                     $(ipydir)/gpep517-$(gpep517-version) \
                     $(ipydir)/python-installer-$(python-installer-version)
	tarball=pycodestyle-$(pycodestyle-version).tar.gz
	$(call import-source, $(pycodestyle-url), $(pycodestyle-checksum))
	$(call pybuild, tar -xf, pycodestyle-$(pycodestyle-version), , \
	                pycodestyle $(pycodestyle-version))

$(ipydir)/pybind11-$(pybind11-version): \
                   $(ibidir)/eigen-$(eigen-version) \
                   $(ibidir)/boost-$(boost-version) \
                   $(ipydir)/gpep517-$(gpep517-version) \
                   $(ipydir)/python-installer-$(python-installer-version)
	tarball=pybind11-$(pybind11-version).tar.lz
	$(call import-source, $(pybind11-url), $(pybind11-checksum))
	pyhook_after() {
	   cp -pvr pybind11/include/pybind11 \
	        $(iidir)/python$(python-major-version)m/
	}
	$(call pybuild, tar -xf, pybind11-$(pybind11-version), , \
	                pybind11 $(pybind11-version), GPEP517)
	echo "Pybind11 $(pybind11-version)" > $@

$(ipydir)/pycparser-$(pycparser-version): \
                     $(ipydir)/gpep517-$(gpep517-version) \
                     $(ipydir)/python-installer-$(python-installer-version)
	tarball=pycparser-$(pycparser-version).tar.gz
	$(call import-source, $(pycparser-url), $(pycparser-checksum))
	$(call pybuild, tar -xf, pycparser-$(pycparser-version), , \
	                pycparser $(pycparser-version))

$(ipydir)/pyerfa-$(pyerfa-version): \
                 $(ipydir)/numpy-$(numpy-version) \
                 $(ipydir)/setuptools-scm-$(setuptools-scm-version)
	tarball=pyerfa-$(pyerfa-version).tar.lz
	$(call import-source, $(pyerfa-url), $(pyerfa-checksum))
	$(call pybuild, tar -xf, pyerfa-$(pyerfa-version), , \
	                PyERFA $(pyerfa-version), GPEP517)

$(ipydir)/pyflakes-$(pyflakes-version): \
                $(ipydir)/gpep517-$(gpep517-version) \
                $(ipydir)/python-installer-$(python-installer-version)
	tarball=pyflakes-$(pyflakes-version).tar.gz
	$(call import-source, $(pyflakes-url), $(pyflakes-checksum))
	$(call pybuild, tar -xf, pyflakes-$(pyflakes-version), , \
	                pyflakes $(pyflakes-version))

$(ipydir)/pyparsing-$(pyparsing-version): \
                    $(ipydir)/gpep517-$(gpep517-version) \
                    $(ipydir)/flit-core-$(flit-core-version) \
                    $(ipydir)/python-installer-$(python-installer-version)
	tarball=pyparsing-$(pyparsing-version).tar.lz
	$(call import-source, $(pyparsing-url), $(pyparsing-checksum))
	$(call pybuild, tar -xf, pyparsing-$(pyparsing-version), , \
	                PyParsing $(pyparsing-version), GPEP517)

$(ipydir)/pypkgconfig-$(pypkgconfig-version): \
                      $(ipydir)/gpep517-$(gpep517-version) \
                      $(ipydir)/python-installer-$(python-installer-version)
	tarball=pkgconfig-$(pypkgconfig-version).tar.gz
	$(call import-source, $(pypkgconfig-url), $(pypkgconfig-checksum))
	$(call pybuild, tar -xf, pkgconfig-$(pypkgconfig-version), ,
	                pkgconfig $(pypkgconfig-version))

$(ipydir)/pyproject-metadata-$(pyproject-metadata-version): \
                    $(ipydir)/gpep517-$(gpep517-version) \
                    $(ipydir)/flit-core-$(flit-core-version) \
                    $(ipydir)/python-installer-$(python-installer-version)
	tarball=pyproject-metadata-$(pyproject-metadata-version).tar.lz
	$(call import-source, $(pyproject-metadata-url), $(pyproject-metadata-checksum))
	$(call pybuild, tar -xf, \
	            pyproject-metadata-$(pyproject-metadata-version),,, GPEP517)

$(ipydir)/python-dateutil-$(python-dateutil-version): \
                          $(ipydir)/setuptools-scm-$(setuptools-scm-version)
	tarball=python-dateutil-$(python-dateutil-version).tar.lz
	$(call import-source, $(python-dateutil-url), $(python-dateutil-checksum))
	$(call pybuild, tar -xf, python-dateutil-$(python-dateutil-version), , \
	                python-dateutil $(python-dateutil-version), GPEP517)

$(ipydir)/python-installer-$(python-installer-version): \
                           $(ibidir)/python-$(python-version)

#	Prepare the tarball.
	tarball=python-installer-$(python-installer-version).tar.lz
	$(call import-source, $(python-installer-url), $(python-installer-checksum))

#	Modify the line in the source that will cause a crash when a
#	to-be-installed file already exists in the installation path. This
#	is very important for Python packages in Maneage (when a dependency
#	is updated, the package needs to be re-built, but that would cause
#	due to this line).
	pyhook_before(){
	  mv -v src/installer/destinations.py src/installer/destinations.py.orig; \
	  sed -e 's/\(raise FileExistsError.message.\)/## \1/' \
	     src/installer/destinations.py.orig > src/installer/destinations.py
	}

#	Build the Python installer.
	$(call pybuild, tar -xf, \
	                python-installer-$(python-installer-version),,, \
	                BOOT_INSTALLER)
	echo "Python-installer $(python-installer-version)" > $@

$(ipydir)/pythran-$(pythran-version): \
                  $(ipydir)/ply-$(ply-version) \
                  $(ipydir)/gast-$(gast-version) \
                  $(ibidir)/boost-$(boost-version) \
                  $(ipydir)/beniget-$(beniget-version) \
                  $(ipydir)/setuptools-scm-$(setuptools-scm-version)
	tarball=pythran-$(pythran-version).tar.lz
	$(call import-source, $(pythran-url), $(pythran-checksum))
	$(call pybuild, tar -xf, pythran-$(pythran-version), , \
	                pythran $(pythran-version))

$(ipydir)/pyyaml-$(pyyaml-version): \
                 $(ibidir)/yaml-$(yaml-version) \
                 $(ipydir)/cython-$(cython-version)
	tarball=pyyaml-$(pyyaml-version).tar.lz
	$(call import-source, $(pyyaml-url), $(pyyaml-checksum))
	$(call pybuild, tar -xf, pyyaml-$(pyyaml-version), , \
	                PyYAML $(pyyaml-version), GPEP517)

$(ipydir)/requests-$(requests-version): $(ipydir)/idna-$(idna-version) \
                   $(ipydir)/numpy-$(numpy-version) \
                   $(ipydir)/certifi-$(certifi-version) \
                   $(ipydir)/chardet-$(chardet-version) \
                   $(ipydir)/urllib3-$(urllib3-version)
	tarball=requests-$(requests-version).tar.gz
	$(call import-source, $(requests-url), $(requests-checksum))
	$(call pybuild, tar -xf, requests-$(requests-version), , \
	                Requests $(requests-version))

# 'pythran' is disabled in the build of Scipy because of complications it
# caused on some systems. We explicitly disable it using a preprocessor
# directive. 'Pythran' can in principle speed up compilation of scientific
# software [1][2].
# [1] https://pythran.readthedocs.io/en/latest
# [2] https://docs.scipy.org/doc/scipy-1.15.2/dev/roadmap-detailed.html
$(ipydir)/scipy-$(scipy-version): \
                  $(ipydir)/numpy-$(numpy-version) \
                  $(ipydir)/pybind11-$(pybind11-version)
	tarball=scipy-$(scipy-version).tar.lz
	$(call import-source, $(scipy-url), $(scipy-checksum))
	if [ x$(on_mac_os) = xyes ]; then
	  export LDFLAGS="$(LDFLAGS) -undefined dynamic_lookup -bundle"
	else
#	  Same question as for 'numpy': why '-shared'? This obstructs
#	  the meson build.
#	  export LDFLAGS="$(LDFLAGS) -shared"
	  :
	fi
	conf="$$(pwd)/reproduce/software/config/numpy-scipy.cfg"

#	Disable pythran: see
#	https://docs.scipy.org/doc/scipy-1.15.2/dev/roadmap-detailed.html#use-of-pythran
#	export SCIPY_USE_PYTHRAN=0 # deprecated(?)
#	Option 1: Hack the source:
	pyhook_before() {
	   mv -iv meson.options meson.options.orig; \
	   sed -e 's/\(use-pythran.*value: *\)true/\1false/' \
	        meson.options.orig > meson.options
	}

#	Option 2: pass the string
#	   --config-json='{"setup-args": "-Duse-pythran=false"}'
#	to gpep517 with correct escaping of single and double quotes.
#	Not tried as of 2025-02-25.
	$(call pybuild, tar -xf, scipy-$(scipy-version),$$conf,, GPEP517)
	cp $(dtexdir)/scipy.tex $(ictdir)/
	echo "Scipy $(scipy-version) \citep{scipy2020}" > $@

$(ipydir)/secretstorage-$(secretstorage-version): \
                        $(ipydir)/jeepney-$(jeepney-version) \
                        $(ipydir)/cryptography-$(cryptography-version)
	tarball=secretstorage-$(secretstorage-version).tar.gz
	$(call import-source, $(secretstorage-url), $(secretstorage-checksum))
	$(call pybuild, tar -xf, SecretStorage-$(secretstorage-version), , \
	                SecretStorage $(secretstorage-version))

$(ipydir)/semantic-version-$(semantic-version-version): \
                           $(ipydir)/setuptools-$(setuptools-version)
	tarball=semantic-version-$(semantic-version-version).tar.lz
	$(call import-source, $(semantic-version-url), \
	         $(semantic-version-checksum))
	$(call pybuild, tar -xf, \
	                semantic-version-$(semantic-version-version), , \
	                Semantic-version $(semantic-version-version), GPEP517)

$(ipydir)/setuptools-$(setuptools-version): \
                     $(ipydir)/gpep517-$(gpep517-version) \
                     $(ipydir)/python-installer-$(python-installer-version)
	tarball=setuptools-$(setuptools-version).tar.lz
	$(call import-source, $(setuptools-url), $(setuptools-checksum))
	$(call pybuild, tar -xf, setuptools-$(setuptools-version), , \
	                Setuptools $(setuptools-version), GPEP517)

$(ipydir)/setuptools-scm-$(setuptools-scm-version): \
                         $(ipydir)/setuptools-$(setuptools-version)
	tarball=setuptools-scm-$(setuptools-scm-version).tar.lz
	$(call import-source, $(setuptools-scm-url), $(setuptools-scm-checksum))
	$(call pybuild, tar -xf, setuptools-scm-$(setuptools-scm-version), , \
	                Setuptools-scm $(setuptools-scm-version), GPEP517)

$(ipydir)/setuptools-rust-$(setuptools-rust-version): \
                          $(ipydir)/setuptools-scm-$(setuptools-scm-version) \
                          $(ipydir)/semantic-version-$(semantic-version-version)
	tarball=setuptools-rust-$(setuptools-rust-version).tar.lz
	$(call import-source, $(setuptools-rust-url), \
	                      $(setuptools-rust-checksum))
	$(call pybuild, tar -xf, setuptools-rust-$(setuptools-rust-version), , \
	                Setuptools-rust $(setuptools-rust-version), GPEP517)

$(ipydir)/sip_tpv-$(sip_tpv-version): \
                  $(ipydir)/sympy-$(sympy-version) \
                  $(ipydir)/astropy-$(astropy-version)
	tarball=sip_tpv-$(sip_tpv-version).tar.gz
	$(call import-source, $(sip_tpv-url), $(sip_tpv-checksum))
	$(call pybuild, tar -xf, sip_tpv-$(sip_tpv-version), ,)
	cp $(dtexdir)/sip_tpv.tex $(ictdir)/
	echo "sip_tpv $(sip_tpv-version) \citep{sip-tpv}" > $@

$(ipydir)/six-$(six-version): \
                     $(ipydir)/setuptools-$(setuptools-version)
	tarball=six-$(six-version).tar.lz
	$(call import-source, $(six-url), $(six-checksum))
	$(call pybuild, tar -xf, six-$(six-version), , \
	                Six $(six-version), GPEP517)
	echo "Six $(six-version)" > $@

$(ipydir)/soupsieve-$(soupsieve-version): \
                    $(ipydir)/setuptools-$(setuptools-version) \
                    $(ipydir)/setuptools-scm-$(setuptools-scm-version)
	tarball=soupsieve-$(soupsieve-version).tar.gz
	$(call import-source, $(soupsieve-url), $(soupsieve-checksum))
	$(call pybuild, tar -xf, soupsieve-$(soupsieve-version), , \
	                SoupSieve $(soupsieve-version))

$(ipydir)/sympy-$(sympy-version): $(ipydir)/mpmath-$(mpmath-version)
	tarball=sympy-$(sympy-version).tar.gz
	$(call import-source, $(sympy-url), $(sympy-checksum))
	$(call pybuild, tar -xf, sympy-$(sympy-version), ,)
	cp $(dtexdir)/sympy.tex $(ictdir)/
	echo "SymPy $(sympy-version) \citep{sympy}" > $@

$(ipydir)/uncertainties-$(uncertainties-version): $(ipydir)/numpy-$(numpy-version)
	tarball=uncertainties-$(uncertainties-version).tar.lz
	$(call import-source, $(uncertainties-url), $(uncertainties-checksum))
	$(call pybuild, tar -xf, uncertainties-$(uncertainties-version), , \
	                uncertainties $(uncertainties-version))

$(ipydir)/urllib3-$(urllib3-version): \
                  $(ipydir)/gpep517-$(gpep517-version) \
                  $(ipydir)/python-installer-$(python-installer-version)
	tarball=urllib3-$(urllib3-version).tar.gz
	$(call import-source, $(urllib3-url), $(urllib3-checksum))
	$(call pybuild, tar -xf, urllib3-$(urllib3-version), , \
	                Urllib3 $(urllib3-version))

$(ipydir)/webencodings-$(webencodings-version): \
                       $(ipydir)/setuptools-$(setuptools-version) \
                       $(ipydir)/setuptools-scm-$(setuptools-scm-version)
	tarball=webencodings-$(webencodings-version).tar.gz
	$(call import-source, $(webencodings-url), $(webencodings-checksum))
	$(call pybuild, tar -xf, webencodings-$(webencodings-version), , \
	                Webencodings $(webencodings-version))

# As of 2025-02, this is only needed if you want 'wheel' on the command
# line; 'setuptools' provides its own version of wheels.
$(ipydir)/wheel-$(wheel-version): \
                $(ipydir)/gpep517-$(gpep517-version) \
                $(ipydir)/flit-core-$(flit-core-version) \
                $(ipydir)/python-installer-$(python-installer-version)
#	tarball=wheel-$(wheel-version).tar.lz
	tarball=wheel-$(wheel-version).tar.gz
	$(call import-source, $(wheel-url), $(wheel-checksum))
	$(call pybuild, tar -xf, wheel-$(wheel-version), , \
	                Wheel $(wheel-version), GPEP517)
