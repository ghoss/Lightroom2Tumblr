# Lightroom2Tumblr
#
# GNU Makefile
#
# Copyright (c) 2012-2017 by Guido Hoss.
#
# Lightroom2Tumblr is free software: you can redistribute it and/or 
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation, either version 3
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with this program.  If not, see
# <http://www.gnu.org/licenses/>.
#
# Git repository home: <https://github.com/ghoss/Lightroom2Tumblr>

LUA	=	luac5.1
PLUGIN	=	tumblr.lrplugin
DIST	=	lr2tumblr.zip

OBJECTS =	$(PLUGIN)/Info.lua \
		$(PLUGIN)/LrSHA1.lua \
		$(PLUGIN)/TumblrAuthentication.lua \
		$(PLUGIN)/TumblrDialog.lua \
		$(PLUGIN)/TumblrExportTask.lua \
		$(PLUGIN)/TumblrServiceProvider.lua

all:	$(PLUGIN) $(OBJECTS)

dist:	all
	zip -9r $(DIST) $(PLUGIN)

clean:
	rm -f $(PLUGIN)/*

$(PLUGIN):
	mkdir $@

# Explicit rule to compile Lua files to plug-in subdirectory
#
$(PLUGIN)/%.lua : %.lua
	$(LUA) -o $@ $(@F)
