#!/bin/sh -e

#
# mysql-replicate-by-triggers/uninstall.sh
#
# Developed by Lubomir Host <lubomir.host@gmail.com>
# Copyright (c) 2014
# Licensed under terms of GNU General Public License.
#
# Changelog:
# 2014-04-15 - created
#

if [ -z "$DATABASE" ]; then
	echo "ERROR: Name of te database not set." > /dev/stderr
	echo "Try command:" > /dev/stderr
	echo "    DATABASE='name_of_db' $0" > /dev/stderr
	exit 1;
fi

echo "echo 'CALL repl_drop(\"srcdb\", \"dstdb\")' | mysql \"$DATABASE\" | mysql \"$DATABASE\""
#echo 'CALL repl_drop("srcdb, "dstdb")' | mysql "$DATABASE" | mysql "$DATABASE"


