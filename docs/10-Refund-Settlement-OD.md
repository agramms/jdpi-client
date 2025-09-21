
# Refund Settlement (Ordem de Devolução / OD)

- **Create validated refund order**: `/spi-api/jdpi/spi/api/v2/od`
- **Query refund order request by id**: `/spi-api/jdpi/spi/api/v2/od/{idReqJdPiConsultada}`
- **List refund reasons**: `/spi-api/jdpi/spi/api/v2/od/motivos`
- **Credit status by E2E**: `/spi-api/jdpi/spi/api/v2/credito-devolucao/{endToEndId}`

### Notes
- The OD flow mirrors payment order status queries, but scoped to refund semantics.
