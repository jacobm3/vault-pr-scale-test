#!/bin/bash


x=$1

base=`pwd`

# for each node loop
sudo ifconfig lo:$x 127.0.1.$x up

thisbase=$base/raft-vault_$x
sudo rm -fr $thisbase
mkdir -p $thisbase

cat > vault_${x}.hcl <<EOF
  storage "raft" {
    path    = "$thisbase"
    node_id = "vault_${x}"
  }
  listener "tcp" {
    address = "127.0.1.${x}:8200"
    #cluster_address = "127.0.1.${x}:8201"
    tls_disable = true
  }
  disable_mlock = true
  cluster_addr = "http://127.0.1.${x}:8201"
  api_addr = "http://127.0.1.${x}:8200"
EOF

echo
echo "Starting vault server $x"
vault-ent server -config=vault_${x}.hcl > log.${x} 2>&1 &
sleep 1
#sudo vault server -config=vault_${x}.hcl 

export VAULT_ADDR=http://127.0.1.$x:8200
echo
echo "Initializing vault server $x"
vault operator init -format=json -n 1 -t 1 > init.$x.json
roottoken=`jq -r .root_token < init.$x.json`
key=`jq -r .unseal_keys_b64[0] < init.$x.json`

cat > env.$x.sh <<EOF
export VAULT_ADDR=http://127.0.1.$x:8200
export VAULT_TOKEN=$roottoken
EOF

echo
echo "Unsealing vault server $x"
vault operator unseal $key
#vault status -format=json

echo
echo "Waiting for online status after unseal"
cluster=null
while [ "$cluster" == "null" ]; do
	sleep 2;
	cluster=`vault status -format=json | jq -r .leader_address`
done

echo
echo "Applying license"
. env.$x.sh
lic=`cat lic`
vault write sys/license text="$lic"

disown -a
