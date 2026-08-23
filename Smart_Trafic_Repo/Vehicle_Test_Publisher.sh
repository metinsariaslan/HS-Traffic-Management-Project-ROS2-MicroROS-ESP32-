#!/bin/bash

TOPIC="/traffic/input/road/register"

for i in $(seq -w 1 10)
do
  POSITION=$(echo "$i * 10" | bc)

  ros2 topic pub --once $TOPIC std_msgs/msg/String \
  "{\"data\": \"{\\\"vehicle_id\\\":\\\"veh_$i\\\",\\\"vehicle_type\\\":\\\"normal\\\",\\\"road_id\\\":\\\"main\\\",\\\"position\\\":$POSITION,\\\"speed\\\":1.0}\"}"

  sleep 2
done