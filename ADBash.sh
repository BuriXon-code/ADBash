#!/data/data/com.termux/files/usr/bin/bash

# ============================================================
#  ADBash - Your Local ADB Shell for Termux
# ------------------------------------------------------------
#  Author: Kamil "BuriXon" Burek
#  Project: ADBash
#  Year: 2025
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

# Some shellcheck stuff
# shellcheck disable=2001,2006,2015,2034,2046,2086,1087,2317,2329

set -ou pipefail

# VARIABLES
## COLORS
RED="\e[1;31m"
GRN="\e[1;32m"
YLW="\e[1;33m"
BLU="\e[1;34m"
MAG="\e[1;35m"
CYN="\e[1;36m"
BLD="\e[1m"
RST="\e[0m"
URL="\e[1;4;36m"
## META
VERSION="1.1 [Port scan fixes]"
VERSIONDATE="2026-01-25"
AUTHOR="Kamil BuriXon Burek"
LICENSE="GPLv3.0"
REPONAME="AD${GRN}Bash"
WEBPAGE="https://burixon.dev/projects/ADBash/"
GITHUB="https://github.com/BuriXon-code/ADBash/"
DONATIONS="https://burixon.dev/donate/"
TARGET="
  The script is dedicated to the Termux environment on devices running Android 11+ with Wireless Debugging (ADB) option."
DESCRIPTION="
  $MAG+$RST ADBash is a single file script for Termux that enables automatic connection to the host device ADB and automatic copying and configuration of Bash in ADB directly from the Termux terminal.

  $MAG+$RST The script automatically locates the appropriate files, libraries and binaries, copies them to the user data directories of the device, then connects to ADB Shell and allows launching a Bash shell within ADB.

  $MAG+$RST By default the script runs in silent mode without displaying excessive text or messages. Any errors are returned via exit codes. To learn the meaning of these codes, run the script with the -C | --codes option.

  $MAG+$RST In case of difficulties it is recommended to use the -h | --help option or refer to the documentation available on the GitHub repository page of the script.

  $RED+$YLW Warning!$RST The script is not able to handle the ADB device pairing process. Before running the script, Termux and ADB must be paired using a PIN or QR code. The procedure may vary depending on the device."
## MODE
NOBASH=false
SETPORT=false
VERBOSE=false
STARTED=false
ONLYSCAN=false
CUSTOMRC=false
MISSING_CMD=false
INVALIDPARAM=false
MATCHINGPORT=""
INVALIDARG=""
PORTDATA=""
RCFILE=""
PORT=""

