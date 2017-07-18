#!/usr/bin/env bash
#
# Lockfile Wrapper script
#
# Executes a task and stores the pid to a lock file
# When called multiple times, pid is checked. If pid is not there 
# any longer, the wrapped program will be started again. 
#

# ARGUMENTS
while [[ $# -ge 1 ]] ; do
	case "$1" in
		-v|--verbose)
			verbose=1
			;;
		-o|--out|--output)
			out="$2"
			shift
			;;
		-l|--lock)
			lock="$2"
			shift
			;;
		-k|--kill)
			kill=1
			;;
		*)
			if [ -z "$prog" ] ; then
				prog="$1"
			else
				args="${args} $1"
			fi
			;;
	esac
	shift
done

# FUNCTIONS
function print_usage_and_exit() {
	echo "Usage:"
	echo "$(basename $0) [-v|--verbose] [-o|--out|--output <file>] [-l|--lock <file>] program <args>"
	echo "To keep a program running"
	echo "$(basename $0) -k|--kill [-l|--lock <file>] [-v|--verbose] program"
	echo "To stop a running program"
	echo 
	echo "-v|--verbose"
	echo "Outputs information about the programs state"
	echo
	echo "-o|--output"
	echo "Redirects (append) output of program to file (both, stdin and stderr)"
	echo "Default is /tmp/wrapper-<program>.log"
	echo
	echo "-l|--lock <file>"
	echo "Custom filename for lockfile."
        echo "Default is /tmp/wrapper-<program>.lock"
	echo
	echo "program"
	echo "The program to call. Full path needed if program is not in $PATH"
	echo
	echo "args"
	echo "Additional command line arguments for the program"
	echo
	echo "Returnvalues"
	echo "As usual, 0 if everything went fine, 1 if otherwise"
	exit 1
}

function message() {
	[ "$verbose" -ne 0 ] && echo "$@"
}

function errcho() {
	>&2 echo "$@"
}

# VERIFY VARIABLES
[ -z "$prog" ]    && print_usage_and_exit
[ -z "$verbose" ] && verbose=0
[ -z "$lock" ]    && lock="/tmp/wrapper-$(basename ${prog}).lock"
[ -z "$out" ]     && out="/tmp/wrapper-$(basename ${prog}).out"
[ -z "$kill" ]    && kill=0

#
# EXECUTE
#

# KILL
if [ "$kill" -eq 1 ] ; then
	if [ ! -f "$lock" ] ; then
		errcho "Cannot stat ${lock}"
		exit 1
	fi
	pid="$(head -1 ${lock})"
	message "Killing ${pid}"
	kill "$pid"

	message "Removing lock"
	rm "$lock"
	exit 0
fi

# START
if [ -f "$lock" ] ; then 
	message "Found lockfile ${lock}"
	pid=`head -n 1 "$lock"`
	name=`head -n 2 "$lock" | tail -1`

	# exit if program is running
	if [ $(ps aux | grep "$name" | awk '{ print $2 }' | grep "$pid" | wc -l) -gt 0 ] ; then
		message "Program already running"
		exit 0
	fi

	# since the program seems to be dead
	# remove pid file and continue as if it wasn't there in the first place
	message "Program dead, removing lock"
	rm "$lock"
fi

message "Launching program ${prog}"
# Absolute path to program given
if [[ "$prog" =~ ^/ ]] ; then
	  $prog $args 1>> $out 2>&1 &
	  pid="$!"

# Program is a file in cwd
elif [ -f "./${prog}" ] ; then
	./$prog $args 1>> $out 2>&1 &
	  pid="$!"

# Program should be in $PATH
elif hash $prog 2>/dev/null ; then
	  $prog $args 1>> $out 2>&1 &
	  pid="$!"

# Abort
else
	errcho "Dont know how to launch program ${prog}"
	exit 1
fi

message "Writing lockfile to ${lock}"
echo $pid > "$lock"
echo "$(basename $prog)" >> "$lock"
