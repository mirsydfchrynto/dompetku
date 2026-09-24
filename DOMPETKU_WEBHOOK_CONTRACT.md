# Phase D1: DOMPETKU_WEBHOOK_CONTRACT

## Payload Specification
The webhook payload defaults to a JSON string wrapped in a `message` key, but depends on `payload_format` configuration (`json_string` or `raw`).

### Example (`json_string` format):
```json
{
  "message": "{\"id\":\"1726058000000\",\"appSource\":\"GoPay\",\"amount\":50000.0,\"formattedAmount\":\"Rp50.000\",\"payerName\":\"Budi\",\"type\":\"gopay_in\",\"dateTime\":\"2026-09-10T12:00:00.000\",\"rawMessage\":\"GoPay: Kamu menerima transfer Rp50.000 dari Budi\"}",
  "amount": 50000.0,
  "id": "1726058000000",
  "appSource": "GoPay"
}
```

## Retry Semantics
- **Condition**: Triggers on `SocketException`, `TimeoutException` (10s), or HTTP response `>= 300`.
- **Action**: Retries via background queue on next transaction reception.
- **Flaw**: 
  - `409 Conflict` (Duplicate) is treated as a failure and retried infinitely.
  - `400 Bad Request` (Invalid Format) is treated as a failure and retried infinitely.
  - Server MUST return `200` to `299` to stop the retry loop.

## Authentication & Headers
- `Content-Type`: `application/json`
- `Authorization`: Optional custom header set in `auth_header` DB field.
- `X-Dompetku-Timestamp`: UNIX Epoch Seconds.
- `X-Dompetku-Signature`: HMAC-SHA256 signature.
  - **Method**: `hmac_sha256(secret, "$timestamp.$payload")`
- `bypass-tunnel-reminder`: Auto-injected if `loca.lt` is detected.

## Server Ack Contract
- **2xx**: Safely acknowledge. Removed from retry queue.
- **4xx / 5xx**: Rejection. Sent to retry queue forever.
- **Failover**: If primary URL returns `500-504`, app immediately attempts a fallback URL within the same HTTP request cycle.

## Verification Map
- missing signature: **SERVER VERIFIED** (App sends it if configured, Server must validate).
- expired timestamp: **SERVER VERIFIED** (Server must implement TTL, app just sends current time).
- duplicate event: **RISK** (App ID is generated locally. Server must rely on business keys: amount, source, time).
- modified payload: **CODE VERIFIED** (HMAC will invalidate).
