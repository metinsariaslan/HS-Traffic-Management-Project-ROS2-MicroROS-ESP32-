# Smart Traffic Light — ROS 2 Workspace (Traffic Management Side)

This is the **Linux / ROS 2 side** of the Smart Traffic Light project: the
decision-making and simulation nodes that run on a PC and talk to the physical
ESP32 traffic light over **micro-ROS**. The ESP32 firmware lives in a separate
repository — see its own `README.md` for building and flashing that side.

## 1. What's in This Workspace

A standard `colcon` workspace (`src/`, `build/`, `install/`, `log/`) containing 5
ROS 2 packages:

| Package | Status | Role |
|---|---|---|
| `traffic_controller` | ✅ Implemented | Intersection Controller — the central decision-making node |
| `vehicle_node` | ✅ Implemented | Simulates a normal vehicle approaching the intersection |
| `traffic_common_data` | ✅ Implemented | Shared enums / reference JSON schemas used across nodes |
| `pedestrian_node` | 🚧 Scaffolded, **not yet implemented** | Will simulate pedestrian crossing requests |
| `emergency_vehicle_node` | 🚧 Scaffolded, **not yet implemented** | Will simulate an emergency vehicle (currently replaced by a manual test script, see §6) |

```
Smart_Trafic_Repo/
├── src/
│   ├── traffic_controller/
│   ├── vehicle_node/
│   ├── traffic_common_data/
│   ├── pedestrian_node/          # empty skeleton — future work
│   └── emergency_vehicle_node/   # empty skeleton — future work
├── Vehicle_Test_Publisher.sh     # manually publishes 10 fake vehicles
├── Emergency_Test_Publisher.sh   # manually publishes one emergency event
└── (build/, install/, log/ — generated, not checked in)
```

## 2. Requirements

- **Ubuntu 24.04 LTS** + **ROS 2 Jazzy**, *or* a Docker image with the same
  (e.g. `osrf/ros:jazzy-desktop`) — see §3b
- `colcon`, `rosdep`
- The **micro-ROS Agent**, to bridge this workspace to the ESP32 (§5) — this is a
  separate install, not a ROS 2 package that ships with `ros-jazzy-desktop`

## 3a. Option A — Native ROS 2 Jazzy Install

```bash
# 1. Enable the Universe repo
sudo apt update
sudo apt install -y software-properties-common
sudo add-apt-repository universe
sudo apt update

# 2. Ensure a UTF-8 locale
sudo apt install -y locales
sudo locale-gen en_US en_US.UTF-8
sudo update-locale LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8
export LANG=en_US.UTF-8

# 3. Add the ROS 2 apt repository
sudo apt install -y curl gnupg2
sudo curl -sSL https://raw.githubusercontent.com/ros/rosdistro/master/ros.key \
  -o /usr/share/keyrings/ros-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) \
signed-by=/usr/share/keyrings/ros-archive-keyring.gpg] \
http://packages.ros.org/ros2/ubuntu $(. /etc/os-release && echo $UBUNTU_CODENAME) main" \
  | sudo tee /etc/apt/sources.list.d/ros2.list > /dev/null
sudo apt update

# 4. Install ROS 2 Jazzy (desktop) + dev tools
sudo apt install -y ros-jazzy-desktop
sudo apt install -y python3-colcon-common-extensions python3-rosdep python3-vcstool git

# 5. Initialise rosdep
sudo rosdep init
rosdep update

# 6. Source ROS 2 in every terminal (and persist it)
echo "source /opt/ros/jazzy/setup.bash" >> ~/.bashrc
source ~/.bashrc
```

Verify with the standard demo:

```bash
# Terminal 1
ros2 run demo_nodes_cpp talker
# Terminal 2
ros2 run demo_nodes_py listener
```

## 3b. Option B — Docker

If you don't want to install ROS 2 on the host:

```bash
docker run -it --rm --net=host -v $(pwd):/ws osrf/ros:jazzy-desktop bash
```

- `--net=host` is important — ROS 2's default DDS discovery uses multicast, which
  generally does **not** work across a container's bridged network, and this
  workspace needs to see the ESP32 on the LAN.
- This repo does not currently ship its own `Dockerfile`; the official
  `osrf/ros:jazzy-desktop` image is a good starting point. Inside the container you
  still need to install the micro-ROS Agent (§5) and this workspace's own
  dependencies (§4) — nothing beyond base ROS 2 is baked in.

## 4. Building This Workspace

```bash
cd Smart_Trafic_Repo
rosdep install --from-paths src --ignore-src -r -y
colcon build
source install/setup.bash
```

> **Note:** `traffic_controller/package.xml` currently doesn't declare its
> `rclpy` / `std_msgs` / `traffic_common_data` dependencies explicitly, even though
> `controller_node.py` imports all three. In practice this doesn't break the build
> because `rclpy`/`std_msgs` already come with `ros-jazzy-desktop` and
> `traffic_common_data` is built earlier in the same workspace — but `rosdep` won't
> know to install them on a machine that's missing base ROS 2 packages. If you hit
> an import error, it's a missing dependency declaration, not a broken build; adding
> the three `<depend>` tags to that `package.xml` is the correct long-term fix.

## 5. Installing and Running the micro-ROS Agent

The Agent is what actually bridges the ESP32's micro-ROS client into this ROS 2
graph. It's not part of `ros-jazzy-desktop` and is normally built from source via
`micro-ros-setup`:

