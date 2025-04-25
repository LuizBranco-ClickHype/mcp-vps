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
4. Adicione o URL do seu servidor conforme instruções abaixo

### Scripts de configuração automática

Para facilitar a configuração, disponibilizamos scripts que configuram automaticamente o Cursor:

#### Windows

1. Baixe o script [configurar_cursor_windows.bat](https://raw.githubusercontent.com/LuizBranco-ClickHype/mcp-vps/main/configurar_cursor_windows.bat)
2. Clique com o botão direito e selecione "Executar como administrador"
3. Digite o IP da sua VPS e o token de acesso quando solicitado
4. Reinicie o Cursor

#### macOS e Linux

1. Baixe o script [configurar_cursor_unix.sh](https://raw.githubusercontent.com/LuizBranco-ClickHype/mcp-vps/main/configurar_cursor_unix.sh)
2. Torne-o executável: `chmod +x configurar_cursor_unix.sh`
3. Execute-o: `./configurar_cursor_unix.sh`
4. Digite o IP da sua VPS e o token de acesso quando solicitado
5. Reinicie o Cursor

### Configuração manual do arquivo mcp.json

No Cursor, você precisa configurar o arquivo `mcp.json` para se conectar ao servidor MCP na sua VPS. 

#### Localização do arquivo mcp.json

- Windows: `C:\\Users\\seu-usuario\\.cursor\\mcp.json`
- macOS: `~/.cursor/mcp.json`
- Linux: `~/.cursor/mcp.json`

#### Conteúdo do arquivo mcp.json

Adicione a seguinte configuração ao seu arquivo `mcp.json`. Se o arquivo já existir, adicione apenas a seção "mcp-vps" dentro do objeto "mcpServers":

```json
{
  "mcpServers": {
    "mcp-vps": {
      "url": "http://SEU_IP_DA_VPS:3000/sse",
      "env": {
        "API_KEY": "SEU_TOKEN_DE_ACESSO"
      }
    }
  }
}
```

Substitua:
- `SEU_IP_DA_VPS` pelo endereço IP ou domínio da sua VPS
- `SEU_TOKEN_DE_ACESSO` pelo token gerado durante a instalação (exibido ao final do processo ou disponível no arquivo `.env` em `/opt/mcp-server/`)

Se você já tem outros servidores MCP configurados (como GitHub), mantenha-os e apenas adicione a nova configuração:

```json
{
  "mcpServers": {
    "github": {
      "command": "cmd",
      "args": [
        "/c",
        "npx",
        "-y",
        "@smithery/cli@latest",
        "run",
        "@dev-assistant-ai/github",
        "--key",
        "sua-chave-github"
      ]
    },
    "mcp-vps": {
      "url": "http://SEU_IP_DA_VPS:3000/sse",
      "env": {
        "API_KEY": "SEU_TOKEN_DE_ACESSO"
      }
    }
  }
}
```

#### Depois da configuração

1. Salve o arquivo mcp.json
2. Reinicie o Cursor para que as alterações sejam aplicadas
3. Verifique nas configurações do Cursor se o servidor MCP aparece na lista de servidores disponíveis

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

## Solução de Problemas

Para ajudar a diagnosticar e resolver problemas comuns de conexão, disponibilizamos um script de diagnóstico.

### Script de Diagnóstico

Execute o seguinte comando para baixar e executar o script de diagnóstico:

```bash
curl -O https://raw.githubusercontent.com/LuizBranco-ClickHype/mcp-vps/main/solucionar_problemas.sh && chmod +x solucionar_problemas.sh && sudo ./solucionar_problemas.sh
```

O script fará as seguintes verificações:
- Status da instalação do MCP Server
- Versão do Node.js
- Configurações de firewall
- Acessibilidade de portas
- Validade do token de acesso
- Teste básico de conectividade HTTP

### Problemas Comuns

#### Cursor não consegue conectar ao servidor

1. **Verifique se o servidor está em execução:**
   ```bash
   sudo systemctl status mcp-server
   ```
   Se estiver inativo, reinicie com: `sudo systemctl restart mcp-server`

2. **Verifique se a porta está aberta:**
   ```bash
   sudo ufw status | grep 3000
   ```
   Se não estiver, abra a porta: `sudo ufw allow 3000/tcp`

3. **Verifique seu arquivo mcp.json:**
   - Certifique-se de que o URL tenha o formato correto: `http://IP_DA_VPS:3000/sse`
   - Verifique se o token está correto (encontre-o em `/opt/mcp-server/.env`)

4. **Teste conectividade HTTP básica:**
   ```bash
   curl -v http://localhost:3000/ping
   ```
   Deve retornar "pong" se o servidor estiver funcionando corretamente.

#### Problemas de autenticação

1. **Recupere seu token de acesso:**
   ```bash
   sudo cat /opt/mcp-server/.env | grep API_KEY
   ```

2. **Verifique se o token no arquivo mcp.json corresponde ao armazenado no servidor**

3. **Se necessário, gere um novo token:**
   ```bash
   sudo -i
   cd /opt/mcp-server
   API_KEY=$(openssl rand -hex 32)
   sed -i "s/API_KEY=.*/API_KEY=$API_KEY/" .env
   systemctl restart mcp-server
   echo "Novo token gerado: $API_KEY"
   ```
   Lembre-se de atualizar o arquivo mcp.json com o novo token.

#### Logs para depuração avançada

Para visualizar logs detalhados do servidor:
```bash
sudo journalctl -u mcp-server -f
```

Esse comando mostrará logs em tempo real, úteis para identificar erros durante tentativas de conexão.

## Segurança

O script gera um token de acesso aleatório que deve ser usado para autenticar conexões remotas. Este token é exibido ao final da instalação e também pode ser encontrado no arquivo `.env` no diretório de instalação.

## Sobre o Model Context Protocol (MCP)

O [Model Context Protocol (MCP)](https://docs.cursor.com/context/model-context-protocol) é um protocolo aberto que padroniza como aplicações fornecem contexto e ferramentas para LLMs. Este servidor usa o transporte SSE (Server-Sent Events) para comunicação remota com o Cursor AI.

## Suporte

Em caso de problemas, verifique os logs do serviço:

```bash
sudo journalctl -u mcp-server
```