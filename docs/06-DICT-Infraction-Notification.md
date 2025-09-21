
# DICT – Infraction Notification (Notificação de Infração)

Core flows (names may include legacy "relato-infracao" in path):
- **Create**: `/chave-relato-infracao-api/jdpi/dict/api/v1/relato-infracao/incluir`
- **List pending**: `/chave-relato-infracao-api/jdpi/dict/api/v1/relato-infracao/listar/pendentes`
- **Consult**: `/chave-relato-infracao-api/jdpi/dict/api/v1/relato-infracao/consultar`
- **Cancel**: `/chave-relato-infracao-api/jdpi/dict/api/v1/relato-infracao/cancelar`
- **Analyze**: `/chave-relato-infracao-api/jdpi/dict/api/v1/relato-infracao/analisar`
- **List**: `/chave-relato-infracao-api/jdpi/dict/api/v1/relato-infracao/listar`

## Key fields (response/consult examples)
- `endToEndId`: E2E id of the transaction
- `motivo`: infraction reason (per DICT v2 naming)
- `tpSitOrigem`: origin situation type, e.g. fraud/scam, unauthorized transaction, coercion, etc.
- `stRelatoInfracao`: status: 0 Open, 1 Received, 2 Canceled, 3 Analyzed
- `pspCriador` / `pspContraParte`: SPB IDs of creator and counterparty PSP
- Timestamps for creation and last update
- Optional `idMarcacaoFraude`, `resultadoAnalise` (0 accepted, 1 rejected), `detalhesAnalise`
- `contatoCriador`: contact info (email lowercase, phone like `+5561988887777`)

### Tips
- Ensure your antifraud pipeline can **link infraction notifications by E2E** and customer/account.
- Provide human-readable mapping for `motivo` and `tpSitOrigem` to analysts.
