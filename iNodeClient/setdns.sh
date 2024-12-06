#!/bin/bash -e

readonly LOG_MESSAGE_COMMAND=$(basename "${0}")
logMessage()
{
	if ${DEBUG} -eq true  ; then
		echo "$(date '+%a %b %e %T %Y') iNode SSL VPN Client: $LOG_MESSAGE_COMMAND: "${@} >> "${SCRIPT_LOG_FILE}"
	fi
}

trim()
{
	echo ${@}
}


setdnserver()
{

set +e
PSID="$( scutil <<-EOF | 
		open
		show State:/Network/Global/IPv4
		quit
		EOF
		grep PrimaryService | sed -e 's/.*PrimaryService : //'
)"

set -e 
MAN_DNS_CONFIG="$( scutil <<-EOF |
		open
		show Setup:/Network/Service/${PSID}/DNS
		quit
EOF
sed -e 's/^[[:space:]]*[[:digit:]]* : //g' | tr '\n' ' '
)"


CUR_DNS_CONFIG="$( scutil <<-EOF |
		open
		show State:/Network/Global/DNS
		quit
EOF
sed -e 's/^[[:space:]]*[[:digit:]]* : //g' | tr '\n' ' '
)"

set +e 

if echo "${MAN_DNS_CONFIG}" | grep -q "ServerAddresses" ; then
		readonly MAN_DNS_SA="$(trim "$( echo "${MAN_DNS_CONFIG}" | sed -e 's/^.*ServerAddresses[^{]*{[[:space:]]*\([^}]*\)[[:space:]]*}.*$/\1/g' )")"
	else
		readonly MAN_DNS_SA="";
fi

if echo "${CUR_DNS_CONFIG}" | grep -q "ServerAddresses" ; then
		readonly CUR_DNS_SA="$(trim "$( echo "${CUR_DNS_CONFIG}" | sed -e 's/^.*ServerAddresses[^{]*{[[:space:]]*\([^}]*\)[[:space:]]*}.*$/\1/g' )")"
	else
		readonly CUR_DNS_SA="";
fi

declare -a vDNS=("${!1}")

