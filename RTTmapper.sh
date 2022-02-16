#!/bin/bash

# This script downloads the latest Cardano's relays list from Cardano Expolorer and measure the Round Trip Times (RTT) for each relays (peer).
# To verify the geo information provided by Cardano Explorer, a further geo-location of the XX best RTT machines is done.
# The output list is saved to a CSV file. This can be imported within an excel file to filter data and cherry picking the relays with
# the best RTT for each continent/country with the aim to build up a good performing mainnet-topology.json file.
# A good performing topology file, maximize the blocks propagation time and helps to compete in slot battles.
#
# Before use this script, please fully undestand how the Cardano's topology works, what "blocks propagation" is and why RTT can be
# crucial in a slot height battle.
#
# HOW TO USE THE SCRIPT:
#
#   - First, make sure you have the little helper tool 'tcptraceroute' installed. if not, the script will tells  you to install it.
#     This tool is needed to make a "ping" request to the open tcp port if the normal ping command fails.
#   - Set CONTINENT to retrieve the relays belonging to a specific country.
#   - Set the SAVETOP variable to save the top XX reachable relays, geo-located within the target continent. If you have for example 500
#     relays from Cardano Explorer for the continent NA (North America), the script will geo-locate (from best to worst RTT) untile collected
#     and saved XX relays matching the target continent.
#   - If you wanna share a screen capture to the community but you want to hide all the IPs, set the parameter HIDEIP to YES
#   - Enable/Disable the GeoLocation lookup for all the peers in the summary setting up the SHOWGEOINFO variable.
#     If disables, the script will not produce a CSV output file.
#
# You're done, just call the script:  ./pingNodes.sh
#
########################################################################################################

### Get this machine public IP
MYIP=$(dig +short myip.opendns.com @resolver1.opendns.com)

### Retrieve from Cardano Explorer the relays list of a specific country
declare -A continents_list=(["EU"]="Europe" ["AF"]="Africa" ["NA"]="North America" ["AS"]="Asia" ["SA"]="South America" ["AN"]="Antartica" ["OC"]="Oceania")
CONTINENT="EU" #Use the country code or ALL for a complete list (EU, AF, NA, AS, SA, AN, OC)
#CONTINENT="ALL" #Retrieve all the peers from Cardano Explorer.

#Translate continent code to extended textual name
TARGET_CONTINENT=${continents_list[$CONTINENT]}

### Geo Locate best peers since XX were collected to a CSV output file
### json.geoiplookup.io API only allows 500 request/hour! Don't run the script too often.
SAVETOP=150		#Show, locate and save top XX relays to CSV file, default
#SAVETOP=0		#Show, locate and save ALL relay to CSV file

### Hide IPs in the summary to share a screenshot with the community
HIDEIP="NO"		#Show the IPs, default
#HIDEIP="YES"	#Hide the IPs

### Retrieve, show and save GeoLocation information. Uses GeoService via https://json.geoiplookup.io/, NOT FOR COMMERCIAL USE, USE IT ONLY FOR PRIVATE TESTING!
### The GeoService, in its free version, is bounded to 500 query/hour. Take it into account when you run the script.
SHOWGEOINFO="YES"	#Lookup each IP in the summary for Geo information (slow), default
#SHOWGEOINFO="NO"   #Don't lookup the Geo information

########################################################################################################
# ------ Don't edit below this line ------
########################################################################################################

VERSION="1.0"

exists()
{
  command -v "$1" >/dev/null 2>&1
}

#If not exists, create the directory were CSV output files are stored
DIRECTORY="./results"
if [ ! -d $DIRECTORY ]; then
  mkdir ./results # Control will enter here if $DIRECTORY doesn't exist.
fi

#Compose the filename and clear its content if exists
filename=./results/$(printf $(date '+%Y-%m-%d'))_$(printf $CONTINENT)_top$(printf $SAVETOP).csv
> $(echo $filename)

#Check if tcptraceroute is installed
if ! exists tcptraceroute; then
  echo -e "\nPlease install the little tool 'tcptraceroute' !\n"
  echo -e "On Ubuntu/Debian like:\n\e[97msudo apt update && sudo apt -y install tcptraceroute\e[0m\n"
  echo -e "Thx! :-)\n"
  exit 2
