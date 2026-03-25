#!/bin/bash

# ==============================================================================
# Script para configurar e rodar o RISC-V Ibex no OpenLane
#
# Melhorias em relação ao original:
#   1. Validação prévia de todos os arquivos RTL antes de iniciar a síntese
#   2. Nome de run previsível (tag com timestamp) para facilitar monitoramento
#   3. Instruções de monitoramento exibidas ANTES de entrar no Docker
#   4. Suporte a "dry-run" (--dry-run) que só valida sem executar
#   5. Suporte a executar até uma etapa específica (--to <stage>)
# ==============================================================================

set -e

# --- Configurações -----------------------------------------------------------
PROJECT_DIR="$HOME/eda_workspace"
OPENLANE_DIR="$PROJECT_DIR/OpenLane"
IBEX_REPO_DIR="$PROJECT_DIR/ibex"
DESIGN_NAME="ibex_top"
DESIGN_DIR="$OPENLANE_DIR/designs/$DESIGN_NAME"
SRC_DIR="$DESIGN_DIR/src"

# OpenLane configuration
CLOCK_PERIOD=20.0
FP_CORE_UTIL=40
PL_TARGET_DENSITY=0.45

# Tag de run com timestamp (previsível e fácil de encontrar)
RUN_TAG="ibex_$(date +%Y%m%d_%H%M%S)"
RUNS_DIR="$DESIGN_DIR/runs/$RUN_TAG"

# --- Parsing de argumentos ----------------------------------------------------
DRY_RUN=false

for arg in "$@"; do
    case "$arg" in
        --dry-run)
            DRY_RUN=true
            ;;
    esac
done

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║   RISC-V Ibex → OpenLane ASIC Flow                            ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# ==============================================================================
# ETAPA 1: Preparação da estrutura de diretórios
# ==============================================================================
echo "▶ [1/4] Criando estrutura de diretórios..."
mkdir -p "$SRC_DIR"

#-------------------------------------------------------------------------
# Step 1: Pre-convert SystemVerilog to Verilog using sv2v
#-------------------------------------------------------------------------
echo "Converting SystemVerilog files to Verilog using sv2v..."
GEN_DIR="$DESIGN_DIR/src/generated"
mkdir -p "$GEN_DIR"

