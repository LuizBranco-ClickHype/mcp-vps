#!/bin/bash

# Script para diagnosticar e solucionar problemas comuns do MCP Server
# Execute com: sudo bash solucionar_problemas.sh

# Cores para melhor visualização
VERDE='\033[0;32m'
VERMELHO='\033[0;31m'
AMARELO='\033[1;33m'
NC='\033[0m' # Sem cor

# Variáveis
MCP_DIR="/opt/mcp-server"
SERVICE_NAME="mcp-server"
PORT=3000

# Função para exibir mensagens de progresso
mensagem() {
    echo -e "${VERDE}[+] $1${NC}"
}

# Função para exibir mensagens de erro
erro() {
    echo -e "${VERMELHO}[!] $1${NC}"
}

# Função para exibir mensagens de aviso
aviso() {
    echo -e "${AMARELO}[!] $1${NC}"
}

# Verifica se está sendo executado como root
if [ "$EUID" -ne 0 ]; then
    erro "Este script precisa ser executado como root."
    exit 1
fi

echo -e "${VERDE}=============================================${NC}"
echo -e "${VERDE} Diagnóstico e Solução de Problemas do MCP  ${NC}"
echo -e "${VERDE}=============================================${NC}"

# Verifica se o serviço está instalado
if ! systemctl list-unit-files | grep -q "$SERVICE_NAME"; then
    erro "O serviço MCP não está instalado. Execute primeiro o script de instalação."
    exit 1
fi

# Verifica o status do serviço
mensagem "Verificando status do serviço..."
if systemctl is-active --quiet "$SERVICE_NAME"; then
    mensagem "O serviço MCP está em execução."
else
    aviso "O serviço MCP não está em execução. Tentando iniciar..."
    systemctl start "$SERVICE_NAME"
    sleep 2
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        mensagem "Serviço iniciado com sucesso."
    else
        erro "Não foi possível iniciar o serviço. Verificando logs..."
        journalctl -u "$SERVICE_NAME" -n 50 --no-pager
    fi
fi

# Verifica a configuração do Node.js
mensagem "Verificando a versão do Node.js..."
NODE_VERSION=$(node -v)
if [[ $(echo $NODE_VERSION | cut -d. -f1 | tr -d 'v') -lt 14 ]]; then
    aviso "Versão do Node.js ($NODE_VERSION) é antiga. Recomendamos atualizar para v14 ou superior."
else
    mensagem "Versão do Node.js ($NODE_VERSION) é adequada."
fi

# Verifica o firewall
mensagem "Verificando configuração do firewall..."
if command -v ufw &> /dev/null; then
    UFW_STATUS=$(ufw status | grep "$PORT")
    if [[ $UFW_STATUS == *ALLOW* ]]; then
        mensagem "Porta $PORT está permitida no firewall."
    else
        aviso "Porta $PORT não está explicitamente permitida no firewall. Configurando..."
        ufw allow "$PORT/tcp"
        mensagem "Porta $PORT configurada no firewall."
    fi
else
    aviso "UFW não está instalado. Verificando iptables..."
    IPTABLES_STATUS=$(iptables -L -n | grep "$PORT")
    if [[ -z "$IPTABLES_STATUS" ]]; then
        aviso "Não foram encontradas regras para a porta $PORT no iptables."
    else
        mensagem "Existem regras para a porta $PORT no iptables."
    fi
fi

# Verifica a acessibilidade da porta
mensagem "Verificando se a porta $PORT está acessível externamente..."
IP_ADDR=$(hostname -I | awk '{print $1}')
if netstat -tuln | grep -q ":$PORT "; then
    mensagem "A porta $PORT está em uso pelo servidor."
    
    # Verifica a interface
    LISTEN_ADDR=$(netstat -tuln | grep ":$PORT " | awk '{print $4}')
    if [[ $LISTEN_ADDR == *0.0.0.0:$PORT || $LISTEN_ADDR == *:::$PORT ]]; then
        mensagem "O servidor está ouvindo em todas as interfaces (0.0.0.0)."
    else
        aviso "O servidor não está ouvindo em todas as interfaces. Isso pode causar problemas."
        aviso "Configuração atual: $LISTEN_ADDR"
        
        # Corrige a configuração de HOST
        if [ -f "$MCP_DIR/.env" ]; then
            sed -i 's/^HOST=.*/HOST=0.0.0.0/' "$MCP_DIR/.env"
            mensagem "Arquivo .env atualizado para usar HOST=0.0.0.0"
            mensagem "Reiniciando o serviço..."
            systemctl restart "$SERVICE_NAME"
            sleep 2
        fi
    fi
