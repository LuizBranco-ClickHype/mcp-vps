#!/bin/bash

# Script de instalação do MCP Server para VPS Ubuntu
# Permite conexões remotas e gera token de acesso
# Compatível com Cursor AI via Model Context Protocol (MCP)

# Cores para melhor visualização
VERDE='\033[0;32m'
VERMELHO='\033[0;31m'
AMARELO='\033[1;33m'
NC='\033[0m' # Sem cor

# Função para exibir mensagens de progresso
mensagem() {
    echo -e "${VERDE}[+] $1${NC}"
}

# Função para exibir mensagens de erro
erro() {
    echo -e "${VERMELHO}[!] $1${NC}"
    exit 1
}

# Função para exibir mensagens de aviso
aviso() {
    echo -e "${AMARELO}[!] $1${NC}"
}

# Verifica se está sendo executado como root
if [ "$EUID" -ne 0 ]; then
    erro "Este script precisa ser executado como root. Use 'sudo ./install_mcp_server.sh'"
fi

# Verifica se é Ubuntu
if ! grep -q "Ubuntu" /etc/os-release; then
    erro "Este script foi projetado para sistemas Ubuntu. Sistema atual não é Ubuntu."
fi

# Atualiza o sistema
mensagem "Atualizando o sistema..."
apt update && apt upgrade -y || erro "Falha ao atualizar o sistema"

# Instala dependências
mensagem "Instalando dependências..."
apt install -y curl git nodejs npm ufw || erro "Falha ao instalar dependências"

# Instala a versão LTS mais recente do Node.js usando nvm
mensagem "Configurando Node.js..."
if ! command -v node &> /dev/null || [ $(node -v | cut -d. -f1 | tr -d 'v') -lt 16 ]; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm install --lts
    nvm use --lts
fi

# Verifica a versão do Node.js
node_version=$(node -v)
mensagem "Node.js $node_version instalado com sucesso"

# Cria diretório para o MCP Server
MCP_DIR="/opt/mcp-server"
mensagem "Criando diretório para o MCP Server em $MCP_DIR..."
mkdir -p $MCP_DIR || erro "Falha ao criar diretório"

# Cria arquivo package.json para o MCP Server
mensagem "Configurando o projeto MCP Server..."
cat > $MCP_DIR/package.json << EOL
{
  "name": "cursor-mcp-server",
  "version": "1.0.0",
  "description": "Servidor MCP para Cursor AI",
  "main": "index.js",
  "scripts": {
    "start": "node index.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "dotenv": "^16.3.1",
    "morgan": "^1.10.0"
  }
}
EOL

# Entra no diretório do MCP Server
cd $MCP_DIR || erro "Falha ao acessar o diretório do MCP Server"

# Instala as dependências do MCP Server
mensagem "Instalando dependências do MCP Server..."
npm install || erro "Falha ao instalar dependências do MCP Server"

# Configura o arquivo de ambiente
mensagem "Configurando o ambiente..."
cat > $MCP_DIR/.env << EOL
PORT=3000
HOST=0.0.0.0
NODE_ENV=production
EOL

# Gera um token de acesso aleatório
TOKEN=$(openssl rand -hex 32)
echo "ACCESS_TOKEN=$TOKEN" >> $MCP_DIR/.env
mensagem "Token de acesso gerado com sucesso"

# Cria o arquivo principal do servidor MCP compatível com Cursor AI
mensagem "Criando servidor MCP com suporte ao protocolo MCP..."
cat > $MCP_DIR/index.js << EOL
require('dotenv').config();
const express = require('express');
const cors = require('cors');
const morgan = require('morgan'); // Para logs de requisição
const fs = require('fs');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || '0.0.0.0';
const ACCESS_TOKEN = process.env.ACCESS_TOKEN;

// Cria diretório de logs
const logDir = path.join(__dirname, 'logs');
if (!fs.existsSync(logDir)) {
  fs.mkdirSync(logDir);
}

// Configura o logger
const accessLogStream = fs.createWriteStream(
  path.join(logDir, 'access.log'),
  { flags: 'a' }
);

// Middleware básicos
app.use(cors({
  origin: '*',
  methods: 'GET,HEAD,PUT,PATCH,POST,DELETE',
  preflightContinue: false,
  optionsSuccessStatus: 204,
  credentials: true,
  allowedHeaders: ['Content-Type', 'Authorization']
}));
app.use(express.json());
app.use(morgan('combined', { stream: accessLogStream }));

