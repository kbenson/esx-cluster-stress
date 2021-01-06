FILE="/dev/shm/serversforkping.`date +%s`"
echo "\"tee\"ing output to $FILE";
lwp-request http://192.168.1.10/servers | cut -d, -f1 | cut -d: -f2 | xargs ./forkping.pl sonic.net google.com | tee $FILE
