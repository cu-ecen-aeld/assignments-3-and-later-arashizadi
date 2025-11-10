#!/bin/sh
# Tester script for assignment 1 and assignment 2
# Author: Siddhant Jajoo

set -eu

NUMFILES=10
WRITESTR=AELD_IS_FUN
WRITEDIR=/tmp/aeld-data
SCRIPT_DIR=$(realpath "$(dirname "$0")")
if PROJ_DIR=$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null); then
    :
else
    PROJ_DIR=$(realpath "$SCRIPT_DIR/..")
fi
FINDER_DIR=${FINDER_DIR:-$SCRIPT_DIR}
CONF_DIR="$FINDER_DIR/conf"
username=$(cat "$CONF_DIR/username.txt")

if [ $# -lt 3 ]
then
	echo "Using default value ${WRITESTR} for string to write"
	if [ $# -lt 1 ]
	then
		echo "Using default value ${NUMFILES} for number of files to write"
	else
		NUMFILES=$1
	fi	
else
	NUMFILES=$1
	WRITESTR=$2
	WRITEDIR=/tmp/aeld-data/$3
fi

MATCHSTR="The number of files are ${NUMFILES} and the number of matching lines are ${NUMFILES}"

echo "Writing ${NUMFILES} files containing string ${WRITESTR} to ${WRITEDIR}"

rm -rf "${WRITEDIR}"

# create $WRITEDIR if not assignment1
assignment=$(cat "$CONF_DIR/assignment.txt")

if [ $assignment != 'assignment1' ]
then
	mkdir -p "$WRITEDIR"

	#The WRITEDIR is in quotes because if the directory path consists of spaces, then variable substitution will consider it as multiple argument.
	#The quotes signify that the entire string in WRITEDIR is a single string.
	#This issue can also be resolved by using double square brackets i.e [[ ]] instead of using quotes.
	if [ -d "$WRITEDIR" ]
	then
		echo "$WRITEDIR created"
	else
		exit 1
	fi
fi

#echo "Rebuilding native writer application"
#make -C "$FINDER_DIR" clean
#make -C "$FINDER_DIR"

for i in $(seq 1 $NUMFILES)
do
	$FINDER_DIR/writer "$WRITEDIR/${username}$i.txt" "$WRITESTR"
done

OUTPUTSTRING=$($FINDER_DIR/finder.sh "$WRITEDIR" "$WRITESTR")

# remove temporary directories
rm -rf /tmp/aeld-data

set +e
if printf '%s' "$OUTPUTSTRING" | grep -F -- "$MATCHSTR" >/dev/null; then
    echo "success"
	exit 0
else
    echo "failed: expected  ${MATCHSTR} in ${OUTPUTSTRING} but instead found"
    exit 1
fi
