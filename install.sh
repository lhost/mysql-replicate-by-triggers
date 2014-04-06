#!/bin/sh -e

#
# mysql-replicate-by-triggers/install.sh
#
# Developed by Lubomir Host <lubomir.host@gmail.com>
# Copyright (c) 2014
# Licensed under terms of GNU General Public License.
#
# Changelog:
# 2014-04-07 - created
#

# run mysql import and preserve comments in procedures
cd sql \
	&& mysql --comments < install.sql

