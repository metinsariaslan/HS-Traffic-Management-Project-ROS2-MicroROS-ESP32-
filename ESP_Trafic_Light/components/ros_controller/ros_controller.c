#include "ros_controller.h"

#include <stdio.h>
#include <string.h>
#include <stdbool.h>

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"

#include "esp_log.h"

#include "wifi_manager.h"
#include "led_controller.h"

#include <rcl/rcl.h>
#include <rclc/rclc.h>
#include <rclc/executor.h>

#include <std_msgs/msg/string.h>

#include "rmw_microros/rmw_microros.h"

#define ROS_MANAGER_TASK_STACK_SIZE 8192
#define ROS_MANAGER_TASK_PRIORITY   5

#define ROS_AGENT_IP   "192.168.1.100"   // BURAYI Linux PC IP adresinle değiştir
#define ROS_AGENT_PORT "8888"

#define LIGHT_CMD_TOPIC "/traffic/output/light1/cmd"

static const char *TAG = "ros_manager";

static rcl_subscription_t light_cmd_subscriber;
static std_msgs__msg__String light_cmd_msg;

static char light_cmd_buffer[512];

static control_mode_t parse_control_mode(const char *json)
{
    if (strstr(json, "\"control_mode\": \"SELF_CONTROL\"") ||
        strstr(json, "\"control_mode\":\"SELF_CONTROL\""))
    {
        return CONTROL_MODE_SELF_CONTROL;
    }

    if (strstr(json, "\"control_mode\": \"SMART\"") ||
        strstr(json, "\"control_mode\":\"SMART\""))
    {
        return CONTROL_MODE_SMART;
    }

    if (strstr(json, "\"control_mode\": \"EMERGENCY\"") ||
        strstr(json, "\"control_mode\":\"EMERGENCY\""))
    {
        return CONTROL_MODE_EMERGENCY;
    }

    return CONTROL_MODE_SELF_CONTROL;
}

static light_command_t parse_light_command(const char *json)
{
    if (strstr(json, "\"cmd\": \"RED\"") ||
        strstr(json, "\"cmd\":\"RED\""))
    {
        return LIGHT_CMD_RED;
    }

    if (strstr(json, "\"cmd\": \"YELLOW\"") ||
        strstr(json, "\"cmd\":\"YELLOW\""))
    {
        return LIGHT_CMD_YELLOW;
    }

    if (strstr(json, "\"cmd\": \"GREEN\"") ||
        strstr(json, "\"cmd\":\"GREEN\""))
    {
        return LIGHT_CMD_GREEN;
    }

    if (strstr(json, "\"cmd\": \"NONE\"") ||
        strstr(json, "\"cmd\":\"NONE\""))
    {
        return LIGHT_CMD_NONE;
    }

    return LIGHT_CMD_NONE;
}

static void light_cmd_callback(const void *msgin)
{
    const std_msgs__msg__String *msg = (const std_msgs__msg__String *)msgin;

    if (msg == NULL || msg->data.data == NULL)
    {
        ESP_LOGW(TAG, "Received empty ROS message");
        return;
    }

    const char *json = msg->data.data;

    ESP_LOGI(TAG, "ROS cmd received: %s", json);

    control_mode_t mode = parse_control_mode(json);
    light_command_t cmd = parse_light_command(json);

    led_controller_set_mode(mode);
    led_controller_apply_command(cmd);

    ESP_LOGI(TAG, "Applied ROS command | mode=%d | cmd=%d", mode, cmd);
}

static void ros_manager_task(void *arg)
{
    while (!wifi_manager_is_connected())
    {
        ESP_LOGI(TAG, "Waiting for WiFi connection...");
        vTaskDelay(pdMS_TO_TICKS(500));
    }

    ESP_LOGI(TAG, "WiFi connected. Starting micro-ROS...");

    rmw_uros_set_custom_transport(
        false,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL
    );

    set_microros_wifi_transports(
        WIFI_SSID,
        WIFI_PASS,
        ROS_AGENT_IP,
        atoi(ROS_AGENT_PORT)
    );

    rcl_allocator_t allocator = rcl_get_default_allocator();
    rclc_support_t support;
    rcl_node_t node;
    rclc_executor_t executor;

    rcl_ret_t ret;

    ret = rclc_support_init(&support, 0, NULL, &allocator);
    if (ret != RCL_RET_OK)
    {
        ESP_LOGE(TAG, "rclc_support_init failed");
        vTaskDelete(NULL);
        return;
    }

    ret = rclc_node_init_default(
        &node,
        "esp32_traffic_light_node",
        "",
        &support
    );

    if (ret != RCL_RET_OK)
    {
        ESP_LOGE(TAG, "rclc_node_init_default failed");
        vTaskDelete(NULL);
        return;
    }

    ret = rclc_subscription_init_default(
        &light_cmd_subscriber,
        &node,
        ROSIDL_GET_MSG_TYPE_SUPPORT(std_msgs, msg, String),
        LIGHT_CMD_TOPIC
    );

    if (ret != RCL_RET_OK)
    {
        ESP_LOGE(TAG, "rclc_subscription_init_default failed");
        vTaskDelete(NULL);
        return;
    }

    light_cmd_msg.data.data = light_cmd_buffer;
    light_cmd_msg.data.size = 0;
    light_cmd_msg.data.capacity = sizeof(light_cmd_buffer);

    ret = rclc_executor_init(
        &executor,
        &support.context,
        1,
        &allocator
    );

    if (ret != RCL_RET_OK)
    {
        ESP_LOGE(TAG, "rclc_executor_init failed");
        vTaskDelete(NULL);
        return;
    }

    ret = rclc_executor_add_subscription(
        &executor,
        &light_cmd_subscriber,
        &light_cmd_msg,
        &light_cmd_callback,
        ON_NEW_DATA
    );

    if (ret != RCL_RET_OK)
    {
        ESP_LOGE(TAG, "rclc_executor_add_subscription failed");
        vTaskDelete(NULL);
        return;
    }

    ESP_LOGI(TAG, "micro-ROS subscriber started on topic: %s", LIGHT_CMD_TOPIC);

    while (1)
    {
        rclc_executor_spin_some(&executor, RCL_MS_TO_NS(100));
        vTaskDelay(pdMS_TO_TICKS(10));
    }
}

void ros_manager_start_task(void)
{
    xTaskCreate(
        ros_manager_task,
        "ros_manager_task",
        ROS_MANAGER_TASK_STACK_SIZE,
        NULL,
        ROS_MANAGER_TASK_PRIORITY,
        NULL
    );
}