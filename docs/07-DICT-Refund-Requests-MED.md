
# DICT – Refund Requests (MED)

- **Create**: `/chave-devolucao-api/jdpi/dict/api/v1/devolucao/incluir`
- **List pending**: `/chave-devolucao-api/jdpi/dict/api/v1/devolucao/listar/pendentes`
- **Consult**: `/chave-devolucao-api/jdpi/dict/api/v1/devolucao/consultar`
- **Cancel**: `/chave-devolucao-api/jdpi/dict/api/v1/devolucao/cancelar`
- **Analyze**: `/chave-devolucao-api/jdpi/dict/api/v1/devolucao/analisar`
- **List**: `/chave-devolucao-api/jdpi/dict/api/v1/devolucao/listar`

### Tips
- Track `codigoDevolucao` and reasons in your UI.
- MED may be triggered from infraction analysis; link both sides in your domain.
