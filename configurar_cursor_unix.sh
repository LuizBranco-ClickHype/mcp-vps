#!/bin/bash

# Cores para melhor visualização
VERDE='\033[0;32m'
VERMELHO='\033[0;31m'
AMARELO='\033[1;33m'
NC='\033[0m' # Sem cor

echo -e "${VERDE}=====================================================${NC}"
echo -e "${VERDE} Configurador do MCP Server para Cursor AI (Unix/Mac) ${NC}"
echo -e "${VERDE}=====================================================${NC}"

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

# Solicita o IP da VPS
read -p "Digite o IP ou domínio da sua VPS: " VPS_IP
if [ -z "$VPS_IP" ]; then
    erro "IP da VPS não pode estar vazio."
fi

# Solicita o token de acesso
read -p "Digite o token de acesso gerado durante a instalação: " TOKEN
if [ -z "$TOKEN" ]; then
    erro "Token de acesso não pode estar vazio."
fi

# Encontrar o diretório do usuário
USER_DIR="$HOME"
CURSOR_DIR="$USER_DIR/.cursor"
CONFIG_FILE="$CURSOR_DIR/mcp.json"

# Verificar se o diretório .cursor existe
if [ ! -d "$CURSOR_DIR" ]; then
    mensagem "Criando diretório .cursor..."
    mkdir -p "$CURSOR_DIR"
fi

# Função para criar arquivo de configuração
criar_configuracao() {
    cat > "$CONFIG_FILE" << EOL
{
  "mcpServers": {
    "mcp-vps": {
      "url": "http://$VPS_IP:3000/sse",
      "env": {
        "API_KEY": "$TOKEN"
      }
    }
  }
}
EOL
}

# Verificar se o arquivo mcp.json já existe
if [ -f "$CONFIG_FILE" ]; then
    mensagem "Arquivo mcp.json já existe. Fazendo backup..."
    cp "$CONFIG_FILE" "$CONFIG_FILE.bak"
    
    # Verifica se o arquivo tem a seção mcpServers
    if grep -q "mcpServers" "$CONFIG_FILE"; then
        mensagem "Atualizando configuração existente..."
        
        # Se estiver usando jq (mais seguro para manipular JSON)
        if command -v jq &> /dev/null; then
            # Remove configuração existente de mcp-vps se houver e adiciona a nova
            jq '.mcpServers["mcp-vps"] = {"url": "http://'"$VPS_IP"':3000/sse", "env": {"API_KEY": "'"$TOKEN"'"}}' "$CONFIG_FILE" > "$CONFIG_FILE.tmp"
            mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        else
            aviso "A ferramenta jq não está instalada. Criando novo arquivo de configuração..."
            criar_configuracao
        fi
    else
        mensagem "Arquivo não contém configuração de mcpServers. Criando nova configuração..."
        criar_configuracao
    fi
else
    mensagem "Criando arquivo mcp.json..."
    criar_configuracao
fi

mensagem "Configuração concluída com sucesso!"
echo -e "Arquivo configurado: $CONFIG_FILE"
echo -e "\nPor favor, reinicie o Cursor para aplicar as alterações.\n"