
# Payment Settlement (SPI)

- **Create validated payment order**: `/spi-api/jdpi/spi/api/v2/op`
- **Query payment order request by id**: `/spi-api/jdpi/spi/api/v2/op/{idReqJdPiConsultada}`
- **PI Account statement**: `/spi-api/jdpi/spi/api/v2/conta-pi/extrato`
- **Transactional account statement**: `/spi-api/jdpi/spi/api/v2/conta-transacional/extrato`
- **Detail PI posting**: `/spi-api/jdpi/spi/api/v2/conta-transacional/{endToEndId}`
- **Credit status by E2E**: `/spi-api/jdpi/spi/api/v2/credito-pagamento/{endToEndId}`
- **SPI posting by E2E**: `/spi-api/jdpi/spi/api/v2/lancamento/{endToEndId}`
- **PI remuneration**: `/spi-api/jdpi/spi/api/v2/remuneracao-conta-pi/{dataCredito}`
- **PI balance (JDPI)**: `/spi-api/jdpi/spi/api/v2/saldo/conta-pi/jdpi`
- **PI balance (SPI)**: `/spi-api/jdpi/spi/api/v2/saldo/conta-pi/spi`

### Request tips
- Include `prioridadePagamento`, `tpPrioridadePagamento`, `finalidade` when required.
- Provide `dtHrRequisicaoPsp` (client timestamp) on order creation.
- When acting as Initiator, include optional `cnpjIniciadorPagamento`.
- Support **CSM channel header** if your setup uses secondary channel (`X-Tipo-Canal`). 
