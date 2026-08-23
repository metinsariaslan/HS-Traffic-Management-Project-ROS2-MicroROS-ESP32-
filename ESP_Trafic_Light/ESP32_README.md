# Smart Traffic Light — ESP32 / micro-ROS Firmware

Embedded firmware for the ESP32 side of the Smart Traffic Light project. It drives a
physical red/yellow/green light over three GPIOs and connects to the team's ROS 2
network as a **micro-ROS** node, so it can be commanded remotely (`SMART` mode) while
still running its own safe fixed-time cycle if the network is unavailable
(`SELF_CONTROL` mode), and reacting to emergency-vehicle priority (`EMERGENCY` mode).

This repository is the **firmware only**. The Linux-side ROS 2 traffic-management
workspace that talks to this device lives in a separate repository — see its own
`README.md` for how to run the decision-making side and the micro-ROS Agent.

## 1. Repository Structure

```
.
├── main/
│   └── main.c                     # app_main(): starts the 3 FreeRTOS tasks
├── components/
│   ├── wifi_manager/              # Wi-Fi station connectivity + auto-reconnect
│   ├── led_controller/            # GPIO lamp driver + control-mode state machine
│   ├── ros_controller/            # micro-ROS client: pub/sub, JSON parsing
│   └── micro_ros_espidf_component/  # vendored micro-ROS library (added by you, see §3)
├── .devcontainer/                 # optional Docker/VS Code dev container (see §4)
├── CMakeLists.txt
├── sdkconfig
└── dependencies.lock
```

## 2. Hardware Requirements

| Item | Notes |
|---|---|
| ESP32 development board | Any standard ESP32 (Xtensa) dev board |
| 3× LED (red, yellow, green) | With appropriate current-limiting resistors |
| Wiring | Red → **GPIO 25**, Yellow → **GPIO 26**, Green → **GPIO 27**, all through a resistor to GND |
| USB cable | For flashing and serial monitor |
| Wi-Fi access point | Must be on the same network/subnet as the PC running the micro-ROS Agent |

## 3. Software Requirements

- **ESP-IDF v5.2.x** (this project was built and tested against 5.2.2/5.2.6 — see the
  "Known Issues" section below for why v6.0 does **not** work here)
- Python 3 + `pip`
- `git`
- Either a native ESP-IDF install **or** Docker + the VS Code "Dev Containers"
  extension (a ready-made container is included, see §4b)

## 4a. Option A — Native ESP-IDF Install

1. **Install ESP-IDF v5.2.x** by following Espressif's official get-started guide,
   selecting the `v5.2.2` (or `release/v5.2`) branch:
   https://docs.espressif.com/projects/esp-idf/en/v5.2.2/esp32/get-started/index.html

   > ⚠️ ESP-IDF v6.0 was tried during development and fails to build the micro-ROS
   > component below. Please use the v5.2 line.

2. **Add the micro-ROS ESP-IDF component** (not committed to this repo — pull it in
   as a submodule/clone before your first build):

   ```bash
   cd components
   git clone --recursive https://github.com/micro-ROS/micro_ros_espidf_component.git
   ```

   `--recursive` matters — a shallow clone leaves nested submodules empty and causes
   confusing "missing header" build errors.

3. **Match the micro-ROS branch to your ROS 2 distribution.** This project targets
   **ROS 2 Jazzy**. If you build the micro-ROS component's own dependency tree
   manually, pin every dependent repo to its `jazzy` branch (the component's build
   scripts normally do this for you the first time you run `idf.py build`, but if you
   ever rebuild the dependency tree by hand, use `-b jazzy` for each of:
   `micro_ros_msgs`, `rosidl_typesupport`, `rosidl_typesupport_microxrcedds`, `rosidl`,
   `rmw`, `rcl_interfaces`, `common_interfaces`).

4. **Install Python build dependencies** used internally by the micro-ROS
   component's colcon/ament build steps:

   ```bash
   pip3 install catkin_pkg lark-parser colcon-common-extensions empy importlib-resources
   ```

   Skipping this causes build failures such as
   `ModuleNotFoundError: No module named 'catkin_pkg'`.

5. **Point your terminal/IDE at ESP-IDF v5.2.x.** Run `. $HOME/esp/esp-idf/export.sh`
   (or your install path's `export.sh`) in every new terminal, and confirm with:

   ```bash
   idf.py --version
   ```

   If you're using VS Code's ESP-IDF extension, make sure it's configured to use the
   same v5.2.x install (especially if you have multiple ESP-IDF versions on the
   machine).

## 4b. Option B — Docker / Dev Container

A `.devcontainer/` folder is included, based on the official `espressif/idf` image.
To use it:

1. Install Docker and the VS Code **Dev Containers** extension.
2. **Pin the image tag to v5.2.2** to match this project (the default `Dockerfile`
   uses `latest`, which may not match). Edit `.devcontainer/Dockerfile`'s
   `DOCKER_TAG` build arg, or build with:

   ```bash
   docker build --build-arg DOCKER_TAG=v5.2.2 -t esp32-traffic-light .devcontainer
   ```

3. Open the project folder in VS Code → **"Reopen in Container"**. ESP-IDF is
   pre-sourced in the container's shell.
4. You will still need to do step 2 and 3 from Option A (adding the micro-ROS
   component and Python deps) *inside* the container — they are not baked into
   the image.
5. Flashing over USB from inside a container requires the container to have access
   to the host's serial device (the included `devcontainer.json` runs with
   `--privileged` for this reason); on some hosts you may still need to pass
   `--device=/dev/ttyUSB0` explicitly or flash from outside the container.

