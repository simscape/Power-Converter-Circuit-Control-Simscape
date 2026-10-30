%[text] %[text:anchor:T_DABsel] # Select Dual-Active-Bridge (DAB) Converter Components
%[text] This script helps you select the voltage and current ratings of the primary and secondary bridge MOSFETs for the `DualActiveBridgeConverter` model. It then helps you pick catalog parts that meet those ratings.
%[text:tableOfContents]{"heading":"Table of Contents"}
%[text] ## Semiconductor Device Model
%[text] This design solution uses the Simscape™ MOSFET (Ideal, Switching) library block to model the primary and secondary bridge MOSFETs. The block provides two levels of model fidelity: thermal and non-thermal.
%[text] To estimate switching losses and efficiency, use the thermal variant of the MOSFET block in both bridges.
%[text] To tune the controller and analyze the component voltages and currents, use the Ideal Switch option, which simulates faster. 
%[text] The MOSFET (Ideal, Switching) block has no output capacitance parameter. The plant therefore models zero-voltage switching (ZVS) with explicit drain-to-source capacitors set by the Output capacitance (Coss) mask parameters. Applying a catalog part leaves that capacitance unchanged, so if you change devices, set it from the datasheet.
%[text] ## Select MOSFET Device
%[text] To determine the voltage and peak current ratings of the primary and secondary MOSFETs, use the `selectDABDeviceRating` function.
  %[control:button:1a7d]{"position":[1,2]}
if ~exist('DABSpec', 'var');DABDefaultInputParameters; end % Load the specification data
deviceRating = selectDABDeviceRating(DABSpec,TurnsRatio = DABDesign.turnsRatio,SeriesInductance = DABDesign.seriesInductance,... %[output:group:5d0c41b8] %[output:8a41c60d]
    MagnetizingInductance = DABDesign.Lm,SafetyFactor = 1.2,NearestCurrentMultiplier = 5,NearestVoltageMultiplier = 10); %[output:group:5d0c41b8] %[output:8a41c60d]
%%
%[text] ### List the Catalog Parts That Meet the Rating
%[text] The `selectConverterParts` function takes the rating table above and lists the Simscape™ catalog parts that match it, with one ranked list per bridge. A part qualifies only if it meets or exceeds both the voltage and the current rating. The qualifying parts are ranked by the smallest combined over-margin, so the closest sufficient part comes first. If fewer parts qualify than you request, the function reports the shortfall.
  %[control:button:2b8e]{"position":[1,2]}
partTable = selectConverterParts(deviceRating,NumberOfParts=5); %[output:1f7b9e42]
%%
%[text] ### Apply the Selected Part to the Plant
%[text] Set the model and the rank you want from each list above, then click Apply parts to plant model. The `applyConverterPart` function loads the model and applies each part with the Simscape™ part collection API. It also writes the matching ideal-fidelity values to the plant block mask. The model is saved after the parts are applied. Each part is applied to the four MOSFETs of its own bridge, including devices in inactive variants. 
%[text] To apply a part that the lists above do not offer, name its manufacturer and part number instead of a rank. Both bridges are MOSFETs and share one catalog, so name the bridge as well. In the MATLAB Command Window, run:
%[text] ```matlabCodeExample
%[text] applyConverterPart("DualActiveBridgeConverter",DeviceRole="PrimaryMOSFET",Manufacturer="Wolfspeed",PartNumber="E3M0016120K")
%[text] ```
modelName = "DualActiveBridgeConverter"; % Model the parts are applied to
primaryMOSFETPartRank = 1;   % Rank to apply from the PrimaryMOSFET list above
secondaryMOSFETPartRank = 1; % Rank to apply from the SecondaryMOSFET list above
  %[control:button:3c9f]{"position":[1,2]}
