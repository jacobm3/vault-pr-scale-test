#!/bin/bash -x

x=$1

echo
echo "Setting up performance replica $x"

# gen 2ndary token on primary
echo
echo "Generating secondary-token on primary cluster for replica $x"
. env.1.sh
vault write sys/replication/performance/primary/secondary-token -format=json id=$x > 2nd-token.$x.json

# activate 2ndary
. env.$x.sh

echo
echo "Activating secondary $x"
token=`jq -r .wrap_info.token < 2nd-token.$x.json`
vault write sys/replication/performance/secondary/enable token=$token

echo
echo "Waiting for replica $x to come online"
cluster=null
while [ "$cluster" == "null" ]; do
	sleep 1;
	cluster=`vault status -format=json | jq -r .leader_address`
done

vault status -format=json

vault read -format=json sys/replication/performance/status

disown -a 