# HANDLERS
on_exit() {
	EXIT_CODE=$?
	VERBOSE=true
	rm -rf /sdcard/adbash/ &>/dev/null
	if $STARTED; then
		info Cleaning...
		adb shell rm /tmp/{*rc,*so*,bash,shell} &>/dev/null
	fi
	if [ "$EXIT_CODE" -eq 0 ]; then
		EXIT_CODE="$BLD$EXIT_CODE$RST /$GRN OK$RST"
		CLR="$GRN"
	else
		EXIT_CODE="$BLD$EXIT_CODE$RST /$RED ERROR$RST"
		CLR="$RED"
	fi
	echo -e "$CLR[ EXIT ]$RST Status code: $EXIT_CODE "
}
trap on_exit EXIT
on_int() {
	if $VERBOSE; then
		info "Aborting... "
	fi
	adb disconnect 127.0.0.1:$MATCHINGPORT &>/dev/null
	exit 130
}
trap on_int SIGINT
help() {
	VERBOSE=true
	banner
	echo -e "Usage: `basename "$0"` [options]

Options:
  -v --verbose       Enable verbose mode (show detailed logs)
  -n --nobash        Skip copying Bash and libraries
  -r --rcfile <file> Specify a custom RC file for Bash configuration
  -p --port <num>    Manually set ADB port (default: automatic detection)
  -s --scan-port     Scan available ports only, do not connect
  -h --help          Show this help message and exit
  -C --codes         Show detailed information about exit codes
  -A --about         Show detailed information about the script
  -V --version       Show version information and exit

Examples:
  `basename "$0"` -s
  `basename "$0"` -v -p 40000
  `basename "$0"` --rcfile ~/.bashrc --verbose
"
	exit $1
}
version() {
	VERBOSE=true
	banner
	info Version: $VERSION
	info Date: $VERSIONDATE
	exit $1
}
about() {
	VERBOSE=true
	banner
	echo -e "$CYN*$RST$BLD Author:$RED      $AUTHOR$RST"
	echo -e "$CYN*$RST$BLD License:$RST     $LICENSE$RST"
	echo -e "$CYN*$RST$BLD Name:$RST        $REPONAME$RST"
	echo -e "$CYN*$RST$BLD Version:$RST     $VERSION$RST"
	echo -e "$CYN*$RST$BLD Date:$RST        $VERSIONDATE$RST"
	echo -e "$CYN*$RST$BLD Target:$RST        $TARGET$RST"
	echo -e "$CYN*$RST$BLD Description:$RST $DESCRIPTION$RST\n"
	echo -e "$CYN*$RST$BLD Webpage:$RST     $URL$WEBPAGE$RST\e[K"
	echo -e "$CYN*$RST$BLD Github:$RST      $URL$GITHUB$RST\e[K"
	echo -e "$CYN*$RST$BLD Donations:$RST   $URL$DONATIONS$RST\e[K"
	echo
	exit $1
}
codes() {
	VERBOSE=true
	banner
	info By default, the script displays minimal output and information during execution \(for aesthetics and a \'wow\' effect when launching the ADB console\). During normal operation, exit codes are the only source of error information. \\n
	info Below is a list of exit codes returned by the script, along with an explanation of their meaning and an example of a possible cause of the error. \\n
	show_code() {
		local DESC CODE
		DESC="$1"
		CODE="$2"
		echo -e "$CYN*$RST$BLD Code $YLW$CODE$RST: $DESC"
	}
	example() {
		local DESC
		if [ $# -eq 0 ]; then
			DESC="\e[2;3mnone\e[0m"
		else
			DESC="$1"
		fi
		echo -e "$MAG*$RST$BLD Example$RST: $DESC\n"
	}
	show_code "Success - pass w/o errors" 0
	example
	show_code "Error while running the script - invalid or unsupported script parameter." 1
	example "While running `basename $0` -x"
	show_code "Parameter configuration error - the --nobash parameter cannot be used together with --rcfile. The declared RC file is meant to be a Bash shell configuration file. Without running Bash, it is unnecessary." 2
	example "While running `basename $0` --nobash --rcfile ~/.bashrc"
	show_code "Parameter configuration error - the --scan-port parameter cannot be used together with --nobash, --rcfile or --port. This option is intended to locate the ADB port without performing further configuration." 3
	example "While running `basename $0` --rcfile ~/.bashrc --scan-port"
	show_code "Parameter configuration error - invalid value for the --port parameter. This value must be a number in the range 1024..65535 (ports available in Android without root)." 4
	example "While running `basename $0` --port 80"
	show_code "Connection error - no service is listening on the port provided via --port parameter. Are you sure this is the correct value?" 5
	example "ADB is listening on port 32123, but the user specified --port 32122"
	show_code "Parameter configuration error - the --rcfile parameter expects a path to a custom RC file, but none was provided." 6
	example "While running `basename $0` --rcfile (without specifying a file path)"
	show_code "File/directory error - the provided RC file does not exist or cannot be read." 7
	example "The user provided a path to a non-existent file or made a typo"
	show_code "Dependency error - one or more of the commands required for the script to run were not found. In --verbose mode, the script will list missing commands that must be provided." 8
	example "Missing command nmap"
	show_code "File/directory error - no access to directory /sdcard/ or $PREFIX/lib/. The directory does not exist, is Read-Only, or lacks read permissions." 9
	example "Termux does not have write permission to /sdcard/"
	show_code "Dependency error - one or more of the libraries required to run the Bash shell in ADB were not found. This error indicates incompatibility between the script and the current Termux version: $TERMUX_VERSION or the current Bash version: `bash --version | grep -Po "\d.\d.\d"`." 10
	example "Missing library \$PREFIX/lib/libandroid-support.so"
	show_code "Dependency error - the main Bash executable file does not exist or is a symlink. This error indicates incompatibility between the script and the current Bash version: `bash --version | grep -Po "\d.\d.\d"`." 11
	example "The bash command in \$PATH does not exist or is a symbolic link"
	show_code "Connection error - ADB port was not found. Is ADB running?" 12
	example "ADB has not been started"
	show_code "Connection error - the script found more than one port that appears to be an ADB port. Another service may be listening on a matching port, or ADB may be in pairing mode." 13
	example "ADB is listening and in pairing mode"
	show_code "ADB error - cannot connect to ADB daemon. Termux may not have completed ADB pairing." 14
	example "Termux has not been paired (authorized) with ADB using the PIN"
	show_code "File/directory error - failed to move dependency files to the temporary ADB Shell working directory." 15
	example "Files being transferred already exist (rerun the script)"
	show_code "File/directory error - failed to change permissions for Bash dependency files. Bash startup will fail." 16
	example
	show_code "File/dependency error - failed to create symlinks for Bash libraries in the temporary ADB Shell working directory." 17
	example "Symbolic links already exist (rerun the script)"
	show_code "Other error - error generated by signals (e.g. SIGINT 130) and other unknown dependency package errors or inherited ADB Shell errors after session termination." 18..254
	example "The last command in ADB exited with code 127, so the script returns code 127"
	show_code "Other error - the ADB Shell session was unexpectedly and abruptly closed. The ADB session may be terminated suddenly, for example, after the screen is locked or the network connection is lost." 255
	example "The device screen was locked during the session"
	exit $1
}
error() {
	if $VERBOSE; then
		echo -e "$RED[ ERR! ]$RST $* " >&2
	fi
}
info() {
	if $VERBOSE; then
		echo -e "$YLW[ INFO ]$RST $* "
	fi
}
success() {
	if $VERBOSE; then
		echo -e "$GRN[ DONE ]$RST $* "
	fi
}
banner() {
		echo -e "$BLD    _   ___ $GRN ___          _    $RST"
		echo -e "$BLD   /_\ |   \\\\$GRN| _ ) __ _ __| |_  $RST"
		echo -e "$BLD  / _ \| |) $GRN| _ \/ _\` (_-< ' \ $RST"
		echo -e "$BLD /_/ \_\___/$GRN|___/\__,_/__/_||_|$RST"
		echo -e "$BLD $CYN*$RST$BLD> Made by$RED BuriXon-code$RST$BLD 2025 $CYN*$RST\n"
}
perf_scan() {
	if ! $SETPORT; then
		PORTDATA=$(nmap -p 30000-49999 127.0.0.1 2>/dev/null | grep -Po "\d{5}/.{4}open.{2}.*")
		if [ -z "$PORTDATA" ] || [[ $PORTDATA == "" ]]; then
			echo -e "${RED}[ ERR! ]${RST} ADB port not found. Is ADB running?" >&2
			exit 12
		fi

		port_count=$(printf "%s\n" "$PORTDATA" | wc -l)
		if [ "$port_count" -ne 1 ]; then
			if $ONLYSCAN; then
				echo -e "${RED}[ ERR! ]${RST} More than 1 matching port is open."
				echo -e "$YLW[ INFO ]$RST Found:"
				while IFS= read -r PORT_; do
					 echo -e "	$YLW[ INFO ]$RST $PORT_"
				done <<< "$PORTDATA"
				exit 13
			else
				if $VERBOSE; then
					error "More than 1 matching port is open."
					echo -e "$YLW[ INFO ]$RST Found:"
					while IFS= read -r PORT_; do
						echo -e "	$YLW[ INFO ]$RST $PORT_"
					done <<< "$PORTDATA"
				else
					echo -e "${RED}[ ERR! ]${RST} More than 1 matching port is open." >&2
				fi
				exit 13
			fi
		fi

		MATCHINGPORT=$(printf "%s\n" "$PORTDATA" | head -n1 | cut -d"/" -f1)
	else
		MATCHINGPORT="$PORT"
	fi

	if ! [[ "$MATCHINGPORT" =~ ^[0-9]+$ ]]; then
		echo -e "${RED}[ ERR! ]${RST} No matching port found." >&2
		exit 12
	fi
}

# ARGS
until [ $# -eq 0 ]; do
	case $1 in
		-h|-H|--help)
			help 0
			;;
		-r|--rcfile)
			CUSTOMRC=true
			RCFILE="$2"
			shift 2
			;;
		-n|--nobash)
			NOBASH=true
			shift
			;;
		-v|--verbose)
			VERBOSE=true
			shift
			;;
		-p|--port)
			SETPORT=true
			PORT="$2"
			shift 2
			;;
		-s|--scan-port)
			ONLYSCAN=true
			shift
			;;
		-V|--version)
			version 0
			;;
		-A|--about)
			about 0
			;;
		-C|--codes)
			codes 0
			;;
		*)
			INVALIDARG="$1"
			INVALIDPARAM=true
			shift
			;;
	esac
