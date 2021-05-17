. env.1.sh

vault policy write super -<<EOF
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOF

vault auth enable userpass

vault write auth/userpass/users/super password="super" policies="super"
