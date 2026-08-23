#include "led_controller.h"

#include <time.h>

#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/gpio.h"
#include "esp_log.h"

static const char *TAG = "led_controller";

/* Internal state */
static control_mode_t g_control_mode = CONTROL_MODE_SELF_CONTROL;
static light_state_t g_current_state = LIGHT_STATE_NONE;
static light_command_t g_received_last_cmd = LIGHT_CMD_NONE;

static void led_controller_all_off(void)
{
    gpio_set_level(LED_RED_PIN, 0);
    gpio_set_level(LED_YELLOW_PIN, 0);
    gpio_set_level(LED_GREEN_PIN, 0);
}

static void led_controller_set_state(light_state_t state)
{
    led_controller_all_off();

    switch (state)
    {
        case LIGHT_STATE_RED:
            gpio_set_level(LED_RED_PIN, 1);
            break;

        case LIGHT_STATE_YELLOW:
            gpio_set_level(LED_YELLOW_PIN, 1);
            break;

        case LIGHT_STATE_GREEN:
            gpio_set_level(LED_GREEN_PIN, 1);
            break;

        case LIGHT_STATE_NONE:
        default:
            break;
    }

    g_current_state = state;
}

void led_controller_init(void)
{
    gpio_config_t io_conf = {
        .pin_bit_mask =
            (1ULL << LED_RED_PIN) |
            (1ULL << LED_YELLOW_PIN) |
            (1ULL << LED_GREEN_PIN),
        .mode = GPIO_MODE_OUTPUT,
        .pull_up_en = GPIO_PULLUP_DISABLE,
        .pull_down_en = GPIO_PULLDOWN_DISABLE,
        .intr_type = GPIO_INTR_DISABLE
    };

    ESP_ERROR_CHECK(gpio_config(&io_conf));

    led_controller_all_off();
    g_current_state = LIGHT_STATE_NONE;
    g_received_last_cmd = LIGHT_CMD_NONE;
    g_control_mode = CONTROL_MODE_SELF_CONTROL;

    ESP_LOGI(TAG, "LED controller initialized on GPIO 25, 26, 27");
}

void led_controller_set_mode(control_mode_t mode)
{
    g_control_mode = mode;
    ESP_LOGI(TAG, "Control mode changed to: %d", mode);
}

void led_controller_apply_command(light_command_t cmd)
{
    g_received_last_cmd = cmd;

    if (g_control_mode == CONTROL_MODE_SELF_CONTROL)
    {
        ESP_LOGI(TAG, "Ignoring external command in SELF_CONTROL mode");
        return;
    }

    switch (cmd)
    {
        case LIGHT_CMD_RED:
            led_controller_set_state(LIGHT_STATE_RED);
            break;

        case LIGHT_CMD_YELLOW:
            led_controller_set_state(LIGHT_STATE_YELLOW);
            break;

        case LIGHT_CMD_GREEN:
            led_controller_set_state(LIGHT_STATE_GREEN);
            break;

        case LIGHT_CMD_NONE:
        default:
            led_controller_set_state(LIGHT_STATE_NONE);
            break;
    }

    ESP_LOGI(TAG, "Applied command: %d", cmd);
}

light_status_msg_t led_controller_get_status(void)
{
    light_status_msg_t status = {
        .active_mode = g_control_mode,
        .current_state = g_current_state,
        .received_last_cmd = g_received_last_cmd,
        .lamp_ok = true,
        .controller_alive = true,
        .timestamp = (uint32_t)time(NULL)
    };

    return status;
}

static void self_control_cycle_step(void)
{
    static int phase = 0;

    switch (phase)
    {
        case 0:
            led_controller_set_state(LIGHT_STATE_RED);
            ESP_LOGI(TAG, "[SELF_CONTROL] RED");
            vTaskDelay(pdMS_TO_TICKS(15000));
            break;

        case 1:
            led_controller_set_state(LIGHT_STATE_YELLOW);
            ESP_LOGI(TAG, "[SELF_CONTROL] YELLOW");
            vTaskDelay(pdMS_TO_TICKS(2000));
            break;

        case 2:
            led_controller_set_state(LIGHT_STATE_GREEN);
            ESP_LOGI(TAG, "[SELF_CONTROL] GREEN");
            vTaskDelay(pdMS_TO_TICKS(5000));
            break;

        case 3:
            led_controller_set_state(LIGHT_STATE_YELLOW);
            ESP_LOGI(TAG, "[SELF_CONTROL] YELLOW");
            vTaskDelay(pdMS_TO_TICKS(2000));
            break;
    }

    phase = (phase + 1) % 4;
}

static void led_controller_task(void *pvParameters)
{
    while (1)
    {
        switch (g_control_mode)
        {
            case CONTROL_MODE_SELF_CONTROL:
                self_control_cycle_step();
                break;

            case CONTROL_MODE_SMART:
            case CONTROL_MODE_EMERGENCY:
            default:
                vTaskDelay(pdMS_TO_TICKS(200));
                break;
        }
    }
}

void led_controller_start_task(void)
{
    xTaskCreate(
        led_controller_task,
        "led_controller_task",
        4096,
        NULL,
        5,
        NULL
    );
}