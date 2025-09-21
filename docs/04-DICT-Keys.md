
# DICT – Addressing Keys (Chaves)

Common endpoints (v1 unless specified by your doc set):

- **Create key**: `/chave-gestao-api/jdpi/dict/api/v1/incluir`
- **Update key**: `/chave-gestao-api/jdpi/dict/api/v1/{chave}`
- **Delete key**: `/chave-gestao-api/jdpi/dict/api/v1/{chave}/excluir`
- **Close account**: `/chave-gestao-api/jdpi/dict/api/v1/encerrar-conta`
- **Remove holder link**: `/chave-gestao-api/jdpi/dict/api/v1/excluir-titular`
- **List customer/account keys**: `/chave-gestao-api/jdpi/dict/api/v1/listar/chave`
- **Get key**: `/chave-gestao-api/jdpi/dict/api/v1/{chave}`
- **Statistics (by CPF/CNPJ)**: `/chave-gestao-api/jdpi/dict/api/v1/estatisticas/{cpfcnpj}`

### Notes
- Respect field sizes (e.g., names, key formats) and account type codes (include “Conta de Pagamento” where accepted).
- Use idempotency only when the header is listed in the specific API.
