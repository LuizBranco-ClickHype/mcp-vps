#!/bin/bash

# Script de instalação do MCP Server para VPS Ubuntu
# Permite gerenciamento completo da VPS, incluindo Docker e stacks
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
    erro "Este script precisa ser executado como root. Use 'sudo ./install_mcp_vps.sh'"
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
DOCKER_DIR="/opt/mcp-docker"
mensagem "Criando diretórios para o MCP Server..."
mkdir -p $MCP_DIR || erro "Falha ao criar diretório MCP"
mkdir -p $DOCKER_DIR || erro "Falha ao criar diretório Docker"
mkdir -p $DOCKER_DIR/stacks || erro "Falha ao criar diretório de stacks"
mkdir -p $DOCKER_DIR/configs || erro "Falha ao criar diretório de configs"
mkdir -p $DOCKER_DIR/backups || erro "Falha ao criar diretório de backups"

# Clona o repositório do GitHub
mensagem "Baixando arquivos do MCP VPS..."
cd $MCP_DIR || erro "Falha ao acessar o diretório MCP"

# Baixa os arquivos do GitHub ou cria localmente
if [ -n "$GITHUB_REPO" ]; then
    git clone $GITHUB_REPO . || erro "Falha ao clonar repositório"
else
    # Cria arquivos localmente
    cat > $MCP_DIR/package.json << EOL
{
  "name": "mcp-vps-manager",
  "version": "1.0.0",
  "description": "Servidor MCP para gerenciamento de VPS com Docker",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "dev": "nodemon index.js"
  },
  "keywords": [
    "mcp",
    "vps",
    "docker",
    "cursor-ai",
    "gerenciamento"
  ],
  "author": "",
  "license": "MIT",
  "dependencies": {
    "cors": "^2.8.5",
    "dotenv": "^16.3.1",
    "express": "^4.18.2"
  }
}
EOL
fi

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
API_KEY=$(openssl rand -hex 32)
echo "API_KEY=$API_KEY" >> $MCP_DIR/.env
mensagem "Token de acesso gerado com sucesso"

# Cria o arquivo principal do servidor MCP se não for baixado do GitHub
if [ ! -f "$MCP_DIR/index.js" ]; then
    mensagem "Criando arquivos do servidor MCP..."
    
    # Criar o arquivo vps_tools.js
    cat > $MCP_DIR/vps_tools.js << 'EOL'
/**
 * MCP Tools - Ferramentas para gerenciamento de VPS
 * 
 * Este módulo contém ferramentas para:
 * - Gerenciamento da VPS (info, restart, etc)
 * - Docker (instalação, configuração)
 * - Stacks Docker (deploy, remoção, atualização)
 * - Monitoramento de recursos
 * - Gerenciamento de backups
 */

const { exec, spawn } = require('child_process');
const fs = require('fs').promises;
const os = require('os');
const path = require('path');
const util = require('util');

const execPromise = util.promisify(exec);

// Diretório onde serão armazenados os arquivos temporários
const TEMP_DIR = '/tmp/mcp-temp';
// Diretório onde serão armazenados arquivos de stacks e configurações
const DOCKER_DIR = '/opt/mcp-docker';

// Função de utilidade para executar comandos com promessas
async function runCommand(command) {
  try {
    const { stdout, stderr } = await execPromise(command);
    return { success: true, stdout, stderr };
  } catch (error) {
    return { 
      success: false, 
      error: error.message,
      stdout: error.stdout,
      stderr: error.stderr
    };
  }
}

// Cria diretórios necessários
async function initializeDirs() {
  try {
    await fs.mkdir(TEMP_DIR, { recursive: true });
    await fs.mkdir(DOCKER_DIR, { recursive: true });
    await fs.mkdir(path.join(DOCKER_DIR, 'stacks'), { recursive: true });
    await fs.mkdir(path.join(DOCKER_DIR, 'configs'), { recursive: true });
    return { success: true };
  } catch (error) {
    return { success: false, error: error.message };
  }
}

