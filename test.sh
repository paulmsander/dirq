#!/bin/sh

# This script tests the functionality of the dirq and dirqst programs,
# giving a PASS/FAIL status if they meet their operational criteria.
# Exit status is 0 upon PASS, non-zero otherwise.

me=`basename "$0"`
here=`dirname "$0"`
if [ "x$here" = "" ]
then
	here="$PWD"
fi
dirq="${here}/dirq"
dirqst="${here}/dirqst"
defdirqdat="${here}/dirq.dat"

# Set up temporary directory

tmpname="${me}-$$"
export TMPDIR="${TMPDIR:-/tmp}/${tmpname}"

cleanup() {
#	echo "Removing the following:"
#	find "$TMPDIR" -print
	rm -rf "$TMPDIR"
}

trap "cleanup" 0

# Set up a dirq.dat file for testing.

dirqdat="${TMPDIR}/dirq.dat"

initialize() {
	mkdir -p "$TMPDIR"

	cat <<-EOF > "$dirqdat"
	type test1 serial $TMPDIR/t1x t1 2 dirq
	type test2 stamp  $TMPDIR/t2x t2 2 dirq
	type test3 serial $TMPDIR/t3x t3 8 dirq st1
	type test4 serial $TMPDIR/t4x t4 8 dirq st1 st2

	status default          dirq    uninitialized   removable  0
	status interrupt        dirq    interrupted     removable  0
	status initialize       dirq    initialized     removable  10
	status create           dirq    created         persistent 1000
	status remove           dirq    removing        persistent 1000
	status preserve         dirq    preserved       persistent 1000

	status default st1 uninitialized removable  0
	status none    st1 initialized   removable  20
	status none    st1 persistent    persistent 1000

	status default st2 uninitialized removable +0
	status none    st2 incr1         removable +30
	status none    st2 incr2         removable +40
	status none    st2 keep          persistent 2000
	EOF
}

initialize

# Reset the environment for clean testing.

reset() {
	cleanup
	initialize
}

# Write a status message.

status() {
	echo "${me} STATUS: $*" 1>&2
}

# Write a pass/fail message for a given test case to stdout.

passfail() {
	if [ "$1" -eq 0 ]
	then
		stv="PASS"
	else
		stv="FAIL"
	fi
	shift
	echo "${me} ${stv}: $*"
}

# Write file to stderr, eliminating the usage message.

writeerr() {
	sed -e '/^dirq.*:[ 	]*[uU]sage:/,$d' "$1" 1>&2
}

# Run a test case and compare stdout to sample exactly.  The interface is
# as follows:
# runtest exst command... < expected
# where:
# exst = 0 if commands exit status is expected to be 0, non-zero otherwise.
# command = dirq or dirqst command to execute.
# expected = expected stdout output to be matched exactly.
# Return status is 0 if command exit status is 0 and its stdout exactly
# matches the expected output, non-zero otherwise.

runtest() {
	exst="$1"
	shift
	outfile="${TMPDIR}/out"
	errfile="${TMPDIR}/err"
	expfile="${TMPDIR}/exp"
	cat > "$expfile"
	"$@" > "$outfile" 2> "$errfile"
	st=$?
	if [ $exst -ne 0 -a $st -eq 0 ]
	then
		status "Success status not expected."
		passfail 1 "$@"
		return 1
	elif [ $exst -eq 0 -a $st -ne 0 ]
	then
		writeerr "$errfile"
		status "Failure status not expected."
		passfail 1 "$@"
		return 1
	else
		cmp "$expfile" "$outfile" 1>&2
		st=$?
		if [ $st -ne 0 ]
		then
			writeerr "$errfile"
			status "stdout does not match expected output."
			echo "Expected output:" 1>&2
			cat "$expfile" 1>&2
			echo "Actual output:" 1>&2
			cat "$outfile" 1>&2
		fi
		passfail $st "$@"
		return $st
	fi
}

