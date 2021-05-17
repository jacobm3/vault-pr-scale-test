#!/bin/bash

. count.conf

for x in `seq 2 $count`; do
. env.$x.sh
unset VAULT_TOKEN
echo -n "$x: "
vault login -method=userpass username=super password=super >/dev/null 2>&1
vault write transit/encrypt/orders \
    plaintext=$(base64 <<< "4111 1111 1111 1111") | grep ciphertext
done
