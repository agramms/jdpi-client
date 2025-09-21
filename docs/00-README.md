# JDPI Integration Blocks (English)
Generated on 2025-09-21. These files summarize the JDPI documentation you shared and are organized for AI-assisted development.
Keep the base URL configurable by environment: `JDPI_ENV=homl` (homolog) or `JDPI_ENV=prod`, and make the client host/DNS configurable as well.

**Base URL template**
```
http://<CLIENT_HOST>.{JDPI_ENV}.jdpi.pstijd
```

**Services (examples)**
- Auth: `/auth/jdpi/connect/token`
- SPI: `/spi-api/jdpi/spi/api/...`
- DICT (keys/claims/infraction/refund): `/chave-gestao-api`, `/chave-reivindicacao-api`, `/chave-relato-infracao-api`, `/chave-devolucao-api`
- QR Code & Certificates: `/qrcode-api/jdpi/qrcode/api/...`, `/certificado-api/jdpi/certificates/download`

> Use OAuth access tokens (Bearer) and idempotency keys where indicated. Treat all endpoints as environment-driven.
