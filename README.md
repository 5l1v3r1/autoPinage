# pinage.sh
## Automatic NULL WPS PIN

### Dependencies :

`reaver 1.6.1` (min) see https://github.com/t6x/reaver-wps-fork-t6x
`macchanger` see https://github.com/alobbs/macchanger

### Usage :

Clone the repository :

`git clone https://github.com/morojgovany/autoPinage.git`

`cd autoPinage`

Make the script executable :

`chmod +x pinage.sh`

Run it !

`./pinage.sh -i <interface>`


### Manual :

```
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
	./pinage.sh -i wlan0mon -r 3 -a 35 -o /path/to/folder```


Some features might be added in the future :

// TODO : Implement -F option "filter" by SSID instead of -j option in wash (faster but less accurate)
// TODO : Implement -S option "safe", reaver with -x 360 -t 0.5 -S options

## Credits :

Site http://www.crack-wifi.com and forum http://www.crack-wifi.com/forum
KCDTV  https://github.com/kcdtv/boxon
