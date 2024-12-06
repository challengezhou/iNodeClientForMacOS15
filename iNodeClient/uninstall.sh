#!/bin/sh

echo "launchctl unload service"
sudo launchctl unload /Library/LaunchDaemons/com.apple.iNodeClient.plist
sudo sh /Applications/iNodeClient/StopService.sh
sudo rm -f /Library/LaunchDaemons/com.apple.iNodeClient.plist

Sec=0
while [ 1 ]
do
    IfExistMon=`ps -Ac -o command|grep -x iNodeMon`
    if [ "$IfExistMon" != "" ]
    then
        sleep 1
        Sec=`expr $Sec + 1`

        if [ "$Sec" -gt 10 ]
	then
            sudo killall -9 iNodeMon
        fi
    else
        break
    fi
done

Sec=0
while [ 1 ]
do
    IfExistAuth=`ps -Ac -o command|grep -x AuthenMngService`
    if [ "$IfExistAuth" != "" ]
    then
        sleep 1
        Sec=`expr $Sec + 1`

        if [ "$Sec" -gt 10 ]
	then
            sudo killall -9 AuthenMngService
        fi
    else
        break
    fi
done
    
IfExistUI=`ps -Ac -o command|grep -x iNodeClient`
if [ "$IfExistUI" != "" ]
then
    sleep 5
    sudo killall -9 iNodeClient
fi

if [ -r "/etc/iNode" ]
then
sudo rm -fr /etc/iNode
fi

if [ ! -f "/etc/iNodePortal/inodesys.conf" ]
then
    sudo rm -f /usr/local/lib/libACE*
    sudo rm -f /usr/local/lib/libdnet*
    sudo rm -f /usr/local/lib/libwx*
fi

sudo rm -f /usr/local/lib/libCoreUtils.dylib
sudo rm -f /usr/local/lib/libOesisCore.dylib
sudo rm -f /usr/local/lib/libImpl*
sudo rm -f /usr/local/lib/tables.dat
sudo rm -f /usr/local/lib/libInodeUtility.dylib
sudo rm -f /usr/local/lib/libInodePortalPt.dylib
sudo rm -f /usr/local/lib/libInodeX1Pt.dylib
sudo rm -f /usr/local/lib/libInodeSecurityAuth.dylib
sudo rm -fr /Library/StartupItems/iNodeAuthService
sudo rm -fr /Library/Receipts/iNodeClient.pkg
sudo rm -fr /private/var/db/receipts/com.h3c.inode*

cd ../
sudo rm -fr iNodeClient

