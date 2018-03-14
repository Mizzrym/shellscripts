#!/usr/bin/env bash
#
# Import databases FASTER
# IMPORTANT: Files to import from need to reside in $files_dir, which is /var/lib/mysql-files on
#            debian based systems. Export your database using:
# 	     mysqldump -t=/var/lib/mysql-files dbname
# NOTE: Script assumes you've set up your ~/.my.cnf properly, because mysql will start nagging 
#       about plain text passwords as commandline options otherwise. 
# USAGE: fast_mysql_import.sh dbname /var/lib/mysql-files
#
# Why a faster mysql import is needed? That's why:
#
# the universe: okay, you're a human. I gave you free will and a
# concious mind, so you're free to do whatever you want. So what
# do you wanna do?
#
# human: GO FAST
#
# the universe: well, you're a perfect pursuit predator but if
# that's the way you want to evolve, go ahead.
#
# human, climbing on a horse: GO FAST
#
# the universe: wait what
#
# human, inventing the car and the bullet train: GO FASTER
#
# the universe: I IMPLORE YOU TO STOP
#
# human, trying to figure out lightspeed travel:
#
#   .d8888b.   .d88888b.       8888888888     d8888  .d8888b. 88888888888 8888888888 8888888b.
#  d88P  Y88b d88P" "Y88b      888           d88888 d88P  Y88b    888     888        888   Y88b
#  888    888 888     888      888          d88P888 Y88b.         888     888        888    888
#  888        888     888      8888888     d88P 888  "Y888b.      888     8888888    888   d88P
#  888  88888 888     888      888        d88P  888     "Y88b.    888     888        8888888P"
#  888    888 888     888      888       d88P   888       "888    888     888        888 T88b
#  Y88b  d88P Y88b. .d88P      888      d8888888888 Y88b  d88P    888     888        888  T88b
#   "Y8888P88  "Y88888P"       888     d88P     888  "Y8888P"     888     8888888888 888   T88b


set -o nounset
set -o pipefail
set -o errexit

# IMPORTANT: Make sure your mysql server can handle this many connections
# NOTE: If you want to increase this make sure ulimit is fine with it as well
readonly plimit=200
files_dir='/var/lib/mysql-files/skeleton' # default, can be changed with argument 2

#
# FUNCTIONS
#

# import_table "path to sql-file"
# assumes that the txt file containing the csv import will use the same path and name,
# but with the suffix '.txt' (mysqldump default)
function import_table() {
	set -o nounset

	sql="${1}"
	txt="${sql/.sql/.txt}"
	basename=`basename $sql`
	tablename=${basename::-4}

	if [ ! -f "$sql" ] ; then
		echo "[FAIL] [${tablename}] ${sql} not found"
		return 1
	fi
	if [ ! -f "$txt" ] ; then
		echo "[FAIL] [${tablename}] ${txt} not found"
		return 1
	fi

	cat <( echo "SET FOREIGN_KEY_CHECKS=0 ;") "${sql}" | mysql -A ${dbname} >/dev/null
	echo "SET FOREIGN_KEY_CHECKS=0 ; LOAD DATA INFILE '${txt}' INTO TABLE \`${tablename}\`" | mysql -A ${dbname}
}

#
# EXEC
#

# parse arguments
export dbname="$1"
[ "$2" != "" ] && export files_dir="$2"

# verify mysqlopts
if ! echo ";" | mysql -A ; then
	echo "[FAIL] Cannot connect to mysql server, check options"
	exit 1
fi

# verify dependencies
if ! hash parallel 2>/dev/null ; then
	echo "[FAIL] Dependency missing: parallel"
	exit 1
fi

# start out clean
echo "DROP DATABASE IF EXISTS \`${dbname}\` ; CREATE DATABASE \`${dbname}\` ;" | mysql -A

# parallel can't use functions that aren't exported
export -f import_table

# GO FASTER
find ${files_dir} -type f -name \*.sql | parallel --no-notice -j${plimit} import_table
