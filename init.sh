#!/bin/bash

# ==============================================================================
# Script de Configuração de Ambiente EDA Open-Source (Ubuntu 22.04/24.04)
# Foco: Projeto de ASIC (RISC-V) com OpenLane e SKY130 PDK
# ==============================================================================

# Aborta o script imediatamente se qualquer comando falhar
set -e

echo "==================================================="
echo "Iniciando a configuração do ambiente EDA no Ubuntu..."
echo "==================================================="

# ------------------------------------------------------------------------------
# 1. Atualização do Sistema e Dependências Base
# ------------------------------------------------------------------------------
echo "Passo 1: Atualizando repositórios e instalando dependências base (Git, Make, Python)..."
sudo apt update
sudo apt install -y build-essential git make flex bison libfl-dev \
                    python3 python3-pip python3-venv \
                    gtkwave curl wget jq

# ------------------------------------------------------------------------------
# 2. Instalação do Docker (Motor do OpenLane)
# Se o Docker já estiver instalado, este passo apenas garante que ele está atualizado.
# O OpenLane depende fortemente do Docker para isolar as versões das ferramentas EDA.
# ------------------------------------------------------------------------------
echo "Passo 2: Verificando/Instalando o Docker..."
if ! command -v docker &> /dev/null; then
    echo "Docker não encontrado. Instalando..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
    # Adiciona o usuário atual ao grupo docker para não precisar usar sudo toda hora
    sudo usermod -aG docker $USER
    echo "AVISO: Você precisará fazer logout e login novamente para usar o Docker sem sudo."
    echo "         Ou execute 'newgrp docker' (ou 'su - $USER') neste terminal."
else
    echo "Docker já está instalado."
fi

# ------------------------------------------------------------------------------
# 3. Ferramentas de Simulação (RTL e Gate-Level)
# - Verilator: Compila SystemVerilog para C++ ultra-rápido (ideal para SoC e RISC-V).
# - Icarus Verilog (iverilog): Simulador de eventos, necessário no final do fluxo
#   para rodar a netlist física com arquivos SDF (atrasos reais de tempo).
# ------------------------------------------------------------------------------
echo "Passo 3: Instalando Simuladores (Verilator e Icarus)..."
sudo apt install -y verilator iverilog

# ------------------------------------------------------------------------------
# 4. Estruturação de Diretórios do Projeto
# ------------------------------------------------------------------------------
PROJECT_DIR="$HOME/eda_workspace"
echo "Passo 4: Criando diretório de trabalho em $PROJECT_DIR..."
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# ------------------------------------------------------------------------------
# 5. Ambiente de Verificação (Cocotb - Testbenches em Python)
# Criamos um ambiente virtual (venv) para evitar conflitos de pacotes Python no sistema.
# ------------------------------------------------------------------------------
echo "Passo 5: Configurando ambiente Python para Cocotb..."
python3 -m venv verification_env
# Ativa o ambiente virtual (apenas para a execução deste script)
source verification_env/bin/activate

echo "Instalando Cocotb e bibliotecas auxiliares de testes..."
pip install --upgrade pip
# cocotb: O framework principal.
# pytest e cocotb-test: Para automatizar e organizar as baterias de testes.
pip install cocotb pytest cocotb-test
deactivate # Sai do venv

# ------------------------------------------------------------------------------
# 6. O Fluxo Físico: OpenLane e SKY130 PDK
# Clonamos o orquestrador (OpenLane) que vai gerenciar Yosys, OpenROAD, Magic, etc.
# ------------------------------------------------------------------------------
echo "Passo 6: Baixando e configurando o OpenLane..."
cd "$PROJECT_DIR"
if [ ! -d "OpenLane" ]; then
    # Clonamos a master que aponta para a versão estável atual
    git clone https://github.com/The-OpenROAD-Project/OpenLane.git
    cd OpenLane
    make
    make test
    # Comando vital: O Makefile do OpenLane vai invocar o Docker para baixar a imagem
    # gigante (tools) contendo todas as ferramentas de EDA compiladas (Yosys, OpenROAD...)
    echo "Baixando containers Docker e o PDK SKY130 (Isso pode demorar dependendo da sua internet)..."
    make pull-openlane
else
    echo "Diretório OpenLane já existe. Pulando clone."
    cd OpenLane
fi

# ------------------------------------------------------------------------------
# 7. O Alvo de Teste: Núcleo RISC-V Ibex
# Clonamos o código-fonte (RTL em SystemVerilog) de um RISC-V de qualidade industrial.
# ------------------------------------------------------------------------------
echo "Passo 7: Baixando o núcleo RISC-V Ibex (lowRISC)..."
cd "$PROJECT_DIR"
if [ ! -d "ibex" ]; then
    git clone https://github.com/lowRISC/ibex.git
else
    echo "Diretório do núcleo Ibex já existe. Pulando clone."
fi

# ==============================================================================
echo "==================================================="
echo "Ambiente base configurado com sucesso!"
echo "O que fazer agora:"
echo "1. Se o Docker foi instalado, recarregue seus grupos com: newgrp docker"
echo "2. O OpenLane baixou o seu container principal, mas para instalar o PDK da SkyWater"
echo "   (onde estão as regras de 130nm), você deve rodar:"
echo "   cd $PROJECT_DIR/OpenLane && make pdk"
echo "   (Esse comando fará o download de giga-bytes de arquivos físicos .lef/.lib)"
echo "3. Para rodar simulações com Python, ative o ambiente virtual:"
echo "   source $PROJECT_DIR/verification_env/bin/activate"
echo "==================================================="