if [ ${#vDNS[*]} -eq 0 ] ; then
	readonly DYN_DNS_SA=""
else
	readonly DYN_DNS_SA="${!1}"
fi


set -e

if [ ${#vDNS[*]} -eq 0 ] ; then
	readonly FIN_DNS_SA="${CUR_DNS_SA}"
else
	if [ "${MAN_DNS_SA}" != "" ] ; then
		case "${OSVER}" in
			10.4 | 10.5)
				SDNS="$(echo "${DYN_DNS_SA}" | tr ' ' '\n')"
				(( i=0 ))
				for n in "${vDNS[@]}" ; do
					if echo "${SDNS}" | grep -q "${n}" ; then
						unset vDNS[${i}]
					fi
					(( i++ ))
				done
				if [ ${#vDNS[*]} -gt 0 ] ; then
					readonly FIN_DNS_SA="$(trim "${DYN_DNS_SA}" "${vDNS[*]}" "${MAN_DNS_SA}")"
				else
					readonly FIN_DNS_SA="${DYN_DNS_SA} ${MAN_DNS_SA}"
				fi
				;;
			* )
				readonly FIN_DNS_SA="${DYN_DNS_SA} ${MAN_DNS_SA}"
				;;
		esac
	else
		case "${OSVER}" in
			10.4 | 10.5)
				SDNS="$(echo "${DYN_DNS_SA}" | tr ' ' '\n')"
				(( i=0 ))
				for n in "${vDNS[@]}" ; do
					if echo "${SDNS}" | grep -q "${n}" ; then
						unset vDNS[${i}]
					fi
					(( i++ ))
				done
				if [ ${#vDNS[*]} -gt 0 ] ; then
					readonly FIN_DNS_SA="$(trim "${DYN_DNS_SA}" "${vDNS[*]}")"
				else
					readonly FIN_DNS_SA="${DYN_DNS_SA}"
				fi
				;;
			* )
				readonly FIN_DNS_SA="${DYN_DNS_SA}"
				;;
		esac
	fi
fi

if [ "${FIN_DNS_SA}" = "" -o "${FIN_DNS_SA}" = "${CUR_DNS_SA}" ] ; then
	SKP_DNS_SA="#"
else
	SKP_DNS_SA=""
fi


if [ "${SKP_DNS_SA}" = "#" ] ; then
	readonly SKP_DNS="#"
else
	readonly SKP_DNS=""
	if [ "${FIN_DNS_SA}" != "" ] ; then
		SKP_DNS_SA=""
	fi
fi


readonly SKP_DNS_SA

case "${OSVER}" in
	10.4 | 10.5 | 10.6 )
		readonly SKP_SETUP_DNS="#"
		readonly bAlsoUsingSetupKeys="false"
		;;
	10.7 )
		if [ "${MAN_DNS_SA}" = "" ] ; then
			readonly SKP_SETUP_DNS="#"
			readonly bAlsoUsingSetupKeys="false"
		else
			readonly SKP_SETUP_DNS=""
			readonly bAlsoUsingSetupKeys="true"
		fi
		;;
	* )
		readonly SKP_SETUP_DNS=""
		readonly bAlsoUsingSetupKeys="true"
		;;
esac


original_resolver_contents="`cat /etc/resolv.conf | grep -v '#' 2>/dev/null`"
scutil_dns="$( scutil --dns)"

#debuging 
logMessage "DEBUG: step one"
logMessage "DEBUG: PSID = ${PSID}"
logMessage "DEBUG: MAN_DNS_CONFIG = ${MAN_DNS_CONFIG}"
logMessage "DEBUG: CUR_DNS_CONFIG = ${CUR_DNS_CONFIG}"
logMessage "DEBUG: MAN_DNS_SA = ${MAN_DNS_CONFIG}"
logMessage "DEBUG: CUR_DNS_SA = ${CUR_DNS_SA}"
logMessage "DEBUG: DYN_DNS_SA = ${DYN_DNS_SA}"
logMessage "DEBUG: FIN_DNS_SA = ${FIN_DNS_SA}"
logMessage "DEBUG: SKP_DNS_SA = ${SKP_DNS_SA}"
logMessage "DEBUG: SKP_DNS = ${SKP_DNS}"
logMessage "DEBUG: SKP_SETUP_DNS= ${SKP_SETUP_DNS}"
logMessage "DEBUG: bAlsoUsingSetupKeys = ${bAlsoUsingSetupKeys}"
logMessage "DEBUG: original_resolver_contents= ${original_resolver_contents}"
logMessage "DEBUG: scutil_dns = ${scutil_dns}"


scutil <<-EOF > /dev/null
	open

	d.init
	d.add PID # ${PPID}
	d.add Service ${PSID}
	d.add FlushDNSCache         "${ARG_FLUSH_DNS_CACHE}"
	d.add bAlsoUsingSetupKeys   "${bAlsoUsingSetupKeys}"
	d.add ScriptLogFile         "${SCRIPT_LOG_FILE}"
	set State:/Network/iNodeSSLVPN
	
	
	d.init
	d.add inodeNoSuchKey true
	${SKP_DNS}${SKP_DNS_SA}get State:/Network/Service/${PSID}/DNS
	set State:/Network/iNodeSSLVPN/OldDNS
	
	d.init
	d.add inodeNoSuchKey true
	${SKP_SETUP_DNS}${SKP_DNS}${SKP_DNS_SA}get Setup:/Network/Service/${PSID}/DNS
	set State:/Network/iNodeSSLVPN/OldDNSSetup
	
	# Initialize the new DNS map via State:
	${SKP_DNS}d.init
	${SKP_DNS}${SKP_DNS_SA}d.add ServerAddresses * ${FIN_DNS_SA}
	${SKP_DNS}set State:/Network/Service/${PSID}/DNS

	# If necessary, initialize the new DNS map via Setup: also
	${SKP_SETUP_DNS}${SKP_DNS}d.init
	${SKP_SETUP_DNS}${SKP_DNS}${SKP_DNS_SA}d.add ServerAddresses * ${FIN_DNS_SA}
	${SKP_SETUP_DNS}${SKP_DNS}set Setup:/Network/Service/${PSID}/DNS

	quit
EOF

sleep 1

scutil <<-EOF > /dev/null
	open

	d.init
	d.add inodeNoSuchKey true
	get State:/Network/Global/DNS
	set State:/Network/iNodeSSLVPN/DNS
	
	quit
EOF


readonly NEW_DNS_SETUP_CONFIG="$( scutil <<-EOF |
		open
		show Setup:/Network/Service/${PSID}/DNS
		quit
EOF
sed -e 's/^[[:space:]]*[[:digit:]]* : //g' | tr '\n' ' '
)"