## 5. Configuration — Do This Before Building

Two values are compiled into the firmware and **must be set for your own network**
before building:

| File | Constant(s) | Purpose |
|---|---|---|
| `components/wifi_manager/wifi_manager.h` | `WIFI_SSID`, `WIFI_PASS` | Your Wi-Fi network credentials |
| `components/ros_controller/ros_controller.c` | `ROS_AGENT_IP`, `ROS_AGENT_PORT` | LAN IP address of the PC running the micro-ROS Agent (default port `8888`) |

> ⚠️ **Security note:** these are plaintext `#define`s compiled directly into the
> binary — fine for a lab prototype, not something to commit with real credentials.
> If you fork this repo, either keep your own credentials **out of version control**
> (e.g. `git update-index --skip-worktree wifi_manager.h` after your first edit) or
> migrate them to ESP-IDF's `menuconfig` (Kconfig) / provisioned NVS storage.

`ROS_AGENT_IP` is a compile-time constant, so the firmware must be **rebuilt and
reflashed** whenever the Agent PC's IP address changes (e.g. after reconnecting to a
different Wi-Fi network).

## 6. Build, Flash, and Monitor

```bash
idf.py set-target esp32
idf.py -p /dev/ttyUSB0 build flash monitor
```

Replace `/dev/ttyUSB0` with your board's serial port (`COMx` on Windows,
`/dev/cu.usbserial-*` on macOS). Exit the monitor with `Ctrl+]`.

On a successful boot you should see log lines for Wi-Fi connecting, then the
micro-ROS node bringing up its node/publisher/subscriber against `ROS_AGENT_IP`.

## 7. What This Firmware Talks Over ROS 2

| Topic | Type | Direction | Payload |
|---|---|---|---|
| `/traffic/output/light1/cmd` | `std_msgs/String` (JSON) | **Subscribes** | `{control_mode, cmd, hold_time_ms, reason, timestamp}` |
| `/traffic/input/status/light1` | `std_msgs/String` (JSON) | **Publishes** (every 2000 ms) | `{active_mode, current_state, received_last_cmd, lamp_ok, controller_alive, timestamp}` |

Full field definitions and JSON examples are documented in the companion
"Software and Hardware Implementation" report if you have it; the essentials are
also in the source comments of `ros_controller.c`.

## 8. Running It End to End

1. Start the micro-ROS Agent on the Linux PC (see the ROS 2 workspace repo's
   README) — it must be listening **before** the ESP32 boots.
2. Power on / reset the ESP32.
3. From the PC:
   ```bash
   ros2 node list      # expect: /esp32_traffic_light_node
   ros2 topic list      # expect the two topics above
   ros2 topic echo /traffic/input/status/light1
   ```
   A status message every ~2 seconds confirms the full chain is working.

## 9. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| micro-ROS component fails to build | Using ESP-IDF v6.0 instead of v5.2.x | Switch to v5.2.2/v5.2.6 |
| `ModuleNotFoundError: No module named 'catkin_pkg'` | Missing Python build deps | `pip3 install catkin_pkg lark-parser colcon-common-extensions empy importlib-resources` |
| Missing headers under `micro_ros_espidf_component` | Cloned without `--recursive` | Re-clone with `--recursive`, or `git submodule update --init --recursive` |
| Firmware runs but never appears in `ros2 node list` | Agent not running yet, wrong `ROS_AGENT_IP`, or a firewall blocking UDP 8888 | Start the Agent first; re-check the PC's current LAN IP; check `sudo ufw status` |
| Build state looks corrupted after an interrupted build | Partially-built `micro_ros_dev` folder | `rm -rf components/micro_ros_espidf_component/micro_ros_dev` then rebuild |
| ESP32 connects but the ROS 2 side never gets messages | micro-ROS package branch doesn't match the PC's ROS 2 distro | Rebuild the micro-ROS dependency tree pinned to the same distro as the PC (Jazzy) |

## 10. Known Limitations

- Wi-Fi credentials and the Agent's IP are hardcoded, plaintext, compile-time
  constants (see §5).
- Incoming JSON commands are parsed with simple substring matching (`strstr`), not a
  real JSON parser — malformed payloads are silently treated as defaults.
- `EMERGENCY` mode switches directly between RED and GREEN with no yellow/all-red
  clearance interval — fine for this single-light prototype, **not** safe for a real
  multi-approach intersection as-is.
- No automatic retry/backoff if the micro-ROS Agent becomes unreachable after the
  initial connection.

## 11. License / Authors

Student project — Smart Traffic Light system. ESP32 firmware and micro-ROS
integration implemented by **Metin Sariaslan**. See the project's academic report
for full architecture and design rationale.
