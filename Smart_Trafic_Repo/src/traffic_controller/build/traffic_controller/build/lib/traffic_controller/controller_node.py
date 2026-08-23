from traffic_common_data.Data_Struct_Topics import (
    ControlMode,
    LightCommand,
    TrafficDensity,
    CommandReason,
    EmergencyType
)

import rclpy
from rclpy.node import Node
from std_msgs.msg import String
import json
import time


class TrafficControllerNode(Node):

    def __init__(self):
        super().__init__('traffic_controller_node')

        self.get_logger().info("Traffic Controller Node started.")

        # internal memory
        self.registered_vehicles = {}

        # publishers
        self.road_status_pub = self.create_publisher(
            String,
            '/traffic/input/road/status',
            10
        )

        self.light_cmd_pub = self.create_publisher(
            String,
            '/traffic/output/light1/cmd',
            10
        )

        # subscribers
        self.create_subscription(
            String,
            '/traffic/input/road/register',
            self.vehicle_register_callback,
            10
        )

        self.create_subscription(
            String,
            '/traffic/input/road/emergency',
            self.emergency_callback,
            10
        )

        self.create_subscription(
            String,
            '/traffic/input/pedestrian/light1',
            self.pedestrian_callback,
            10
        )

        self.create_subscription(
            String,
            '/traffic/input/status/light1',
            self.light_status_callback,
            10
        )

        # periodic decision loop
        self.timer = self.create_timer(
            2.0,
            self.control_loop
        )

        self.emergency_active = False
        self.current_emergency_type = EmergencyType.NONE
        self.current_emergency_vehicle_id = None
        self.last_emergency_seen = 0.0
        self.emergency_timeout_sec = 10.0
        self.current_emergency_speed = 0.0
        self.pedestrian_waiting = False


    # ======================
    # CALLBACKS
    # ======================

    def vehicle_register_callback(self, msg):

        data = json.loads(msg.data)

        vehicle_id = data["vehicle_id"]

        self.registered_vehicles[vehicle_id] = {
            "vehicle_type": data["vehicle_type"],
            "road_id": data["road_id"],
            "position": data["position"],
            "speed": data["speed"],
            "last_seen": time.time()
        }

        self.get_logger().info(
            f"Vehicle registered: {vehicle_id}"
        )


    def emergency_callback(self, msg):
        
        data = json.loads(msg.data)

        self.emergency_active = data.get("emergency_present", False)
        self.current_emergency_type = data.get("emergency_type", EmergencyType.NONE)
        self.current_emergency_vehicle_id = data.get("vehicle_id", None)
        self.current_emergency_speed = data.get("speed", 0.0)
        self.last_emergency_seen = time.time()

        if self.emergency_active:
            self.get_logger().warn(
                f"Emergency detected: "
                f"id={self.current_emergency_vehicle_id} | "
                f"type={self.current_emergency_type} | "
                f"speed={self.current_emergency_speed}")
        else:
            self.get_logger().info("Emergency cleared.")


    def update_emergency_state(self):
        if not self.emergency_active:
            return

        elapsed_time = time.time() - self.last_emergency_seen

        if elapsed_time > self.emergency_timeout_sec:
            self.get_logger().warn(
                f"Emergency timeout. No update for {elapsed_time:.1f}s. Clearing emergency state."
            )

        self.emergency_active = False
        self.current_emergency_type = EmergencyType.NONE
        self.current_emergency_vehicle_id = None
        self.current_emergency_speed = 0.0


    def pedestrian_callback(self, msg):

        data = json.loads(msg.data)

        if data["request_to_pass"]:
            self.pedestrian_waiting = True

            self.get_logger().info(
                "Pedestrian crossing request received."
            )


    def light_status_callback(self, msg):

        data = json.loads(msg.data)

        self.get_logger().info(
            f"Light state: {data['current_state']}"
        )

    def compute_density_and_speed(self, vehicle_count):

        if 0 <= vehicle_count <= 3:
            return TrafficDensity.LOW, 40
        elif 4 <= vehicle_count <= 6:
            return TrafficDensity.MEDIUM, 35
        elif 7 <= vehicle_count <= 10:
            return TrafficDensity.HIGH, 20
        else:
            return TrafficDensity.HIGH, 20


    # ======================
    # CONTROL LOOP
    # ======================

    def control_loop(self):
        self.update_emergency_state()
        vehicle_count = len(self.registered_vehicles)
        traffic_density, avg_speed = self.compute_density_and_speed(vehicle_count)
        self.get_logger().info(
            f"Vehicle count: {vehicle_count} | Density: {traffic_density} | Avg speed: {avg_speed}"
        )

        
        if self.emergency_active:
            control_mode = ControlMode.EMERGENCY
            cmd = LightCommand.GREEN
            reason = CommandReason.EMERGENCY_PRIORITY

        elif self.pedestrian_waiting:
            control_mode = ControlMode.SMART
            cmd = LightCommand.RED
            reason = CommandReason.PEDESTRIAN_REQUEST

        elif traffic_density == TrafficDensity.HIGH:
            control_mode = ControlMode.SMART
            cmd = LightCommand.NONE
            reason = CommandReason.NORMAL_CYCLE

        else:
            control_mode = ControlMode.SELF_CONTROL
            cmd = LightCommand.NONE
            reason = CommandReason.LOCAL_CYCLE


        # publish road status

        road_status_msg = {

            "road_id": "main",

            "registered_vehicle_count": vehicle_count,

            "emergency_present": self.emergency_active,

            "emergency_type": self.current_emergency_type,

            "emergency_vehicle_id": self.current_emergency_vehicle_id,

            "emergency_vehicle_speed": self.current_emergency_speed,

            "traffic_density": traffic_density,

            "avg_traffic_speed": avg_speed,

            "timestamp": int(time.time())
        }

        msg = String()
        msg.data = json.dumps(road_status_msg)

        self.road_status_pub.publish(msg)


        # publish light command

        light_cmd_msg = {

            "control_mode": control_mode,
            "cmd": cmd,
            "hold_time_ms": 5000,
            "reason": reason,
            "timestamp": int(time.time())
        }

        msg = String()
        msg.data = json.dumps(light_cmd_msg)

        self.light_cmd_pub.publish(msg)

        self.get_logger().info(
            f"Command sent: {cmd} | mode: {control_mode}"
        )


def main(args=None):

    rclpy.init(args=args)

    node = TrafficControllerNode()

    try:
        rclpy.spin(node)

    except KeyboardInterrupt:
        pass

    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()