readonly NEW_DNS_STATE_CONFIG="$( scutil <<-EOF |
		open
		show State:/Network/Service/${PSID}/DNS
		quit
EOF
sed -e 's/^[[:space:]]*[[:digit:]]* : //g' | tr '\n' ' '
)"

readonly NEW_DNS_GLOBAL_CONFIG="$( scutil <<-EOF |
		open
		show State:/Network/Global/DNS
		quit
EOF
sed -e 's/^[[:space:]]*[[:digit:]]* : //g' | tr '\n' ' '
)"

readonly EXPECTED_NEW_DNS_GLOBAL_CONFIG="$( scutil <<-EOF |
		open
		show State:/Network/iNodeSSLVPN/DNS
		quit
EOF
sed -e 's/^[[:space:]]*[[:digit:]]* : //g' | tr '\n' ' '
)"

new_resolver_contents="`cat /etc/resolv.conf | grep -v '#' 2>/dev/null`"
scutil_dns="$( scutil --dns)"

#debuging
logMessage "DEBUG: step two"
logMessage "DEBUG: NEW_DNS_SETUP_CONFIG = ${NEW_DNS_SETUP_CONFIG}"
logMessage "DEBUG: NEW_DNS_STATE_CONFIG = ${NEW_DNS_STATE_CONFIG}"
logMessage "DEBUG: NEW_DNS_GLOBAL_CONFIG = ${NEW_DNS_GLOBAL_CONFIG}"
logMessage "DEBUG: EXPECTED_NEW_DNS_GLOBAL_CONFIG= ${EXPECTED_NEW_DNS_GLOBAL_CONFIG}"
logMessage "DEBUG: new_resolver_contents= ${new_resolver_contents}"
logMessage "DEBUG: scutil_dns= ${scutil_dns}"

logMessage "DEBUG: step three"
logMessage "DEBUG: Try to flushDNSCache"

flushdnscache

}

flushdnscache()
{
    if ${ARG_FLUSH_DNS_CACHE} -eq true ; then
        case "${OSVER}" in
            10.4 )
                if [ -f /usr/sbin/lookupd ] ; then
                    /usr/sbin/lookupd -flushcache
                    logMessage "Flushed the DNS Cache"
                else
                    logMessage "/usr/sbin/lookupd not present. Not flushing the DNS cache"
                fi
                ;;
            10.5 | 10.6 )
                if [ -f /usr/bin/dscacheutil ] ; then
                    /usr/bin/dscacheutil -flushcache
                    logMessage "Flushed the DNS Cache"
                else
                    logMessage "/usr/bin/dscacheutil not present. Not flushing the DNS cache"
                fi
                ;;
            * )
				set +e 
				hands_off_ps="$( ps -ax | grep HandsOffDaemon | grep -v grep.HandsOffDaemon )"
				set -e 
				if [ "${hands_off_ps}" = "" ] ; then
					if [ -f /usr/bin/killall ] ; then
						/usr/bin/killall -HUP mDNSResponder
						logMessage "Flushed the DNS Cache"
					else
						logMessage "/usr/bin/killall not present. Not flushing the DNS cache"
					fi
				else
					logMessage "Hands Off is running. Not flushing the DNS cache"
				fi
                ;;
        esac
    fi
}



ARG_FLUSH_DNS_CACHE=false
DEBUG=false
readonly OSVER="$(sw_vers | grep 'ProductVersion:' | grep -o '10\.[0-9]*')"
SCRIPT_LOG_FILE="./iNodeSSLVPN.log"

unset dnsv
((i = 0 ))
for arg in ${@}
do
	if [ "${arg}" == "debug" ] ; then
		DEBUG=true
	elif [ "${arg}" == "flushdns" ] ; then
		ARG_FLUSH_DNS_CACHE=true
	else
		dnsv[${i}]=${arg}
		(( i++ ))
	fi
done


if ! scutil -w State:/Network/iNodeSSLVPN &>/dev/null -t 1 ; then
	logMessage "Don't need to clear garbage."		
else
	logMessage "Need to clear garbage"	
	if ${DEBUG}; then
		./unsetdns.sh debug
	else
		./unsetdns.sh
	fi
fi

setdnserver dnsv[@]

