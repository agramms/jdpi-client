
# Common Headers & Idempotency

## Required headers (typical)
- `Authorization: Bearer <token>`
- `Content-Type: application/json; charset=utf-8`
- `Accept: application/json`

## Idempotency
Some APIs require **`Chave-Idempotencia`**:
- **Header**: `Chave-Idempotencia: <GUID>` (8-4-4-4-12 hex format, e.g., `69F963C6-7487-4363-9406-A1DE2A9636D4`)
- **Cache lifetime**: up to 24h
- Only include this header **when the API indicates it is required**. Avoid adding it to endpoints that do not support it.
