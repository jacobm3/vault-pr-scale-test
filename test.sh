#!/bin/bash

arrayx=(1 2 7 8)

for x in ${arrayx[@]}; do
  echo $x
done

array=()
for x in `seq 1 5`; do
  sleep 3 &
  jobid=$!
  echo "sleep:$jobid"
  array+=($jobid)
done
 

echo "waiting..."
for x in ${array[@]}; do
  wait $x
done