done

# BANNER
banner

# INVALID
if $INVALIDPARAM; then
	error Invalid option: $INVALIDARG
	exit 1
fi

# VALIDATE ARGS
info Checking parameters...
## MIXING
if $NOBASH && $CUSTOMRC; then
	error You cannot combine --nobash and --rcfile options.
	exit 2
fi
## SCAN
only_scan() {
	error The --scan-port option cannot be combined with other parameters.
	exit 3
}
if $ONLYSCAN; then
	$NOBASH && only_scan
	$CUSTOMRC && only_scan
	$SETPORT && only_scan
	perf_scan
	if $VERBOSE; then
		success Matching port found: $MATCHINGPORT
		exit 0
	else
		VERBOSE=true
		success Matching port found: $MATCHINGPORT
		VERBOSE=false
		exit 0
	fi
fi
## PORT
if $SETPORT; then
	if [ -z "$PORT" ] || ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1024 ] || [ "$PORT" -gt 65535 ]; then
		error Invlid port number: $PORT.
		exit 4
	fi
	if ! bash -c "</dev/tcp/127.0.0.1/${PORT}" &>/dev/null; then
		error No service is listening on port $PORT.
		exit 5
	fi
fi
## RCFILE
if $CUSTOMRC; then
	[ -z "$RCFILE" ] && {
		error The RC file was not provided.
		exit 6
	}
	! [ -r "$RCFILE" ] && {
		error The RC file does not exist or cannot be read.
		exit 7
	}
