#!/data/data/com.termux/files/usr/bin/bash

# ============================================================
#  ADBash - Your Local ADB Shell for Termux
# ------------------------------------------------------------
#  Author: Kamil "BuriXon" Burek
#  Project: ADBash
#  Year: 2026
#  License: GNU General Public License v3.0 (GPLv3)
# ------------------------------------------------------------
#  Description:
#  ADBash is a minimal Bash automation tool for Termux.
#  It connects Termux directly to the ADB host running on
#  the same Android device (localhost / 127.0.0.1) and
#  launches a ready-to-use Bash shell inside the ADB session.
# ------------------------------------------------------------
#  Website: https://burixon.dev/projects/ADBash
#  Repository: https://github.com/BuriXon-code/ADBash
# ============================================================

# ----------------------
# CONFIGURATION
# ----------------------

# Some shellcheck stuff
# shellcheck disable=2028,2009,2001,2006,2015,2034,2046,2086,1087,2317,2329,2188,2207,2183,2181

set -ou pipefail

# COLORS
RED=$'\e[1;31m'
GRN=$'\e[1;32m'
YLW=$'\e[1;33m'
BLU=$'\e[1;34m'
MAG=$'\e[1;35m'
CYN=$'\e[1;36m'
BLD=$'\e[1m'
RST=$'\e[0m'
URL=$'\e[1;4;36m'

