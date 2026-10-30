// LoRa receiver with JSON forwarding to a Windows HTTP -> RabbitMQ gateway.
// Radio pins, struct, and modulation are retained from the working receiver.
#include <Arduino.h>
#include <SPI.h>
#include <LoRa.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include "local_config.h"

#define LORA_SS 5
#define LORA_RST 13
#define LORA_DIO0 25
#define LORA_FREQ 923E6
#define LORA_SYNC 0x34

#pragma pack(push, 1)
typedef struct {
    uint8_t  packetCounter;
    uint32_t deviceID;
    double   latitude;
    double   longitude;
    double   altitude;
    double   speed;
    uint8_t  satellites;
    char     timeUTC[20];
    bool     doorValue;
    char     tujuan[14];
    char     perusahaan[20];
    char     isi[16];
} TelemetryPacket;
#pragma pack(pop)
static_assert(sizeof(TelemetryPacket) == 109, "LoRa packet layout changed");

TelemetryPacket rx;

static uint8_t readRegister(uint8_t address) {
    digitalWrite(LORA_SS, LOW);
    SPI.beginTransaction(SPISettings(8000000, MSBFIRST, SPI_MODE0));
    SPI.transfer(address & 0x7F);
    uint8_t value = SPI.transfer(0x00);
    SPI.endTransaction();
    digitalWrite(LORA_SS, HIGH);
    return value;
}

static void writeRegister(uint8_t address, uint8_t value) {
    digitalWrite(LORA_SS, LOW);
    SPI.beginTransaction(SPISettings(8000000, MSBFIRST, SPI_MODE0));
    SPI.transfer(address | 0x80);
    SPI.transfer(value);
    SPI.endTransaction();
    digitalWrite(LORA_SS, HIGH);
}

static bool connectWiFi() {
    if (WiFi.status() == WL_CONNECTED) return true;
    WiFi.mode(WIFI_STA);
    WiFi.setSleep(false);
    WiFi.begin(WIFI_SSID, WIFI_PASS);
    unsigned long started = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - started < 10000) {
        delay(250);
    }
    if (WiFi.status() == WL_CONNECTED) {
        Serial.print("Wi-Fi ready, IP: ");
        Serial.println(WiFi.localIP());
        return true;
    }
    Serial.println("Wi-Fi unavailable, packet cannot be forwarded");
    return false;
}

static void terminateStrings(TelemetryPacket &p) {
    p.timeUTC[sizeof(p.timeUTC) - 1] = '\0';
    p.tujuan[sizeof(p.tujuan) - 1] = '\0';
    p.perusahaan[sizeof(p.perusahaan) - 1] = '\0';
    p.isi[sizeof(p.isi) - 1] = '\0';
}

static bool forwardToGateway(const TelemetryPacket &p, int rssi, float snr) {
    if (!connectWiFi()) return false;

    JsonDocument doc;
    // deviceID originates from the LoRa TRANSMITTER, not the receiver Wi-Fi MAC.
    // The transmitter stores the low 24 bits of ESP.getEfuseMac() as uint32_t.
    doc["deviceID"] = String(p.deviceID);
    doc["packetCounter"] = p.packetCounter;
    JsonObject gps = doc["gps"].to<JsonObject>();
    gps["latitude"] = p.latitude;
    gps["longitude"] = p.longitude;
    gps["altitude"] = p.altitude;
    gps["speed"] = p.speed;
    gps["satellites"] = p.satellites;
    gps["timeUTC"] = String(p.timeUTC);
    doc["door"] = p.doorValue ? "CLOSED" : "OPEN";
    doc["doorStatus"] = p.doorValue ? "CLOSED" : "OPEN";
    doc["rssi"] = rssi;
    doc["snr"] = snr;
    doc["tujuan"] = String(p.tujuan);
    doc["perusahaan"] = String(p.perusahaan);
    doc["isi"] = String(p.isi);

    String body;
    serializeJson(doc, body);
    HTTPClient http;
    http.begin(GATEWAY_URL);
    http.setTimeout(3500);
    http.addHeader("Content-Type", "application/json");
    http.addHeader("X-Device-Key", GATEWAY_KEY);
    int code = http.POST(body);
    if (code == 202) {
        Serial.printf("[GATEWAY] Queued device=%lu packet=%u\n",
                      (unsigned long)p.deviceID, (unsigned int)p.packetCounter);
        http.end();
        return true;
    }
    Serial.printf("[GATEWAY] Failed status=%d response=%s\n",
                  code, http.getString().c_str());
    http.end();
    return false;
}

void setup() {
    Serial.begin(115200);
    delay(300);
    Serial.println("LoRa receiver to RabbitMQ gateway starting");
    LoRa.setPins(LORA_SS, LORA_RST, LORA_DIO0);
    int tries = 0;
    while (!LoRa.begin(LORA_FREQ)) {
        Serial.println("LoRa init failed; retrying");
        delay(1000);
        if (++tries > 15) ESP.restart();
    }
    LoRa.setSpreadingFactor(12);
    LoRa.setSignalBandwidth(125E3);
    LoRa.setCodingRate4(8);
    LoRa.setPreambleLength(12);
    LoRa.setSyncWord(LORA_SYNC);
    LoRa.enableCrc();
    LoRa.disableInvertIQ();
    writeRegister(0x31, 0xC3);
    writeRegister(0x37, 0x0A);
    uint8_t cfg3 = readRegister(0x26);
    writeRegister(0x26, cfg3 | 0x08);
    LoRa.receive();
    Serial.println("LoRa ready");
    connectWiFi();
}

void loop() {
    int packetSize = LoRa.parsePacket();
    if (!packetSize) {
        delay(10);
        return;
    }
    int rssi = LoRa.packetRssi();
    float snr = LoRa.packetSnr();
    if (packetSize != (int)sizeof(TelemetryPacket)) {
        Serial.printf("[LORA] Unexpected packet size %d (expected %u)\n",
                      packetSize, (unsigned int)sizeof(TelemetryPacket));
        while (LoRa.available()) LoRa.read();
        LoRa.receive();
        return;
    }

    memset(&rx, 0, sizeof(rx));
    int n = LoRa.readBytes((uint8_t *)&rx, sizeof(rx));
    while (LoRa.available()) LoRa.read();
    LoRa.receive();
    if (n != (int)sizeof(rx)) {
        Serial.printf("[LORA] Incomplete read: %d bytes\n", n);
        return;
    }
    terminateStrings(rx);
    Serial.printf("[LORA] Device=%lu Counter=%u RSSI=%d SNR=%.1f GPS=%.6f,%.6f Door=%s\n",
                  (unsigned long)rx.deviceID, (unsigned int)rx.packetCounter,
                  rssi, snr, rx.latitude, rx.longitude, rx.doorValue ? "CLOSED" : "OPEN");
    // HTTP is synchronous; short transmission intervals may cause missed LoRa packets.
    forwardToGateway(rx, rssi, snr);
}
