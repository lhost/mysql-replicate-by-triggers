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

if [ -z "$DATABASE" ]; then
	echo "ERROR: Name of te database not set." > /dev/stderr
	echo "Try command:" > /dev/stderr
	echo "    DATABASE='name_of_db' $0" > /dev/stderr
	exit 1;
fi

# run mysql import and preserve comments in procedures
cd sql \
	&& mysql "$DATABASE" --comments < install.sql

# create schema and tables
# triggers should be created by 2-pass
# (root@localhost) [mysql]> PREPARE stmt FROM 'DROP TRIGGER IF EXISTS `repl_insert_user`';
# ERROR 1295 (HY000): This command is not supported in the prepared statement protocol yet
echo "echo 'CALL repl_init(\"srcdb\", \"dstdb\")' | mysql \"$DATABASE\" | mysql \"$DATABASE\""
#echo 'CALL repl_init("srcdb", "dstdb")' | mysql "$DATABASE" | mysql "$DATABASE"