# Run a test case as with runtest, but the sample input is a file of
# regular expressions.  The interface is as follows:
# runtestre exst command... < expected
# where:
# exst = 0 if commands exit status is expected to be 0, non-zero otherwise.
# command = dirq or dirqst command to execute.
# expected = expected stdout output to be compared by regular expression match.
# Return status is 0 if command exit status is 0 and each line of its stdout
# matches the corresponding regular expression in the expect output, non-zero
# otherwise.

runtestre() {
	exst="$1"
	shift
	outfile="${TMPDIR}/out"
	"$@" > "$outfile"
	st=$?
	lincnt=0
	if [ $exst -ne 0 -a $st -eq 0 ]
	then
		status "Success status not expected."
		passfail 1 "$@"
		return 1
	elif [ $exst -eq 0 -a $st -ne 0 ]
	then
		writeerr "$errfile"
		status "Failure status not expected."
		passfail 1 "$@"
		return 1
	else
		paste - "$outfile" |
		while read exp lin
		do
			if [ "x$lin" = "x" ]
			then
				writeerr "$errfile"
				status "stdout was exhausted prematurely."
				passfail 1 "$@"
				return 1
			elif [ "x$exp" = "x" ]
			then
				writeerr "$errfile"
				status "expected output exhausted prematurely."
				passfail 1 "$@"
				return 1
			fi
			lincnt=`expr $lincnt + 1`
			expr "x$lin" : "x$exp" > /dev/null
			if [ $? -ne 0 ]
			then
				status "Line ${lincnt}: RE $exp doesn't match $lin"
				writeerr "$errfile"
				passfail 1 "$@"
				return 1
			fi
		done
		passfail 0 "$@"
		return 0
	fi
}

# Run a test case as with runtestre, but the output of the command is
# also taken as a list of directories whose existence are checked.
# The interface is as follows:
# runtestdirs cnt exst command... < expected
# where:
# cnt = number of directories listed in the command's output that must
#       exist.  All others must NOT exist.
# exst = 0 if commands exit status is expected to be 0, non-zero otherwise.
# command = dirq or dirqst command to execute.
# expected = expected stdout output to be compared by regular expression match.
# Return status is 0 if command exit status is 0 and each line of its stdout
# matches the corresponding regular expression in the expect output and
# existence of each directory is as expected, non-zero otherwise.

runtestdirs() {
	cnt="$1"
	shift
	exst="$1"
	shift
	outfile="${TMPDIR}/out"
	"$@" > "$outfile"
	st=$?
	lincnt=0
	retst=0
	if [ $exst -ne 0 -a $st -eq 0 ]
	then
		status "Success status not expected."
		passfail 1 "$@"
		return 1
	elif [ $exst -eq 0 -a $st -ne 0 ]
	then
		writeerr "$errfile"
		status "Failure status not expected."
		passfail 1 "$@"
		return 1
	else
		lsts=0
		( paste - "$outfile"; echo ) |
		( while read exp lin
		do
			if [ "x$exp" = "x" ]
			then
				exit $lsts
			fi
			if [ "x$lin" = "x" ]
			then
				writeerr "$errfile"
				status "stdout was exhausted prematurely."
				passfail 1 "$@"
				exit 1
			elif [ "x$exp" = "x" ]
			then
				writeerr "$errfile"
				status "expected output exhausted prematurely."
				passfail 1 "$@"
				exit 1
			fi
			lincnt=`expr $lincnt + 1`
			expr "x$lin" : "x$exp" > /dev/null
			if [ $? -ne 0 ]
			then
				status "Line ${lincnt}: RE $exp doesn't match $lin"
				writeerr "$errfile"
				passfail 1 "$@"
				lsts=1
			fi
			if [ $cnt -gt 0 ]
			then
				if [ ! -d "$lin" ]
				then
					passfail 1 "$@: Directory does not exist: $lin"
					lsts=1
				fi
				cnt=`expr $cnt - 1`
			elif [ -d "$lin" ]
			then
				passfail 1 "$@: Directory was not deleted: $lin"
				lsts=1
			fi
		done )
		retst=$?
		passfail $retst "$@"
		return $retst
	fi
}

