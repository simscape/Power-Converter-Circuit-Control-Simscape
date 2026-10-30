# MOSFET Model (Electro-Thermal Switch)

Data-sheet-parameterized MOSFET switch model with an electro-thermal (loss + junction-temperature) interface, built for fast simulation inside power-converter bridges.

- **Library:** `Components/ConverterLibrary.slx`
- **Block path:** `ConverterLibrary/Components/MOSFET Model`
- **Mask type:** `MOSFET thermal model`
- **Link status:** `none` (locally authored subsystem, not a link to a shipping library block)
- **Domain:** Simscape Electrical (electrical core) + Simulink (loss and thermal computation)

---

## 1. Overview / Purpose

This block models one power MOSFET switch position for use inside converter bridges (half-bridges, full bridges, and resonant legs).

You enter tabulated conduction voltage, switching energies, and body-diode forward drop as functions of junction temperature and current, and the block reproduces the device's conduction loss, switching loss, body-diode loss, and self-heating. It exposes a thermal case port so it can be tied to an external heatsink/ambient network.

An ideal Simscape MOSFET does the electrical switching, and Simulink computes all loss and thermal dynamics. This keeps the stiff electro-thermal coupling out of the Simscape solver, as the mask states:

> *"This block implements the MOSFET (Ideal, Switching) with thermal ports using a Simulink interface for better simulation performance."*

---

## 2. Ports

The block has **four physical (Simscape) connection ports**:

| Port | Name   | Meaning |
|------|--------|---------|
| `G`  | Gate   | Gate control terminal. Drives the ideal switch on/off (referenced to the internal gate-threshold logic). |
| `D`  | Drain  | Drain power terminal. |
| `S`  | Source | Source power terminal. |
| `A`  | Case / thermal port | Thermal connection representing the device case (below the internal junction-to-case RC network). Connect to an external heatsink / ambient thermal network. Junction temperature `Tj` develops internally above this node. |

`D` and `S` carry the switched power current; `G` is the control terminal; `A` is the thermal interface for heat extraction.

---

## 3. Architecture: ideal electrical core + Simulink loss/thermal path

The model deliberately **splits electrical behavior from loss/thermal computation**.

### 3.1 Electrical core (Simscape)
- A stock `ee_lib` "MOSFET (Ideal, Switching)" block runs in its non-thermal variant with a physical-signal gate control port (`port_option = ee.enum.controlport.ps`). It switches ideally and fast, with no internally coupled Simscape thermal solve (`thermal_loss_option = constantvalues`).
- An external **Diode** (`Vf ≈ 0.6 V`, `Ron = 0.3`) plus **PS Switch / SPST Switch** and **PS Constant** sources sit alongside the MOSFET to form the switched electrical network.
- **Simscape Probes** observe the switch voltage, current, and gate/switch state and export them into Simulink through a **PS-Simulink Converter**.

Because the electrical core is ideal, the electrical solve stays cheap and numerically well-conditioned.

### 3.2 Loss + thermal computation (Simulink) - the `Thermal model` subsystem
The measured switch voltage, current, and gate state feed a **`Thermal model` Simulink subsystem** that:

1. Computes the four loss terms (Section 4) from lookup tables indexed by junction temperature `Tj` and current/voltage.
2. Sums the instantaneous power dissipation.
3. Injects that power as a heat flow into a junction thermal mass inside the Simscape thermal network.
4. Reads the junction temperature back and feeds `Tj` back to re-index the temperature-dependent loss tables (closing the electro-thermal loop).

**Thermal network (as built):**
- Total dissipated power -> **`Simulink-PS Converter`** -> **`Junction Heat Flow`** (a controlled heat flow source) into the **`Junction Thermal Mass`** (`thermal_mass`, initial temperature `Tj0`).
- The junction node connects through a **`Thermal Resistance`** (`resistance = thermal_resistance`) to the case port `A`, so the heat reaches the heatsink or ambient network attached there and the energy balance closes.
- A **`Junction Temperature Sensor`** reads the junction temperature and outputs **`Tj`** (converted to degC), which is looped back to the loss tables.

The trade-off is that the electrical core is ideal (no on-resistance-driven electro-thermal feedback within the Simscape domain) and the thermal network is a single lumped RC (Section 8).

### 3.3 Commutation-value latching (`Ival` subsystem)
Switching energies must be evaluated at the current and voltage at the switching instant, not at the instantaneous post-transition values. The **`Ival` subsystem** uses **Memory blocks and switches** to latch the last current and voltage (`iLast` / `Vlast`, routed through Goto/From tags and `Memory` blocks) so the `Eon`/`Eoff` tables see the correct commutation operating point. A **`Signum` "Switching event"** detects on/off transitions, and a **"Select on or off switching loss"** Switch gates whether switching-loss energy is counted (driven by the soft-switching flag, Section 5).

---