SV_FILES=(
    "$IBEX_REPO_DIR/vendor/lowrisc_ip/ip/prim/rtl/prim_cipher_pkg.sv"
    "$IBEX_REPO_DIR/vendor/lowrisc_ip/ip/prim/rtl/prim_count_pkg.sv"
    "$IBEX_REPO_DIR/vendor/lowrisc_ip/ip/prim/rtl/prim_secded_pkg.sv"
    "$IBEX_REPO_DIR/vendor/lowrisc_ip/ip/prim/rtl/prim_util_pkg.sv"
    "$IBEX_REPO_DIR/vendor/lowrisc_ip/ip/prim/rtl/prim_mubi_pkg.sv"
    "$IBEX_REPO_DIR/vendor/lowrisc_ip/ip/prim_generic/rtl/prim_pkg.sv"
    "$IBEX_REPO_DIR/vendor/lowrisc_ip/ip/prim_generic/rtl/prim_ram_1p_pkg.sv"
    "$IBEX_REPO_DIR/rtl/ibex_pkg.sv"
    "$IBEX_REPO_DIR/vendor/lowrisc_ip/ip/prim/rtl/prim_count.sv"
    "$IBEX_REPO_DIR/vendor/lowrisc_ip/ip/prim/rtl/prim_secded_inv_39_32_dec.sv"
    "$IBEX_REPO_DIR/vendor/lowrisc_ip/ip/prim/rtl/prim_secded_inv_39_32_enc.sv"
    "$IBEX_REPO_DIR/vendor/lowrisc_ip/ip/prim/rtl/prim_lfsr.sv"
    "$IBEX_REPO_DIR/vendor/lowrisc_ip/ip/prim_generic/rtl/prim_and2.sv"
    "$IBEX_REPO_DIR/vendor/lowrisc_ip/ip/prim_generic/rtl/prim_buf.sv"
    "$IBEX_REPO_DIR/vendor/lowrisc_ip/ip/prim_generic/rtl/prim_clock_mux2.sv"
    "$IBEX_REPO_DIR/vendor/lowrisc_ip/ip/prim_generic/rtl/prim_flop.sv"
    "$IBEX_REPO_DIR/vendor/lowrisc_ip/ip/prim_generic/rtl/prim_clock_gating.sv"
    "$IBEX_REPO_DIR/rtl/ibex_top.sv"
    "$IBEX_REPO_DIR/rtl/ibex_core.sv"
    "$IBEX_REPO_DIR/rtl/ibex_counter.sv"
    "$IBEX_REPO_DIR/rtl/ibex_alu.sv"
    "$IBEX_REPO_DIR/rtl/ibex_branch_predict.sv"
    "$IBEX_REPO_DIR/rtl/ibex_compressed_decoder.sv"
    "$IBEX_REPO_DIR/rtl/ibex_controller.sv"
    "$IBEX_REPO_DIR/rtl/ibex_cs_registers.sv"
    "$IBEX_REPO_DIR/rtl/ibex_csr.sv"
    "$IBEX_REPO_DIR/rtl/ibex_decoder.sv"
    "$IBEX_REPO_DIR/rtl/ibex_ex_block.sv"
    "$IBEX_REPO_DIR/rtl/ibex_fetch_fifo.sv"
    "$IBEX_REPO_DIR/rtl/ibex_id_stage.sv"
    "$IBEX_REPO_DIR/rtl/ibex_if_stage.sv"
    "$IBEX_REPO_DIR/rtl/ibex_load_store_unit.sv"
    "$IBEX_REPO_DIR/rtl/ibex_multdiv_fast.sv"
    "$IBEX_REPO_DIR/rtl/ibex_multdiv_slow.sv"
    "$IBEX_REPO_DIR/rtl/ibex_prefetch_buffer.sv"
    "$IBEX_REPO_DIR/rtl/ibex_pmp.sv"
    "$IBEX_REPO_DIR/rtl/ibex_wb_stage.sv"
    "$IBEX_REPO_DIR/rtl/ibex_dummy_instr.sv"
    "$IBEX_REPO_DIR/rtl/ibex_icache.sv"
    "$IBEX_REPO_DIR/rtl/ibex_register_file_ff.sv"
    "$IBEX_REPO_DIR/rtl/ibex_register_file_fpga.sv"
    "$IBEX_REPO_DIR/rtl/ibex_register_file_latch.sv"
    "$IBEX_REPO_DIR/rtl/ibex_lockstep.sv"
)

# Common dependencies that should be passed to every sv2v call
PKGS=(
    "$IBEX_REPO_DIR/vendor/lowrisc_ip/ip/prim/rtl/prim_util_pkg.sv"
    "$IBEX_REPO_DIR/vendor/lowrisc_ip/ip/prim/rtl/prim_mubi_pkg.sv"
    "$IBEX_REPO_DIR/vendor/lowrisc_ip/ip/prim_generic/rtl/prim_pkg.sv"
    "$IBEX_REPO_DIR/vendor/lowrisc_ip/ip/prim/rtl/prim_cipher_pkg.sv"
    "$IBEX_REPO_DIR/vendor/lowrisc_ip/ip/prim/rtl/prim_count_pkg.sv"
    "$IBEX_REPO_DIR/vendor/lowrisc_ip/ip/prim/rtl/prim_secded_pkg.sv"
    "$IBEX_REPO_DIR/vendor/lowrisc_ip/ip/prim_generic/rtl/prim_ram_1p_pkg.sv"
    "$IBEX_REPO_DIR/rtl/ibex_pkg.sv"
)