fi

#Check HideIP
if [[ ${HIDEIP^^} == "NO" ]]; then HIDEIP="NO"; else HIDEIP="YES"; fi

#Check ShowGeoInfo
if [[ ${SHOWGEOINFO^^} == "NO" ]]; then SHOWGEOINFO="NO";
  else SHOWGEOINFO="YES";

	#Check if curl and jq is installed
	if ! exists curl; then
	  echo -e "\nTo use the SHOWGEOINFO feature, you need the tool 'curl' !\n"
	  echo -e "On Ubuntu/Debian like:\n\e[97msudo apt update && sudo apt -y install curl\e[0m\n"
	  echo -e "Thx! :-)\n"
	  exit 2
	fi
        if ! exists jq; then
          echo -e "\nTo use the SHOWGEOINFO feature, you need the tool 'jq' !\n"
          echo -e "On Ubuntu/Debian like:\n\e[97msudo apt update && sudo apt -y install jq\e[0m\n"
          echo -e "Thx! :-)\n"
          exit 2
        fi
   fi

#Initialize the variables
uniqPeers=()
netstatPeers=()
savedCNT=()

#Retrieve the latest topology throught Cardano Explorer API
echo
echo -e "-------- Pulling relays list from Cardano Explorer for county code (${CONTINENT})... --------"
echo

if [[ $CONTINENT == "ALL" ]]; then
   content=$(curl -X GET -H "Content-type: application/json" -H "Accept: application/json" "https://explorer.mainnet.cardano.org/relays/topology.json")
else
   #Filter relays over continent belonging
   content=$(curl -X GET -H "Content-type: application/json" -H "Accept: application/json" "https://explorer.mainnet.cardano.org/relays/topology.json" | jq --arg TARGET_CONTINENT "$TARGET_CONTINENT" -r 'del(.Producers[] | select (.continent!=$TARGET_CONTINENT))')
fi

echo
echo -e " ---------------------------------------------------------------------------------------"

#Delete the public IP of this machine from the list and adjust json in a correct format
uniqPeers=$(echo "${content}"| jq --arg MYIP $MYIP -r 'del(.Producers[] | select (.addr==$MYIP))' | jq -r '.Producers[] | "\(.addr):\(.port) "')

# (to test) consider only unique values
# uniqPeers=$(echo "${content}"| jq --arg MYIP $MYIP -r 'del(.Producers[] | select (.addr==$MYIP))' | jq -r '.Producers[] | "\(.addr):\(.port) "' | jq 'unique_by(.addr)' )

# Count total IP:PORT occurrencies
peerCNTABS=$(echo "${content}"| jq -r '.Producers | length')

#Build new NetstatPeers, now only unique
netstatPeers=$(printf '%s\n' "${uniqPeers[@]}")

#Set all Variables to zero
let peerCNT=0; let peerRTTSUM=0; let peerCNT0=0; let peerCNT1=0; let peerCNT2=0; let peerCNT3=0; let peerCNT4=0
let bestRTT=0; let worstRTT=0; let pct1=0; let pct2=0; let pct3=0; let pct4=0;
rtt_results=()

#Print Header
printf "\n pingNodes (Ver ${VERSION}) - Starting...\n\n"

echo -e " --------------------+------------------------------------------------------------------"
printf "          \e[0mMachine IP | \e[97m%s\e[0m" ${MYIP}
printf "               \e[0mPeers | Found \e[97m%d\e[0m unique IPs\n" ${peerCNTABS}

printf "  \e[0m   Locate and save | \e[97mtop %s\e[0m reachable peers\n" ${SAVETOP}

echo -e " --------------------+------------------------------------------------------------------"
echo

#Ping every Node in the list
for PEER in $netstatPeers; do

peerIP=$(echo ${PEER} | cut -d: -f1)
peerPORT=$(echo ${PEER} | cut -d: -f2)

