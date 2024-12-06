#!/bin/bash

sudo launchctl unload /Library/LaunchDaemons/com.apple.iNodeClient.plist
echo "stop AuthenMngService"
        
IfExist=`ps -Ac -o command|grep -x iNodeMon`
if [ "$IfExist" != "" ]
then
    /Applications/iNodeClient/iNodeMon -k

    Sec=0
    while [ 1 ]
    do
        IfExist=`ps -Ac -o command|grep -x iNodeMon`
        if [ "$IfExist" != "" ]
        then
            sleep 1
	    Sec=`expr $Sec + 1`

	    if [ "$Sec" -gt 10 ]
	    then
	        killall -9 iNodeMon
	    fi
	else
	    break
	fi
    done
fi
	
IfExist=`ps -Ac -o command|grep -x AuthenMngService`
if [ "$IfExist" != "" ]
then
    /Applications/iNodeClient/AuthenMngService -k
    
    Sec=0
    while [ 1 ]
    do
        IfExist=`ps -Ac -o command|grep -x AuthenMngService`
        if [ "$IfExist" != "" ]
        then
            sleep 1
	    Sec=`expr $Sec + 1`

	    if [ "$Sec" -gt 10 ]
	    then
	        killall -9 AuthenMngService
	    fi
	else
	    break
	fi
    done
else
    echo "AuthenMngService not running"	
fi
 
return 0;

