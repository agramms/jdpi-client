
# Payment Initiation (QR Codes & Certificates)

- **Static QR**: `/qrcode-api/jdpi/qrcode/api/v1/estatico/gerar`
- **Dynamic Immediate**: `/qrcode-api/jdpi/qrcode/api/v1/dinamico/gerar`
- **Decode QR**: `/qrcode-api/jdpi/qrcode/api/v1/decodificar`
- **Update Dynamic Immediate**: `/qrcode-api/jdpi/qrcode/api/v1/dinamico/{idDocumento}`
- **Certificate download**: `/certificado-api/jdpi/certificates/download`
- **Dynamic with Due Date (CobV) – generate**: `/qrcode-api/jdpi/qrcode/api/v1/dinamico/cobv/gerar`
- **Dynamic with Due Date (CobV) – update**: `/qrcode-api/jdpi/qrcode/api/v1/dinamico/cobv/{idDocumento}`
- **CobV JWS**: `/qrcode-api/jdpi/qrcode/api/v1/dinamico/cobv/jws`

### CobV JWS request (fields vary by case)
- `idDocumento` (GUID) – unique billing identifier
- Optional PSP ISPB when indirect PSP uses its own cert
- Optional pricing fields: `valorOriginal`, `abatimento`, `desconto`, `juros`, etc.
