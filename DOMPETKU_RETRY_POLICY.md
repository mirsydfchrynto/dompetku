# DompetKu Retry & Dead Letter Policy

**Phase:** D3 — Release Verification

## Overview
Prior to hardening, any non-2xx HTTP response (including 4xx client errors) triggered an infinite retry loop, inflating server logs and masking true network failures. The new policy introduces Bounded Retries and Semantic Dead Lettering.

## Retry Lifespan & Age
- **Base Backoff Formula:** `nextRetryAt = DateTime.now() + (retryCount * 5 minutes)`
- **Maximum Retries:** 10 attempts.
- **Maximum Time in Queue:** The 10 retries span approximately 275 minutes (~4.5 hours) cumulatively.
- **Outage Risk:** If the GASTON.YK backend suffers a major outage exceeding 4.5 hours, queued events will exhaust their retries and fall into `DEAD_LETTER`.
- **Recovery:** These events will NOT be deleted. They remain safely persisted in the Hive local database and require manual operator intervention/requeueing once the server is restored.

## Semantic HTTP Handling

### 1. Transient Failures (RETRY)
- **Triggers:**
  - `TimeoutException` (10s threshold)
  - `SocketException` (No internet / DNS failure)
  - HTTP `500`, `502`, `503`, `504`
- **Behavior:**
  - `webhookStatus` = `failed`
  - `retryCount` incremented by 1.
  - Backoff: `nextRetryAt = DateTime.now() + (retryCount * 5 minutes)`.
  - Max Retries: 10.
- **Evidence Level:** CODE VERIFIED.

### 2. Idempotency Hit (DUPLICATE_ACK)
- **Triggers:**
  - HTTP `409 Conflict`.
- **Behavior:**
  - Backend acknowledges it received the payload but it's a known duplicate.
  - `webhookStatus` = `success`.
  - Removed from the retry queue immediately.
- **Evidence Level:** CODE VERIFIED.

### 3. Terminal Errors (DEAD_LETTER)
- **Triggers:**
  - HTTP `400 Bad Request`, `401 Unauthorized`, `403 Forbidden`, `422 Unprocessable Entity`
  - `FormatException` (Malformed URL)
  - Exceeding 10 retries on Transient Failures.
- **Behavior:**
  - `webhookStatus` = `dead_letter`
  - `isDeadLetter` = `true`
  - `webhookError` stores the operator-visible reason (e.g., specific HTTP error or Timeout limit).
  - Event remains in local DB for audit but will NEVER be automatically retried.
- **Evidence Level:** CODE VERIFIED.

## Conclusion
The system safely tolerates network interruptions (queue remains safe on device) but aggressively bounds looping errors to protect backend resources. Infinite retry scenarios are eliminated.
