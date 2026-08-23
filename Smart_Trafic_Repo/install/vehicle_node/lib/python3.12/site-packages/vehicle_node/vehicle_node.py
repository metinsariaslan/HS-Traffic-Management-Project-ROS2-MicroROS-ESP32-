from traffic_common_data.Data_Struct_Topics import (
    VehicleType,
    EmergencyType,
    TrafficDensity,
)
import rclpy
from rclpy.node import Node
from std_msgs.msg import String
import json
import time


class VehicleNode(Node):
    def __init__(self):
        super().__init__('vehicle_node')

        self.get_logger().info('Vehicle Node started.')

        self.vehicle_id = 'veh_01'
        self.vehicle_type = VehicleType.NORMAL
        self.road_id = 'main'
        self.position = 12.5
        self.speed = 0.8
        self.direction = 'forward'
        self.registered = True

        self.current_road_status = {}
        self.current_pedestrian_status = {}

        self.road_register_pub = self.create_publisher(
            String,
            '/traffic/input/road/register',
            10
        )

        self.create_subscription(
            String,
            '/traffic/input/road/status',
            self.road_status_callback,
            10
        )

        self.create_subscription(
            String,
            '/traffic/input/pedestrian/light1',
            self.pedestrian_callback,
            10
        )

        self.timer = self.create_timer(2.0, self.publish_vehicle_data)

    def safe_float(self, value, default=0.0):
        try:
            return float(value)
        except (TypeError, ValueError):
            return default

    def road_status_callback(self, msg):
        try:
            data = json.loads(msg.data)
        except json.JSONDecodeError:
            self.get_logger().error("Invalid JSON received on road status topic")
            return

        self.current_road_status = data

        road_id = data.get("road_id", "unknown")
        vehicle_count = data.get("registered_vehicle_count", 0)

        traffic_density = data.get("traffic_density", TrafficDensity.LOW)

        avg_speed = self.safe_float(
            data.get(
                "avg_speed",
                data.get("avg_traffic_speed", 0.0)
            )
        )

        emergency_present = data.get("emergency_present", False)
        emergency_type = data.get("emergency_type", EmergencyType.NONE)

        emergency_speed = self.safe_float(
            data.get(
                "emergency_speed",
                data.get(
                    "emergency_vehicle_speed",
                    data.get("emergency_avg_speed", 0.0)
                )
            )
        )

        emergency_vehicle_id = data.get("emergency_vehicle_id", "none")
        emergency_road_id = data.get("emergency_road_id", road_id)
        timestamp = data.get("timestamp", 0)

        self.get_logger().info(
            f"[ROAD STATUS] road={road_id} | "
            f"vehicles={vehicle_count} | "
            f"density={traffic_density} | "
            f"avg_speed={avg_speed} | "
            f"emergency={emergency_present} ({emergency_type}) | "
            f"emergency_speed={emergency_speed} | "
            f"emergency_vehicle_id={emergency_vehicle_id} | "
            f"timestamp={timestamp}"
        )

        target_speed = self.speed

        if avg_speed > 0:
            if avg_speed >= 40:
                target_speed = 0.8
            elif avg_speed >= 25:
                target_speed = 0.6
            elif avg_speed >= 10:
                target_speed = 0.4
            else:
                target_speed = 0.2
        else:
            if traffic_density == TrafficDensity.HIGH:
                target_speed = 0.4
            elif traffic_density == TrafficDensity.MEDIUM:
                target_speed = 0.6
            elif traffic_density == TrafficDensity.LOW:
                target_speed = 0.8

        same_road_emergency = emergency_road_id == self.road_id

        if (
            emergency_present
            and emergency_type != EmergencyType.NONE
            and same_road_emergency
        ):
            if emergency_speed >= 40:
                target_speed = 0.0
                action = "stopping / yielding lane"
            elif emergency_speed > 0:
                target_speed = min(target_speed, 0.2)
                action = "slowing down / yielding lane"
            else:
                target_speed = min(target_speed, 0.2)
                action = "yielding lane"

            self.get_logger().warn(
                f"Emergency vehicle detected: {emergency_type} | "
                f"speed={emergency_speed} | action={action}"
            )

        self.speed = target_speed

    def pedestrian_callback(self, msg):
        try:
            data = json.loads(msg.data)
        except json.JSONDecodeError:
            self.get_logger().error("Invalid JSON received on pedestrian topic")
            return

        self.current_pedestrian_status = data

        self.get_logger().info(
            f"Pedestrian request received | "
            f"light_id: {data.get('light_id')} | "
            f"request_to_pass: {data.get('request_to_pass')}"
        )

    def publish_vehicle_data(self):
        vehicle_msg = {
            'vehicle_id': self.vehicle_id,
            'vehicle_type': self.vehicle_type,
            'road_id': self.road_id,
            'position': self.position,
            'speed': self.speed,
            'direction': self.direction,
            'registered': self.registered,
            'timestamp': int(time.time())
        }

        msg = String()
        msg.data = json.dumps(vehicle_msg)
        self.road_register_pub.publish(msg)

        self.get_logger().info(
            f"Vehicle data published: {self.vehicle_id} | "
            f"type={self.vehicle_type} | "
            f"speed={self.speed}"
        )


def main(args=None):
    rclpy.init(args=args)
    node = VehicleNode()

    try:
        rclpy.spin(node)
    except KeyboardInterrupt:
        pass
    finally:
        node.destroy_node()
        rclpy.shutdown()


if __name__ == '__main__':
    main()