# Check the status of directories returned by a dirq command.  The
# interface is as follows:
# checkdirs chk stin cmd new [pred [rm...]]
# where:
# chk = scope of check as list of characters:  n = new directory,
#       p = predecessor directory, r = removed directories.
# stin = return status value of one of the runtest functions.
# cmd = quoted dirq command passed as a single parameter.
# new = fullpath of newly created directory.
# pred = fullpath of new directory's predecessor.
# rm = fullpath of deleted directory.

checkdirs() {
	chk="$1"
	stin="$2"
	cmd="$3"
	shift 3
	retst=0
	if [ $stin -ne 0 ]
	then
		passfail 1 "${cmd}"
		return 0
	fi
	if test $# -ge 1
	then
		if [ ! -d "$1" ]
		then
			passfail 1 "${cmd}: Failed to create new directory $1"
			retst=1
		fi
		shift
	fi
	if test $# -ge 1 && expr "x$chk" : "x.*p" > /dev/null
	then
		if [ ! -d "$1" ]
		then
			passfail 1 "${cmd}: Predecessor does not exist $1"
			retst=1
		fi
		shift
	fi
	if test $# -ge 1 && expr "x$chk" : "x.*r" > /dev/null
	then
		for d in "$@"
		do
			if [ ! -d "$d" ]
			then
				passfail 1 "${cmd}: Did not remove $d"
				retst=1
			fi
		done
	fi
	return $retst
}

# Function to normalize contents of a file: Remove comments, eliminate blank
# lines, eliminate leading and trailing whitespace, and combine remaining
# whitespace into single blank characters.

normalize() {
	sed -e 's/#.*$//' \
	    -e '/^[ 	]*$/d' \
	    -e 's/^[ 	]*//' \
	    -e 's/[ 	]*$//' \
	    -e 's/[ 	][ 	]*/ /g' \
	    "$1"
}

# Initialize test.sh script's exit status.

exitst=0

# Test the basic queue list capability.

normalize "$defdirqdat" |
grep '^type' |
cut '-d ' -f2-6 |
runtest 0 "$dirq" -t
test $? -eq 0 || exitst=2

# Repeat using the -f option.

normalize "$dirqdat" |
grep '^type' |
cut '-d ' -f2-6 |
runtest 0 "$dirq" -t -f "$dirqdat"
test $? -eq 0 || exitst=2

# Negative test of -f option.

runtest 2 "dirq" -t -f "${TMPDIR}/zyzzy" < /dev/null
test $? -eq 0 || exitst=2

# Combine -t with queue type.

normalize "$dirqdat" |
grep '^type test3 ' |
cut '-d ' -f2-6 |
runtest 0 "$dirq" -t -f "$dirqdat" test3
test $? -eq 0 || exitst=2

# Negative test combining -t with queue type.

runtest 2 "$dirq" -t -f "$dirqdat" testxyzzy < /dev/null
test $? -eq 0 || exitst=2

# Create a directory with serial number.

cat <<EOF |
${TMPDIR}/t1x/t1#1*$
EOF
runtestdirs 1 0 "$dirq" -f "$dirqdat" test1
test $? -eq 0 || exitst=2

# Create a second directory with serial number.

cat <<EOF |
${TMPDIR}/t1x/t1#2$
${TMPDIR}/t1x/t1#1$
EOF
runtestdirs 2 0 "$dirq" -p -f "$dirqdat" test1
test $? -eq 0 || exitst=2

# Create a third directory with serial number, in a queue of length 2.

cat <<EOF |
${TMPDIR}/t1x/t1#3$
${TMPDIR}/t1x/t1#2$
${TMPDIR}/t1x/t1#1$
EOF
runtestdirs 2 0 "$dirq" -p -r -f "$dirqdat" test1
test $? -eq 0 || exitst=2

# Create a directory with a timestamp.

cat <<EOF |
${TMPDIR}/t2x/t2-[0-9][0-9]*-0001$
EOF
runtestdirs 1 0 "$dirq" -f "$dirqdat" test2
test $? -eq 0 || exitst=2

