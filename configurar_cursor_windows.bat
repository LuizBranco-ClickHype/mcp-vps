@echo off
setlocal enabledelayedexpansion

echo =====================================================
echo  Configurador do MCP Server para Cursor AI (Windows)
echo =====================================================

:: Verificar se está sendo executado como administrador
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Este script precisa ser executado como administrador.
    echo Clique com o botao direito e selecione "Executar como administrador"
    pause
    exit /b 1
)

:: Solicita o IP da VPS
set /p VPS_IP="Digite o IP ou dominio da sua VPS: "
if "!VPS_IP!"=="" (
    echo IP da VPS nao pode estar vazio.
    pause
    exit /b 1
)

:: Solicita o token de acesso
set /p TOKEN="Digite o token de acesso gerado durante a instalacao: "
if "!TOKEN!"=="" (
    echo Token de acesso nao pode estar vazio.
    pause
    exit /b 1
)

:: Encontrar o diretório do usuário
set USER_DIR=%USERPROFILE%
set CURSOR_DIR=%USER_DIR%\.cursor
set CONFIG_FILE=%CURSOR_DIR%\mcp.json

:: Verificar se o diretório .cursor existe
if not exist "%CURSOR_DIR%" (
    echo Criando diretorio .cursor...
    mkdir "%CURSOR_DIR%"
)

:: Verificar se o arquivo mcp.json já existe
if exist "%CONFIG_FILE%" (
    echo Arquivo mcp.json ja existe. Fazendo backup...
    copy "%CONFIG_FILE%" "%CONFIG_FILE%.bak"
    
    :: Lê o conteúdo do arquivo existente para verificar se já possui a seção mcpServers
    type "%CONFIG_FILE%" > temp.json
    findstr /C:"mcpServers" temp.json > nul
    if !errorlevel! equ 0 (
        echo Atualizando configuracao existente...
        
        :: Gera um arquivo temporário com a nova configuração
        echo {> temp_new.json
        echo   "mcpServers": {>> temp_new.json
        
        :: Extrai as configurações existentes exceto mcp-vps (se existir)
        for /f "tokens=*" %%a in ('type "%CONFIG_FILE%" ^| findstr /v "mcp-vps" ^| findstr /v "}"') do (
            echo %%a>> temp_new.json
        )
        
        :: Adiciona a nova configuração
        echo     "mcp-vps": {>> temp_new.json
        echo       "url": "http://!VPS_IP!:3000/sse",>> temp_new.json
        echo       "env": {>> temp_new.json
        echo         "API_KEY": "!TOKEN!">> temp_new.json
        echo       }>> temp_new.json
        echo     }>> temp_new.json
        echo   }>> temp_new.json
        echo }>> temp_new.json
        
        :: Substitui o arquivo original
        move /y temp_new.json "%CONFIG_FILE%"
        del temp.json
    ) else (
        echo Criando nova configuracao...
        echo {> "%CONFIG_FILE%"
        echo   "mcpServers": {>> "%CONFIG_FILE%"
        echo     "mcp-vps": {>> "%CONFIG_FILE%"
        echo       "url": "http://!VPS_IP!:3000/sse",>> "%CONFIG_FILE%"
        echo       "env": {>> "%CONFIG_FILE%"
        echo         "API_KEY": "!TOKEN!">> "%CONFIG_FILE%"
        echo       }>> "%CONFIG_FILE%"
        echo     }>> "%CONFIG_FILE%"
        echo   }>> "%CONFIG_FILE%"
        echo }>> "%CONFIG_FILE%"
        del temp.json
    )
) else (
    echo Criando arquivo mcp.json...
    echo {> "%CONFIG_FILE%"
    echo   "mcpServers": {>> "%CONFIG_FILE%"
    echo     "mcp-vps": {>> "%CONFIG_FILE%"
    echo       "url": "http://!VPS_IP!:3000/sse",>> "%CONFIG_FILE%"
    echo       "env": {>> "%CONFIG_FILE%"
    echo         "API_KEY": "!TOKEN!">> "%CONFIG_FILE%"
    echo       }>> "%CONFIG_FILE%"
    echo     }>> "%CONFIG_FILE%"
    echo   }>> "%CONFIG_FILE%"
    echo }>> "%CONFIG_FILE%"
)

echo.
echo Configuracao concluida com sucesso!
echo Arquivo configurado: %CONFIG_FILE%
echo.
echo Por favor, reinicie o Cursor para aplicar as alteracoes.
echo.
pause