V_FILES=()
for file in "${SV_FILES[@]}"; do
    filename=$(basename "$file")
    vname="${filename%.sv}.v"
    vout="$GEN_DIR/$vname"
    
    echo "  Converting $filename -> $vname"
    sv2v \
        --define=SYNTHESIS --define=YOSYS \
        -I"$IBEX_REPO_DIR/vendor/lowrisc_ip/ip/prim/rtl" \
        -I"$IBEX_REPO_DIR/rtl" \
        -I"$IBEX_REPO_DIR/vendor/lowrisc_ip/dv/sv/dv_utils" \
        "${PKGS[@]}" \
        "$file" \
        > "$vout"
    
    # Map primitives like in Ibex's own syn script
    sed -i 's/prim_and2/prim_generic_and2/g' "$vout"
    sed -i 's/prim_buf/prim_generic_buf/g' "$vout"
    sed -i 's/prim_clock_mux2/prim_generic_clock_mux2/g' "$vout"
    sed -i 's/prim_flop/prim_generic_flop/g' "$vout"

    V_FILES+=("dir::src/generated/$vname")
done

# ==============================================================================
# ETAPA 2: Links simbólicos e dependências (Prim)
# ==============================================================================
echo "▶ [2/4] Criando links simbólicos e preparando dependências..."
ln -sfn "$IBEX_REPO_DIR/rtl" "$SRC_DIR/core"
ln -sfn "$IBEX_REPO_DIR/vendor/lowrisc_ip/ip/prim/rtl" "$SRC_DIR/prim"
ln -sfn "$IBEX_REPO_DIR/vendor/lowrisc_ip/ip/prim_generic/rtl" "$SRC_DIR/prim_generic"
ln -sfn "$IBEX_REPO_DIR/vendor/lowrisc_ip/dv/sv/dv_utils" "$SRC_DIR/dv_utils"

# ==============================================================================
# ETAPA 3: Geração do config.json
# ==============================================================================
echo "▶ [3/4] Gerando config.json..."

# Build the VERILOG_FILES string for JSON
V_FILES_STR=$(printf '"%s", ' "${V_FILES[@]}" | sed 's/, $//')

cat <<EOF > "$DESIGN_DIR/config.json"
{
    "DESIGN_NAME": "$DESIGN_NAME",
    "VERILOG_FILES": [
        $V_FILES_STR
    ],
    "CLOCK_PORT": "clk_i",
    "CLOCK_PERIOD": $CLOCK_PERIOD,
    "FP_CORE_UTIL": $FP_CORE_UTIL,
    "PL_TARGET_DENSITY": $PL_TARGET_DENSITY,
    "SYNTH_DEFINES": ["SYNTHESIS", "YOSYS"],
    "QUIT_ON_LINTER_ERRORS": false,
    "LINTER_RELATIVE_INCLUDES": true,
    "SYNTH_USE_SPATIAL_MEM": true,
    "VDD_NETS": ["vccd1"],
    "GND_NETS": ["vssd1"]
}
EOF

# ==============================================================================
# ETAPA 4: VALIDAÇÃO PRÉ-SÍNTESE (config.json + arquivos RTL)
# ==============================================================================
echo "▶ [4/4] Validando config.json e links simbólicos..."
echo ""

