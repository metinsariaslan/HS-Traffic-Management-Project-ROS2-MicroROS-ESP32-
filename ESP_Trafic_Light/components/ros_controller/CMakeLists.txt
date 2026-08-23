idf_component_register(
    SRCS "ros_controller.c"
    INCLUDE_DIRS "include"
    REQUIRES
        led_controller
        wifi_manager
        micro_ros_espidf_component
)