## 4. Loss mechanisms

Each of the four loss terms is a **2-D lookup table** indexed by junction temperature and current (or voltage), located inside the `Thermal model` subsystem.

| Loss term | Subsystem | Lookup table | Breakpoints (dim1 × dim2) | Computation |
|-----------|-----------|--------------|---------------------------|-------------|
| **Turn-on switching energy** | `Eon` | `Eon_data` | `Tj_loss` × `Iout_data_loss` | Triggered on turn-on; table energy scaled by **`1/Voff`** (`Product` with the `1/Voff` gain) so the tabulated energy is referenced to the tabulation voltage `Voff` and rescaled to the actual off-state voltage. |
| **Turn-off switching energy** | `Eoff` | `Eoff_data` | `Tj_loss` × `Iout_data_loss` | Triggered on turn-off; energy scaled by **`1/Voff`**. |
| **Conduction (on-state) loss** | `On-state loses` | `Von_data` | `Tj` × `Iout_data` | `Vds_on(Tj, Ids) × I`, saturated to `[0, inf]`. |
| **Body-diode loss** | `Diode loss` | `Vf_data` | `Tj_diode` × `If_data` | Anti-parallel / body-diode forward loss `Vf(Tj, If) × I`, saturated to `[0, inf]`. |

The switching-energy subsystems are triggered on the detected switching edge and use the latched commutation current/voltage from `Ival`; the conduction and diode subsystems run continuously on the instantaneous operating point. All four contributions are summed to form the total power that drives the RC thermal network.

---

## 5. Soft-switching flag

The mask check box **`Soft_Switching_Flag`** ("Soft-Switching Application", default **on**) sets an internal `SwitchLossFlag` in the mask initialization:

```matlab
currentStatus = get_param(gcb, 'Soft_Switching_Flag');
if strcmp(currentStatus, 'on')
    SwitchLossFlag = 1;   % soft-switching (ZVS/ZCS) assumed -> switching losses suppressed
else
    SwitchLossFlag = 0;   % hard switching -> switching losses counted
end
```

When on, the "Select on or off switching loss" gate suppresses the `Eon`/`Eoff` switching-loss contribution, for soft-switched converters (LLC, CLLC, DAB). When off, switching losses are included, for hard-switched applications. Conduction and body-diode losses are always active.

---

## 6. Mask parameter reference (31 parameters)

Every physical parameter has a companion `*_unit` dropdown. The mask initialization converts each value to internal SI units (V, A, J, K, K/W, J/K), and sets `SwitchLossFlag` from the soft-switching check box.

### 6.1 Threshold
| Parameter | Prompt | Default | Units (dropdown) |
|-----------|--------|---------|------------------|
| `Vth` | Threshold voltage | `3.2` V | V, mV |

### 6.2 On-state (conduction)
| Parameter | Prompt | Default | Units |
|-----------|--------|---------|-------|
| `Von_data` | On-state voltage `Vds_on(Tj, Ids)` (2-D table) | `[-3.075 -1.321 -0.5334 -0.2017 -5.735e-2 0 ...` V | V, mV |
| `Tj` | Temperature breakpoints for `Von_data` | `[-55 25 150 900]` degC | K, degC |
| `Iout_data` | Drain-source current breakpoints for `Von_data` | `[-99.94 -39.11 -14.94 -5.333 -1.517 0 1.517 ...` A | A, mA |

### 6.3 Switching loss
| Parameter | Prompt | Default | Units |
|-----------|--------|---------|-------|
| `Eon_data` | Switch-on loss `Eon(Tj, Ids)` (2-D table) | `[0 2.53e-4 7.404e-4 1.481e-3 2.418e-3 ...` J | J, mJ, uJ |
| `Eoff_data` | Switch-off loss `Eoff(Tj, Ids)` (2-D table) | `[0 1.079e-4 2.792e-4 6.058e-4 1.107e-3 ...` J | J, mJ, uJ |
| `Tj_loss` | Temperature breakpoints for `Eon`/`Eoff` | `[-55 25 150 900 1000]` degC | K, degC |
| `Iout_data_loss` | Current breakpoints for `Eon`/`Eoff` | `[0 16.04 32.08 48.12 64.15 80.19]` A | A, mA |
| `Voff` | Off-state (tabulation reference) voltage; switching energies are scaled by `1/Voff` | `800` V | V, kV |

### 6.4 Body diode
| Parameter | Prompt | Default | Units |
|-----------|--------|---------|-------|
| `Vf_data` | Diode forward voltage `Vf(Tj, If)` (2-D table) | `[0 3.294 3.769 4.385 5.249 6.672; 0 2.997 ...` V | V, mV |
| `Tj_diode` | Temperature breakpoints for `Vf_data` | `[-55 25 150 900 1000]` degC | K, degC |
| `If_data` | Forward-current breakpoints for `Vf_data` | `[0 1.516 5.33 14.93 39.07 99.82]` A | A, mA |

