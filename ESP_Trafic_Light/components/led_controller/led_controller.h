#ifndef LED_CONTROLLER_H
#define LED_CONTROLLER_H

#include <stdbool.h>
#include <stdint.h>

#define LED_RED_PIN     25
#define LED_YELLOW_PIN  26
#define LED_GREEN_PIN   27

typedef enum
{
    CONTROL_MODE_SELF_CONTROL = 0,
    CONTROL_MODE_SMART,
    CONTROL_MODE_EMERGENCY
} control_mode_t;

typedef enum
{
    LIGHT_CMD_NONE = 0,
    LIGHT_CMD_RED,
    LIGHT_CMD_YELLOW,
    LIGHT_CMD_GREEN
} light_command_t;

typedef enum
{
    LIGHT_STATE_NONE = 0,
    LIGHT_STATE_RED,
    LIGHT_STATE_YELLOW,
    LIGHT_STATE_GREEN
} light_state_t;

typedef struct
{
    control_mode_t control_mode;
    light_command_t cmd;
    uint32_t hold_time_ms;
    char reason[32];
    uint32_t timestamp;
} light_cmd_msg_t;

typedef struct
{
    control_mode_t active_mode;
    light_state_t current_state;
    light_command_t received_last_cmd;
    bool lamp_ok;
    bool controller_alive;
    uint32_t timestamp;
} light_status_msg_t;

void led_controller_init(void);
void led_controller_start_task(void);

void led_controller_set_mode(control_mode_t mode);
void led_controller_apply_command(light_command_t cmd);
light_status_msg_t led_controller_get_status(void);

#endif