fi
success Parameters: OK

# CHECK ENV
info Checking environment...
## DEPENDENCIES
info Checking dependencies...
for CMD in nmap bash adb cp mv wc echo shopt mkdir cat; do
	command -v $CMD &>/dev/null || {
		error The required $CMD command does not exist.
		MISSING_CMD=true
	}
done
if $MISSING_CMD; then
	error Some dependencies are missing.
	exit 8
fi
success Dependencies: OK
## DIRS
info Checking directories...
if ! $NOBASH; then
	dir_not_found() {
		error The directory $1 does not exist or is not readable.
		exit 9
	}
	for dir in /sdcard "$PREFIX/lib"; do
		if [ ! -d "$dir" ] || [ ! -r "$dir" ] || [ ! -w "$dir" ]; then
			dir_not_found "$dir"
		fi
	done
fi
success Directories: OK
## LIBRARIES
if ! $NOBASH; then
	info Checking libraries...
	shopt -s nullglob
	PATTERNS=(
		"$PREFIX/lib/libandroid-support.so"
		"$PREFIX/lib/libreadline.so*"
		"$PREFIX/lib/libncursesw.so*"
		"$PREFIX/lib/libiconv.so*"
	)
	DEST="/sdcard/adbash"
	mkdir -p "$DEST" || {
		error The /sdcard directory is unavailable or Read-Only.
		exit 9
	}
	i=1
	for pat in "${PATTERNS[@]}"; do
		FOUND=false
		for f in $pat; do
			[ ! -L "$f" ] && [ -e "$f" ] && {
				BASENAME=`basename "$f"`
				NEWNAME=`echo "$BASENAME" | sed 's/\.so.*/.so/'`
				info Copying library $i of 4.
				cp "$f" "$DEST/$NEWNAME"
				FOUND=true
				((i++))
				break
			}
		done
		if ! $FOUND; then
			error Some required libraries are missing.
			exit 10
		fi
	done
	shopt -u nullglob
	success Libraries: OK
fi
## FILES
if ! $NOBASH; then
	info Checking files...
	BASHFILE="$PREFIX/bin/bash"
	if [ -f "$BASHFILE" ] && [ ! -L "$BASHFILE" ]; then
		cp "$BASHFILE" "$DEST/shell"
	else
		error The main bash executable does not exist or is a symlink.
		exit 11
	fi
	success Files: OK
