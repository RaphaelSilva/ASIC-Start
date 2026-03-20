# Walkthrough: Monitoramento e Validação do Fluxo OpenLane para o Ibex

## O que foi feito

Dois scripts foram criados/aprimorados:

| Script | Finalidade |
|--------|-----------|
| [run_ibex_flow.sh](file:///root/ASIC-Start/run_ibex_flow.sh) | Fluxo principal — agora com validação, dry-run, e instruções de monitoramento |
| [monitor_flow.sh](file:///root/ASIC-Start/monitor_flow.sh) | Script auxiliar para monitorar de um segundo terminal |

---

## 1. Monitoramento em Tempo Real

### O log mestre: [openlane.log](file:///root/eda_workspace/OpenLane/designs/spm/runs/openlane_test/openlane.log)

O arquivo mais importante. Cada vez que o OpenLane termina uma etapa, ele imprime uma linha `[INFO]` neste arquivo. Use:

```bash
# Em um SEGUNDO terminal:
tail -f ~/eda_workspace/OpenLane/designs/ibex_core/runs/*/openlane.log
```

Formato típico de cada linha:
```
[INFO]: Running Synthesis (log: .../logs/synthesis/1-synthesis.log)...
[INFO]: Running Initial Floorplanning (log: .../logs/floorplan/3-initial_fp.log)...
...
[SUCCESS]: Flow complete.
```

> [!TIP]
> O script [monitor_flow.sh](file:///root/ASIC-Start/monitor_flow.sh) simplifica isto. Basta rodar [./monitor_flow.sh](file:///root/ASIC-Start/monitor_flow.sh) ou `./monitor_flow.sh status` do segundo terminal.

### Monitoramento por etapa

Use `./monitor_flow.sh <etapa>` ou `tail -f` direto:

| Etapa | Commando | Log |
|-------|----------|-----|
| Síntese (Yosys) | `./monitor_flow.sh synthesis` | `logs/synthesis/1-synthesis.log` |
| Floorplan | `./monitor_flow.sh floorplan` | `logs/floorplan/3-initial_fp.log` |
| Placement | `./monitor_flow.sh placement` | `logs/placement/7-global.log` |
| CTS | `./monitor_flow.sh cts` | `logs/cts/12-cts.log` |
| Routing | `./monitor_flow.sh routing` | `logs/routing/23-detailed.log` |
| Signoff/GDSII | `./monitor_flow.sh signoff` | `logs/signoff/33-gdsii.log` |
| **Todos os erros** | `./monitor_flow.sh errors` | `logs/*/*.errors` |
| **Status rápido** | `./monitor_flow.sh status` | — |

---

## 2. Milestones — Como saber que cada etapa terminou

As linhas do [openlane.log](file:///root/eda_workspace/OpenLane/designs/spm/runs/openlane_test/openlane.log) são os marcos. Baseado no fluxo real (verificado no run `spm`):

| Step | Etapa | Sucesso = linha no [openlane.log](file:///root/eda_workspace/OpenLane/designs/spm/runs/openlane_test/openlane.log) |
|------|-------|-----------------------------------|
| 1 | Linting | `0 errors found by linter` |
| 2 | **Synthesis** | `Running Single-Corner Static Timing Analysis` (logo após) |
| 3-6 | **Floorplan** | `Floorplanned with width X and height Y` |
| 7-11 | **Placement** | `Running Detailed Placement` completa sem erros |
| 12-14 | **CTS** | `Running Placement Resizer Timing Optimizations` aparece |
| 15-24 | **Routing** | `No DRC violations after detailed routing` |
| 25-32 | **Signoff STA** | Extrações SPEF e STA multicorner completam |
| 33-35 | **GDSII** | `No XOR differences between KLayout and Magic gds` |
| 36-41 | **LVS/DRC** | `No DRC violations after GDS streaming out` |
| 42 | **ERC** | `[SUCCESS]: Flow complete.` ← **FIM!** |

> [!IMPORTANT]
> Se o [openlane.log](file:///root/eda_workspace/OpenLane/designs/spm/runs/openlane_test/openlane.log) parar de crescer por mais de 10 minutos **e** nenhum arquivo novo aparece em `logs/`, o fluxo pode estar travado.

---

## 3. Arquivos Gerados — O que esperar de um run bem-sucedido

Todos ficam em: `designs/ibex_core/runs/<tag>/`

### Estrutura principal

```
runs/<tag>/
├── openlane.log           ← Log mestre
├── warnings.log           ← Warnings consolidados
├── config.tcl             ← Config expandido pelo OpenLane
├── runtime.yaml           ← Tempos de cada etapa
├── reports/
│   ├── manufacturability.rpt  ← ⭐ Resumo final
│   ├── metrics.csv            ← Métricas numéricas
│   ├── synthesis/
│   │   ├── 1-synthesis.AREA_0.stat.rpt   ← Área e contagem de células
│   │   └── 2-syn_sta.summary.rpt         ← Timing pós-síntese
│   ├── signoff/
│   │   ├── 31-rcx_sta.max.rpt  ← ⭐ Timing final (setup)
│   │   ├── 31-rcx_sta.min.rpt  ← ⭐ Timing final (hold)
│   │   ├── drc.rpt             ← ⭐ DRC violations
│   │   └── 39-*.lvs.rpt       ← ⭐ LVS (layout vs schematic)
│   └── ...
├── results/
│   ├── synthesis/ibex_core.v      ← Netlist gate-level
│   ├── floorplan/ibex_core.def    ← DEF do floorplan
│   ├── routing/ibex_core.def      ← DEF roteado
│   ├── signoff/
│   │   ├── ibex_core.gds          ← ⭐ GDSII (Magic)
│   │   ├── ibex_core.klayout.gds  ← GDSII (KLayout)
│   │   ├── ibex_core.lef          ← LEF (macro abstraction)
│   │   ├── ibex_core.spice        ← SPICE netlist
│   │   └── ibex_core.sdf          ← SDF (timing delays)
│   └── final/                     ← ⭐ Cópia consolidada
│       ├── gds/ibex_core.gds
│       ├── lef/ibex_core.lef
│       ├── lib/ibex_core.lib
│       ├── sdc/ibex_core.sdc
│       ├── sdf/...(multicorner)
│       ├── spef/...(multicorner)
│       └── verilog/gl/ibex_core.v
└── logs/
    ├── synthesis/, floorplan/, placement/, cts/, routing/, signoff/
    └── Cada etapa tem: <N>-<nome>.log, .errors, .warnings
```

> [!NOTE]
> O diretório `results/final/` é a **cópia consolidada** de todos os entregáveis. É o diretório que você entregaria para uma foundry.

---

## 4. Validação Rápida (Dry-Run)

### Modo dry-run do script

```bash
./run_ibex_flow.sh --dry-run
```

Isto **NÃO** inicia Docker nem a síntese. Apenas:
1. Cria os links simbólicos
2. Gera o [config.json](file:///root/eda_workspace/OpenLane/designs/ibex_core/config.json)
3. Verifica que **cada arquivo** listado no [config.json](file:///root/eda_workspace/OpenLane/designs/ibex_core/config.json) existe e é acessível
4. Imprime um resumo da configuração (clock, utilização, nº de arquivos)
5. Sai com ✅ ou ❌

### Executar apenas a síntese (smoke test)

```bash
./run_ibex_flow.sh --to synthesis
```

Isso executa `flow.tcl -to synthesis`, que roda apenas Yosys + STA pós-síntese. Se os arquivos SV tiverem problemas de parsing, você descobre em ~2 minutos em vez de 30.

---

## 5. Verificação de GDSII Válido

Para confirmar que o GDSII final está pronto para tapeout, verifique estas 3 condições:

```bash
TAG="ibex_*"  # ou o nome específico do run
RUNS="~/eda_workspace/OpenLane/designs/ibex_core/runs/$TAG"

# 1. O GDSII existe e tem tamanho razoável (>100KB para o Ibex)
ls -lh $RUNS/results/final/gds/ibex_core.gds

# 2. Zero violações DRC
grep -c "Total errors" $RUNS/reports/signoff/drc.rpt
# Esperado: 0

# 3. LVS passou (matches)
grep -i "match\|unique" $RUNS/reports/signoff/*lvs.rpt

# 4. Sem violações de timing (setup/hold)
grep "VIOLATED\|PASSED" $RUNS/reports/signoff/31-rcx_sta.summary.rpt
```

---

## Referência Rápida de Comandos

```bash
# Validar config sem executar:
./run_ibex_flow.sh --dry-run

# Rodar fluxo completo:
./run_ibex_flow.sh

# Monitorar progresso (segundo terminal):
./monitor_flow.sh          # log principal
./monitor_flow.sh status   # resumo rápido
./monitor_flow.sh errors   # check de erros
./monitor_flow.sh synthesis # log do Yosys em tempo real
```
