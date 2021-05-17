#!/bin/bash 

# start-nodes.sh

set -x

base=`pwd`

export VAULT_LOG_LEVEL=debug

unset VAULT_ADDR
sudo rm -f log.* 

pgrep vault | xargs kill 2>/dev/null

# export VAULT_ADDR=http://127.0.1.1:8200

set -e

for x in `seq 1 20`; do 

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

vault-ent server -config=vault_${x}.hcl > log.${x} 2>&1 &
#sudo vault server -config=vault_${x}.hcl 

sleep 0.25

done
