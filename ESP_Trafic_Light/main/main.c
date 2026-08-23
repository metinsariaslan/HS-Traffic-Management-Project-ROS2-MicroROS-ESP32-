#include "wifi_manager.h"
#include "led_controller.h"
#include "esp_log.h"
#include "ros_controller.h"

static const char *TAG = "main";

void app_main(void)
{
    ESP_LOGI(TAG, "System startup");

    wifi_manager_init();
    led_controller_init();

    wifi_manager_start_task();
    led_controller_start_task();
    ros_manager_start_task();

    ESP_LOGI(TAG, "Tasks created, app_main will return now");
}