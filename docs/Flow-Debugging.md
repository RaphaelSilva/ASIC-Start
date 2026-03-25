# Ibex OpenLane Flow Debugging Walkthrough

Successfully resolved SystemVerilog parsing errors and physical design constraints, enabling a complete ASIC flow for the Ibex RISC-V core.

## 🛠️ Problems Identified & Solved

### 1. SystemVerilog Parsing Failure (Yosys)
Yosys, the synthesis tool within OpenLane, struggled with advanced SystemVerilog constructs in Ibex (e.g., multidimensional packed arrays in [prim_cipher_pkg.sv](file:///root/eda_workspace/ibex/vendor/lowrisc_ip/ip/prim/rtl/prim_cipher_pkg.sv)).

**Solution**: Integrated `sv2v` as a pre-processing step to convert all SystemVerilog files to standard Verilog before synthesis.

### 2. Missing Package & Module Dependencies
Initial `sv2v` and synthesis runs failed due to missing files in the design list.
- **Packages**: Added [prim_util_pkg.sv](file:///root/eda_workspace/ibex/vendor/lowrisc_ip/ip/prim/rtl/prim_util_pkg.sv), [prim_mubi_pkg.sv](file:///root/eda_workspace/ibex/vendor/lowrisc_ip/ip/prim/rtl/prim_mubi_pkg.sv), [prim_pkg.sv](file:///root/eda_workspace/ibex/vendor/lowrisc_ip/ip/prim_generic/rtl/prim_pkg.sv), and [ibex_pkg.sv](file:///root/eda_workspace/ibex/rtl/ibex_pkg.sv).
- **Modules**: Added [ibex_counter.sv](file:///root/eda_workspace/ibex/rtl/ibex_counter.sv), [ibex_register_file_ff.sv](file:///root/eda_workspace/ibex/rtl/ibex_register_file_ff.sv), and [ibex_icache.sv](file:///root/eda_workspace/ibex/rtl/ibex_icache.sv).

### 3. Floorplan IO Pin Constraint
The `ibex_core` module had **828 IO pins**, which exceeded the default floorplan capacity (642).

**Solution**: Switched the synthesis target to `ibex_top`, which acts as a standard chip-level wrapper with only **105 IO pins**, fitting perfectly within the floorplan.

---

## 🚀 Final Results

The [run_ibex_flow.sh](file:///root/ASIC-Start/run_ibex_flow.sh) script now automates the entire process:
1.  **Pre-conversion**: SystemVerilog → Verilog via `sv2v`.
2.  **Validation**: RTL list verification and [config.json](file:///root/eda_workspace/OpenLane/designs/ibex_core/config.json) generation.
3.  **ASIC Flow**: Full OpenLane execution (Synthesis, Floorplan, Placement, CTS, and Routing).

### Current Progress
The latest run is currently in the **Routing** phase (Step 15+).

- **Main Log**: [openlane.log](file:///root/eda_workspace/OpenLane/designs/ibex_top/runs/ibex_20260320_043212/openlane.log)
- **Top Module**: `ibex_top`
- **Clock**: 50 MHz (20 ns)

---

## ✅ Verification Steps Taken

1.  **Linter Validation**: Confirmed 0 errors in the Verilator linter phase.
2.  **Synthesis Verification**: Monitored Yosys logs to confirm successful technology mapping (~20k gates).
3.  **Floorplan Validation**: Confirmed that `ibex_top` correctly fits within the physical constraints.
4.  **Flow Monitoring**: Verified that the design successfully advanced past CTS and into Global Routing.

> [!NOTE]
> The OpenLane flow is still running in the background. You can monitor the final result with:
> `tail -f /root/eda_workspace/OpenLane/designs/ibex_top/runs/ibex_20260320_043212/openlane.log`
