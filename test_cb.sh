#!/bin/bash

printf "Request : \n"




count=1
while [ $count -le 9 ]
do
curl http://localhost:9090/resilient/time
sleep 1
printf "\n Request : curl http://localhost:9090/resilient/time \n"
(( count++ ))
done

