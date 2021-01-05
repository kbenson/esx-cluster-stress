MYID="$RANDOM"
echo "Getting[$MYID] $1 `date`"
echo "Finished[$MYID] $1" `wget -q -T 2 -O - "http://$1/digest" | wc` `date`
