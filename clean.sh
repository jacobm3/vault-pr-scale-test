
base=`pwd`

pgrep vault | xargs kill 2>/dev/null
 
rm -fr raft-vault* log.* *.hcl 2nd-token.*.json env.*.sh init.*.json start.*.log setup.*.log