fi
success Enviroment: OK

# ENV FILES
info Checking RC files...
## BASH SCRIPT
if ! $NOBASH; then
	info Creating Bash launcher...
	echo "#!/bin/sh

export LD_LIBRARY_PATH=/tmp
/tmp/shell --noprofile --rcfile /tmp/shell.rc

" > "$DEST"/bash
	success Bash launcher: OK
	## RC FILE
	if $CUSTOMRC; then
		info Copying RC file...
		if [ -f "$RCFILE" ]; then
			cp "$RCFILE" "$DEST"/shell.rc || {
				error Failed to copy the RC file.
				exit 9
			}
		fi
		success RC file: OK
	else
		info Generating RC file...
		cat <<'EOF' > "$DEST"/shell.rc
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
PS2='\[\e[0;32m\]\w\[\e[0m\] \[\e[0;97m\]>\[\e[0m\] '
PS3='\[\e[0;32m\]\w\[\e[0m\] \[\e[0;97m\]>\[\e[0m\] '
PS4='$(if [[ $? -eq 0 ]]; then echo -e "\e[0;32m TRUE/DONE\n\n\e[0m"; else echo -e "\e[1;5;31m FALSE/ERROR\n\n\e[0m"; fi)'
alias ls="ls --color=always"
alias ".."="cd .."
alias "~"="cd $HOME"
alias grep="grep --color=auto"

echo -e "\e[1mWelcome in \e[32mBash\e[0m!"

EOF
	success RC file: OK
	fi
fi
success RC files: OK

# FIND ADB PORT
info Checking connection...
## IS ANY PORT
info Looking for ADB port...
perf_scan
success Connection: OK

# DO CONNECT
info Preparing ADB connection...
## ADB CONNECT
STARTED=true
info Restarting ADB daemon...
adb kill-server &>/dev/null && adb start-server &>/dev/null &&
success ADB daemon: OK
info Connecting to ADB...
TRYCONNECT=`adb connect 127.0.0.1:$MATCHINGPORT`
if [[ "$TRYCONNECT" =~ [Rr]efused ]]; then
	error Cannot connect to ADB.
	exit 14
fi
success Connecting: OK
## PREPARE FILES
info Preparing files...
if ! $NOBASH; then
	info Copying files...
	adb shell mv /sdcard/adbash/* /tmp/ &>/dev/null && {
		success Copying: OK
	} || {
		error Cannot copy dependencies.
		exit 15
	}
	info Changing permissions...
	adb shell chmod +x /tmp/{shell,*so*,bash} &>/dev/null && {
		success Permissions: OK
	} || {
		error Cannot change permissions.
		exit 16
	}
	info Creating symlinks...
	adb shell ln -s /tmp/libreadline.so /tmp/libreadline.so.8 &>/dev/null || {
		error Cannot make symlink.
		exit 17
	}
	adb shell ln -s /tmp/libncursesw.so /tmp/libncursesw.so.6 &>/dev/null && {
		success Symlinks: OK
	} || {
		error Cannot make symlink.
		exit 17
	}
fi
success Files: OK

# MAGIC!
info Starting ADB...
$VERBOSE && banner
echo -e "${BLD}Welcome to your device's ADB shell!$RST

You are logged in as the shell user and currently located in the root (/) directory of your Android device.
"
if ! $NOBASH; then
	echo -e "To start Bash, run the command ${GRN}sh /tmp/bash$RST.\n"
fi
echo -e "Remember not to disconnect from the network or turn off the device screen. Otherwise, the ADB session may be terminated.
"
adb shell 2>/dev/null

# READ STATUS
EXIT_ADB_STATUS=$?
case $EXIT_ADB_STATUS in
	0)
		success Session ended successfully.
		exit $EXIT_ADB_STATUS
		;;
	1)
		error Cannot connect to ADB.
		info Try running the script again or resetting ADB.
		exit $EXIT_ADB_STATUS
		;;
	255)
		error The session was abruptly terminated.
		info The device may have gone offline or the screen has turned off.
		exit $EXIT_ADB_STATUS
		;;
	*)
		error An error has occurred.
		info It could be a connection error or a return code inherited from the ADB console.
		exit $EXIT_ADB_STATUS
		;;
esac
