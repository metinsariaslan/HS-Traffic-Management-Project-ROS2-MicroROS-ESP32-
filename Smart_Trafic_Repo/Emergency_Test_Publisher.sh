#!/bin/bash

TOPIC="/traffic/input/road/emergency"

ros2 topic pub --once $TOPIC std_msgs/msg/String \
'{
  "data": "{\"emergency_present\":true,\"type\":\"ambulance\",\"id\":\"emg_01\",\"pos\":18.20,\"speed\":1.20,\"siren\":true}"
}'