# Create a second directory with a timestamp.

cat <<EOF |
${TMPDIR}/t2x/t2-[0-9][0-9]*-0002$
${TMPDIR}/t2x/t2-[0-9][0-9]*-0001$
EOF
runtestdirs 2 0 "$dirq" -p -f "$dirqdat" test2
test $? -eq 0 || exitst=2

# Create a third directory with a timestamp, in a queue of length 2.

cat <<EOF |
${TMPDIR}/t2x/t2-[0-9][0-9]*-0003$
${TMPDIR}/t2x/t2-[0-9][0-9]*-0002$
${TMPDIR}/t2x/t2-[0-9][0-9]*-0001$
EOF
runtestdirs 2 0 "$dirq" -p -r -f "$dirqdat" test2
test $? -eq 0 || exitst=2

# Test queue listing for serial queue.

cat <<EOF |
${TMPDIR}/t1x/t1#2
${TMPDIR}/t1x/t1#3
EOF
runtest 0 "$dirq" -f "$dirqdat" -l test1
test $? -eq 0 || exitst=2

# Test queue listing for stamp queue.

cat <<EOF |
${TMPDIR}/t2x/t2-[0-9][0-9]*-0002$
${TMPDIR}/t2x/t2-[0-9][0-9]*-0003$
EOF
runtestre 0 "$dirq" -f "$dirqdat" -l test2

# Negative test to try creating a directory of non-existent type.

runtest 1 "$dirq" -f "$dirqdat" testxyzzy < /dev/null
test $? -eq 0 || exitst=2

# Negative test to try listing a queue of non-existent type.

runtest 1 "$dirq" -f "$dirqdat" -l testxyzzy < /dev/null
test $? -eq 0 || exitst=2

# List queue with state values.

cat <<EOF |
${TMPDIR}/t1x/t1#2
dirq=initialized

${TMPDIR}/t1x/t1#3
dirq=initialized

EOF
runtest 0 "$dirq" -f "$dirqdat" -l -s test1
test $? -eq 0 || exitst=2

# List queue with quality assessments.

cat <<EOF |
${TMPDIR}/t1x/t1#2 removable 10 dirq initialized
${TMPDIR}/t1x/t1#3 removable 10 dirq initialized
EOF
runtest 0 "$dirq" -f "$dirqdat" -l -w test1

# Create a new queue and directory with a preserved state.

cat <<EOF |
${TMPDIR}/t3x/t3#1$
EOF
runtestdirs 1 0 "$dirq" -p -r -f "$dirqdat" test3 st1=persistent
test $? -eq 0 || exitst=2

# Create a second directory in the new queue without a preserved state.

cat <<EOF |
${TMPDIR}/t3x/t3#2$
${TMPDIR}/t3x/t3#1$
EOF
runtestdirs 2 0 "$dirq" -p -r -f "$dirqdat" test3
test $? -eq 0 || exitst=2

# List the new queue with status values.

cat <<EOF |
${TMPDIR}/t3x/t3#1
dirq=initialized
st1=persistent

${TMPDIR}/t3x/t3#2
dirq=initialized
st1=uninitialized

EOF
runtest 0 "$dirq" -f "$dirqdat" -l -s test3
test $? -eq 0 || exitst=2

# List the new queue with quality assessment.

cat <<EOF |
${TMPDIR}/t3x/t3#1 persistent 1000 st1 persistent
${TMPDIR}/t3x/t3#2 removable 10 dirq initialized
EOF
runtest 0 "$dirq" -f "$dirqdat" -l -w test3
test $? -eq 0 || exitst=2

# Create one more directory in the new queue without persistence.
# Queue length prevents deletion.

cat <<EOF |
${TMPDIR}/t3x/t3#3$
${TMPDIR}/t3x/t3#2$
EOF
runtestdirs 2 0 "$dirq" -p -r -f "$dirqdat" test3
test $? -eq 0 || exitst=2

# Create new directory and override the length, reducing it from 8 to 3.
# Directory #4 is created, #3 is #4's predecessor, #1 is persistent, #2
# is removed.

