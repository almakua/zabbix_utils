#!/bin/bash

#***********************************************************************
#Beginning of custom variables
#Set these to appropriate values before executing script...

baseDir='/location/of/these/files'

zabbixServer='YOUR_ZABBIX_SERVER_DNS_ADDRESS'

zabbixUsername='Admin'
zabbixPassword='zabbix'

zabbixHostGroup='MY_TARGET_HOSTGROUP'
maintenanceWindowName="Maintenance Window for $zabbixHostGroup"

#End of custom variables
#***********************************************************************

header='Content-Type:application/json'
zabbixApiUrl="https://$zabbixServer/zabbix/api_jsonrpc.php"

cd $baseDir

function exit_with_error() {
  echo '********************************'
  echo "$errorMessage"
  echo '--------------------------------'
  echo 'INPUT'
  echo '--------------------------------'
  echo "$json"
  echo '--------------------------------'
  echo 'OUTPUT'
  echo '--------------------------------'
  echo "$result"
  echo '********************************'
  exit 1
}

#------------------------------------------------------
# Auth to zabbix
# https://www.zabbix.com/documentation/3.4/manual/api/reference/user/login
#------------------------------------------------------
errorMessage='*ERROR* - Unable to get Zabbix authorization token'
json=`cat user.login.json`
json=${json/USERNAME/$zabbixUsername}
json=${json/PASSWORD/$zabbixPassword}
result=`curl --silent --show-error --insecure --header $header --data "$json" $zabbixApiUrl`
auth=`echo $result | jq '.result'`
if [ $auth == null ]; then exit_with_error; fi
echo "Login successful - Auth ID: $auth"


#------------------------------------------------------
# Get Hostgroup ID
# https://www.zabbix.com/documentation/3.4/manual/api/reference/hostgroup/get
#------------------------------------------------------
errorMessage="*ERROR* - Unable to get hostgroup ID for host group named '$zabbixHostGroup'"
json=`cat hostgroup.get.json`
json=${json/HOSTGROUP/$zabbixHostGroup}
json=${json/AUTHID/$auth}
result=`curl --silent --show-error --insecure --header $header --data "$json" $zabbixApiUrl`
hostgroupId=`echo $result | jq '.result | .[0] | .groupid' | tr -d "\""`
if [ $hostgroupId == null ]; then exit_with_error; fi
echo "Hostgroup ID for '$zabbixHostGroup': $hostgroupId"

#------------------------------------------------------
# Create Maintenance Window
# https://www.zabbix.com/documentation/3.4/manual/api/reference/maintenance/create
#
# Active since = Right now
# Active since = Right now + 24 hours
# Period type = 'One time only'
# Period start = Right now
# Period length = 10 days
# Maint Type: 'With data collection'
#------------------------------------------------------
errorMessage="*ERROR* - Unable to create maintenance window for '$maintenanceWindowName'"
startTime=`date +%s`
endTime=$((startTime + 86400))
json=`cat maintenance.create.json`
json=${json/MAINTENANCEWINDOWNAME/$maintenanceWindowName}
json=${json/MAINTENANCESTARTTIME/$startTime}
json=${json/MAINTENANCESTARTTIME/$startTime}
json=${json/MAINTENANCEENDTIME/$endTime}
json=${json/HOSTGROUPID/$hostgroupId}
json=${json/AUTHID/$auth}
result=`curl --silent --show-error --insecure --header $header --data "$json" $zabbixApiUrl`
createMaintenanceId=`echo $result | jq '.result.maintenanceids[0]' | tr -d "\""`
if [ $createMaintenanceId == null ]; then exit_with_error; fi
echo "Created maintenance window named '$maintenanceWindowName' and given ID: $createMaintenanceId"

#------------------------------------------------------
# Get Maintenance Window ID
# https://www.zabbix.com/documentation/3.4/manual/api/reference/maintenance/get
#------------------------------------------------------
errorMessage="*WARNING* - Unable to get maintenance window ID for '$maintenanceWindowName'"
json=`cat maintenance.get.json`
json=${json/MAINTENANCEWINDOWNAME/$maintenanceWindowName}
json=${json/AUTHID/$auth}
result=`curl --silent --show-error --insecure --header $header --data "$json" $zabbixApiUrl`
getMaintenanceId=`echo $result | jq '.result | .[0] | .maintenanceid' | tr -d "\""`
if [ $getMaintenanceId == null ]; then exit_with_error; fi
echo "Maintenance window named '$maintenanceWindowName' has ID: $getMaintenanceId"


#------------------------------------------------------
# Delete Maintenance Window
# https://www.zabbix.com/documentation/3.4/manual/api/reference/maintenance/delete
#------------------------------------------------------
errorMessage="*WARNING* - Unable to delete maintenance window named '$maintenanceWindowName' with ID $getMaintenanceId"
json=`cat maintenance.delete.json`
json=${json/MAINTENANCEWINDOWID/$getMaintenanceId}
json=${json/AUTHID/$auth}
result=`curl --silent --show-error --insecure --header $header --data "$json" $zabbixApiUrl`
deleteMaintenanceId=`echo $result | jq '.result.maintenanceids[0]' | tr -d "\""`
if [ $deleteMaintenanceId == null ]; then exit_with_error; fi
echo "Maintenance window with ID $deleteMaintenanceId deleted"


#------------------------------------------------------
# Logout of zabbix
# https://www.zabbix.com/documentation/3.4/manual/api/reference/user/logout
#------------------------------------------------------
errorMessage='*ERROR* - Failed to logout'
json=`cat user.logout.json`
json=${json/AUTHID/$auth}
result=`curl --silent --show-error --insecure --header $header --data "$json" $zabbixApiUrl`
logout=`echo $result | jq '.result'`
if [ $logout == null ]; then exit_with_error; fi
echo 'Successfully logged out of Zabbix'