SERVERS=`wget -q -T 1 -O - http://192.168.1.10/servers | cut -d',' -f1 | cut -d':' -f2`
SERVERS="$SERVERS $SERVERS $SERVERS $SERVERS $SERVERS $SERVERS $SERVERS $SERVERS $SERVERS $SERVERS"
SERVERS="$SERVERS $SERVERS"
echo "$SERVERS" | xargs -P8 -n1 echo ./wgetserver.sh