cat <<EOF |
${TMPDIR}/t3x/t3#4$
${TMPDIR}/t3x/t3#3$
${TMPDIR}/t3x/t3#2$
EOF
runtestdirs 2 0 "$dirq" -N 3 -p -r -f "$dirqdat" test3
test $? -eq 0 || exitst=2

# Repeat the above test, with the no-op flag.

cat <<EOF |
${TMPDIR}/t3x/t3#5
${TMPDIR}/t3x/t3#4
${TMPDIR}/t3x/t3#3
EOF
runtest 0 "$dirq" -n -N 3 -p -r -f "$dirqdat" test3
test $? -eq 0 || exitst=2

# Verify that no directory was created by the above test.

cat <<EOF |
${TMPDIR}/t3x/t3#1
${TMPDIR}/t3x/t3#3
${TMPDIR}/t3x/t3#4
EOF
runtest 0 "$dirq" -f "$dirqdat" -l test3
test $? -eq 0 || exitst=2

# List the test1 queue, overriding the directory prefix.  This should be empty.

runtest 1 "$dirq" -f "$dirqdat" -P TT -l test1 < /dev/null
test $? -eq 0 || exitst=2

# Create a directory in the test1 queue with overridden prefix.

cat <<EOF |
${TMPDIR}/t1x/TT#1$
EOF
runtestdirs 1 0 "$dirq" -f "$dirqdat" -P TT -p -r test1
test $? -eq 0 || exitst=2

# Repeat the fill the queue.

cat <<EOF |
${TMPDIR}/t1x/TT#2$
${TMPDIR}/t1x/TT#1$
EOF
runtestdirs 2 0 "$dirq" -f "$dirqdat" -P TT -p -r test1
test $? -eq 0 || exitst=2

# Repeat and overflow the queue.

cat <<EOF |
${TMPDIR}/t1x/TT#3$
${TMPDIR}/t1x/TT#2$
${TMPDIR}/t1x/TT#1$
EOF
runtestdirs 2 0 "$dirq" -f "$dirqdat" -P TT -p -r test1
test $? -eq 0 || exitst=2

# List the queue to verify contents.

cat <<EOF |
${TMPDIR}/t1x/TT#2
${TMPDIR}/t1x/TT#3
EOF
runtest 0 "$dirq" -f "$dirqdat" -P TT -l test1
test $? -eq 0 || exitst=2

# Create a directory in the test4 queue to prepare for testing
# incremental quality assessments.

cat <<EOF |
${TMPDIR}/t4x/t4#1$
EOF
runtestdirs 1 0 "$dirq" -f "$dirqdat" -p -r test4 st1=initialized st2=incr2
test $? -eq 0 || exitst=2

# Create a second directory in the test4 queue with a different weight.

cat <<EOF |
${TMPDIR}/t4x/t4#2$
${TMPDIR}/t4x/t4#1$
EOF
runtestdirs 2 0 "$dirq" -f "$dirqdat" -p -r test4 st1=initialized st2=incr1
test $? -eq 0 || exitst=2

# Create a third directory in the test4 queue and preserve it.

cat <<EOF |
${TMPDIR}/t4x/t4#3$
${TMPDIR}/t4x/t4#2$
EOF
runtestdirs 2 0 "$dirq" -f "$dirqdat" -p -r test4 st1=initialized st2=keep
test $? -eq 0 || exitst=2

# Check the weights of the directories.

cat <<EOF |
${TMPDIR}/t4x/t4#1 removable 60 dirq initialized
${TMPDIR}/t4x/t4#2 removable 50 dirq initialized
${TMPDIR}/t4x/t4#3 persistent 2000 dirq initialized
EOF
runtest 0 "$dirq" -f "$dirqdat" -l -w test4
test $? -eq 0 || exitst=2

# Create a new directory in the test4 queue, shortening its length to 3.
# The t4#2 directory has the lowest weight and should be removed.