#Ping peerIP
checkPEER=$(ping -c 2 -i 0.3 -w 1 ${peerIP} 2>&1)
if [[ $? == 0 ]]; then #Ping OK, show RTT
        peerRTT=$(echo ${checkPEER} | tail -n 1 | cut -d/ -f5 | cut -d. -f1)
	pingTYPE="icmp"
	let peerCNT++
	let "peerRTTSUM = $peerRTTSUM + $peerRTT"
	else #Normal ping is not working, try tcptraceroute to the given port
	checkPEER=$(tcptraceroute -n -S -f 255 -m 255 -q 1 -w 1 ${peerIP} ${peerPORT} 2>&1 | tail -n 1)
	if [[ ${checkPEER} == *'[open]'* ]]; then
	        peerRTT=$(echo ${checkPEER} | awk {'print $4'} | cut -d. -f1)
		pingTYPE="tcp/syn"
		let peerCNT++
                let "peerRTTSUM = $peerRTTSUM + $peerRTT" 
		else #Nope, no response
	        peerRTT=-1
		pingTYPE="-------"
	fi
fi

if [[ $peerCNT -gt 0 ]]; then let "peerRTTAVG = $peerRTTSUM / $peerCNT"; fi

#Save best and worst peer
if [[ $peerCNT == 1 && $worstRTT == 0 && $bestRTT == 0 ]]; then worstIP=${peerIP}; worstPORT=${peerPORT}; worstRTT=$peerRTT; bestIP=${peerIP}; bestPORT=${peerPORT}; bestRTT=$peerRTT; fi
if [[ $peerRTT -gt $worstRTT ]]; then worstIP=${peerIP}; worstPORT=${peerPORT}; worstRTT=$peerRTT; fi
if [[ $peerRTT -gt -1 && $peerRTT -lt $bestRTT ]]; then bestIP=${peerIP}; bestPORT=${peerPORT}; bestRTT=$peerRTT; fi

#Set colors and count entries
if [[ $peerRTT -gt 199 ]]; then  COLOR="\e[35m"; let peerCNT4++; 
elif [[ $peerRTT -gt 99 ]]; then  COLOR="\e[91m"; let peerCNT3++;
elif [[ $peerRTT -gt 49 ]]; then  COLOR="\e[33m"; let peerCNT2++;
elif [[ $peerRTT -gt -1 ]]; then  COLOR="\e[32m"; let peerCNT1++;
else COLOR="\e[41m\e[37m"; let peerCNT0++; peerRTT="---"
fi

#peerCNTABS=$(echo "${content}"| jq -r '.Producers | length')
printf "\e[97m%3d/%3d\e[90m # ${COLOR}IP: %-40s\tPORT:%5s\tRTT: %3s ms\t\e[97mAVG: %3s ms\e[90m\t%7s\e[0m\n" ${peerCNT} ${peerCNTABS} ${peerIP:0:38} ${peerPORT} ${peerRTT} ${peerRTTAVG} ${pingTYPE}

if [[ ! "$peerRTT" == "---" ]]; then rtt_results+=("${peerRTT}:${peerIP}:${peerPORT} "); fi

done

#Print Summary
let "peerCNTSKIPPED = $peerCNTABS - $peerCNT - $peerCNT0"  
echo -e "\n\n pingNodes (Ver ${VERSION}) - RTT Summary \n"

printf  "  \e[0m   Locate and save | \e[97mtop %s\e[0m reachable peers\n" ${SAVETOP}

#Generate Bars
barline=" ██████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████"

let "peerCNTREACHED = $peerCNT1 + $peerCNT2 + $peerCNT3 + $peerCNT4"
let peerMAX=0
if [[ $peerCNTREACHED -gt 0 ]]; then
 if [[ $peerCNT1 -gt $peerMAX ]]; then let peerMAX=$peerCNT1; fi
 if [[ $peerCNT2 -gt $peerMAX ]]; then let peerMAX=$peerCNT2; fi
 if [[ $peerCNT3 -gt $peerMAX ]]; then let peerMAX=$peerCNT3; fi
 if [[ $peerCNT4 -gt $peerMAX ]]; then let peerMAX=$peerCNT4; fi

