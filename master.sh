#!/bin/bash 

# start-nodes.sh

. count.conf

set -x

base=`pwd`

export VAULT_LOG_LEVEL=debug

unset VAULT_ADDR
sudo rm -f log.* 

pgrep vault | xargs kill 2>/dev/null

# export VAULT_ADDR=http://127.0.1.1:8200

set -e

echo "###############################################"
echo "Starting primary node"
echo "###############################################"
x=1

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
    address = "127.0.1.1:8200"
    #cluster_address = "127.0.1.1:8201"
    tls_disable = true
  }
  disable_mlock = true
  cluster_addr = "http://127.0.1.1:8201"
  api_addr = "http://127.0.1.1:8200"
EOF

echo
echo "Starting vault server $x"
vault-ent server -config=vault_${x}.hcl > log.${x} 2>&1 &
sleep 1
#sudo vault server -config=vault_${x}.hcl 

export VAULT_ADDR=http://127.0.1.1:8200
echo
echo "Initializing vault server $x"
vault operator init -format=json -n 1 -t 1 > init.$x.json
roottoken=`jq -r .root_token < init.$x.json`
key=`jq -r .unseal_keys_b64[0] < init.$x.json`

cat > env.$x.sh <<EOF
export VAULT_ADDR=http://127.0.1.1:8200
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
sleep 3;
cluster=`vault status -format=json | jq -r .leader_address`
done

echo
echo "Applying license"
. env.$x.sh
lic=`cat lic`
vault write sys/license text="$lic"

echo "Enabling primary performance replication"
vault write -f sys/replication/performance/primary/enable
sleep 2

echo "###############################################"
echo "# Primary node setup complete."
echo "###############################################"
# end primary node setup



# for each node loop
echo "#####################################################"
echo "# Starting secondary node setup jobs in background"
echo "#####################################################"
jobarrayx=()
for x in `seq 2 $count`; do 
  ./start-unseal-nodes.sh $x &>start.$x.log &
  jobid=$!
  jobarrayx+=($jobid)
  sleep 4
done

echo "###############################################"
echo "# Waiting for standbys to come online..."
echo "###############################################"
for jobid in ${jobarrayx[@]}; do
  wait $jobid
done
# end for each node loop
echo "###############################################"
echo "# Standbys are all online"
echo "###############################################"


# Setup performance replicas

# for each secondary loop
echo "###################################################################"
echo "# Configuring performance replication for each node in background"
echo "###################################################################"

jobarrayy=()
for x in `seq 2 $count`; do 
  ./setup-replication.sh $x &>setup.$x.log & 
  jobid=$!
  jobarrayy+=($jobid)
  sleep 6
done

echo "###############################################"
echo "# Waiting for standbys to come back online..."
echo "###############################################"
for jobid in ${jobarrayy[@]}; do
  wait $jobid
done

# end for each secondary loop