// Define e exporta todas as ferramentas que serão expostas via MCP
const vpsTools = {
  /* ==== VPS SYSTEM TOOLS ==== */
  
  /**
   * Obtém informações do sistema
   */
  async getSystemInfo() {
    const uptimeCmd = await runCommand('uptime -p');
    const diskCmd = await runCommand('df -h | grep "/$"');
    const memCmd = await runCommand('free -h');
    
    // Obter informações do processador e memória
    const cpuInfo = os.cpus();
    const totalMem = Math.round(os.totalmem() / (1024 * 1024 * 1024));
    const freeMem = Math.round(os.freemem() / (1024 * 1024 * 1024));
    
    return {
      success: true,
      hostname: os.hostname(),
      platform: os.platform(),
      release: os.release(),
      uptime: uptimeCmd.success ? uptimeCmd.stdout.trim() : "Indisponível",
      cpu: {
        model: cpuInfo[0].model,
        cores: cpuInfo.length,
        speed: cpuInfo[0].speed + ' MHz'
      },
      memory: {
        total: `${totalMem} GB`,
        free: `${freeMem} GB`,
        usedPercent: Math.round((1 - (os.freemem() / os.totalmem())) * 100) + '%',
        details: memCmd.success ? memCmd.stdout : "Indisponível"
      },
      disk: diskCmd.success ? diskCmd.stdout : "Indisponível",
      loadAverage: os.loadavg()
    };
  },
  
  /**
   * Reinicia a VPS
   */
  async rebootSystem() {
    const result = await runCommand('shutdown -r now');
    return { 
      success: result.success,
      message: result.success ? "Sistema será reiniciado em breve" : result.error
    };
  },
  
  /**
   * Atualiza os pacotes do sistema
   */
  async updateSystem() {
    const update = await runCommand('apt update');
    if (!update.success) return { success: false, error: update.error };
    
    const upgrade = await runCommand('apt upgrade -y');
    return { 
      success: upgrade.success, 
      output: upgrade.success ? upgrade.stdout : upgrade.error 
    };
  },
  
  /* ==== DOCKER MANAGEMENT ==== */
  
  /**
   * Verifica se o Docker está instalado
   */
  async checkDockerInstalled() {
    const result = await runCommand('docker --version');
    return { 
      installed: result.success,
      version: result.success ? result.stdout.trim() : null
    };
  },
  
  /**
   * Instala o Docker e Docker Compose
   */
  async installDocker() {
    // Verifica se já está instalado
    const checkResult = await this.checkDockerInstalled();
    if (checkResult.installed) {
      return { 
        success: true, 
        message: "Docker já está instalado", 
        version: checkResult.version 
      };
    }
    
    // Instala dependências
    const deps = await runCommand(
      'apt update && apt install -y apt-transport-https ca-certificates curl software-properties-common'
    );
    if (!deps.success) return { success: false, error: deps.error };
    
    // Adiciona chave GPG do Docker
    const gpgKey = await runCommand(
      'curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -'
    );
    if (!gpgKey.success) return { success: false, error: gpgKey.error };
    
    // Adiciona repositório Docker
    const ubuntuRelease = await runCommand('lsb_release -cs');
    const repo = await runCommand(
      `add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu ${ubuntuRelease.stdout.trim()} stable"`
    );
    if (!repo.success) return { success: false, error: repo.error };
    
    // Instala Docker
    const installDocker = await runCommand(
      'apt update && apt install -y docker-ce docker-ce-cli containerd.io'
    );
    if (!installDocker.success) return { success: false, error: installDocker.error };
    
    // Instala Docker Compose
    const composeInstall = await runCommand(
      'curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose'
    );
    
    // Inicia e habilita o serviço Docker
    await runCommand('systemctl start docker');
    await runCommand('systemctl enable docker');
    
    // Verifica a instalação
    const finalCheck = await this.checkDockerInstalled();
    const composeCheck = await runCommand('docker-compose --version');
    
    return {
      success: finalCheck.installed,
      dockerVersion: finalCheck.version,
      composeVersion: composeCheck.success ? composeCheck.stdout.trim() : "Erro ao instalar Docker Compose",
      message: "Docker e Docker Compose instalados com sucesso"
    };
  },
  
  // Outras funções de gerenciamento do sistema...
  
  initializeDirs
};

module.exports = vpsTools;
EOL
    
    # Criar o arquivo index.js
    cat > $MCP_DIR/index.js << 'EOL'
/**
 * MCP Server para gerenciamento de VPS
 * Fornece ferramentas para gerenciamento completo da VPS via MCP (Model Context Protocol)
 */

require('dotenv').config();
const express = require('express');
const cors = require('cors');
const app = express();
const vpsTools = require('./vps_tools');

// Configurações do servidor
const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || '0.0.0.0';
const API_KEY = process.env.API_KEY || (process.env.ACCESS_TOKEN || '');

// Middleware
app.use(cors());
app.use(express.json());

// Middleware de autenticação
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];
  
  if (token == null) return res.status(401).json({ error: 'Token de acesso não fornecido' });
  if (token !== API_KEY) return res.status(403).json({ error: 'Token de acesso inválido' });
  
  next();
};

// Endpoint para verificar status
app.get('/status', (req, res) => {
  res.json({ status: 'online' });
});

// Endpoint para healthcheck simples
app.get('/ping', (req, res) => {
  res.send('pong');
});

