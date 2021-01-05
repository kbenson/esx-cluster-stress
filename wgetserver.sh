echo "Getting $1"
echo "Finished $1" `wget -q -T 2 -O - "http://$1/digest" | wc`
