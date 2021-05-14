
base=`pwd`

pgrep vault | xargs kill 2>/dev/null
 
rm -fr raft-vault* log.* *.hcl