else
    erro "A porta $PORT não está sendo usada. O servidor pode não estar funcionando corretamente."
    mensagem "Reiniciando o serviço..."
    systemctl restart "$SERVICE_NAME"
    sleep 2
fi

# Verifica token de acesso
mensagem "Verificando token de acesso..."
if [ -f "$MCP_DIR/.env" ]; then
    TOKEN=$(grep ACCESS_TOKEN "$MCP_DIR/.env" | cut -d= -f2)
    if [ -n "$TOKEN" ]; then
        mensagem "Token de acesso encontrado: ${TOKEN:0:8}...${TOKEN: -8}"
        
        # Verifica a configuração do Cursor
        CURSOR_CONFIG_UNIX="$HOME/.cursor/mcp.json"
        CURSOR_CONFIG_WIN="/mnt/c/Users/$USER/.cursor/mcp.json"
        
        if [ -f "$CURSOR_CONFIG_UNIX" ]; then
            mensagem "Arquivo de configuração do Cursor encontrado: $CURSOR_CONFIG_UNIX"
            grep -q "$TOKEN" "$CURSOR_CONFIG_UNIX"
            if [ $? -eq 0 ]; then
                mensagem "Token encontrado na configuração do Cursor."
            else
                aviso "Token não encontrado na configuração do Cursor. Verifique o arquivo $CURSOR_CONFIG_UNIX"
            fi
        elif [ -f "$CURSOR_CONFIG_WIN" ]; then
            mensagem "Arquivo de configuração do Cursor encontrado: $CURSOR_CONFIG_WIN"
            grep -q "$TOKEN" "$CURSOR_CONFIG_WIN"
            if [ $? -eq 0 ]; then
                mensagem "Token encontrado na configuração do Cursor."
            else
                aviso "Token não encontrado na configuração do Cursor. Verifique o arquivo $CURSOR_CONFIG_WIN"
            fi
        else
            aviso "Arquivo de configuração do Cursor não encontrado."
        fi
    else
        aviso "Token de acesso não encontrado no arquivo .env"
    fi
else
    erro "Arquivo .env não encontrado em $MCP_DIR"
fi

# Teste de conectividade
mensagem "Testando conectividade HTTP básica..."
CURL_OUTPUT=$(curl -s "http://localhost:$PORT/status")
if [ -n "$CURL_OUTPUT" ]; then
    mensagem "Conectividade local OK. Resposta: $CURL_OUTPUT"
else
    erro "Não foi possível conectar-se localmente ao servidor."
fi

# Verificação extensiva dos logs
mensagem "Verificando logs em busca de erros recentes..."
ERROR_LOGS=$(journalctl -u "$SERVICE_NAME" -n 100 --no-pager | grep -i "error\|exception\|fail")
if [ -n "$ERROR_LOGS" ]; then
    aviso "Encontrados erros nos logs:"
    echo "$ERROR_LOGS"
else
    mensagem "Nenhum erro óbvio encontrado nos logs recentes."
fi

# Informações de configuração
echo -e "${VERDE}=============================================${NC}"
echo -e "${VERDE} Resumo da Configuração                      ${NC}"
echo -e "${VERDE}=============================================${NC}"
echo -e "IP do Servidor: $IP_ADDR"
echo -e "Porta: $PORT"
echo -e "URL do MCP: http://$IP_ADDR:$PORT/sse"
echo -e "Token de Acesso: ${TOKEN:0:8}...${TOKEN: -8}"
echo -e "${VERDE}=============================================${NC}"
echo -e "Configuração para o mcp.json do Cursor:"
echo -e "${VERDE}"
cat << EOF
{
  "mcpServers": {
    "mcp-vps": {
      "url": "http://$IP_ADDR:$PORT/sse",
      "env": {
        "API_KEY": "$TOKEN"
      }
    }
  }
}
EOF
echo -e "${NC}"
echo -e "${VERDE}=============================================${NC}"
echo -e "Comandos para testes:"
echo -e "- Testar status: curl http://$IP_ADDR:$PORT/status"
echo -e "- Testar autenticação: curl -H \"Authorization: Bearer $TOKEN\" http://$IP_ADDR:$PORT/test-auth"
echo -e "${VERDE}=============================================${NC}"

# Pergunta se deseja reiniciar o servidor
read -p "Deseja reiniciar o servidor MCP? (s/N): " REINICIAR
if [[ $REINICIAR == "s" || $REINICIAR == "S" ]]; then
    mensagem "Reiniciando o servidor MCP..."
    systemctl restart "$SERVICE_NAME"
    sleep 2
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        mensagem "Servidor reiniciado com sucesso."
    else
        erro "Não foi possível reiniciar o servidor."
    fi
fi

mensagem "Diagnóstico concluído!"