bar1=${barline:0:((1 + ($peerCNT1 * 50 / $peerMAX)))}; let "pct1 = $peerCNT1 * 10000 / $peerCNTREACHED";
bar2=${barline:0:((1 + ($peerCNT2 * 50 / $peerMAX)))}; let "pct2 = $peerCNT2 * 10000 / $peerCNTREACHED";
bar3=${barline:0:((1 + ($peerCNT3 * 50 / $peerMAX)))}; let "pct3 = $peerCNT3 * 10000 / $peerCNTREACHED";
bar4=${barline:0:((1 + ($peerCNT4 * 50 / $peerMAX)))}; let "pct4 = $peerCNT4 * 10000 / $peerCNTREACHED";
fi

echo -e " --------------------+------------------------------------------------------------------"
printf  "     0ms to 50ms RTT | \e[32m%4d  %s %3.1f%%\e[0m\n" ${peerCNT1} " ${bar1}" ${pct1}e-2
printf  "   50ms to 100ms RTT | \e[33m%4d  %s %3.1f%%\e[0m\n" ${peerCNT2} " ${bar2}" ${pct2}e-2
printf  "  100ms to 200ms RTT | \e[91m%4d  %s %3.1f%%\e[0m\n" ${peerCNT3} " ${bar3}" ${pct3}e-2
printf  " more than 200ms RTT | \e[35m%4d  %s %3.1f%%\e[0m\n" ${peerCNT4} " ${bar4}" ${pct4}e-2
printf  "         unreachable | \e[0m%4d\e[0m\n" ${peerCNT0}
printf  "             skipped | \e[0m%4d\e[0m\n" ${peerCNTSKIPPED}
echo -e " --------------------+------------------------------------------------------------------"
printf  "               total | \e[97m%4d established\e[0m\n" ${peerCNTABS}
printf  "   total average RTT | \e[97m%4d ms\e[0m\n" ${peerRTTAVG}

#Hide IPs?
if [[ $HIDEIP == "YES" ]]; then bestIP="x.x.x.x"; worstIP="x.x.x.x"; fi

#Color for best peer and show it
if [[ $bestRTT -gt 199 ]]; then  COLOR="\e[35m";
elif [[ $bestRTT -gt 99 ]]; then  COLOR="\e[91m";
elif [[ $bestRTT -gt 49 ]]; then  COLOR="\e[33m";
elif [[ $bestRTT -gt -1 ]]; then  COLOR="\e[32m";
else COLOR="\e[0m";
fi
printf  "           best Peer | ${COLOR}%s on Port %s with %s ms RTT\e[0m\n" ${bestIP} ${bestPORT} ${bestRTT}

#Color for worst peer and show it
if [[ $worstRTT -gt 199 ]]; then  COLOR="\e[35m";
elif [[ $worstRTT -gt 99 ]]; then  COLOR="\e[91m";
elif [[ $worstRTT -gt 49 ]]; then  COLOR="\e[33m";
elif [[ $worstRTT -gt -1 ]]; then  COLOR="\e[32m";
else COLOR="\e[0m";
fi
printf  "          worst Peer | ${COLOR}%s on Port %s with %s ms RTT\e[0m\n" ${worstIP} ${worstPORT} ${worstRTT}
echo -e " --------------------+------------------------------------------------------------------\n"

#Only show Top-x peers if some peers were reached
if [[ $peerCNTREACHED -gt 0 ]]; then

if [[ $SHOWGEOINFO == "YES" ]]; then
		printf "\e[97m  %4s %-39s %7s   %-6s    %-22s %-21s  %-s\e[0m\n\n" 'Top-X' '      IP' 'PORT' 'RTT (ms)' 'Continent' 'Country(CC)' 'City/Region' # | tee -a "$(echo $filename)"
  		# Write columns name on file
        	printf "Top-X;IP;PORT;RTT (ms);Continent;Country(CC);City/Region\n" >> "$(echo $filename)"
	else
		printf "\e[97m\t%4s\t%41s\t%7s\t%7s\e[0m\n\n" 'Top-X' 'IP     ' 'PORT' 'RTT'
fi

let peerCNT=0;