### 6.5 Thermal network
| Parameter | Prompt | Default | Units |
|-----------|--------|---------|-------|
| `thermal_resistance` | Junction-to-case thermal resistance `Rth` | `0.001` K/W | K/W, degC/W |
| `thermal_mass` | Junction thermal mass (heat capacity) `Cth` | `0.01` J/K | J/K, kJ/K |
| `Tj0` | Initial junction temperature | `25` degC | K, degC |

### 6.6 Options
| Parameter | Prompt | Default | Control |
|-----------|--------|---------|---------|
| `Soft_Switching_Flag` | Soft-Switching Application | `on` | check box (Section 5) |

> Companion unit combo-boxes (not listed separately): `Vth_unit`, `Von_data_unit`, `Tj_unit`, `Iout_data_unit`, `Iout_data_loss_unit`, `Tj_loss_unit`, `Eoff_data_unit`, `Eon_data_unit`, `Voff_unit`, `Tj_diode_unit`, `If_data_unit`, `Vf_data_unit`, `thermal_resistance_unit`, `thermal_mass_unit`, `Tj0_unit`. These bring the parameter count to 31.

---

## 7. How and where to use it

- **Instance it as a single switch position inside a converter bridge.** Wire `D`/`S` into the power path and `G` to the gate-drive signal source; tie `A` to a shared heatsink/ambient thermal network (or a Thermal Reference at fixed ambient if you only need junction temperature relative to a constant case).
- **Parameterize from a data sheet.** Populate `Von_data`, `Eon_data`, `Eoff_data`, and `Vf_data` from the device data sheet's temperature/current curves. Set `Voff` to the voltage at which the switching-energy curves were characterized.
- **Set the switching mode with the soft-switching flag.** Leave it **on** for resonant / soft-switched legs (LLC, CLLC, DAB); turn it **off** for hard-switched legs where turn-on/turn-off losses matter.
- **Read junction temperature** from the internal `Tj` state (from the junction temperature sensor) to drive thermal-derating or protection logic in the surrounding converter.

Because losses are handled in Simulink and the electrical core is ideal, many of these devices can be instanced across a converter without the cost of a fully coupled Simscape electro-thermal network at every switch.

---

## 8. Assumptions and limitations

- **Ideal switching electrical core.** The electrical MOSFET is the `ee_lib` "MOSFET (Ideal, Switching)" in its non-thermal, PS-gate variant. Detailed switching transients, gate-charge dynamics, and Coss oscillation are not resolved by the electrical solve - switching behavior is idealized and the loss is accounted for separately from the tabulated energies.
- **Lookup-table loss model.** Conduction, turn-on, turn-off, and body-diode losses are tabulated versus `Tj` and current (and referenced to `Voff` for switching energy). Accuracy depends entirely on the quality/coverage of the entered tables; operating points outside the breakpoint range are clamped/extrapolated by the lookup blocks.
- **Switching energies scale linearly with voltage** through the `1/Voff` factor (energy assumed proportional to the actual blocking voltage relative to the tabulation voltage `Voff`).
- **Single lumped-RC thermal network.** Junction temperature is modeled by one thermal mass (`thermal_mass`) and one junction-to-case resistance (`thermal_resistance`); it does not capture multi-stage (Foster/Cauer) junction-to-case-to-heatsink dynamics. For multi-time-constant thermal behavior, cascade an external thermal network on port `A`.
- **Soft-switching is a modeling assumption, not a detected condition.** With `Soft_Switching_Flag` on, switching losses are suppressed unconditionally; the model does not verify that ZVS/ZCS is actually achieved for the given operating point. Use it only where soft switching is expected.
- **Body diode is loss-tabulated, separate from the electrical diode.** The anti-parallel diode's forward drop for loss is taken from `Vf_data`; the small external electrical Diode (`Vf ≈ 0.6 V`, `Ron = 0.3`) in the core handles the electrical conduction path.

---

## 9. Quick reference summary

- **What:** Data-sheet-parameterized electro-thermal MOSFET switch (device model, not a converter).
- **Ports:** `G` (gate), `D` (drain), `S` (source), `A` (thermal case).
- **Core idea:** Ideal Simscape switching + Simulink-domain loss/thermal computation for fast simulation.
- **Losses:** Turn-on (`Eon_data`), turn-off (`Eoff_data`), conduction (`Von_data`), body diode (`Vf_data`) - all 2-D LUTs versus `Tj` and current.
- **Thermal:** Heat flow into a single junction thermal mass (`thermal_mass`) behind one junction-to-case resistance (`thermal_resistance`), initial temp `Tj0`, junction temperature fed back to the loss tables.
- **Soft-switching flag:** On: switching losses suppressed (resonant converters); off: switching losses counted (hard switching).
