echo "$SERVER" `wget -q -T 2 -O - "http://$1/digest" | wc`
