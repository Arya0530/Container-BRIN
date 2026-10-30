#pragma once
// Copy this file to local_config.h and fill in your own private network settings.
// The ESP32 and the Windows computer must be reachable on the same network.
#define WIFI_SSID "YOUR_WIFI_SSID"
#define WIFI_PASS "YOUR_WIFI_PASSWORD"
#define GATEWAY_URL "http://192.168.1.105:8090/ingest"
// Must exactly match INGEST_API_KEY from the gateway's .env.
#define GATEWAY_KEY "REPLACE_WITH_A_LONG_RANDOM_KEY"