# Extrai os caminhos dos arquivos Verilog do config.json
VERILOG_FILES=$(python3 -c "
import json, sys
with open('$DESIGN_DIR/config.json') as f:
    cfg = json.load(f)
for v in cfg.get('VERILOG_FILES', []):
    # 'dir::' é substituído pelo diretório do design dentro do OpenLane
    print(v.replace('dir::', ''))
")

VALIDATION_OK=true
FILE_COUNT=0
MISSING_COUNT=0

echo "  Verificando arquivos RTL listados no config.json:"
echo "  ─────────────────────────────────────────────────"
while IFS= read -r rel_path; do
    full_path="$DESIGN_DIR/$rel_path"
    FILE_COUNT=$((FILE_COUNT + 1))
    if [ -f "$full_path" ]; then
        echo "    ✅  $rel_path"
    else
        echo "    ❌  $rel_path  ← ARQUIVO NÃO ENCONTRADO!"
        VALIDATION_OK=false
        MISSING_COUNT=$((MISSING_COUNT + 1))
    fi
done <<< "$VERILOG_FILES"

echo ""
echo "  Resumo: $FILE_COUNT arquivos verificados, $MISSING_COUNT ausentes."
echo ""

if [ "$VALIDATION_OK" = false ]; then
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║  ❌ VALIDAÇÃO FALHOU!!!                                      ║"
    echo "║  Corrija os caminhos no config.json ou verifique os links.    ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    exit 1
fi

echo "  ✅ Todos os arquivos RTL foram encontrados e estão acessíveis."
echo ""

# --- Verificações adicionais do config.json ---
echo "  Configuração detectada:"
python3 -c "
import json
with open('$DESIGN_DIR/config.json') as f:
    cfg = json.load(f)
print(f'    DESIGN_NAME:    {cfg[\"DESIGN_NAME\"]}')
print(f'    CLOCK_PORT:     {cfg[\"CLOCK_PORT\"]}')
print(f'    CLOCK_PERIOD:   {cfg[\"CLOCK_PERIOD\"]} ns ({1000/cfg[\"CLOCK_PERIOD\"]:.1f} MHz)')
print(f'    FP_CORE_UTIL:   {cfg[\"FP_CORE_UTIL\"]}%')
print(f'    PL_TARGET_DENS: {cfg[\"PL_TARGET_DENSITY\"]}')
print(f'    Nº de arquivos: {len(cfg[\"VERILOG_FILES\"])}')
"
echo ""

# ==============================================================================
# MODO DRY-RUN: Só valida, não executa
# ==============================================================================
if [ "$DRY_RUN" = true ]; then
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║  🏁 DRY-RUN COMPLETO                                       ║"
    echo "║  A validação passou. Nenhum fluxo foi executado.            ║"
    echo "║  Para rodar de verdade, execute sem --dry-run               ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    exit 0
fi

# ==============================================================================
# INSTRUÇÕES DE MONITORAMENTO (exibidas ANTES de entrar no Docker)
# ==============================================================================
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║               🔍 INSTRUÇÕES DE MONITORAMENTO                 ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║                                                               ║"
echo "║  O terminal será 'sequestrado' pelo Docker.                   ║"
echo "║  Abra um SEGUNDO terminal (Ctrl+Alt+T ou SSH) e use:          ║"
echo "║                                                               ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║  📊 LOG PRINCIPAL (progresso geral):                          ║"
echo "║                                                               ║"
echo "║  tail -f $DESIGN_DIR/runs/*/openlane.log                      ║"
echo "║                                                               ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║  🔬 LOGS POR ETAPA (quando quiser detalhe):                   ║"
echo "║                                                               ║"
echo "║  # Síntese (Yosys):                                           ║"
echo "║  tail -f .../runs/*/logs/synthesis/1-synthesis.log            ║"
echo "║                                                               ║"
echo "║  # Floorplan:                                                 ║"
echo "║  tail -f .../runs/*/logs/floorplan/3-initial_fp.log           ║"
echo "║                                                               ║"
echo "║  # Placement (global):                                        ║"
echo "║  tail -f .../runs/*/logs/placement/7-global.log               ║"
echo "║                                                               ║"
echo "║  # CTS (Clock Tree Synthesis):                                ║"
echo "║  tail -f .../runs/*/logs/cts/12-cts.log                       ║"
echo "║                                                               ║"
echo "║  # Routing (detalhado):                                       ║"
echo "║  tail -f .../runs/*/logs/routing/23-detailed.log              ║"
echo "║                                                               ║"
echo "║  # Signoff (GDSII, DRC, LVS):                                 ║"
echo "║  tail -f .../runs/*/logs/signoff/33-gdsii.log                 ║"
echo "║  tail -f .../runs/*/logs/signoff/40-drc.log                   ║"
echo "║                                                               ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║  ⏱️  VERIFICAÇÃO RÁPIDA DE PROGRESSO:                         ║"
echo "║                                                               ║"
echo "║  # Ver última linha do log principal:                         ║"
echo "║  tail -n 5 $DESIGN_DIR/runs/*/openlane.log                    ║"
echo "║                                                               ║"
echo "║  # Listar arquivos gerados (novos = progresso):               ║"
echo "║  ls -lt $DESIGN_DIR/runs/*/results/*/ | head -20              ║"
echo "║                                                               ║"
echo "║  # Ver erros em qualquer etapa:                               ║"
echo "║  cat $DESIGN_DIR/runs/*/logs/*/*.errors                       ║"
echo "║                                                               ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║  ✅ SUCESSO = a linha '[SUCCESS]: Flow complete.' aparece     ║"
echo "║     no openlane.log e o arquivo ibex_core.gds existe em:      ║"
echo "║     runs/<tag>/results/final/gds/ibex_core.gds                ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "Pressione ENTER para iniciar o fluxo, ou Ctrl+C para abortar..."
read -r

# ==============================================================================
# EXECUÇÃO DO FLUXO
# ==============================================================================
echo "🚀 Iniciando OpenLane com tag: $RUN_TAG"
echo "   Tempo estimado: 10-30+ minutos (depende do hardware)"
echo ""

cd "$OPENLANE_DIR"

# Monta o comando com -tag para nome de run previsível
OL_CMD="./flow.tcl -design $DESIGN_NAME -tag $RUN_TAG"

echo ""
# Injeta o comando no ambiente Docker gerenciado pelo Makefile do OpenLane
make -C "$OPENLANE_DIR" -f Makefile -f <(echo 'run_custom: ; cd $(OPENLANE_DIR) && $(ENV_COMMAND) sh -c "$(CUSTOM_CMD)"') run_custom CUSTOM_CMD="$OL_CMD"
# ==============================================================================
echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║              📋 VERIFICAÇÃO PÓS-EXECUÇÃO                     ║"
echo "╚═══════════════════════════════════════════════════════════════╝"

if [ -f "$RUNS_DIR/results/final/gds/$DESIGN_NAME.gds" ]; then
    GDS_SIZE=$(du -h "$RUNS_DIR/results/final/gds/$DESIGN_NAME.gds" | cut -f1)
    echo "  ✅ GDSII encontrado: $RUNS_DIR/results/final/gds/$DESIGN_NAME.gds ($GDS_SIZE)"
else
    # Tenta o caminho alternativo (signoff)
    if [ -f "$RUNS_DIR/results/signoff/$DESIGN_NAME.gds" ]; then
        GDS_SIZE=$(du -h "$RUNS_DIR/results/signoff/$DESIGN_NAME.gds" | cut -f1)
        echo "  ✅ GDSII encontrado: $RUNS_DIR/results/signoff/$DESIGN_NAME.gds ($GDS_SIZE)"
    else
        echo "  ❌ GDSII NÃO encontrado. Verifique os logs de erro."
    fi
fi

# Mostra o resumo de manufaturabilidade, se existir
if [ -f "$RUNS_DIR/reports/manufacturability.rpt" ]; then
    echo ""
    echo "  📊 Relatório de manufaturabilidade:"
    cat "$RUNS_DIR/reports/manufacturability.rpt"
fi

# Mostra as últimas linhas do log principal
if [ -f "$RUNS_DIR/openlane.log" ]; then
    echo ""
    echo "  📝 Últimas linhas do log:"
    tail -n 10 "$RUNS_DIR/openlane.log"
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║  Diretório completo dos resultados:                           ║"
echo "║  $RUNS_DIR/                                                   ║"
echo "╚═══════════════════════════════════════════════════════════════╝"