rtt_sorted=$(printf '%s\n' "${rtt_results[@]}" | sort -n)

for PEER in $rtt_sorted; do

peerRTT=$(echo ${PEER} | cut -d: -f1)
peerIP=$(echo ${PEER} | cut -d: -f2)
peerPORT=$(echo ${PEER} | cut -d: -f3)

let peerCNT++;

#Color for RTT rank
if [[ $peerRTT -gt 199 ]]; then  COLOR="\e[35m";
elif [[ $peerRTT -gt 99 ]]; then  COLOR="\e[91m";
elif [[ $peerRTT -gt 49 ]]; then  COLOR="\e[33m";
elif [[ $peerRTT -gt -1 ]]; then  COLOR="\e[32m";
else COLOR="\e[0m";
fi

#Do the Geo look up if enabled
if [[ $SHOWGEOINFO == "YES" ]]; then
	peerGEOJSON=$(curl -s https://json.geoiplookup.io/${peerIP})
	peerGEO_SUCCESS=$(echo ${peerGEOJSON} | jq -r .success)
	if [[ ${peerGEO_SUCCESS} == "true" ]]; then
		peerGEO_COUNTRYCODE=$(echo ${peerGEOJSON} | jq -r .country_code)
		peerGEO_COUNTRYNAME=$(echo ${peerGEOJSON} | jq -r .country_name)
		peerGEO_COUNTRY=$(echo "${peerGEO_COUNTRYNAME}(${peerGEO_COUNTRYCODE})")
		peerGEO_CITY=$(echo ${peerGEOJSON} | jq -r .city)
		peerGEO_REGION=$(echo ${peerGEOJSON} | jq -r .region)
		peerGEO_CITYREGION=$(echo "${peerGEO_CITY}/${peerGEO_REGION}")
                peerGEO_CONTINENTCODE=$(echo ${peerGEOJSON} | jq -r .continent_code)
                peerGEO_CONTINENTNAME=$(echo ${peerGEOJSON} | jq -r .continent_name)
                peerGEO_CONTINENT=$(echo "${peerGEO_CONTINENTCODE}/${peerGEO_CONTINENTNAME}")
        else
		peerGEO_COUNTRY=""
		peerGEO_CITYREGION=""
        fi
fi

#Hide the IP if enabled
if [[ $HIDEIP == "YES" ]]; then peerIP="x.x.x.x"; fi

#Show IP Geo information and save to CSV file
if [[ $SHOWGEOINFO == "YES" ]]; then
		# print to screen
		printf "\e[97m %4s${COLOR}   %-40s%7s %6s\e[0m ms\e[0m     %-20s   %-20s   %-s\e[0m\n" ${peerCNT} ${peerIP:0:38} ${peerPORT} ${peerRTT} "${peerGEO_CONTINENT}" ${peerLOCATION} "${peerGEO_COUNTRY}" "${peerGEO_CITYREGION}"
		# print to file
		if [[ ${peerGEO_CONTINENTCODE} == $CONTINENT ]]; then  #salva solo se geolocalizza uguale a quello che cerco nelle impostazioni
			printf "%s;%s;%s;%s$s;%s;%s;%s\n" ${peerCNT} ${peerIP} ${peerPORT} ${peerRTT} "${peerGEO_CONTINENT}" ${peerLOCATION} "${peerGEO_COUNTRY}" "${peerGEO_CITYREGION}" >> "$(echo $filename)"
			let savedCNT++;
		elif [[ $CONTINENT == "ALL" ]]; then
			printf "%s;%s;%s;%s$s;%s;%s;%s\n" ${peerCNT} ${peerIP} ${peerPORT} ${peerRTT} "${peerGEO_CONTINENT}" ${peerLOCATION} "${peerGEO_COUNTRY}" "${peerGEO_CITYREGION}" >> "$(echo $filename)";
		fi
else
	printf "\e[97m\t%4s\t${COLOR}%40s\t%7s\t%6s ms\e[0m\n" ${peerCNT} ${peerIP} ${peerPORT} ${peerRTT}
fi

if [[ $savedCNT == $SAVETOP ]]; then break; fi
	done
fi

echo
