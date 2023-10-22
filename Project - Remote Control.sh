# PURPOSE: Get details of target IP via a remote machine

#!/bin/bash

function check_requirements(){
	for app in ${required_apps[@]}; do													# runs through array of required apps
		if [ -z $(which $app) ]; then													# if not installed, proceed to install
			echo "[!] Not installed: $app"	
			if [ "$app" == "nipe" ]; then												# if installing for nipe, different method required
				if [ $(ls -l | grep nipe | wc -l) -ge 1 ]; then							# check if nipe folder was created before and goes into it (have to be within 1 directory down)
					echo "[!] nipe was found in a different directory..." && cd nipe		
				else
					git clone https://github.com/htrgouvea/nipe && cd nipe				# install nipe
					sudo cpanm --installdeps .
					sudo perl nipe.pl install
				fi
			else
				sudo apt install $app													# normal app installation process
			fi
		else
			echo "[#] Already installed: $app"
		fi
	done
	echo
}

function Anon_connect_check(){
	sudo perl nipe.pl stop 																# ensures nipe service turned off first
	original_ip=$(sudo perl nipe.pl status | head -n 3 | tail -n 1 | awk '{print $3}')	# gets and neaten original IP

	sudo perl nipe.pl start																# start nipe service
	nipe_ip=$(sudo perl nipe.pl status | head -n 3 | tail -n 1 | awk '{print $3}')		# gets and neaten niped IP

	if [ "$original_ip" == "$nipe_ip" ]; then											# checks that after nipe started, different IP on current machine
		echo "[!] Non-anonymous connection, exiting now..."								# if no change, stop nipe and exit script
		sudo perl nipe.pl stop
		exit
	else
		# Display Spoofed country name
		spoofed_country=$(geoiplookup $nipe_ip | awk '{print $(NF-1)" "$NF}')			# if different ip, get country of spoofed IP
		echo "[*] Anonymous connection verified"
		echo "[*] Spoofed IP: $nipe_ip"
		echo "[*] Spoofed Country: $spoofed_country"
	fi
	echo
}

function get_remote_server_details(){
	echo "[*] Connecting to Remote Server..."
	echo "[*] Country: $(geoiplookup $REMOTE_IP | awk '{print $(NF-1)" "$NF}')"						# Display country of remote server
	echo "[*] IP: $REMOTE_IP"																		# Display IP of remote server
	# uptime=$(sshpass -p $pass ssh $user@$REMOTE_IP "w | grep up | tr ":" ' '| tr "," ' '")		# Less details
	# uptime=$(echo $uptime | awk '{print $5" "$6" "$7"hr "$8"min"}')	
	uptime=$(sshpass -p $pass ssh $user@$REMOTE_IP "w | grep up")	
	echo "[*] uptime: $uptime"																		# Display uptime of remote server
}

function do_stuff_from_remote_server(){
	# check if nmap available on remote server before proceeding
	nmap_check=$(sshpass -p $pass ssh $user@$TARGET_IP "which nmap | wc -l")
	if [ "$nmap_check" -gt 0 ]; then
		echo "[*] nmap available!"
		
		#~ 2.2, 2.3: get remote server to check 'whois' of given address & do port scan of the address
		remote_pwd=$(sshpass -p $pass ssh $user@$REMOTE_IP "pwd")
		echo "[*] Whois-ing target address..."
		echo "[@] Whois data saved to: $remote_pwd/whois_file_s31"
		sshpass -p $pass ssh $user@$REMOTE_IP "whois $TARGET_IP > whois_file_s31"
		echo "[*] Scanning target address..."
		echo "[@] Nmap data saved to: $remote_pwd/nmap_file_s31"
		sshpass -p $pass ssh $user@$REMOTE_IP "nmap -Pn -sV $TARGET_IP -oG nmap_file_s31 >/dev/null"
		
		# save the whois and nmap into local machine
		echo "[*] Downloading files into local machine..."
		sshpass -p $pass scp $user@$REMOTE_IP:~/*_file_s31 .
		
		# remove created files
		echo "[*] Removing files in remote server..."
		sshpass -p $pass ssh $user@$REMOTE_IP "rm whois_file_s31 nmap_file_s31"
	else
		echo "[!] nmap unavailable on remote server: No Scan was done..."
	fi
}

function consolidate_logfile(){
	# Create log and audit data collection
	# Log created 1 directory above nipe
	echo
	DETAILED_LOG_NAME="../remote_scan.log"
	MAIN_LOG_NAME="/var/log/nr.log"
	CUR_DIR=$(pwd | sed 's/\(.*\)\//\1 /' | awk '{print $1}')
	
	if [ -f /var/log/nr.log ]; then 
		echo "[*] Consolidating logs..."
	else
		echo "[!] log file not found, creating log file"
		sudo touch /var/log/nr.log
	fi

	# DETAILED LOGGING
	# line break & entry date in log for easier viewing of each entry
	echo "======================== $(date) ========================" >> $DETAILED_LOG_NAME
	# neaten & append nmap log, does not print error if files unavailable
	echo "[*] Consolidating nmap data..."
	cat nmap_file_s31 | grep open | sed 's/, /\n/g' | sed 's/Ports: /\nOpen Ports:\n/' | sed 's/Ignored/\nIgnored/' | sed 's/\/open/ /' 2>/dev/null >> $DETAILED_LOG_NAME
	sudo echo "$(date) - [*] nmap data collected for: $TARGET_IP" | sudo tee -a $MAIN_LOG_NAME >/dev/null
	
	# neaten & append whois log, does not print error if files unavailable
	echo "[*] Consolidating whois data..."
	cat whois_file_s31 | sed '/^\# */d' | sed '/^$/d' 2>/dev/null >> $DETAILED_LOG_NAME
	sudo echo "$(date) - [*] whois data collected for: $TARGET_IP" | sudo tee -a $MAIN_LOG_NAME >/dev/null

	# remove individual log files and move consolidated
	rm whois_file_s31 nmap_file_s31 
	echo "[@] Main log updated in: $MAIN_LOG_NAME"
	echo "[@] Detailed log created in: $CUR_DIR$(echo $DETAILED_LOG_NAME | sed 's/\.\.//')"
}


# Array of required apps for this script
required_apps=("sshpass" "git" "nipe" "nmap" "whois" "geoiplookup" "tee")

# remote server credentials
REMOTE_IP="xxx.xxx.xxx.xxx"
user="USER"
pass="PASSWORD"

# Check if sshpass, nipe, torify, nmap, whois installed AND install uninstalled applications
check_requirements

# Check if network connection is anonymous, if not alert user and exit
Anon_connect_check

# allow user to specify address to scan via remote server, save into variable
echo -n "[?] Enter Target IP: "
read TARGET_IP
echo

# Display details of remote server (country, IP, uptime)
get_remote_server_details

# get remote server to check 'whois' of given address & do port scan of the address
# save whois and nmap into local machine
do_stuff_from_remote_server

# stops nipe
sudo perl nipe.pl stop

#~ 3.2: Create log and audit data collection
consolidate_logfile

echo "[-] Script Completed successfully!"