cat <<EOF |
${TMPDIR}/t4x/t4#4$
${TMPDIR}/t4x/t4#3$
${TMPDIR}/t4x/t4#2$
EOF
runtestdirs 2 0 "$dirq" -f "$dirqdat" -N 3 -p -r test4 st1=initialized
test $? -eq 0 || exitst=2

# Show values of state variables.

cat <<EOF |
dirq=initialized
st1=initialized
st2=incr2
EOF
runtest 0 "$dirqst" -f "$dirqdat" "${TMPDIR}/t4x/t4#1"
test $? -eq 0 || exitst=2

# Show value of one selected state variable.

cat <<EOF |
st1=initialized
EOF
runtest 0 "$dirqst" -f "$dirqdat" "${TMPDIR}/t4x/t4#1" st1
test $? -eq 0 || exitst=2

# Show value of multiple selected state variables.

cat <<EOF |
st1=initialized
st2=incr2
EOF
runtest 0 "$dirqst" -f "$dirqdat" "${TMPDIR}/t4x/t4#1" st1 st2
test $? -eq 0 || exitst=2

# Change value of one selected state variable.

cat <<EOF |
st2=incr2
EOF
runtest 0 "$dirqst" -f "$dirqdat" "${TMPDIR}/t4x/t4#1" st2=incr1
test $? -eq 0 || exitst=2

# Change values of multiple state variables.

cat <<EOF |
st1=initialized
st2=incr1
EOF
runtest 0 "$dirqst" -f "$dirqdat" "${TMPDIR}/t4x/t4#1" st2=incr2 st1=persistent
test $? -eq 0 || exitst=2

# Show values of state variables.

cat <<EOF |
dirq=initialized
st1=persistent
st2=incr2
EOF
runtest 0 "$dirqst" -f "$dirqdat" "${TMPDIR}/t4x/t4#1"
test $? -eq 0 || exitst=2

# Change values of multiple state variables with no-op option.

cat <<EOF |
st1=persistent
st2=incr2
EOF
runtest 0 "$dirqst" -f "$dirqdat" -n "${TMPDIR}/t4x/t4#1" \
                    st2=incr1 st1=initialized
test $? -eq 0 || exitst=2

# Show values of state variables to confirm no change was made.

cat <<EOF |
dirq=initialized
st1=persistent
st2=incr2
EOF
runtest 0 "$dirqst" -f "$dirqdat" "${TMPDIR}/t4x/t4#1"
test $? -eq 0 || exitst=2

# Add an arbitrary state variable.

runtest 0 "$dirqst" -f "$dirqdat" "${TMPDIR}/t4x/t4#1" \
                    "comment=This is {a | ~ test}" < /dev/null
test $? -eq 0 || exitst=2

# Show values of state variables to confirm that comment was saved.

cat <<EOF |
comment=This is {a | ~ test}
dirq=initialized
st1=persistent
st2=incr2
EOF
runtest 0 "$dirqst" -f "$dirqdat" "${TMPDIR}/t4x/t4#1"
test $? -eq 0 || exitst=2

# Verify comment value can be selected for display.

cat <<EOF |
comment=This is {a | ~ test}
EOF
runtest 0 "$dirqst" -f "$dirqdat" "${TMPDIR}/t4x/t4#1" comment
test $? -eq 0 || exitst=2

# Clear the comment.

cat <<EOF |
comment=This is {a | ~ test}
EOF
runtest 0 "$dirqst" -f "$dirqdat" "${TMPDIR}/t4x/t4#1" comment=
test $? -eq 0 || exitst=2

# Show values of state variables to confirm that comment was cleared.

cat <<EOF |
dirq=initialized
st1=persistent
st2=incr2
EOF
runtest 0 "$dirqst" -f "$dirqdat" "${TMPDIR}/t4x/t4#1"
test $? -eq 0 || exitst=2

# Verify comment value can be selected for display.

runtest 0 "$dirqst" -f "$dirqdat" "${TMPDIR}/t4x/t4#1" comment < /dev/null
test $? -eq 0 || exitst=2

# Display final pass/fail message.

passfail $exitst "FULL TEST SUITE"
exit $exitst