// Middleware para log de todas as requisições (para debug)
app.use((req, res, next) => {
  console.log(\`\${new Date().toISOString()} - \${req.method} \${req.url} - IP: \${req.ip}\`);
  console.log('Headers:', JSON.stringify(req.headers));
  next();
});

// Middleware de autenticação melhorado
const authenticateToken = (req, res, next) => {
  console.log('Autenticando requisição...');
  let token = null;
  
  // Tenta obter o token do cabeçalho Authorization
  const authHeader = req.headers['authorization'];
  if (authHeader) {
    if (authHeader.startsWith('Bearer ')) {
      token = authHeader.split(' ')[1];
      console.log('Token extraído do Bearer:', token);
    } else {
      token = authHeader;
      console.log('Token extraído diretamente do Authorization:', token);
    }
  }
  
  // Tenta obter o token do parâmetro de consulta
  if (!token && req.query.token) {
    token = req.query.token;
    console.log('Token extraído do query parameter:', token);
  }
  
  // Tenta obter o token do env.API_KEY (formato MCP específico)
  if (!token && req.headers['x-api-key']) {
    token = req.headers['x-api-key'];
    console.log('Token extraído do X-API-KEY header:', token);
  }
  
  // Se nenhuma das opções acima, assume que o endpoint não requer autenticação
  if (!token) {
    if (req.path === '/status' || req.path === '/') {
      console.log('Rota pública, continuando sem autenticação');
      return next();
    }
    
    console.log('Token não fornecido');
    return res.status(401).json({ 
      error: 'Token de acesso não fornecido',
      message: 'Por favor, forneça um token de acesso válido. Verifique a documentação para mais informações.'
    });
  }
  
  // Log para debug
  console.log('Comparando tokens:');
  console.log('Token recebido:', token);
  console.log('Token esperado:', ACCESS_TOKEN);
  
  // Verifica se o token é válido
  if (token !== ACCESS_TOKEN) {
    console.log('Token inválido');
    return res.status(401).json({ 
      error: 'Token de acesso inválido',
      message: 'O token fornecido não é válido. Por favor, verifique o token e tente novamente.'
    });
  }
  
  console.log('Token válido, autenticação bem-sucedida');
  next();
};

// Rota raiz para informações básicas
app.get('/', (req, res) => {
  res.json({
    name: "cursor-mcp-server",
    version: "1.0.0",
    description: "Servidor MCP para Cursor AI",
    endpoints: [
      { path: "/", method: "GET", description: "Esta informação" },
      { path: "/status", method: "GET", description: "Verificar status do servidor" },
      { path: "/sse", method: "GET", description: "Endpoint SSE para o Cursor AI (requer autenticação)" },
      { path: "/test-auth", method: "GET", description: "Testar autenticação" }
    ]
  });
});

// Endpoint de teste simplificado para verificar conectividade
app.get('/status', (req, res) => {
  res.json({ 
    status: 'online', 
    time: new Date().toISOString(),
    serverId: ACCESS_TOKEN.substring(0, 8)
  });
});

// Endpoint para testar autenticação
app.get('/test-auth', authenticateToken, (req, res) => {
  res.json({ 
    message: 'Autenticação bem-sucedida!',
    time: new Date().toISOString()
  });
});

// Rota principal para o endpoint SSE do MCP
app.get('/sse', authenticateToken, (req, res) => {
  console.log('Conexão SSE estabelecida');
  
  // Configurações padrão do SSE
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  
  // Função de envio de eventos para o cliente
  const sendEvent = (event, data) => {
    const eventString = \`event: \${event}\\ndata: \${JSON.stringify(data)}\\n\\n\`;
    console.log(\`Enviando evento: \${event}\`);
    res.write(eventString);
  };

  // Envia informações sobre as ferramentas disponíveis
  sendEvent('tools', {
    tools: [
      {
        name: "exemplo_ferramenta",
        description: "Uma ferramenta de exemplo para demonstrar o protocolo MCP",
        parameters: {
          type: "object",
          properties: {
            query: {
              type: "string",
              description: "Consulta a ser processada"
            }
          },
          required: ["query"]
        }
      },
      {
        name: "servidor_info",
        description: "Retorna informações sobre o servidor MCP",
        parameters: {
          type: "object",
          properties: {}
        }
      }
    ]
  });

  // Diz ao cliente que a configuração inicial está completa
  sendEvent('ready', { 
    time: new Date().toISOString(),
    message: "Servidor MCP pronto para uso"
  });

  // Configura o tratamento de ferramenta "exemplo_ferramenta"
  app.post('/tools/exemplo_ferramenta', authenticateToken, (req, res) => {
    console.log('Ferramenta exemplo_ferramenta chamada:', req.body);
    const { query } = req.body;
    
    // Simula o processamento da ferramenta
    setTimeout(() => {
      res.json({
        result: \`Resposta processada para: \${query || 'consulta vazia'}\`
      });
    }, 500);
  });

  // Configura o tratamento da ferramenta servidor_info
  app.post('/tools/servidor_info', authenticateToken, (req, res) => {
    console.log('Ferramenta servidor_info chamada');
    
    const serverInfo = {
      host: HOST,
      port: PORT,
      nodeVersion: process.version,
      uptime: process.uptime(),
      memoryUsage: process.memoryUsage(),
      timestamp: new Date().toISOString()
    };
    
    res.json({
      result: serverInfo
    });
  });

  // Mantém a conexão aberta com ping periódico
  const pingInterval = setInterval(() => {
    sendEvent('ping', { timestamp: Date.now() });
  }, 30000);

  // Fecha a conexão e limpa o intervalo quando o cliente desconecta
  req.on('close', () => {
    console.log('Cliente desconectou-se do SSE');
    clearInterval(pingInterval);
  });
});

// Tratamento global de erros
app.use((err, req, res, next) => {
  console.error('Erro:', err.stack);
  res.status(500).json({
    error: 'Erro interno do servidor',
    message: err.message || 'Algo deu errado',
    path: req.path
  });
});

// Inicia o servidor
app.listen(PORT, HOST, () => {
  console.log(\`Servidor MCP em execução em http://\${HOST}:\${PORT}\`);
  console.log(\`Endpoint SSE disponível em http://\${HOST}:\${PORT}/sse\`);
});
EOL

# Configura o serviço systemd
mensagem "Configurando o serviço systemd..."
cat > /etc/systemd/system/mcp-server.service << EOL
[Unit]
Description=MCP Server para Cursor AI
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$MCP_DIR
ExecStart=$(which node) $MCP_DIR/index.js
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=mcp-server
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOL

# Recarrega o systemd
systemctl daemon-reload

# Configura o firewall
mensagem "Configurando o firewall..."
ufw allow 3000/tcp || aviso "Falha ao configurar o firewall"
ufw --force enable || aviso "Falha ao habilitar o firewall"

# Inicia o serviço
mensagem "Iniciando o MCP Server..."
systemctl enable mcp-server
systemctl start mcp-server

# Verifica se o serviço está em execução
if systemctl is-active --quiet mcp-server; then
    mensagem "MCP Server instalado e iniciado com sucesso!"
    IP_ADDR=$(hostname -I | awk '{print $1}')
    echo -e "${VERDE}==========================================${NC}"
    echo -e "${VERDE}      MCP Server está pronto!            ${NC}"
    echo -e "${VERDE}==========================================${NC}"
    echo -e "Acesse o servidor em: http://$IP_ADDR:3000"
    echo -e "Endpoint SSE: http://$IP_ADDR:3000/sse"
    echo -e "Token de acesso: $TOKEN"
    echo -e "${VERDE}==========================================${NC}"
    echo -e "Para testar a API:"
    echo -e "curl http://$IP_ADDR:3000/status"
    echo -e "curl -H \"Authorization: Bearer $TOKEN\" http://$IP_ADDR:3000/test-auth"
    echo -e "${VERDE}==========================================${NC}"
    echo -e "Para configurar no Cursor AI:"
    echo -e "1. Edite o arquivo ~/.cursor/mcp.json"
    echo -e "2. Adicione esta configuração:"
    echo -e "${VERDE}"
    echo -e '{
  "mcpServers": {
    "mcp-vps": {
      "url": "http://'"$IP_ADDR"':3000/sse",
      "env": {
        "API_KEY": "'"$TOKEN"'"
      }
    }
  }
}'
    echo -e "${NC}"
    echo -e "${VERDE}==========================================${NC}"
    echo -e "Para verificar o status: systemctl status mcp-server"
    echo -e "Para ver os logs: journalctl -u mcp-server -f"
    echo -e "${VERDE}==========================================${NC}"
else
    erro "Houve um problema ao iniciar o MCP Server. Verifique os logs com 'journalctl -u mcp-server'"
fi