# MWTADATA
VERSION="2.0 [Fresh look]"
CHANGES="This version has corrected minor bugs and added new functionalities:
  \e[1;32m>\e[0m A convenient select menu has been added allowing you to choose one of the found (max 5) ports on which ADB can listen [only in verbose mode]:
    \e[1;34m+\e[0m convenient port selection
    \e[1;34m+\e[0m the ability to do everything at once (instead of writing many commands)
    \e[1;34m+\e[0m high compatibility 
    \e[1;34m+\e[0m fresh design
  \e[1;32m>\e[0m A second port checking system has been added in case of problems with nmap.
  \e[1;32m>\e[0m The layout and graphic elements have been improved:
    \e[1;34m+\e[0m improved appearance/content of messages
    \e[1;34m+\e[0m added very-verbose mode
    \e[1;34m+\e[0m error information moved to STDERR
    \e[1;34m+\e[0m improved indentation, message invocation method and line spacing
  \e[1;32m>\e[0m Handling of signals and error codes has been improved.
  \e[1;32m>\e[0m New fresh and convenient Bash RC file and Bash launcher with:
    \e[1;34m+\e[0m more information about ADB script and shell
    \e[1;34m+\e[0m more convenient popular aliases
    \e[1;34m+\e[0m handler for non-existent commands
    \e[1;34m+\e[0m ready-made Bash history configuration
"
VERSIONDATE="2026-03-06"
AUTHOR="Kamil BuriXon Burek"
LICENSE="GPLv3"
WEBPAGE="https://burixon.dev/projects/ADBash/"
GITHUB="https://github.com/BuriXon-code/ADBash/"

# MODES / FLAGS
NOBASH=false
SETPORT=false
VERBOSE=false
STARTED=false
ONLYSCAN=false
CUSTOMRC=false
VVERBOSE=false
MISSING_CMD=false
INVALIDPARAM=false

# VERBOSITY
v=0
vv=0
for arg in "$@"; do
	case "$arg" in
		-v) ((v++));;
		-vv) ((vv++));;
		--verbose) ((v++));;
		--very-verbose) ((vv++));;
	esac
done
((v>=2)) && VERBOSE=true
((vv>=1)) && VVERBOSE=true && echo VERY VERBOSE LEVEL

# PLACES / PARAMETERS
REMOTE_TMP_PREFIX="/tmp/adbash-$$"
DEST_BASE="/sdcard/adbash-$$"
# thwse must stay empty at start
MATCHINGPORTS=()
MATCHINGPORT=""
INVALIDARG=""
PORTDATA=""
RCFILE=""
PORT=""

# ----------------------
# UI helpers
# ----------------------
banner() {
	echo -e "$BLD    _   ___ $GRN ___          _    $RST"
	echo -e "$BLD   /_\\ |   \\\\$GRN| _ ) __ _ __| |_  $RST"
	echo -e "$BLD  / _ \\| |) $GRN| _ \\/ _\` (_-< ' \\ $RST"
	echo -e "$BLD /_/ \\_\\___/$GRN|___/\\__,_/__/_||_|$RST"
	echo -e "$BLD $CYN*$RST$BLD> Made by$RED BuriXon-code$RST$BLD ${VERSIONDATE:0:4} $CYN*$RST\n"
}
error() {
	# always print to stderr
	echo -e "${RED}[ ERR! ]${RST} $*" >&2
}
info() {
	[ "$VERBOSE" = true ] && echo -e "${YLW}[ INFO ]${RST} $*"
}
success() {
	[ "$VERBOSE" = true ] && echo -e "${GRN}[ DONE ]${RST} $*"
}
vvinfo() {
	[ "$VVERBOSE" = true ] && echo -e "  ${CYN}+${RST} $*"
}

# ----------------------
# Interactive menu select (arrow keys)
# usage: menu_select varname items...
# ----------------------
menu_select() {
	vvinfo "Calling select menu."
	local __out="$1"
	shift
	local items=("$@")
	local N=${#items[@]}
	[ "$N" -eq 0 ] && return 1
	local choice=1
	local cols line i key rest

	cols=`tput cols 2>/dev/null || stty size 2>/dev/null | awk '{print $2}'`
	[ -z "$cols" ] && cols=80
	# hide cursor, enable wrap toggle
	echo -ne $'\e[?25l\e[?7l'
	while :; do
		# draw
		for ((i=1;i<=N;i++)); do
			line="  ${items[i-1]}"
			if (( ${#line} > cols )); then
				line="${line:0:cols}"
			else
				while (( ${#line} < cols )); do
					line+=" "
				done
			fi

			if (( i == choice )); then
				# selected
				if [[ "$line" == *"ABORT"* ]]; then
					echo -e "\e[1;31m< \e[0m\e[1;3;7;31m${line}\e[0m"
				else
					echo -e "\e[1;33m> \e[0m\e[1;3;7;33m${line}\e[0m"
				fi
			else
				echo -e "\e[2m| ${line}\e[0m"
			fi
		done
		# move cursor back up to redraw
		echo -ne "\e[${N}A"
		# read key
		read -rsn1 key
		case "$key" in
			$'\x1b')
				# possible arrow
				read -rsn2 -t 0.1 rest 2>/dev/null || rest=''
				if [[ "$rest" == "[A" ]]; then
					((choice--))
					((choice < 1)) && choice=$N
				elif [[ "$rest" == "[B" ]]; then
					((choice++))
					((choice > N)) && choice=1
				fi
			;;
			"")
				break
			;;
			q)
				break
			;;
		esac

		echo -ne "\e[J"
	done
	# restore cursor and attributes
	echo -en "\e[${N}A\e[J\e[?7h\e[?25h"
	# set output variable without using printf -v
	local selected="${items[choice-1]}"
	# escape double quotes for eval assignment
	local selected_esc="${selected//\"/\\\"}"
	eval "$__out=\"$selected_esc\""
	return 0
}

# ----------------------
# TRAPS AND HANDLERS
# ----------------------
on_exit() {
	local EXIT_CODE=$?
	vvinfo "Received EXIT."
	VERBOSE=true
	vvinfo "Received return code: ${EXIT_CODE}."
	rm -rf "${DEST_BASE}" &>/dev/null || true
	vvinfo "Local temp dir [${DEST_BASE}] cleared."
	# if the script has already performed file operations, need to clean
	if [ "$STARTED" = true ]; then
		info "Cleaning remote temp."
		adb shell "rm -rf $REMOTE_TMP_PREFIX" &>/dev/null || true
		vvinfo "Remote temp dir [${REMOTE_TMP_PREFIX}] cleared."
	fi
	# build status text
	local CLR STATUS_TEXT
	CLR="$RED"
	vvinfo "Determining the final message."
	if [ "$EXIT_CODE" -eq 0 ]; then
		CLR="$GRN"
		STATUS_TEXT="${BLD}${EXIT_CODE}${RST} /${GRN} OK${RST}"
	elif [ "$EXIT_CODE" -eq 255 ]; then
		STATUS_TEXT="${BLD}${EXIT_CODE}${RST} /${RED} CRASHED${RST}"
	elif [ "$EXIT_CODE" -ge 128 ]; then
		STATUS_TEXT="${BLD}${EXIT_CODE}${RST} /${YLW} STOPPED${RST}"
	else
		STATUS_TEXT="${BLD}${EXIT_CODE}${RST} /${RED} ERROR${RST}"
	fi
	echo -e "${CLR}[ EXIT ]${RST} Status code: ${STATUS_TEXT}"
}
trap on_exit EXIT
on_int() {
	if [ "$VERBOSE" = true ]; then
		vvinfo "Received SIG.\e[K"
		info "Aborting... Please wait.\e[K"
	fi
	vvinfo "Disconnecting ADB."
	# make sure ADB is disconnected
	[ -n "$MATCHINGPORT" ] && adb disconnect 127.0.0.1:"$MATCHINGPORT" &>/dev/null || true
	vvinfo "ADB disconnected."
	exit 130
}
trap on_int SIGINT SIGHUP SIGTERM

# ----------------------
# HANDLERS/OUTPUTS/CLI
# ----------------------
help() {
	VERBOSE=true
	banner
	echo -e "Usage: `basename "$0"` [options]"
	echo
	echo -e "Options:"
	echo -e "  -v --verbose       Enable verbose mode"
	echo -e "  -vv --very-verbose Enable very verbose mode"
	echo -e "  -n --nobash        Skip copying Bash and libraries"
	echo -e "  -r --rcfile <file> Specify a custom RC file"
	echo -e "  -p --port <num>    Manually set ADB port"
	echo -e "  -s --scan-port     Scan available ports only, do not connect"
	echo -e "  -h -H --help       Show this help message and exit"
	echo -e "  -C --codes         Show exit codes"
	echo -e "  -A --about         Show info about the script"
	echo -e "  -V --version       Show version info and exit"
	exit $1
}
version() {
	VERBOSE=true
	banner
	echo -e "Version: $VERSION"
	echo -e "Date: $VERSIONDATE"
	exit $1
}
about() {
	VERBOSE=true
	local open_page sel
	banner
	echo -e "$CYN*$RST$BLD Author:$YLW      >_ $RED$AUTHOR$RST"
	echo -e "$CYN*$RST$BLD License:$RST     $LICENSE$RST"
	echo -e "$CYN*$RST$BLD Webpage:$RST     $URL$WEBPAGE$RST"
	echo -e "$CYN*$RST$BLD Github:$RST      $URL$GITHUB$RST"
	echo -e "$CYN*$RST$BLD Version:$RST     $VERSION @ $VERSIONDATE$RST"
	echo -e "$CYN*$RST$BLD Changes:$RST     $CHANGES$RST"
	# interacrive webpage handler
	echo -en "${CYN}[ ASK? ]${RST} Open the project page now? [y/N]: "
	read -rsn1 -t 30 ANSWER
	if [ $? -ne 0 ]; then
		echo -e "${YLW}-${RST}"
		info "No answer."
		exit 0
	fi
	case ${ANSWER,,} in
		y) echo -e "${GRN}$ANSWER${RST}" ;;
		n) echo -e "${YLW}$ANSWER${RST}"; exit 0 ;;
		'') echo -e "${YLW}n${RST}"; exit 0 ;;
		*) echo -e "${RED}$ANSWER${RST}"; error "Invalid operation."; exit 1 ;;
	esac
	echo -e "${CYN}[ ASK? ]${RST} Use arrow keys to choose website, Enter to select:"
	# call menu select
	menu_select open_page BURIXON.DEV GITHUB.COM ABORT || open_page="ABORT"
	if [[ "$open_page" == "ABORT" ]]; then
		info "Aborting...\e[K"
		kill -2 $$
		exit 130
	fi
	case $open_page in
		BURIXON.DEV) open_page="${WEBPAGE}?FROM_CLI_`date +%s`" ;;
		GITHUB.COM) open_page="${GITHUB}";;
		*) error "Something went wrong."; exit 1 ;;
	esac
	# determine how to open page - Android browser/Termux VNC browser
	local vnc_proc vnc_pid browser
	for b in firefox firefox-esr chromium brave google-chrome midori qutebrowser netsurf; do
		if command -v "$b" >/dev/null 2>&1; then
			browser="$b"
			break
		fi
	done
	by_termux() {
		if command -v termux-open-url &>/dev/null; then
			termux-open-url "${1}"
		else
			error "Cannot open link."
			exit 1
		fi
	}
	# if vnc is running
	if ps -e | grep -iE 'vnc|tigervnc|vncserver' | grep -v grep &>/dev/null; then
		#  make sure VNC is actually running (there is a .pid file)
		if ls "$HOME/.vnc/"*.pid &>/dev/null; then
			# finally - if a browser is available and if the display variable is set, open the page
			if [ -n "$browser" ] && [ -n "${DISPLAY:-}" ]; then
				"$browser" "$open_page" &>/dev/null & disown
			else
				#  otherwise open in Android browser
				by_termux "$open_page"
			fi
		else
			#  otherwise open in Android browser
			by_termux "$open_page"
		fi
	else
		#  otherwise open in Android browser
		by_termux "$open_page"
	fi
	exit $1
}
codes() { #  display info about error codes and their meanings
	VERBOSE=true
	banner
	echo -e "$CYN*$RST$BLD Code 0$RST: Success"
	echo -e "$CYN*$RST$BLD Code 1$RST: Invalid/unsupported parameter"
	echo -e "$CYN*$RST$BLD Code 2$RST: --nobash cannot be combined with --rcfile"
	echo -e "$CYN*$RST$BLD Code 3$RST: --scan-port cannot be combined with other params"
	echo -e "$CYN*$RST$BLD Code 4$RST: Invalid port value for --port"
	echo -e "$CYN*$RST$BLD Code 5$RST: No service listening on specified port"
	echo -e "$CYN*$RST$BLD Code 6$RST: RC file not provided"
	echo -e "$CYN*$RST$BLD Code 7$RST: RC file not readable or missing"
	echo -e "$CYN*$RST$BLD Code 8$RST: Missing required external dependency (adb etc.)"
	echo -e "$CYN*$RST$BLD Code 9$RST: /sdcard or \$PREFIX/lib not accessible"
	echo -e "$CYN*$RST$BLD Code 10$RST: Required libraries missing"
	echo -e "$CYN*$RST$BLD Code 11$RST: Bash binary missing or symlinked"
	echo -e "$CYN*$RST$BLD Code 12$RST: ADB port not found"
	echo -e "$CYN*$RST$BLD Code 13$RST: More than one matching port (pairing mode?)"
	echo -e "$CYN*$RST$BLD Code 14$RST: Cannot connect to ADB daemon (pairing/auth)"
	echo -e "$CYN*$RST$BLD Code 15$RST: Failed to move/push dependencies to device tmp"
	echo -e "$CYN*$RST$BLD Code 16$RST: Failed to change permissions on remote files"
	echo -e "$CYN*$RST$BLD Code 17$RST: Failed to create symlinks on remote"
	echo -e "$CYN*$RST$BLD Code 18..254$RST: Other errors/signals"
	echo -e "$CYN*$RST$BLD Code 255$RST: ADB session abruptly closed"
	exit $1
}

# ----------------------
# ARGS PARSING
# ----------------------
until [ $# -eq 0 ]; do
vvinfo "Parsing arg: $1"
	case $1 in
		-h|-H|--help) help 0 ;; # handle help option
		-r|--rcfile) # set user RC file or "none" if empty
			CUSTOMRC=true
			RCFILE="${2:-none}"
			shift 2
			;;
		-n|--nobash) # run ADB without Bash 
			NOBASH=true
			shift
			;;
		-v|--verbose)
			if $VERBOSE; then # just in case
				VVERBOSE=true
			fi
			VERBOSE=true
			shift
			;;
		-vv|--very-verbose) # just in case
			VERBOSE=true
			VVERBOSE=true
			shift
			;;
		-p|--port) # speed up the process by setting the port if there is one
			SETPORT=true
			PORT="${2:-none}"
			shift 2
			;;
		-s|--scan-port) # just scan for matching ports
			ONLYSCAN=true
			shift
			;;
		-V|--version) version 0 ;; # version info handler
		-A|--about) about 0 ;; # about info handler
		-C|--codes) codes 0 ;; # about codes info handler
		*) # handle incorrect/invalid args
			INVALIDARG="$1"
			INVALIDPARAM=true
			shift
			;;
	esac
done
# display banner
vvinfo "Banner:"
banner
vvinfo "Checking the validation of the provided parameters."
# invalid arg - show error and exit (after banner)
if [ "$INVALIDPARAM" = true ]; then
	error "Invalid option: $INVALIDARG"
	vvinfo "Help and usage info:"
	$VVERBOSE && help 1
	exit 1
fi
# validate values/options
for arg in "$PORT" "$RCFILE"; do
	if [ "$arg" = "none" ]; then
		vvinfo "Missing $arg"
		error "Missing parameter."
		exit 1
	fi
done
if [ "$NOBASH" = true ] && [ "$CUSTOMRC" = true ]; then
	error "You cannot combine --nobash and --rcfile options."
	exit 2
fi
only_scan() {
	error "The --scan-port option cannot be combined with other parameters."
	exit 3
}
if [ "$ONLYSCAN" = true ]; then
	vvinfo "Calling scan funcion."
	$NOBASH && only_scan
	$CUSTOMRC && only_scan
	$SETPORT && only_scan
	:
fi

# ----------------------
# HELPERS
# ----------------------
perf_scan() {
	vvinfo "Performing scan."
	# if user-definied port is valid - return
	if [ "$SETPORT" = true ]; then
		vvinfo "Setting procided port: $PORT."
		MATCHINGPORT="$PORT"
		return 0
	fi
	# run nmap first
	if command -v nmap &>/dev/null; then
		vvinfo "Searching for a listening port using nmap."
		mapfile -t MATCHINGPORTS < <(nmap -p 30000-49999 127.0.0.1 2>/dev/null | grep -Po '\d{5}/.{4}open' | cut -d'/' -f1)
	else
		# run bash-builtin in case of problems with nmap
		# this method is much slower, but it works
		error "Command nmap not found."
		info "Searching port via bash builtins may take a while... Please wait."
		vvinfo "Searching for a listening port using builtins."
		local p
		for ((p=30000;p<=49999;p++)); do
			vvinfo "Checking port: $p"
			if bash -c "</dev/tcp/127.0.0.1/$p" &>/dev/null; then
				vvinfo "Matching port: $p"
				MATCHINGPORTS+=("$p")
			fi
		done
	fi
	vvinfo "Counting marching ports."
	# exit if no ports found 
	if [ "${#MATCHINGPORTS[@]}" -eq 0 ]; then
		vvinfo "No matching port found."
		error "${RED}[ ERR! ]${RST} ADB port not found. Is ADB running?"
		exit 12
	fi
	# handle too many ports
	# in silent mode, exit code 13; in verbose and very verbose mode, allow port selection
	if [ "${#MATCHINGPORTS[@]}" -gt 1 ]; then
		vvinfo "More than 1 matching port found."
		if [ "$ONLYSCAN" = true ]; then
			vvinfo "Only scan: display content:"
			echo -e "${YLW}[ INFO ]${RST} Found:"
			for p in "${MATCHINGPORTS[@]}"; do
				echo -e "  ${YLW}[>]${RST} $p"
			done
			exit 0
		else
			if ! $VERBOSE; then
				exit 13
			fi
			vvinfo "Preparing port selection."
			if [ -t 1 ]; then
				error "Multiple possible ADB ports found:"
				local i=1 items=()
				for p in "${MATCHINGPORTS[@]}"; do
					items+=("$p")
					echo -e "  ${YLW}[>]${RST} $p"
					((i++))
				done
				vvinfo "Checking the number of selection options."
				if [[ $i -gt 5 ]]; then # allow to choose between max of 5 matching ports
					error "${RED}[ ERR! ]${RST} Too many matching ports."
					exit 13
				fi
				vvinfo "Preparing select menu."
				echo -e "${CYN}[ ASK? ]${RST} Use arrow keys to choose port, Enter to select: "
				local sel
				menu_select sel "${items[@]}" ABORT || sel="${items[0]}"
				if [[ "$sel" == "ABORT" ]]; then
					info "Aborting...\e[K"
					kill -2 $$
					exit 130
				fi
				vvinfo "Selected: $sel"
				MATCHINGPORT="$sel"
				echo
			else
				vvinfo "Picking first matching port."
				MATCHINGPORT="${MATCHINGPORTS[0]}"
			fi
		fi
	else
		vvinfo "Setting matching port."
		MATCHINGPORT="${MATCHINGPORTS[0]}"
	fi
	vvinfo "Checking port format."
	# last port validation
	if ! [[ "$MATCHINGPORT" =~ ^[0-9]+$ ]]; then
		vvinfo "Invalid port format."
		error "${RED}[ ERR! ]${RST} No matching port found."
		exit 12
	fi
}


# ----------------------
# SCAN AND PORT PARSING
# ----------------------
# run scan only
if $ONLYSCAN; then
	vvinfo "Performing only scan."
	perf_scan
	success "${GRN}[ OK ]${RST} Matching port: $MATCHINGPORT"
	exit 0
fi
# validate port again
if $SETPORT; then
	vvinfo "Validating user-provided port number."
	if [ -z "$PORT" ] || ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1024 ] || [ "$PORT" -gt 65535 ]; then
		vvinfo "Invalid port format."
		error "Invalid port number: $PORT."
		exit 4
	fi
	if ! bash -c "</dev/tcp/127.0.0.1/${PORT}" &>/dev/null; then
		vvinfo "Port is closed."
		error "No service is listening on port $PORT."
		exit 5
	fi
fi
# check if provided RC file exists
if $CUSTOMRC; then
	vvinfo "Checking user-provided RC file."
	[ -z "$RCFILE" ] && { error "The RC file was not provided."; exit 6; }
	! [ -r "$RCFILE" ] && { error "The RC file does not exist or cannot be read."; exit 7; }
fi

vvinfo "Finishing args checking."
success "Parameters: OK"

# ----------------------
# DEPENDENCIES
# ----------------------
vvinfo "Checking environment."
info "Checking environment."
vvinfo "Checking util commands."
REQUIRED_CMDS=(adb cp mv mkdir cat echo grep sed cut basename awk wc) # essential commands
MISSING=false
for CMD in "${REQUIRED_CMDS[@]}"; do
	vvinfo "Checking: $CMD"
	if ! command -v "$CMD" &>/dev/null; then
		error "The required $CMD command does not exist."
		MISSING=true
	fi
done
if $MISSING; then
	error "Some required dependencies are missing."
	exit 8
fi
vvinfo "Dependent commands found."
success "Dependencies: OK"

# ----------------------
# DIRECTORIES ANS FILES
# ----------------------
vvinfo "Checking directories/files/libraries/exexutables."
if ! $NOBASH; then
	vvinfo "Checking local temp dir: /sdcard"
	if [ ! -d /sdcard ] || [ ! -w /sdcard ]; then
		error "The directory /sdcard does not exist or is not writable."
		exit 9
	fi
	vvinfo "Checking Termux \$PREFIX dir: $PREFIX"
	if [ -z "${PREFIX:-}" ]; then
		vvinfo "System \$PREFIX is not set. Setting new."
		PREFIX="`command -v bash | xargs dirname | xargs dirname 2>/dev/null || echo /data/data/com.termux/files/usr`"
	fi
	# check if the prefix is set or exists 
	# if the prefix does not exist, try defining a new one
	vvinfo "Checking Termux \$PREFIX dir: $PREFIX"
	if [ ! -d "$PREFIX/lib" ] || [ ! -w "$PREFIX/lib" ]; then
		error "The directory $PREFIX/lib does not exist or is not writable."
		exit 9
	fi
	info "Checking libraries."
	shopt -s nullglob
	PATTERNS=( # these libraries are necessary to run bash
		"$PREFIX/lib/libandroid-support.so"
		"$PREFIX/lib/libreadline.so.8.3*" # Must be 8.3 !
		"$PREFIX/lib/libncursesw*"
		"$PREFIX/lib/libiconv.so*"
	)
	vvinfo "Creating local temp dir: $DEST_BASE"
	mkdir -p "${DEST_BASE}" || { error "The /sdcard directory is unavailable or Read-Only."; exit 9; }
	i=1
	vvinfo "Copying libraries:"
	# copying paths to universal names and paths
	#  later they will be linked and set accordingly
	for pat in "${PATTERNS[@]}"; do
		FOUND=false
		for f in $pat; do
			vvinfo "Checking: $f"
			if [ ! -L "$f" ] && [ -e "$f" ]; then
				BASENAME=`basename "$f"`
				vvinfo "Setting basename: $BASENAME"
				NEWNAME=`echo "$BASENAME" | sed 's/\.so.*/.so/'`
				vvinfo "Setting new name: $NEWNAME"
				info "Copying library $i of ${#PATTERNS[@]}: `basename $f`"
				cp "$f" "${DEST_BASE}/${NEWNAME}" || break
				FOUND=true
				((i++))
				break
			fi
		done
		vvinfo "Checking if OK."
		if [ "$FOUND" != true ]; then
			error "Some required libraries are missing."
			shopt -u nullglob
			exit 10
		fi
	done
	vvinfo "Libraries copied."
	shopt -u nullglob
	success "Libraries: OK"
	vvinfo "Checking bash binary."
	info "Checking bash binary."
	# check if Bash exists, is not a link and can be used 
	BASHFILE="$PREFIX/bin/bash"
	vvinfo "Found bash: $BASHFILE"
	vvinfo "Checking $BASHFILE"
	if [ -f "$BASHFILE" ] && [ ! -L "$BASHFILE" ]; then
		vvinfo "Copying bash."
		cp "$BASHFILE" "${DEST_BASE}/shell"
	else
		vvinfo "Bash appears to be unreachable."
		error "The main bash executable does not exist or is a symlink."
		exit 11
	fi
	vvinfo "Bash copied."
	success "Files: OK"
fi
success "Environment: OK"


# ----------------------
# LAUNCHER AND RC FILE
# ----------------------
if ! $NOBASH; then
	vvinfo "Preparing launcher."
	info "Creating config files."
	{
		echo "#!/bin/sh"
		echo "export LD_LIBRARY_PATH=${REMOTE_TMP_PREFIX}"
	} > "${DEST_BASE}/bash"
	# here I use HEREDOC to easily handle difficult escapes and quotings
	# the "echo" used is echo from /system/bin, not Bash builtin - it doesn't handle escapes the same way, doesn't support the "-e" parameter and should be handled more delicately
	cat <<'LAUNCHER' >> "${DEST_BASE}/bash"
echo $'\n\e[1m'"Welcome in "$'\e[1;32m'"Bash"$'\e[0m\e[1m'"!"$'\e[0m'
echo $'\n'"Please note that this bash is not the same as your Termux bash. Your aliases and functions do not work here, and you are using a different \$PATH."
echo "To view a list of aliases I have prepared, use the "$'\e[1;32m'"alias"$'\e[0m'" command."
echo $'\n\e[1;31m'"Important!"$'\e[0m'" Remember - this is your device's ADB console. Proceed with caution to avoid damaging the system."$'\n'
LAUNCHER
	echo "exec ${REMOTE_TMP_PREFIX}/shell --noprofile --rcfile ${REMOTE_TMP_PREFIX}/shell.rc" >> "${DEST_BASE}/bash"
	# set permissions
	# this may be important if you want to run Bash from "/tmp/bash" instead of "sh /tmp/bash"
	chmod +x "${DEST_BASE}/bash" || true
	vvinfo "Launcher created."
	if $CUSTOMRC; then
		vvinfo "Copying user-provided RC file."
		info "Copying RC file."
		if [ -f "$RCFILE" ]; then
			cp "$RCFILE" "${DEST_BASE}/shell.rc" || { error "Failed to copy the RC file."; exit 9; }
		fi
		vvinfo "RC file copied."
		success "RC file: OK"
	else
		vvinfo "Preparing RC file."
		# another HEREDOC, because setting prompts differently can be very difficult
		cat <<'BASHRC' > "${DEST_BASE}/shell.rc"
export HOME=/tmp
export PROMPT_DIRTRIM=2
PROMPT_DIRTRIM=2
PS1='\[$(
  case $? in
    0|"")
      echo -e "\e[32m\w\e[0m "
      ;;
    127)
      echo -e "\e[33m\w\e[0m "
      ;;
    255)
      echo -e "\e[1;31m\w\e[0m "
      ;;
    *)
      echo -e "\e[31m\w\e[0m "
      ;;
  esac
)\]\$ '
PS2='\[\e[0;32m\]-\[\e[0m\] \[\e[0;97m\]>\[\e[0m\] '
PS3='SELECT: '
PS4='$(if [[ $? -eq 0 ]]; then echo -e "\e[0;32m TRUE/DONE\n\n\e[0m"; else echo -e "\e[1;5;31m FALSE/ERROR\n\n\e[0m"; fi)'
HISTFILE=/tmp/.bash_history
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoredups:erasedups
shopt -s histappend
PROMPT_COMMAND='history -a; history -n'
alias ls="ls --color=always"
alias ll="ls -l"
alias la="ls -la"
alias ".."="cd .."
alias "~"="cd $HOME"
alias grep="grep --color=auto"
command_not_found_handle() {
	echo -e "Command \e[1;31m$1\e[0m not found."
	echo -e "Remember that you are in the ADB shell and you use system commands."
	return 127
}
echo -e "\e[2A\r\e[J"
BASHRC
		vvinfo "RC file created."
		vvinfo "RC file copied."
		success "RC file: OK"
	fi
fi
vvinfo "Environmnent and files look OK."
success "Config files: OK"

# ----------------------
# ENSURE PORT
# ----------------------
vvinfo "Performing port scan."
info "Looking for ADB port."
perf_scan
$VERBOSE && echo -en "\e[1A" # to maintain a nice layout
success "Connection: OK (selected port: $MATCHINGPORT)"

# ----------------------
# ADB CONNECT
# ----------------------
vvinfo "Setting up ADB connection."
info "Preparing ADB connection."
STARTED=true
info "Restarting ADB daemon."
adb kill-server &>/dev/null || true
vvinfo "ADB client server stopped."
adb start-server &>/dev/null || true # restarting just in case
vvinfo "ADB client server started."
success "ADB daemon: OK"
info "Connecting to ADB."
TRYCONNECT=`adb connect 127.0.0.1:"$MATCHINGPORT" 2>&1 || true`
vvinfo "Connection initiated. Waiting for response."
if echo "$TRYCONNECT" | grep -Eiq 'refused|failed to connect|unable to connect'; then
	error "Cannot connect to ADB."
	exit 14
fi
vvinfo "Connection established."
success "Connecting: OK"

# ----------------------
# FINAL CONFIGURATION
# ----------------------
if ! $NOBASH; then
	vvinfo "Preparing remote temp files."
	info "Preparing files on host and device."
	vvinfo "Ensuring $DEST_BASE."
	mkdir -p "${DEST_BASE}/" || { error "Cannot create ${DEST_BASE}"; exit 9; }
	vvinfo "Creating remote dir."
	adb shell "mkdir -p /sdcard/adbash" &>/dev/null || true
	adb push "${DEST_BASE}/." /sdcard/adbash/ &>/dev/null || true
	vvinfo "Moving local files ti remote dir."
	adb shell "mkdir -p ${REMOTE_TMP_PREFIX}" &>/dev/null || true
	adb shell "mv /sdcard/adbash/* ${REMOTE_TMP_PREFIX}/" &>/dev/null || {
		error "Cannot move dependencies to device tmp."
		exit 15
	}
	# some magic
	vvinfo "Making files executable."
	info "Changing permissions."
	adb shell "chmod +x ${REMOTE_TMP_PREFIX}/shell ${REMOTE_TMP_PREFIX}/*.so ${REMOTE_TMP_PREFIX}/bash" &>/dev/null || {
		error "Cannot change permissions."
		exit 16
	}
	info "Creating symlinks."
	vvinfo "Linking launcher to /tmp/bash."
	adb shell "ln -sf ${REMOTE_TMP_PREFIX}/bash /tmp/bash" &>/dev/null || {
		adb shell "cp ${REMOTE_TMP_PREFIX}/bash /tmp/bash && chmod +x /tmp/bash" &>/dev/null || true
	}
	vvinfo "Linking libraries (to ensure proper naming and structure)."
	vvinfo "Linking: libreadline"
	adb shell "ln -sf ${REMOTE_TMP_PREFIX}/libreadline.so ${REMOTE_TMP_PREFIX}/libreadline.so.8" &>/dev/null || {
		error "Cannot make symlink."
		exit 17
	}
	vvinfo "Linking: libncursesw"
	adb shell "ln -sf ${REMOTE_TMP_PREFIX}/libncursesw.so ${REMOTE_TMP_PREFIX}/libncursesw.so.6" &>/dev/null || {
		error "Cannot make symlink."
		exit 17
	}
	vvinfo "Files and slinks look OK"
	success "Files: OK"
fi

# ----------------------
# ADB SHELL
# ----------------------
vvinfo "Configuration finished."
info "Starting ADB shell."
[ "$VERBOSE" = true ] && banner
vvinfo "Done. Welcome to Bash!"
echo -e "\n${BLD}Welcome to your device's ADB shell!${RST}"
if ! $NOBASH; then
	echo -e "\nTo start Bash, run: ${GRN}sh /tmp/bash${RST}"
fi
echo -e "\nDo not disconnect network or turn off device screen; ADB session may end.\n"
adb shell 2>/dev/null

# ----------------------
# FINAL STATUS AND EXIT
# ----------------------
EXIT_ADB_STATUS=$?
vvinfo "Checking exit code/error status: $EXIT_ADB_STATUS"
case $EXIT_ADB_STATUS in
	0)
		success "Session ended successfully."
		exit $EXIT_ADB_STATUS
		;;
	1)
		error "Cannot connect to ADB."
		info "Try running the script again or resetting ADB."
		exit $EXIT_ADB_STATUS
		;;
	255)
		error "The session was abruptly terminated."
		info "The device may have gone offline or the screen has turned off."
		exit $EXIT_ADB_STATUS
		;;
	*)
		error "An error has occurred."
		info "It could be a connection error or a return code inherited from the ADB console."
		exit $EXIT_ADB_STATUS
		;;
esac
