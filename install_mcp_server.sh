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
    "dotenv": "^16.3.1"
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
const app = express();
const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || '0.0.0.0';
const ACCESS_TOKEN = process.env.ACCESS_TOKEN;

// Middleware
app.use(cors());
app.use(express.json());

// Middleware de autenticação
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];
  
  if (token == null) return res.status(401).json({ error: 'Token de acesso não fornecido' });
  if (token !== ACCESS_TOKEN) return res.status(403).json({ error: 'Token de acesso inválido' });
  
  next();
};

// Endpoint para verificar status
app.get('/status', (req, res) => {
  res.json({ status: 'online' });
});

// Endpoint para obter descrição do servidor MCP
app.get('/description', (req, res) => {
  res.json({
    name: "cursor-mcp-server",
    version: "1.0.0",
    description: "Servidor MCP para Cursor AI"
  });
});

// Rota principal para o endpoint SSE do MCP
app.get('/sse', authenticateToken, (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  
  // Função de envio de eventos para o cliente
  const sendEvent = (event, data) => {
    res.write(\`event: \${event}\\n\`);
    res.write(\`data: \${JSON.stringify(data)}\\n\\n\`);
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
      }
    ]
  });

  // Configura o tratamento de ferramenta "exemplo_ferramenta"
  app.post('/tools/exemplo_ferramenta', authenticateToken, (req, res) => {
    const { query } = req.body;
    
    // Simula o processamento da ferramenta
    setTimeout(() => {
      res.json({
        result: \`Resposta processada para: \${query}\`
      });
    }, 500);
  });

  // Mantém a conexão aberta
  const pingInterval = setInterval(() => {
    sendEvent('ping', { timestamp: Date.now() });
  }, 30000);

  // Fecha a conexão e limpa o intervalo quando o cliente desconecta
  req.on('close', () => {
    clearInterval(pingInterval);
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
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=mcp-server

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
    echo -e "Para configurar no Cursor AI:"
    echo -e "1. Acesse as configurações do Cursor"
    echo -e "2. Vá para a seção MCP"
    echo -e "3. Adicione http://$IP_ADDR:3000/sse como servidor SSE"
    echo -e "4. Use o token de acesso acima para autenticação"
    echo -e "${VERDE}==========================================${NC}"
    echo -e "Para verificar o status: systemctl status mcp-server"
    echo -e "Para ver os logs: journalctl -u mcp-server"
    echo -e "${VERDE}==========================================${NC}"
else
    erro "Houve um problema ao iniciar o MCP Server. Verifique os logs com 'journalctl -u mcp-server'"
fi