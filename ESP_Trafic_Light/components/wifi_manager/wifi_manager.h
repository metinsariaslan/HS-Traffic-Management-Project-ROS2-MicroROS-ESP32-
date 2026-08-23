#ifndef WIFI_MANAGER_H
#define WIFI_MANAGER_H

#include <stdbool.h>


#define WIFI_SSID "OnlyLans.com"
#define WIFI_PASS "hjZFVHLuWm4tt5qFP8so%"

void wifi_manager_init(void);
bool wifi_manager_is_connected(void);
void wifi_manager_start_task(void);

#endif
