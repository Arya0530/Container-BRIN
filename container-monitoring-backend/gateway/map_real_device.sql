-- Use the LoRa transmitter ID from the ESP32 receiver's JSON payload.
-- The ESP32 BLE MAC address is a different transport identifier.
-- This replaces the old mock device mapping for container series 746996.
BEGIN;
UPDATE public.containers
SET device_id = '746996'
WHERE series = '746996';
SELECT container_id, series, device_id, destination, contents
FROM public.containers
WHERE series = '746996';
COMMIT;
