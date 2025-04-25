#!/bin/bash

# Script de instalação rápida para MCP Server
# Baixa e executa o script principal de instalação

# Cores para melhor visualização
VERDE='\033[0;32m'
VERMELHO='\033[0;31m'
NC='\033[0m' # Sem cor

# Verifica se está sendo executado como root
if [ "$EUID" -ne 0 ]; then
    echo -e "${VERMELHO}[!] Este script precisa ser executado como root. Use 'sudo ./install.sh'${NC}"
    exit 1
fi

echo -e "${VERDE}[+] Iniciando instalação do MCP Server...${NC}"
echo -e "${VERDE}[+] Baixando o script principal de instalação...${NC}"

# URL do repositório GitHub
REPO_URL="https://raw.githubusercontent.com/LuizBranco-ClickHype/mcp-vps/main"

# Baixa o script principal
curl -O "$REPO_URL/install_mcp_server.sh" || {
    echo -e "${VERMELHO}[!] Falha ao baixar o script de instalação.${NC}"
    exit 1
}

# Torna o script executável
chmod +x install_mcp_server.sh

# Executa o script principal
echo -e "${VERDE}[+] Executando o script de instalação...${NC}"
./install_mcp_server.sh

# Remove o script após a execução
rm install_mcp_server.sh