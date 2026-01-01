# Basic preparations, called by './project make'.
#
# Copyright (C) 2019-2026 Mohammad Akhlaghi <mohammad@akhlaghi.org>
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





# Final-target
#
# Without this file, './project make' won't work.
#
# We need to remove the 'prepare' word from the list of 'makesrc'.
prepare-dep = $(filter-out prepare, $(makesrc))
$(badir)/preparation-done.mk: \
                $(foreach s, $(prepare-dep), $(mtexdir)/$(s).tex)

#	If you need to add preparations (mainly automatically generated
#	configuration files or Makefiles to simplify the './project make'
#	phase) take the following step:
#
#	   1. Add prerequisites to this target ('preparation-done.mk'). Try
#	      to avoid any kind of analysis in this (preparation) phase!
#	      Preparation should ideally only involve automatic creation of
#	      configuration files or Makefile that will be loaded into the
#	      analysis phase (from 'top-make.mk').
#
#	   2. Set the value of 'include-prepare-results' (defined below) to
#	      'yes'. If it is kept to the default 'no', then your
#	      prepartion outputs will not be automatically
#	      generated. Recall that just like 'top-make.mk',
#	      'top-prepare.mk' also loads 'initialize.mk' before everything
#	      else. So you can safely assume everything that is defined in
#	      'initialize.mk' to be available in the preparation phase
#	      also.
#
#	TIP: the targets can actually be automatically generated Makefiles
#	that are used by './project make'. They can include variables, or
#	automatically generated rules. Just make sure that those Makefiles
#	aren't written in the source directory (only hand-written files
#	should be in your source). Even though they are Makefiles, they are
#	automatically built, so they don't belong in the
#	source. '$(prepdir)' has been defined for this purpose (see
#	'initialize.mk'), we recommend that you put all automatically
#	generated configuration files or Makefiles under this directory. In
#	the 'make' phase, 'initialize.mk' will automatically load all the
#	'*.mk' files there.
	@echo "include-prepare-results = no" > $@
