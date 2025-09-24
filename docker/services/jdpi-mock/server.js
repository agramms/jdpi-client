const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const fs = require('fs');
const path = require('path');

const app = express();
const port = process.env.PORT || 3000;

// Middleware
app.use(helmet());
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Logging
if (process.env.NODE_ENV !== 'test') {
  app.use(morgan('combined'));
}

// Mock data and responses
const mockResponses = {
  // OAuth token response
  oauth: {
    access_token: "mock_access_token_123456789",
    token_type: "Bearer",
    expires_in: 3600,
    scope: "auth_apim dict_api spi_api qr_api participants_api"
  },

  // Generic success response
  success: {
    status: "success",
    timestamp: new Date().toISOString()
  },

  // Generic error response
  error: (message, code = 400) => ({
    error: {
      code,
      message,
      timestamp: new Date().toISOString()
    }
  })
};

// Utility function to log requests
function logRequest(req, endpoint) {
  const logData = {
    timestamp: new Date().toISOString(),
    method: req.method,
    endpoint,
    headers: req.headers,
    body: req.body,
    query: req.query
  };

  if (process.env.DEBUG === 'true') {
    console.log(`[JDPI MOCK] ${req.method} ${endpoint}:`, JSON.stringify(logData, null, 2));
  }
}

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    service: 'jdpi-mock-server',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// OAuth2 Authentication endpoint
app.post('/auth/jdpi/connect/token', (req, res) => {
  logRequest(req, 'AUTH');

  // Simulate different scenarios based on client_id
  const clientId = req.body.client_id;

  if (clientId === 'invalid_client') {
    return res.status(401).json(mockResponses.error('Invalid client credentials', 401));
  }

  if (clientId === 'rate_limited_client') {
    return res.status(429).json(mockResponses.error('Rate limit exceeded', 429));
  }

  // Default successful response
  res.json(mockResponses.oauth);
});

// DICT API endpoints
app.route('/dict/api/v2/key*')
  .get((req, res) => {
    logRequest(req, 'DICT_KEY_GET');
    res.json({
      ...mockResponses.success,
      data: {
        chave: req.params[0] || "user@example.com",
        tipo: "EMAIL",
        ispb: "12345678",
        status: "ACTIVE"
      }
    });
  })
  .post((req, res) => {
    logRequest(req, 'DICT_KEY_CREATE');
    res.status(201).json({
      ...mockResponses.success,
      data: {
        chave: req.body.chave,
        tipo: req.body.tipo,
        ispb: "12345678",
        status: "ACTIVE"
      }
    });
  })
  .put((req, res) => {
    logRequest(req, 'DICT_KEY_UPDATE');
    res.json({
      ...mockResponses.success,
      data: {
        chave: req.body.chave,
        tipo: req.body.tipo,
        ispb: "12345678",
        status: "UPDATED"
      }
    });
  })
  .delete((req, res) => {
    logRequest(req, 'DICT_KEY_DELETE');
    res.status(204).send();
  });

// DICT Claims endpoints
app.route('/dict/api/v2/claims*')
  .get((req, res) => {
    logRequest(req, 'DICT_CLAIMS_GET');
    res.json({
      ...mockResponses.success,
      data: {
        id: "claim-123",
        chave: "user@example.com",
        tipo_reivindicacao: "OWNERSHIP",
        status: "WAITING_RESOLUTION"
      }
    });
  })
  .post((req, res) => {
    logRequest(req, 'DICT_CLAIMS_CREATE');
    res.status(201).json({
      ...mockResponses.success,
      data: {
        id: "claim-" + Date.now(),
        chave: req.body.chave,
        tipo_reivindicacao: req.body.tipo_reivindicacao,
        status: "OPEN"
      }
    });
  });

// SPI OP (Payment Operations) endpoints
app.route('/spi/api/v1/op*')
  .post((req, res) => {
    logRequest(req, 'SPI_OP_CREATE');

    // Simulate payment validation
    const valor = req.body.valor;
    if (valor && valor > 100000) { // R$ 1000.00 limit
      return res.status(400).json(mockResponses.error('Payment amount exceeds limit'));
    }

    res.status(201).json({
      ...mockResponses.success,
      data: {
        id: "op-" + Date.now(),
        valor: req.body.valor,
        chave: req.body.chave,
        status: "PROCESSING",
        endToEndId: "E" + Date.now() + "123456789012345"
      }
    });
  })
  .get((req, res) => {
    logRequest(req, 'SPI_OP_GET');
    res.json({
      ...mockResponses.success,
      data: {
        id: req.params[0] || "op-123",
        status: "COMPLETED",
        valor: 1500,
        chave: "user@example.com"
      }
    });
  });

// SPI OD (Settlement Queries) endpoints
app.route('/spi/api/v1/od*')
  .get((req, res) => {
    logRequest(req, 'SPI_OD_GET');
    res.json({
      ...mockResponses.success,
      data: {
        endToEndId: req.query.endToEndId || "E123456789012345",
        status: "SETTLED",
        valor: 2500,
        dataLiquidacao: new Date().toISOString()
      }
    });
  });

// QR Code API endpoints
app.route('/qr/api/v1/qr*')
  .post((req, res) => {
    logRequest(req, 'QR_CREATE');
    res.status(201).json({
      ...mockResponses.success,
      data: {
        qrId: "qr-" + Date.now(),
        qrCode: "00020101021226830014br.gov.bcb.pix2561mock.pix.url/qr/v2/123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890520400005303986540510.005802BR5913MOCK MERCHANT6009SAO PAULO62070503***6304ABCD",
        pixCopyPaste: "mock-pix-copy-paste-code"
      }
    });
  });

// Participants API endpoints
app.route('/participants/api/v1/participants*')
  .get((req, res) => {
    logRequest(req, 'PARTICIPANTS_GET');
    res.json({
      ...mockResponses.success,
      data: [
        {
          ispb: "12345678",
          nome: "Mock Bank 1",
          nomeReduzido: "MOCK1",
          modalidadeParticipacao: "DIRETA"
        },
        {
          ispb: "87654321",
          nome: "Mock Bank 2",
          nomeReduzido: "MOCK2",
          modalidadeParticipacao: "INDIRETA"
        }
      ]
    });
  });

// Catch-all for unhandled routes
app.use('*', (req, res) => {
  logRequest(req, 'UNKNOWN_ENDPOINT');
  res.status(404).json(mockResponses.error('Endpoint not found', 404));
});

// Error handler
app.use((err, req, res, next) => {
  console.error('Server error:', err);
  res.status(500).json(mockResponses.error('Internal server error', 500));
});

// Start server
app.listen(port, '0.0.0.0', () => {
  console.log(`🚀 JDPI Mock Server running on port ${port}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`Debug mode: ${process.env.DEBUG === 'true' ? 'enabled' : 'disabled'}`);
  console.log(`Available endpoints:`);
  console.log(`  GET  /health                     - Health check`);
  console.log(`  POST /auth/jdpi/connect/token    - OAuth2 authentication`);
  console.log(`  *    /dict/api/v2/key/*          - DICT key management`);
  console.log(`  *    /dict/api/v2/claims/*       - DICT claims`);
  console.log(`  *    /spi/api/v1/op/*            - SPI payment operations`);
  console.log(`  GET  /spi/api/v1/od/*            - SPI settlement queries`);
  console.log(`  POST /qr/api/v1/qr/*             - QR code generation`);
  console.log(`  GET  /participants/api/v1/*      - Participants info`);
});

module.exports = app;