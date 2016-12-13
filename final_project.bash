#!/bin/bash
# history of bash 2
# variable types 1
# control structures in bash 1
# why the project interesting 2
# overview of the project 1
# goto the project code

# this funtion will scan all the logs for irregulaties
# the only  parameter is the path to the file where you want the results saved
# input 1 the output file
function scanLogs {
	rm $1
	echo "Apache Log" >> $1
	cat /var/log/apache2/access.log | grep "-" | awk '{print "IP: " $1 " Type: " $6 " Action: " $7 $8 $9}' | sort | uniq -dc | sort -rn >> $1
	echo "Syslog" >> $1
	cat /var/log/syslog | grep -i "UFW BLOCK" | awk '{print "Date: " $1 ":" $2 " Action: " $7 $8 "IP: " $12}' | sort | uniq -dc | sort -rn>> $1
	exit 0
}

# this function checks the /var/log/auth.log for any failed attempts a user has made
# the first parameter is the username you are searching against, the second parameter is either -b or -p
# -b will block that ip using the iptables
# -p will simply print out the ip and how many times it has incorrectly attempted to login
# todo add in failed attempt, and sort by date.
# input 1 the user you are searching for
# input 2 either -b for block or -p for print
function loginHistory {

        #grep searches the entire file for user={the given user}, awk breaks each line up by spaces and then prints the 16th field which is the ip
        #cut splits the string in 2 by '=' and takes the second field. xargs will trim all whitespace
        #once all these operations have been completed it saves it to the $ip variable

	lines=$(sudo grep -i "user=$1" /var/log/auth.log | grep -i 'authentication failure' | awk '{print $1 ":" $2 "-" $16}' | sort | uniq -dc | sort -rn | awk '{print $1 "-" $2}')
	for line in $( echo -n $lines);
	do
		#splitting the string into variables
		count=$(echo $line | awk -F"-" '{print $1}')
		date=$(echo $line | awk -F"-" '{print $2}')
		ip=$(echo $line | awk -F"-" '{print $3 }'  | cut -d'=' -f2)

		#if it is a -b the count is > 50 and the ip isn't empty then block the ip
		if [[ $2 == '-b' && ! -z "$ip" && $count -gt 50 ]]; then
			# a simple if statement to see if the ip address is already blocked in the iptables
			contains=$( sudo iptables --list | grep -i "$ip" )
			if [[ -z "$contains" ]]; then
				iptables -A INPUT -p all -s $ip -j DROP
                		echo "IP:$ip was blocked"
			fi
        	fi
		#if ip isn't empty and is -p then print out the results.
        	if [[ $2 == '-p' && ! -z "$ip" && $count -gt 50 ]]; then
			echo "Date: $date, Address: $ip, Attemts made:$count"
        	fi
	done

        exit 0

}


# a function that will scan a given directory for any files accessed, modified, or  created at a given timestamp
# input 1 the folder you wish to search
# input 2 the given timestamp
# input 3 type, m, a, or c
# input 4 outfile
function scanForTimestamp {
	folder=$1
	timestamp=$2
	type=$3
	out_file=$4

	result=""
	echo "scanning for files now..."
	if [ $3 == m ]; then
		result="$(find $1 -mtime $2 -printf '%Tc %p \n')"
	elif [ $3 == a ]; then
		result="$(find $1 -atime $2 -printf '%Tc %p \n')"
	else
		result="$(find $1 -ctime $2 -printf '%Tc %p \n')"
	fi
	echo "${result}"
	# if the fourth param is empty
	if [ ! -z "$4" ]; then
		echo "${result}" > $4
	fi
}

# a simple helper function to print out the script usage
function printHelp {
	echo ""
	echo "Help -h"
	echo "Scan Logs -s [Output File]"
	echo "Check Login History -l [User] [-b Block IP | -p Print results]"
	echo "Scan For Timestamp -t [target folder] [days ago] [Type I.e m=last modified | c=last permission change | a=last accessed] [Output File]"
	echo ""
	exit 0
}

# the core of the script.
# will accept -h for help
# -s for scan logs
# -l for check login history
# or -t scan for timestamp
while getopts "hs:l::t::" flag;
do
	case "$1" in
		 -h)
			printHelp
			;;
		-s)
			#if doesn't contain enough parameters print help and break
			if [[ -z "$2" ]]; then
				printHelp
				exit 0
			fi
			scanLogs $2
			;;
		-l)
                        # if the third parameter is empty then there are not enough parameters
                        if [[ -z "$3" ]]; then
                                printHelp
                                exit 0
                        fi
                        loginHistory $2 $3
                        ;;

		-t)
			#if doesn't have enough parameters then print help screen and break
			if [[ -z "$5" ]]; then
				printHelp
				exit 0
			fi
			scanForTimestamp $2 $3 $4 $5
			;;
		*)
			printHelp
			exit 0
			;;
	esac

done