%%
%[text] ## Dual-Active-Bridge Converter Model
%[text] You can build the power converter model using your designed power stage, controller, and the parameterized primary and secondary bridge MOSFETs.
%[text] To open the parameterized DAB converter model, in the MATLAB Command Window, run:
%[text] ```matlabCodeExample
%[text] open_system("DualActiveBridgeConverter");
%[text] ```
%[text] 
%[text] %[text:anchor:TMP_DABsel] Copyright 2026 The MathWorks, Inc.

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":27.8}
%---
%[control:button:1a7d]
%   data: {"label":"Estimate device rating","run":"Section"}
%---
%[control:button:2b8e]
%   data: {"label":"List candidate parts","run":"Section"}
%---
%[control:button:3c9f]
%   data: {"callbackCode":"applyConverterPart(modelName,PartTable=partTable,DeviceRole=[\"PrimaryMOSFET\" \"SecondaryMOSFET\"],Rank=[primaryMOSFETPartRank secondaryMOSFETPartRank],SaveModel=true);","label":"Apply parts to plant model","run":"Callback"}
%---
%[output:8a41c60d]
%   data: {"dataType":"text","outputData":{"text":"                   <strong>Primary and Secondary MOSFET Rating<\/strong>                \n    <strong>__________________________________________________________________<\/strong>\n\n                <strong>Device<\/strong>                 <strong>Rating<\/strong>    <strong>Unit<\/strong>    <strong>MetadataField<\/strong>\n    <strong>_______________________________<\/strong>    <strong>______<\/strong>    <strong>____<\/strong>    <strong>_____________<\/strong>\n                                                                      \n    Primary MOSFET voltage rating       960       V       \"VdsMax\"    \n    Primary MOSFET current rating        35       A       \"IdsMaxDC\"  \n    Secondary MOSFET voltage rating     720       V       \"VdsMax\"    \n    Secondary MOSFET current rating      45       A       \"IdsMaxDC\"  \n\n","truncated":false}}
%---
%[output:1f7b9e42]
%   data: {"dataType":"text","outputData":{"text":"\nPrimaryMOSFET - 61 of 145 catalog parts meet 960 V and 35 A (closest first):\n    <strong>Rank<\/strong>        <strong>Manufacturer<\/strong>            <strong>PartNumber<\/strong>        <strong>VoltageRating<\/strong>    <strong>CurrentRating<\/strong>    <strong>VoltageMarginPercent<\/strong>    <strong>CurrentMarginPercent<\/strong>\n    <strong>____<\/strong>    <strong>____________________<\/strong>    <strong>__________________<\/strong>    <strong>_____________<\/strong>    <strong>_____________<\/strong>    <strong>____________________<\/strong>    <strong>____________________<\/strong>\n\n     1      \"Infineon\"              \"AIMW120R060M1H\"          1200              36                   25                    2.8571       \n     2      \"Infineon\"              \"IMBG120R060M1H\"          1200              36                   25                    2.8571       \n     3      \"STMicroelectronics\"    \"SCTWA40N120G2V-4\"        1200              36                   25                    2.8571       \n     4      \"STMicroelectronics\"    \"SCTWA40N120G2V\"          1200              36                   25                    2.8571       \n     5      \"Wolfspeed\"             \"C2M0080120D\"             1200              36                   25                    2.8571       \n\n\nSecondaryMOSFET - 59 of 145 catalog parts meet 720 V and 45 A (closest first):\n    <strong>Rank<\/strong>        <strong>Manufacturer<\/strong>           <strong>PartNumber<\/strong>       <strong>VoltageRating<\/strong>    <strong>CurrentRating<\/strong>    <strong>VoltageMarginPercent<\/strong>    <strong>CurrentMarginPercent<\/strong>\n    <strong>____<\/strong>    <strong>____________________<\/strong>    <strong>________________<\/strong>    <strong>_____________<\/strong>    <strong>_____________<\/strong>    <strong>____________________<\/strong>    <strong>____________________<\/strong>\n\n     1      \"Wolfspeed\"             \"E4M0045075J2\"           750              46                 4.1667                  2.2222       \n     2      \"STMicroelectronics\"    \"SCT30N120\"             1200              45                 66.667                       0       \n     3      \"STMicroelectronics\"    \"SCTWA30N120\"           1200              45                 66.667                       0       \n     4      \"IXYS\"                  \"IXFN50N120SiC\"         1200              47                 66.667                  4.4444       \n     5      \"Infineon\"              \"IMBG120R045M1H\"        1200              47                 66.667                  4.4444       \n\n","truncated":false}}
%---
