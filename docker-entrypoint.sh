#!/bin/bash

set -e

# if service discovery was activated, we overwrite the BACKEND_SERVER_LIST with the
# results of DNS service lookup
if [ -n "$DB_SERVICE_NAME" ]; then
  BACKEND_SERVER_LIST=`getent hosts tasks.$DB_SERVICE_NAME|awk '{print $1}'|tr '\n' ' '`
fi



# We break our IP list into array
IFS=', ' read -r -a backend_servers <<< "$BACKEND_SERVER_LIST"


config_file="/etc/maxscale.cnf"

# We start config file creation

cat <<EOF > $config_file
[maxscale]
threads=$MAX_THREADS

[Galera Service]
type=service
router=readconnroute
router_options=synced
servers=${BACKEND_SERVER_LIST// /,}
user=$MAX_USER
passwd=$MAX_PASS
enable_root_user=$ENABLE_ROOT_USER

[Galera Listener]
type=listener
service=Galera Service
protocol=MySQLClient
port=3306

[Galera Monitor]
type=monitor
module=galeramon
servers=${BACKEND_SERVER_LIST// /,}
user=$MAX_USER
passwd=$MAX_PASS

[CLI]
type=service
router=cli
[CLI Listener]
type=listener
service=CLI
protocol=maxscaled
port=6603

# Start the Server block
EOF

# add the [server] block
for i in ${!backend_servers[@]}; do
cat <<EOF >> $config_file
[${backend_servers[$i]}]
type=server
address=${backend_servers[$i]}
port=$BACKEND_PORT
protocol=MySQLBackend

EOF

done


exec "$@"

