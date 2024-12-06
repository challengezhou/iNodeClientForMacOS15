#!/bin/bash -e

readonly LOG_MESSAGE_COMMAND=$(basename "${0}")
logMessage()
{
	if ${DEBUG} -eq true ; then
		echo "$(date '+%a %b %e %T %Y') iNode SSL VPN Client: $LOG_MESSAGE_COMMAND: "${@} >> "${SCRIPT_LOG_FILE}"
	fi
}

trim()
{
echo ${@}
}

flushdnscache()
{
    if ${ARG_FLUSH_DNS_CACHE} -eq true ; then
        readonly OSVER="$(sw_vers | grep 'ProductVersion:' | grep -o '10\.[0-9]*')"
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


trap "" TSTP
trap "" HUP
trap "" INT

export PATH="/bin:/sbin:/usr/sbin:/usr/bin"
DEBUG=false
if [ "${1}" == "debug" ] ; then
	DEBUG=true	
fi


if ! scutil -w State:/Network/iNodeSSLVPN &>/dev/null -t 1 ; then
	echo "DEBUG: No data need to clear!"
	exit 0
fi

INODESSLVPN_CONFIG="$( scutil <<-EOF
	open
	show State:/Network/iNodeSSLVPN
	quit
EOF
)"

PSID="$(echo "${INODESSLVPN_CONFIG}" | grep -i '^[[:space:]]*Service :' | sed -e 's/^.*: //g')"
bAlsoUsingSetupKeys="$(echo "${INODESSLVPN_CONFIG}" | grep -i '^[[:space:]]*bAlsoUsingSetupKeys :' | sed -e 's/^.*: //g')"
SCRIPT_LOG_FILE="$(echo "${INODESSLVPN_CONFIG}" | grep -i '^[[:space:]]*ScriptLogFile :' | sed -e 's/^.*: //g')"
ARG_FLUSH_DNS_CACHE="$(echo "${INODESSLVPN_CONFIG}" | grep -i '^[[:space:]]*FlushDNSCache :' | sed -e 's/^.*: //g')"

#maybe error
#PSID_CURRENT="$( scutil <<-EOF |
#	open
#	show State:/Network/iNodeSSLVPN
#	quit
#EOF
#grep Service | sed -e 's/.*Service : //'
#)"

set +e
PSID_CURRENT="$( scutil <<-EOF | 
		open
		show State:/Network/Global/IPv4
		quit
		EOF
		grep PrimaryService | sed -e 's/.*PrimaryService : //'
)"

set -e

if [ "${PSID}" != "${PSID_CURRENT}" ] ; then
	logMessage "$PSID --> $PSID_CURRENT"
fi

DNS_OLD="$( scutil <<-EOF
	open
	show State:/Network/iNodeSSLVPN/OldDNS
	quit
EOF
)"

DNS_OLD_SETUP="$( scutil <<-EOF
	open
	show State:/Network/node/OldDNSSetup
	quit
EOF
)"

TB_NO_SUCH_KEY="<dictionary> {
  inodeNoSuchKey : true
}"

#debugging

logMessage "DEBUG: step one"
logMessage "DEBUG: INODESSLVPN_CONFIG = ${INODESSLVPN_CONFIG}"
logMessage "DEBUG: PSID = ${PSID}"
logMessage "DEBUG: bAlsoUsingSetupKeys = ${bAlsoUsingSetupKeys}"
logMessage "DEBUG: SCRIPT_LOG_FILE = ${SCRIPT_LOG_FILE}"
logMessage "DEBUG: ARG_FLUSH_DNS_CACHE = ${ARG_FLUSH_DNS_CACHE}"
logMessage "DEBUG: PSID_CURRENT = ${PSID_CURRENT}"
logMessage "DEBUG: DNS_OLD = ${DNS_OLD}"
logMessage "DEBUG: DNS_OLD_SETUP = ${DNS_OLD_SETUP}"
logMessage "DEBUG: TB_NO_SUCH_KEY = ${TB_NO_SUCH_KEY}"


if [ "${DNS_OLD}" = "${TB_NO_SUCH_KEY}" ] ; then
	scutil <<-EOF
		open
		remove State:/Network/Service/${PSID}/DNS
		quit
EOF
else
	scutil <<-EOF
		open
		get State:/Network/iNodeSSLVPN/OldDNS
		set State:/Network/Service/${PSID}/DNS
		quit
EOF
fi

if [ "${DNS_OLD_SETUP}" = "${TB_NO_SUCH_KEY}" ] ; then
	if ${bAlsoUsingSetupKeys} ; then
		scutil <<-EOF
			open
			remove Setup:/Network/Service/${PSID}/DNS
			quit
		EOF
	fi
else
	if ${bAlsoUsingSetupKeys} ; then
		scutil <<-EOF
			open
			get State:/Network/iNodeSSLVPN/OldDNSSetup
			set Setup:/Network/Service/${PSID}/DNS
			quit
		EOF
	fi
fi

set +e
new_resolver_contents="`cat /etc/resolv.conf | grep -v '#' 2>/dev/null`"
set -e
scutil_dns="$( scutil --dns)"

#debuging 
logMessage "DEBUG: step two"
logMessage "DEBUG: new_resolver_contents = ${new_resolver_contents}"
logMessage "DEBUG: scutil_dns = ${scutil_dns}"

logMessage "DEBUG: step three"
logMessage "DEBUG: Try to flushDNSCache"
flushdnscache

# Remove our system configuration data
scutil <<-EOF
	open
	remove State:/Network/iNodeSSLVPN/OldDNS
	remove State:/Network/iNodeSSLVPN/OldDNSSetup
	remove State:/Network/iNodeSSLVPN/DNS
	remove State:/Network/iNodeSSLVPN
	quit
EOF

exit 0
