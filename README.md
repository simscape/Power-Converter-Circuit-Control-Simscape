# Power Converter Circuit and Control Design with Simscape

Power converters are fundamental components in various electrification applications. 
This repository provides tools and workflows to design and analyze different power 
converter configurations and control techniques.

[![View Power Converter Circuit and Control Design with Simscape on File Exchange](https://www.mathworks.com/matlabcentral/images/matlab-file-exchange.svg)](https://in.mathworks.com/matlabcentral/fileexchange/131783-power-converter-circuit-and-control-design-with-simscape)
[![Open in MATLAB Online](https://www.mathworks.com/images/responsive/global/open-in-matlab-online.svg)](https://matlab.mathworks.com/open/github/v1?repo=simscape/Power-Converter-Circuit-Control-Simscape)

## 📖 Table of Contents

- Overview
- [Grid-Forming Converter Design](https://viewer.mathworks.com/addons/131783/26.1.1/files/ScriptData/GridFormingConverter/Workflow/GridFormingConverterMain.m)  
- [LLC Resonant Converter Design](https://viewer.mathworks.com/addons/131783/26.1.1/files/ScriptData/LLCConverter/Workflow/LLCResonantConverterFullBridgeMain.m)  
- [CLLC Bidirectional Resonant Converter Design](https://viewer.mathworks.com/addons/131783/26.1.1/files/ScriptData/CLLCConverter/Workflow/CLLCBiDirectionalResonantConverterMain.m)  
- [Dual-Active-Bridge Converter Design](https://viewer.mathworks.com/addons/131783/26.1.1/files/ScriptData/DAB/Workflow/DualActiveBridgeConverterMain.m)  
- [Dual-Active-Bridge Thermal Analysis with Custom MOSFET Model](https://viewer.mathworks.com/addons/131783/26.1.1/files/ScriptData/DABThermalAnalysisWithCustomMOSFET/Workflow/DABThermalAnalysisWithCustomMOSFETMain.m)  
- [Totem-Pole Boost PFC Converter Design](https://viewer.mathworks.com/addons/131783/26.1.1/files/ScriptData/TotemPoleBoostPFC/Workflow/TotemPoleBoostPFCMain.m)  
- [Boost PFC Converter Design](https://viewer.mathworks.com/addons/131783/26.1.1/files/ScriptData/BoostPFC/Workflow/BoostPFCMain.m)  
- [Interleaved Boost PFC Converter Design](https://viewer.mathworks.com/addons/131783/26.1.1/files/ScriptData/InterleavedBoostPFC/Workflow/InterleavedBoostPFCMain.m)  
- [Non-Isolated DC-DC Converter Design](https://viewer.mathworks.com/addons/131783/26.1.1/files/ScriptData/NonIsolatedDCDC/Workflow/NonIsolatedDCDCMain.m)  
- System Level Design Solution
    - Microgrid Design with Simscape[![View Microgrid Design with Simscape on File Exchange](https://www.mathworks.com/matlabcentral/images/matlab-file-exchange.svg)](https://www.mathworks.com/matlabcentral/fileexchange/123865-microgrid-design-with-simscape)
    - Renewable Energy Integration Design with Simscape[![View ​Renewable Energy Integration Design with Simscape on File Exchange](https://www.mathworks.com/matlabcentral/images/matlab-file-exchange.svg)](https://www.mathworks.com/matlabcentral/fileexchange/123870-renewable-energy-integration-design-with-simscape)
- Prerequisites
- Setup 

---

## 🌍 Overview

This repository provides workflows for modeling, simulating, and analyzing power 
converter circuits and control systems using Simscape Electrical. It supports the 
design and simulation of various converter topologies and control algorithms for grid 
modernization and transportation electrification applications.

---

## ⚡ Engineering Solutions

## Grid-Forming Converter Design

Modern power systems face reduced inertia and limited short-circuit current due to increased use of converter-based resources and fewer synchronous machines. Grid-forming (GFM) converters address these issues by emulating synchronous machine dynamics, providing inertia, damping, and enhanced control of active and reactive power.

<table>
  <tr>
    <td width="50%" align="center"><img src="Overview/Images/GridFormingConverterCircuitOverview.png" alt="GFMConverter" width="100%"></td>
    <td width="50%" align="center"><img src="Overview/Images/FullSystemFrequencyChangeGFMResponse.png" alt="GFMConverterFreq" width="100%"></td>
  </tr>
</table>

## LLC Resonant Converter Design

This design solution enables you to design and analyze a full-bridge LLC resonant converter. The workflow guides you through developing the converter to meet your specifications by plotting gain curves for various load conditions, quality factors, and inductor ratios.

<table>
  <tr>
    <td width="50%" align="center"><img src="Overview/Images/LLCConverterModel.png" alt="LLCConverter" width="100%"></td>
    <td width="50%" align="center"><img src="Overview/Images/LLCGainCurve.png" alt="LLCConverter1" width="100%"></td>
  </tr>
</table>

## CLLC Bidirectional Resonant Converter Design

This design solution enables you to design and analyze a bidirectional CLLC resonant converter. A full-bridge synchronous rectifier on the secondary side allows power to flow in either direction.

<table>
  <tr>
    <td width="50%" align="center"><img src="Overview/Images/CLLCConverterModel.png" alt="CLLCConverter" width="100%"></td>
    <td width="50%" align="center"><img src="Overview/Images/CLLCGainCurve.png" alt="CLLCConverter1" width="100%"></td>
  </tr>
</table>

## Dual-Active-Bridge Converter Design

This design solution enables you to design and analyze an isolated bidirectional dual-active-bridge (DAB) converter. The controller regulates either the output voltage or the output current.

<table>
  <tr>
    <td width="50%" align="center"><img src="Overview/Images/DABConverterModel.png" alt="DABConverter" width="100%"></td>
    <td width="50%" align="center"><img src="Overview/Images/DABPowerTransferCurve.png" alt="DABConverter1" width="100%"></td>
  </tr>
</table>

## Dual-Active-Bridge Thermal Analysis with Custom MOSFET Model

This design solution simulates the junction temperature of the eight bridge devices of a dual active bridge converter that uses the MOSFET Model block from ConverterLibrary, and estimates the device loss and the efficiency.

<table>
  <tr>
    <td width="50%" align="center"><img src="Overview/Images/DABThermalAnalysisModel.png" alt="DABThermalAnalysis" width="100%"></td>
    <td width="50%" align="center"><img src="Overview/Images/DABTemperatureRise.png" alt="DABThermalAnalysis1" width="100%"></td>
  </tr>
</table>

## Totem-Pole Boost PFC Converter Design

This design solution enables you to design and analyze a totem-pole boost power factor correction (PFC) converter. You choose whether the slow leg is a diode, a MOSFET, or a thyristor.

<table>
  <tr>
    <td width="50%" align="center"><img src="Overview/Images/TotemPoleConverterModel.png" alt="TotemPoleConverter" width="100%"></td>
    <td width="50%" align="center"><img src="Overview/Images/TotemPoleInductorRipple.png" alt="TotemPoleConverter1" width="100%"></td>
  </tr>
</table>

## Boost PFC Converter Design

This design solution enables you to design and analyze a boost power factor correction (PFC) converter with a diode rectifier bridge at its input.

<table>
  <tr>
    <td width="50%" align="center"><img src="Overview/Images/BoostPFCConverterModel.png" alt="BoostPFCConverter" width="100%"></td>
    <td width="50%" align="center"><img src="Overview/Images/BoostPFCInductorRipple.png" alt="BoostPFCConverter1" width="100%"></td>
  </tr>
</table>

## Interleaved Boost PFC Converter Design

This design solution enables you to design and analyze a two-leg interleaved boost power factor correction (PFC) converter. The two boost legs are identical and operate 180 degrees apart.

<table>
  <tr>
    <td width="50%" align="center"><img src="Overview/Images/InterleavedBoostPFCConverterModel.png" alt="InterleavedBoostPFCConverter" width="100%"></td>
    <td width="50%" align="center"><img src="Overview/Images/InterleavedBoostPFCInductorRipple.png" alt="InterleavedBoostPFCConverter1" width="100%"></td>
  </tr>
</table>

## Non-Isolated DC-DC Converter Design

This design solution enables you to design and analyze a non-isolated DC-DC converter. Choose one of six topologies: buck, boost or buck-boost, each with a synchronous variant.

<table>
  <tr>
    <td width="50%" align="center"><img src="Overview/Images/NonIsolatedDCDCConverterModel.png" alt="NonIsolatedDCDCConverter" width="100%"></td>
    <td width="50%" align="center"><img src="Overview/Images/NonIsolatedDCDCCCMBoundary.png" alt="NonIsolatedDCDCConverter1" width="100%"></td>
  </tr>
</table>

---

## 🛠️ Prerequisites

- MATLAB R2026a or later
- Simscape and Simscape Electrical

---

## 🚀 Setup

1. Clone or download the repository.
2. Add the folder to your MATLAB path.
3. Open PowerConverterCircuitAndControlDesignWithSimscape.prj to get started.
4. Use project shortcut buttons in the toolstrip to access examples.
--------------------------------------------------------

© 2023–2026 The MathWorks, Inc.

