#!/bin/bash
# Author: Mario Forzanini https://marioforzanini.com
# Date: 25/05/2021
# Description: Download and watch video lessons from ariel.unimi.it
# Dependencies: dmenu https://tools.suckless.org/dmenu mpv https://mpv.io,
# 		wget, youtube-dl https://www.youtube-dl.org, ffmpeg
#		https://ffmpeg.org

# Exit codes
EXIT_SUCCESS=0
EXIT_NO_DEPS=1
EXIT_NO_INPUT=2
EXIT_WRONG_ARG=3
EXIT_NOT_FOUND=4
EXIT_INTERRUPT=5

# File name for site's html code
INPUT_FILE=webpage.html

# Speed of download: set with option -s, possible values are: 'fast' or 'slow'
# 'slow' requires ffmpeg only, 'fast' requires youtube-dl and ffmpeg.
# If no -s argument is given it will default to value set below
SPEED=fast

function usage() {
	printf "Usage:\n\tuniversity-cli [-s SPEED] [OPTIONS] \
		\n\nAvailable options: \
		\n\t-h:\tDisplay this help message \
		\n\t-c:\tCheck to see which videos aren't downloaded \
		\n\t-d:\tChoose a lesson to download \
		\n\t-D:\tDownload all videos \
		\n\t-s:\tChoose speed of download (possible values: fast, slow), \
has to be set as first option. \
		\n\t-v:\tChoose a lesson to watch\n"
		exit $1
}

function no_dep() {
		printf "university-cli: $1 not found, install $1 to proceed.\n"
		exit $EXIT_NO_DEPS
}

# Commands to download videos
function slow_dl() {
	which ffmpeg>/dev/null || no_dep ffmpeg
	# from https://wiki.studentiunimi.it/guida:scaricare_videolezioni_ariel
	ffmpeg -i "$1" -n -preset slow -c:v libx265 -crf 31 -c:a aac \
		-b:a 64k -ac 1 "$2"
}

function fast_dl() {
	which youtube-dl>/dev/null || no_dep youtube-dl
	youtube-dl --no-overwrite --no-check-certificate "$1" -o "$2"
}

# Error handling
function no_file() {
	printf "university-cli: %s not found, use -d to download it.\n" "$1"
}

function no_download() {
	if test -e $1; then
		printf "%s exists. Nothing to do.\n" "$1"
		return $EXIT_SUCCESS
	else
		return $EXIT_NOT_FOUND
	fi
}

function no_input() {
	printf "university-cli: No input file found: download the html page \
in a file called $INPUT_FILE and retry.\n"
	exit $EXIT_NO_INPUT
}

function interrupt() {
	printf "\nInterrupted by user, exiting\n"
	exit $EXIT_INTERRUPT
}

function set_speed() {
	SPEED="$1"
	if test "$SPEED" = "fast"; then
		DOWNLOAD_COMMAND="fast_dl"
	elif test "$SPEED" = "slow"; then
		DOWNLOAD_COMMAND="slow_dl"
	else
		printf "Speed argument not recognised, possible values are: 'fast' or 'slow'\n"
		exit $EXIT_WRONG_ARG
	fi
}

function check_webpage() {
	# Check for the existence of the input file
	test -e $INPUT_FILE || no_input

	# Variables
	VIDEOS=($(grep "source src=" $INPUT_FILE | cut -d\" -f2))
	NAMES=($(grep "source src=" $INPUT_FILE | cut -d\" -f2 | sed 's/^.*mp4://;s/%20/%%20/g' \
		| rev | cut -d/ -f2 | rev))
			#VIDEOS=($(grep mp4 $INPUT_FILE | cut -d\" -f2 | sed 's/%20/%%20/g'))
			#NAMES=($(grep mp4 $INPUT_FILE | cut -d\" -f2 | cut -d: -f3 | \
			#sed 's/.mp4.*//'))
}

function check_downloads() {
	for i in ${!NAMES[@]}; do
		#test -e "${NAMES[$i]}".mp4 || no_file "${NAMES[$i]}".mp4
		test -e "${NAMES[$i]}" || no_file "${NAMES[$i]}"
	done && exit $EXIT_SUCCESS
}

function download() {
	lesson=$(echo ${NAMES[@]} | sed 's/ /\n/g' | \
		dmenu -p "Download Lesson: " -i -l 10) || exit $EXIT_INTERRUPT
	trap interrupt SIGINT

	no_download "$lesson".mp4 && exit $EXIT_SUCCESS
	$DOWNLOAD_COMMAND "$(grep "$lesson" $INPUT_FILE | cut -d\" -f2 | \
		sed 's/%20/ /g')" "$lesson" && exit $EXIT_SUCCESS
}

function download_all() {
	trap interrupt SIGINT
	for i in ${!VIDEOS[@]}; do
		$DOWNLOAD_COMMAND "${VIDEOS[$i]}" "${NAMES[$i]}"
		#"${NAMES[$i]}".mp4
	done && exit $EXIT_SUCCESS
}

function view() {
	which mpv>/dev/null || no_dep mpv
	lesson=$(echo ${NAMES[@]} | sed 's/ /\n/g' | \
		dmenu -p "View Lesson: " -i -l 10) || exit $EXIT_INTERRUPT

	if test -e "$lesson"; then
		mpv "$lesson"
	else
		mpv $(grep "$lesson" $INPUT_FILE | cut -d\" -f2 | \
			sed 's/%20/ /g')
	fi
	exit $EXIT_SUCCESS
}

# Set default speed
set_speed $SPEED

# Read command line options
[ $# -eq 0 ] && usage $EXIT_WRONG_ARG
while getopts ":hcdDs:v" o; do case "${o}" in
	h) usage $EXIT_SUCCESS
	;;
c) check_webpage
	check_downloads
	;;
d) check_webpage
	download
	;;
D) check_webpage
	download_all
	;;
s) set_speed ${OPTARG}
	;;
v) check_webpage
	view
	;;
*) printf "Invalid option: -%s\\nTry -h for help\n" "$OPTARG" && \
	exit $EXIT_WRONG_ARG
	;;
esac
done
