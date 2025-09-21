
# Connectivity & Authentication

## Connectivity test (SPI)
- **Endpoint**: `/spi-api/jdpi/spi/api/v2/teste-conectividade`
- **Purpose**: Health/connectivity check to SPI via JDPI.

## OAuth token
- **Endpoint**: `/auth/jdpi/connect/token`
- **Use**: Obtain access token for subsequent calls.
- **Headers**: `Content-Type: application/x-www-form-urlencoded` (typical OAuth form post).
- **Response**: Access token (Bearer) used in `Authorization` header.
