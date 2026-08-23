# HS-Traffic-Management-Project-ROS2-MicroROS-ESP32

A smart-intersection traffic management system built across three sub-projects: a
MATLAB simulation used to model and validate the traffic-control logic, a ROS 2
(Jazzy) workspace that implements that logic as real-time decision-making nodes on
Linux, and a micro-ROS-enabled ESP32 firmware that drives a physical traffic light in
response. Together they form a full pipeline from algorithm design, to simulated
validation, to real-time control, to physical actuation.

## Repository Structure

```
.
├── traffic_manager/               # ROS 2 (Jazzy) workspace — traffic-management logic
├── esp32_micro_ros/                # ESP32 firmware — micro-ROS client + physical light control
└── FinalVersion_TrafficLightRos/   # MATLAB/Simulink model — emergency-vehicle simulation
```

> `traffic_manager/` and `esp32_micro_ros/` names above are placeholders — rename to
> match your actual folder names for those two sub-projects.

## Sub-Projects

### 1. Traffic Manager (ROS 2 / Linux)
The decision-making core of the system. A ROS 2 Jazzy workspace containing the
Intersection Controller node and supporting simulation nodes (vehicle registration,
pedestrian requests, emergency-vehicle priority). It evaluates live traffic
conditions and publishes light-control commands and status summaries over standard
ROS 2 topics.

➡️ See [`traffic_manager/README.md`](./traffic_manager/README.md) for setup,
dependencies, and how to run it.

### 2. ESP32 Firmware (micro-ROS)
The physical actuation layer. ESP-IDF/FreeRTOS firmware running on an ESP32 that
connects into the same ROS 2 graph as a micro-ROS client over UDP/XRCE-DDS. It
drives a real red/yellow/green LED signal, supports a network-independent fail-safe
cycling mode, and reports its live physical state back to ROS 2.

➡️ See [`esp32_micro_ros/README.md`](./esp32_micro_ros/README.md) for setup,
dependencies, and how to build/flash it.

### 3. MATLAB Simulation — `FinalVersion_TrafficLightRos/`
An emergency-vehicle-priority simulation for the intersection, built in
MATLAB/Simulink. It models how an emergency vehicle approaching the intersection
should preempt normal signal timing — the same behavior implemented live in the
`EMERGENCY` control mode of the ROS 2 traffic manager and ESP32 firmware, here
studied and validated offline before/alongside the real-time implementation.

➡️ See [`FinalVersion_TrafficLightRos/README.md`](./FinalVersion_TrafficLightRos/README.md)
for MATLAB/Simulink version, required toolboxes, and how to run it.

## How the Three Pieces Fit Together

```
   MATLAB Simulation                ROS 2 Traffic Manager              ESP32 Firmware
 (FinalVersion_TrafficLightRos:  ─▶   (real-time decision logic,   ─▶   (micro-ROS client,
  emergency-priority modeling)         Linux, ROS 2 Jazzy)                physical LED control)
                                          │      ▲
                                          │      │ status feedback
                                          ▼      │
                                   micro-ROS Agent (UDP/XRCE-DDS bridge)
```

The MATLAB model informed the emergency-priority control logic implemented in the
ROS 2 traffic manager's `EMERGENCY` mode. The traffic manager runs on a PC and
publishes light-control commands over ROS 2; the micro-ROS Agent bridges those
commands to the ESP32, which physically actuates the light and reports its real
state back — closing the loop.

## Getting Started

Each sub-project has its own dependencies and setup process (documented in its own
README) — there is no single top-level build step. As a starting point:

1. Read [`traffic_manager/README.md`](./traffic_manager/README.md) and install ROS 2
   Jazzy + the micro-ROS Agent.
2. Read [`esp32_micro_ros/README.md`](./esp32_micro_ros/README.md) and set up
   ESP-IDF to build and flash the firmware.
3. Read
   [`FinalVersion_TrafficLightRos/README.md`](./FinalVersion_TrafficLightRos/README.md)
   for the MATLAB/Simulink requirements if you want to run or modify the emergency
   simulation.
4. With the ESP32 flashed, the micro-ROS Agent running, and the traffic manager
   nodes running, the full system communicates over the ROS 2 topics documented in
   the `traffic_manager` README.

## Known Limitations

A full, per-project list of known issues and future work is documented in each
sub-project's own README. At a system level:

- Communication between the ROS 2 side and the ESP32 uses hand-serialized JSON over
  `std_msgs/String` rather than generated ROS 2 interfaces.
- Some simulated actors (pedestrian requests, emergency vehicles) are currently
  triggered manually / via test scripts rather than dedicated simulation nodes.
- The emergency-priority behavior does not yet implement a full yellow/all-red
  clearance sequence — see the ESP32 firmware README for details.

## Authors

- **Traffic Manager (Smart_Trafic_Repo) & ESP32 Firmware (ESP_Trafic_Light)** — Metin Sariaslan
- **Emergency Simulation (`FinalVersion_TrafficLightRos`, MATLAB/Simulink)** —
  Atharav Karande, Maribel Corondo
- **Research** — Daniel Dumila
