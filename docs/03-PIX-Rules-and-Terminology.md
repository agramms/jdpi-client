
# PIX Rules & Terminology Helpers

This section highlights frequent PIX fields present in JDPI flows. Use it to validate payloads.

- **tpIniciacao (Initiation Type)**: includes QR code flows and Service of Initiation of Payment (SIP). Watch for values like `6` (Payment Initiation Service) and `7` (Payer QR). Check endpoint specs for which responses include it.
- **prioridadePagamento / tpPrioridadePagamento**: priority flags for immediate vs scheduled; ensure to pass when required by SPI order endpoints.
- **finalidade**: reason/purpose codes; JDPI SPI APIs require this in payment requests; consult your business mapping for permitted values.
- **endToEndId (E2E)**: PIX transaction identifier (32 chars, starts with 'E' + structured digits). Validate length and characters; keep it immutable once created.
- **cnpjIniciadorPagamento**: optional in some SPI flows when a Payment Initiation Service is used.
- **infEntreClientes**: free-form message between clients; returned in several SPI queries.
- **Modalities for QR with change/withdraw**: dynamic QR endpoints support optional “withdraw/change” parameters when using cash-out or cash-back modalities.

> Always map fields to your domain model and centralize validation (e.g., Rails model or request object validators).