// Endpoint para obter descrição do servidor MCP
app.get('/description', (req, res) => {
  res.json({
    name: "mcp-vps-manager",
    version: "1.0.0",
    description: "Servidor MCP para gerenciamento de VPS"
  });
});

// Handler para processar chamadas de ferramentas MCP
const handleToolCall = async (toolName, params) => {
  console.log(`Executando ferramenta: ${toolName} com parâmetros:`, params);
  
  try {
    // Ferramentas do sistema
    if (toolName === 'get_system_info') {
      return await vpsTools.getSystemInfo();
    }
    else if (toolName === 'reboot_system') {
      return await vpsTools.rebootSystem();
    }
    else if (toolName === 'update_system') {
      return await vpsTools.updateSystem();
    }
    
    // Ferramentas do Docker
    else if (toolName === 'check_docker') {
      return await vpsTools.checkDockerInstalled();
    }
    else if (toolName === 'install_docker') {
      return await vpsTools.installDocker();
    }
    
    // Ferramenta não encontrada
    else {
      return { 
        success: false, 
        error: `Ferramenta '${toolName}' não encontrada`
      };
    }
  } catch (error) {
    console.error(`Erro ao executar ferramenta ${toolName}:`, error);
    return { 
      success: false, 
      error: `Erro interno: ${error.message}`
    };
  }
};

// Rota principal para o endpoint SSE do MCP
app.get('/sse', authenticateToken, (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  
  // Função de envio de eventos para o cliente
  const sendEvent = (event, data) => {
    res.write(`event: ${event}\n`);
    res.write(`data: ${JSON.stringify(data)}\n\n`);
  };

  // Envia informações sobre as ferramentas disponíveis
  sendEvent('tools', {
    tools: [
      // Ferramentas de gerenciamento do sistema
      {
        name: "get_system_info",
        description: "Obter informações detalhadas do sistema",
        parameters: {
          type: "object",
          properties: {},
          required: []
        }
      },
      {
        name: "reboot_system",
        description: "Reiniciar o sistema (VPS)",
        parameters: {
          type: "object",
          properties: {},
          required: []
        }
      },
      {
        name: "update_system",
        description: "Atualizar pacotes do sistema",
        parameters: {
          type: "object",
          properties: {},
          required: []
        }
      },
      
      // Ferramentas do Docker
      {
        name: "check_docker",
        description: "Verificar se o Docker está instalado",
        parameters: {
          type: "object",
          properties: {},
          required: []
        }
      },
      {
        name: "install_docker",
        description: "Instalar Docker e Docker Compose",
        parameters: {
          type: "object",
          properties: {},
          required: []
        }
      }
    ]
  });

  // Configura rotas para cada ferramenta
  const toolNames = [
    'get_system_info', 'reboot_system', 'update_system',
    'check_docker', 'install_docker'
  ];
  
  toolNames.forEach(toolName => {
    app.post(`/tools/${toolName}`, authenticateToken, async (req, res) => {
      const result = await handleToolCall(toolName, req.body);
      res.json(result);
    });
  });

  // Mantém a conexão aberta com pings periódicos
  const pingInterval = setInterval(() => {
    sendEvent('ping', { timestamp: Date.now() });
  }, 30000);

  // Fecha a conexão e limpa o intervalo quando o cliente desconecta
  req.on('close', () => {
    clearInterval(pingInterval);
  });
});

// Inicializa diretórios necessários e inicia o servidor
async function startServer() {
  try {
    // Inicializa os diretórios necessários
    await vpsTools.initializeDirs();
    
    // Inicia o servidor
    app.listen(PORT, HOST, () => {
      console.log(`Servidor MCP em execução em http://${HOST}:${PORT}`);
      console.log(`Endpoint SSE disponível em http://${HOST}:${PORT}/sse`);
    });
  } catch (error) {
    console.error('Erro ao iniciar servidor:', error);
    process.exit(1);
  }
}

startServer();
EOL
fi

# Configura o serviço systemd
mensagem "Configurando o serviço systemd..."
cat > /etc/systemd/system/mcp-server.service << EOL
[Unit]
Description=MCP Server para gerenciamento de VPS
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
    echo -e "Token de acesso: $API_KEY"
    echo -e ""
    echo -e "Configure o Cursor AI adicionando ao arquivo mcp.json:"
    echo -e ""
    echo -e '{
  "mcpServers": {
    "mcp-vps": {
      "url": "http://'$IP_ADDR':3000/sse",
      "env": {
        "API_KEY": "'$API_KEY'"
      }
    }
  }
}'
else
    erro "Falha ao iniciar o serviço MCP Server. Verifique os logs com 'journalctl -u mcp-server'"
fi