```bash
mkdir -p ~/microros_ws/src
cd ~/microros_ws
git clone -b jazzy https://github.com/micro-ROS/micro-ros-setup.git src/micro-ros-setup

sudo apt update
rosdep update
rosdep install --from-paths src --ignore-src -y

colcon build
source install/local_setup.bash

ros2 run micro_ros_setup create_agent_ws.sh
ros2 run micro_ros_setup build_agent.sh
source install/local_setup.bash
```

Then, every time you need it (start this **before** powering on the ESP32):

```bash
ros2 run micro_ros_agent micro_ros_agent udp4 --port 8888
```

Find the IP address the ESP32 should connect to with `ip addr` or `hostname -I` —
this must match `ROS_AGENT_IP` in the ESP32 firmware's `ros_controller.c` (see the
firmware repo's README). If your PC's IP changes, update, rebuild, and reflash the
firmware.

## 6. Running the Nodes

```bash
# Terminal 1 — the decision-making node
ros2 run traffic_controller controller_node

# Terminal 2 — a simulated vehicle
ros2 run vehicle_node vehicle_node
```

`pedestrian_node` and `emergency_vehicle_node` have no runnable entry points yet
(empty skeleton packages) — use the provided shell scripts to simulate their
traffic in the meantime:

```bash
chmod +x Vehicle_Test_Publisher.sh Emergency_Test_Publisher.sh

./Vehicle_Test_Publisher.sh      # publishes 10 fake vehicle registrations
./Emergency_Test_Publisher.sh    # publishes one emergency-vehicle event
```

## 7. ROS 2 Topics in This System

| Topic | Type | Publisher | Subscriber(s) | Rate / Trigger |
|---|---|---|---|---|
| `/traffic/input/road/register` | `std_msgs/String` (JSON) | `vehicle_node` | `traffic_controller_node` | every 2.0 s |
| `/traffic/input/road/status` | `std_msgs/String` (JSON) | `traffic_controller_node` | `vehicle_node` | every 2.0 s |
| `/traffic/input/road/emergency` | `std_msgs/String` (JSON) | test script / (planned `emergency_vehicle_node`) | `traffic_controller_node` | event-triggered |
| `/traffic/input/pedestrian/light1` | `std_msgs/String` (JSON) | (planned `pedestrian_node`) | `traffic_controller_node`, `vehicle_node` | event-triggered, planned |
| `/traffic/output/light1/cmd` | `std_msgs/String` (JSON) | `traffic_controller_node` | **ESP32** (`esp32_traffic_light_node`) | every 2.0 s |
| `/traffic/input/status/light1` | `std_msgs/String` (JSON) | **ESP32** (`esp32_traffic_light_node`) | `traffic_controller_node` | every 2000 ms |

See each package's source for exact JSON field names — in particular, note that
`/traffic/input/road/emergency`'s actual field names (`type`, `id`, `pos`, `speed`,
`siren`) differ from the longer reference names in
`traffic_common_data/Data_Struct_Topics.py` (`emergency_type`, `vehicle_id`,
`position`, `priority_level`, `siren_on`) — the code and the test script agree with
each other, but the reference schema file is out of date and should be corrected.

## 8. Verifying the Full System (PC ↔ ESP32)

With the Agent, `controller_node`, and the powered-on ESP32 all running:

```bash
ros2 node list
# expect: /traffic_controller_node  and  /esp32_traffic_light_node

ros2 topic echo /traffic/input/status/light1
# a status message every ~2 s confirms the ESP32 is connected and reporting
```

## 9. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| ESP32 never shows up in `ros2 node list` | Agent not running, wrong port, or a firewall blocking UDP 8888 | Start the Agent first; check `sudo ufw status` |
| `talker`/`listener` demo works but no custom topics appear | Forgot to `source /opt/ros/jazzy/setup.bash` in that terminal | Source it, or make sure it's in `~/.bashrc` |
| Build fails referencing `catkin_pkg` or similar while building the Agent | Missing Python build deps for colcon/ament (same issue as the ESP32-side build) | `pip3 install catkin_pkg lark-parser colcon-common-extensions empy importlib-resources` |
| Nodes on different machines/subnets can't discover each other | Multicast DDS discovery not routed across the network | Keep the PC and ESP32 on the same subnet, or use `--net=host` in Docker / configure a discovery server |
| Emergency test script has no effect | `traffic_controller_node` isn't running, or it already timed out the emergency (20 s timeout with no repeated messages) | Make sure the controller node is running first; re-run the script if needed |

## 10. Known Limitations

- `pedestrian_node` and `emergency_vehicle_node` are unimplemented — the pedestrian
  topic has no real publisher yet, and emergency events must be triggered manually.
- Messages are hand-serialised JSON over `std_msgs/String` rather than generated ROS
  2 interfaces, so there's no compile-time guarantee that a publisher's fields match
  what a subscriber reads (see the emergency-topic schema note in §7).
- `traffic_controller`'s `package.xml` is missing some `<depend>` declarations
  (see §4).
- `EMERGENCY` mode commands the light straight to GREEN with no yellow/all-red
  clearance interval — acceptable for this single-light prototype, not for a real
  intersection.

## 11. License / Authors

Student project — Smart Traffic Light system. Traffic-management ROS 2 nodes
implemented by the team; this README covers the environment setup needed to run
them alongside the ESP32 firmware repository.
