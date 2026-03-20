#!/bin/bash

# ==============================================================================
# Script auxiliar para monitorar o progresso do OpenLane em tempo real
# Execute este script em um SEGUNDO terminal enquanto o fluxo roda.
#
# Uso:
#   ./monitor_flow.sh               # Monitora o log principal
#   ./monitor_flow.sh synthesis      # Monitora a síntese (Yosys)
#   ./monitor_flow.sh floorplan      # Monitora o floorplan
#   ./monitor_flow.sh placement      # Monitora o placement
#   ./monitor_flow.sh cts            # Monitora o CTS
#   ./monitor_flow.sh routing        # Monitora o routing detalhado
#   ./monitor_flow.sh signoff        # Monitora o signoff (GDSII/DRC)
#   ./monitor_flow.sh errors         # Mostra todos os erros
#   ./monitor_flow.sh status         # Resumo rápido do progresso
# ==============================================================================

DESIGN_DIR="$HOME/eda_workspace/OpenLane/designs/ibex_core"

# Encontra o run mais recente
LATEST_RUN=$(ls -td "$DESIGN_DIR/runs/"*/ 2>/dev/null | head -1)

if [ -z "$LATEST_RUN" ]; then
    echo "❌ Nenhum run encontrado em $DESIGN_DIR/runs/"
    echo "   O fluxo já foi iniciado?"
    exit 1
fi

RUN_TAG=$(basename "$LATEST_RUN")
echo "═══════════════════════════════════════════════════"
echo " 🔍 Monitorando run: $RUN_TAG"
echo "═══════════════════════════════════════════════════"
echo ""

case "${1:-main}" in
    main)
        echo "📊 Log principal (pressione Ctrl+C para sair):"
        tail -f "$LATEST_RUN/openlane.log"
        ;;
    synthesis|syn)
        echo "🔬 Log da Síntese (Yosys):"
        tail -f "$LATEST_RUN/logs/synthesis/1-synthesis.log"
        ;;
    floorplan|fp)
        echo "📐 Log do Floorplan:"
        tail -f "$LATEST_RUN/logs/floorplan/3-initial_fp.log"
        ;;
    placement|place)
        echo "📍 Log do Placement (global):"
        tail -f "$LATEST_RUN/logs/placement/7-global.log"
        ;;
    cts)
        echo "🕐 Log do CTS (Clock Tree Synthesis):"
        tail -f "$LATEST_RUN/logs/cts/12-cts.log"
        ;;
    routing|route)
        echo "🛤️  Log do Routing (detalhado):"
        tail -f "$LATEST_RUN/logs/routing/23-detailed.log"
        ;;
    signoff|gds)
        echo "✍️  Log do Signoff (GDSII):"
        tail -f "$LATEST_RUN/logs/signoff/33-gdsii.log"
        ;;
    errors|err)
        echo "❌ Erros encontrados em TODAS as etapas:"
        echo ""
        for err_file in "$LATEST_RUN"/logs/*/*.errors; do
            if [ -s "$err_file" ]; then
                stage=$(basename "$(dirname "$err_file")")
                step=$(basename "$err_file")
                echo "── $stage / $step ──"
                cat "$err_file"
                echo ""
            fi
        done
        TOTAL=$(find "$LATEST_RUN/logs" -name "*.errors" -not -empty | wc -l)
        echo "Total de arquivos com erros: $TOTAL"
        ;;
    status|st)
        echo "📋 STATUS RÁPIDO DO FLUXO:"
        echo ""

        # Conta arquivos gerados por etapa
        for stage in synthesis floorplan placement cts routing signoff; do
            result_dir="$LATEST_RUN/results/$stage"
            log_dir="$LATEST_RUN/logs/$stage"
            if [ -d "$result_dir" ]; then
                count=$(find "$result_dir" -type f | wc -l)
                echo "  ✅ $stage: $count arquivo(s) gerado(s)"
            elif [ -d "$log_dir" ]; then
                # Logs existem mas resultados ainda não
                last_log=$(ls -t "$log_dir"/*.log 2>/dev/null | head -1)
                if [ -n "$last_log" ]; then
                    echo "  ⏳ $stage: EM PROGRESSO ($(basename "$last_log"))"
                else
                    echo "  ⬜ $stage: aguardando"
                fi
            else
                echo "  ⬜ $stage: aguardando"
            fi
        done

        echo ""

        # Verifica resultado final
        if [ -d "$LATEST_RUN/results/final" ]; then
            echo "  🏁 RESULTADOS FINAIS:"
            for ext in gds lef lib mag spef sdc sdf; do
                dir="$LATEST_RUN/results/final/$ext"
                if [ -d "$dir" ]; then
                    files=$(ls "$dir" 2>/dev/null | head -3)
                    if [ -n "$files" ]; then
                        echo "    📦 $ext/ → $files"
                    fi
                fi
            done
        fi

        echo ""

        # Última atividade
        if [ -f "$LATEST_RUN/openlane.log" ]; then
            echo "  ⏱️  Última atividade:"
            tail -n 3 "$LATEST_RUN/openlane.log" | sed 's/^/    /'
        fi
        ;;
    *)
        echo "Uso: $0 [main|synthesis|floorplan|placement|cts|routing|signoff|errors|status]"
        exit 1
        ;;
esac
