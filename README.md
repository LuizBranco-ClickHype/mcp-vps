# MCP Server para VPS Ubuntu com suporte ao Cursor AI

Este repositório contém script de instalação automatizada do MCP Server para VPS Ubuntu, permitindo conexões remotas, gerando token de acesso e com compatibilidade para o [Cursor AI](https://cursor.sh/) através do protocolo MCP (Model Context Protocol).

## Requisitos

- VPS com Ubuntu (18.04 ou superior)
- Acesso root à VPS
- Portas de firewall abertas (o script configura automaticamente)

## Instalação Rápida

Execute o comando abaixo para instalar o MCP Server:

```bash
curl -O https://raw.githubusercontent.com/LuizBranco-ClickHype/mcp-vps/main/install.sh && chmod +x install.sh && sudo ./install.sh
```

## O que o script faz?

1. Atualiza o sistema
2. Instala dependências necessárias
3. Configura Node.js na versão LTS mais recente
4. Instala e configura o MCP Server com suporte ao protocolo MCP do Cursor AI
5. Gera um token de acesso único
6. Configura o MCP Server como serviço systemd
7. Configura o firewall para permitir conexões remotas
8. Inicia o serviço automaticamente

## Detalhes da configuração

- Porta padrão: 3000
- Diretório de instalação: /opt/mcp-server
- Interface: 0.0.0.0 (permite conexões de qualquer IP)
- Token de acesso: gerado automaticamente e exibido ao final da instalação
- Endpoint SSE: /sse (utilizado pelo Cursor AI para conexão)

## Integrando com o Cursor AI

Após a instalação, você poderá conectar seu MCP Server ao Cursor AI:

1. Abra o Cursor AI
2. Acesse as configurações
3. Vá para a seção MCP
4. Adicione o URL do seu servidor: `http://seu-ip:3000/sse`
5. Use o token de acesso gerado durante a instalação como chave de autenticação

O Cursor AI agora poderá se comunicar com seu MCP Server, permitindo a utilização das ferramentas disponibilizadas.

## Gerenciamento do serviço

```bash
# Verificar status
sudo systemctl status mcp-server

# Reiniciar o serviço
sudo systemctl restart mcp-server

# Parar o serviço
sudo systemctl stop mcp-server

# Visualizar logs
sudo journalctl -u mcp-server
```

## Segurança

O script gera um token de acesso aleatório que deve ser usado para autenticar conexões remotas. Este token é exibido ao final da instalação e também pode ser encontrado no arquivo `.env` no diretório de instalação.

## Sobre o Model Context Protocol (MCP)

O [Model Context Protocol (MCP)](https://docs.cursor.com/context/model-context-protocol) é um protocolo aberto que padroniza como aplicações fornecem contexto e ferramentas para LLMs. Este servidor usa o transporte SSE (Server-Sent Events) para comunicação remota com o Cursor AI.

## Suporte

Em caso de problemas, verifique os logs do serviço:

```bash
sudo journalctl -u mcp-server
```