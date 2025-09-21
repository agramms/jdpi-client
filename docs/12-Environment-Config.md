
# Environment & Base URL Configuration

Make the **base URL** fully configurable via environment entries.

**Recommended variables**
- `JDPI_ENV`: `homl` (homologation) or `prod` (production)
- `JDPI_CLIENT_HOST`: your client-visible host or IP used in JDPI DNS schema
- `JDPI_BASE`: computed, e.g. `http://{JDPI_CLIENT_HOST}.{JDPI_ENV}.jdpi.pstijd`

**Example**
```env
JDPI_ENV=homl
JDPI_CLIENT_HOST=api.mybank
JDPI_BASE=http://api.mybank.homl.jdpi.pstijd
```

Then compose service paths per module, e.g.: `${JDPI_BASE}/spi-api/jdpi/spi/api/v2/op`.
