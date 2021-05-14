#!/bin/bash 

set -x
set -e

base=`pwd`

export VAULT_LOG_LEVEL=debug


echo "Initializing primary cluster"
export VAULT_ADDR=http://127.0.1.1:8200

vault operator init -format=json -n 1 -t 1 > init.json

proottoken=`jq -r .root_token < init.json`
key=`jq -r .unseal_keys_b64[0] < init.json`

vault operator unseal $key
vault status -format=json
cluster=null
while [ "$cluster" == "null" ]; do
	sleep 1;
	cluster=`vault status -format=json | jq -r .leader_address`
done
vault login $proottoken
sleep 1
vault write -f sys/replication/performance/primary/enable


# Setup performance replicas


for x in `seq 2 20`; do

echo "Setting up performance replica $x"

# gen 2ndary token on primary
export VAULT_ADDR=http://127.0.1.1:8200
vault login $proottoken
vault write sys/replication/performance/primary/secondary-token -format=json id=$x > 2nd-token.$x.json

# activate 2ndary
export VAULT_ADDR=http://127.0.1.$x:8200
vault operator init -format=json -n 1 -t 1 > init.$x.json
token=`jq -r .root_token < init.$x.json`
key=`jq -r .unseal_keys_b64[0] < init.$x.json`

vault operator unseal $key
vault status -format=json
cluster=null
while [ "$cluster" == "null" ]; do
	sleep 1;
	cluster=`vault status -format=json | jq -r .leader_address`
done
vault login $token

token=`jq -r .wrap_info.token < 2nd-token.$x.json`
vault write sys/replication/performance/secondary/enable token=$token

cluster=null
while [ "$cluster" == "null" ]; do
	sleep 1;
	cluster=`vault status -format=json | jq -r .leader_address`
done

vault status -format=json

vault read -format=json sys/replication/performance/status

done

