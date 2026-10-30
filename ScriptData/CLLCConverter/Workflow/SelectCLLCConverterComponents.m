%[text] %[text:anchor:T_453a] # Select CLLC Resonant Converter Components
%[text] This script helps you select the voltage and current ratings of the primary and secondary bridge MOSFETs for the `CLLCResonantConverter` model, and then pick catalog parts that meet those ratings.
%[text:tableOfContents]{"heading":"Table of Contents"}
%[text] ## Semiconductor Device Model
%[text] This design solution models the primary and secondary MOSFETs with the Simscape™ MOSFET (Ideal, Switching) block, which has two fidelity levels: thermal and non-thermal.
%[text] To estimate the switching losses, efficiency, and temperature rise, use the thermal variant of the MOSFET block in both bridges.
%[text] To tune the controller and analyze component voltages and currents, use the Ideal Switch option, which simulates faster. In the plant block, Model option selects the Simplified or Detailed power stage, and Primary device option and Secondary device option select Ideal Switch or MOSFET (Ideal, Switching) with Thermal in each bridge. The thermal MOSFETs take their parameters from the applied catalog part.
%[text] ## Select MOSFET Device
%[text] Select the primary and secondary MOSFETs from the voltage and peak current ratings your converter requires. To determine the device ratings, use the `selectCLLCDeviceRating` function. To simulate the primary converter, use the Simscape MOSFET (Ideal, Switching) block. To model zero-voltage switching (ZVS), add an external drain-to-source parasitic capacitor in parallel with the MOSFET (Ideal, Switching) block.
  %[control:button:1bcd]{"position":[1,2]}
% The defaults load only when a variable this script reads is absent, so running EstimateCLLCConverterResonantTankParameters first is enough.
if ~all([exist('CLLCSpec','var') exist('CLLCDesign','var') exist('frequencyRange','var')]); CLLCConverterDefaultInputParameters; end % Load the specification data
% One device rating serves both power-flow directions, so the devices are sized at the lowest
% operating frequency of the two: the peak magnetizing current grows with the half period.
minOperatingFrequency = getCLLCOperatingFrequencyRange(frequencyRange);
deviceRating = selectCLLCDeviceRating(CLLCSpec,TurnsRatio = CLLCDesign.turnsRatio,SafetyFactor = 1.2,NearestCurrentMultiplier=5,NearestVoltageMultiplier=10,... %[output:group:8ee28060] %[output:60843b6a]
    MagnetizingInductance=simscape.Value(CLLCDesign.Lm,"H"),MinOperatingFreq=simscape.Value(minOperatingFrequency,"Hz")); %[output:group:8ee28060] %[output:60843b6a]
%%
%[text] ### List the Catalog Parts That Meet the Rating
%[text] For the required ratings, you can use parameterized MOSFET (Ideal, Switching) parts or parameterize the block from manufacturer datasheets and loss table XML files. This design solution uses parameterized parts. The `selectConverterParts` function lists the Simscape™ catalog parts that meet or exceed both the voltage and the current rating in the table above, with one ranked list per bridge. The part with the smallest combined over-margin comes first. If fewer parts qualify than you asked for, the function reports the shortfall.
  %[control:button:2a1f]{"position":[1,2]}
partTable = selectConverterParts(deviceRating,NumberOfParts=5); %[output:7fdd9487]
%%
%[text] ### Apply the Selected Part to the Plant
%[text] Set the model and the rank you want from each list above, then click Apply parts to plant model. The `applyConverterPart` function applies each part to the model and sets the matching ideal-fidelity values on the plant block. The model is saved after the parts are applied.
%[text] Each part is applied to the four MOSFETs of its bridge, including devices in inactive variants, so a later fidelity change needs no reapply. The thermal network topology of each device is set to external, because the plant supplies its own thermal network.
%[text] To apply a part that the lists do not offer, set its manufacturer, part number, and bridge instead of a rank. At the MATLAB Command Window, run: 
%[text] ```matlabCodeExample
%[text] applyConverterPart("CLLCResonantConverter",DeviceRole="PrimaryMOSFET",Manufacturer="Wolfspeed",PartNumber="E4M0015075K1")
%[text] ```
modelName = "CLLCResonantConverter"; % Model the parts are applied to
primaryMOSFETPartRank = 1;   % Rank to apply from the PrimaryMOSFET list above
secondaryMOSFETPartRank = 1; % Rank to apply from the SecondaryMOSFET list above
  %[control:button:3b7c]{"position":[1,2]}
%%
%[text] ## CLLC Resonant Converter Model
%[text] You can build the power converter model using your designed resonant tank, controller, and the parameterized primary and secondary MOSFETs.
%[text] To open the parameterized CLLC converter model, at the MATLAB Command Window, run: 
%[text] ```matlabCodeExample
%[text] open_system("CLLCResonantConverter");
%[text] ```
%%
%[text] %[text:anchor:TMP_60ba] Copyright 2025-2026 The MathWorks, Inc.

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":27.8}
%---
%[control:button:1bcd]
%   data: {"label":"Estimate device rating","run":"Section"}
%---
%[control:button:2a1f]
%   data: {"label":"List candidate parts","run":"Section"}
%---
%[control:button:3b7c]
%   data: {"callbackCode":"applyConverterPart(modelName,PartTable=partTable,DeviceRole=[\"PrimaryMOSFET\" \"SecondaryMOSFET\"],Rank=[primaryMOSFETPartRank secondaryMOSFETPartRank],SaveModel=true);","label":"Apply parts to plant model","run":"Callback"}
%---
%[output:60843b6a]
%   data: {"dataType":"text","outputData":{"text":"                   <strong>Primary and Secondary MOSFET Rating<\/strong>                \n    <strong>__________________________________________________________________<\/strong>\n\n                <strong>Device<\/strong>                 <strong>Rating<\/strong>    <strong>Unit<\/strong>    <strong>MetadataField<\/strong>\n    <strong>_______________________________<\/strong>    <strong>______<\/strong>    <strong>____<\/strong>    <strong>_____________<\/strong>\n                                                                      \n    Primary MOSFET voltage rating       480       V       \"VdsMax\"    \n    Primary MOSFET current rating       105       A       \"IdsMaxDC\"  \n    Secondary MOSFET voltage rating     480       V       \"VdsMax\"    \n    Secondary MOSFET current rating     115       A       \"IdsMaxDC\"  \n\n","truncated":false}}
%---
%[output:7fdd9487]
%   data: {"dataType":"text","outputData":{"text":"\nPrimaryMOSFET - 13 of 145 catalog parts meet 480 V and 105 A (closest first):\n    <strong>Rank<\/strong>        <strong>Manufacturer<\/strong>           <strong>PartNumber<\/strong>        <strong>VoltageRating<\/strong>    <strong>CurrentRating<\/strong>    <strong>VoltageMarginPercent<\/strong>    <strong>CurrentMarginPercent<\/strong>\n    <strong>____<\/strong>    <strong>____________________<\/strong>    <strong>_________________<\/strong>    <strong>_____________<\/strong>    <strong>_____________<\/strong>    <strong>____________________<\/strong>    <strong>____________________<\/strong>\n\n     1      \"STMicroelectronics\"    \"SCTWA90N65G2V-4\"         650              119                35.417                  13.333       \n     2      \"STMicroelectronics\"    \"SCTWA90N65G2V\"           650              119                35.417                  13.333       \n     3      \"Wolfspeed\"             \"C3M0015065D\"             650              120                35.417                  14.286       \n     4      \"Wolfspeed\"             \"C3M0015065K\"             650              120                35.417                  14.286       \n     5      \"Wolfspeed\"             \"E4M0015075K1\"            750              128                 56.25                  21.905       \n\n\nSecondaryMOSFET - 12 of 145 catalog parts meet 480 V and 115 A (closest first):\n    <strong>Rank<\/strong>        <strong>Manufacturer<\/strong>           <strong>PartNumber<\/strong>        <strong>VoltageRating<\/strong>    <strong>CurrentRating<\/strong>    <strong>VoltageMarginPercent<\/strong>    <strong>CurrentMarginPercent<\/strong>\n    <strong>____<\/strong>    <strong>____________________<\/strong>    <strong>_________________<\/strong>    <strong>_____________<\/strong>    <strong>_____________<\/strong>    <strong>____________________<\/strong>    <strong>____________________<\/strong>\n\n     1      \"STMicroelectronics\"    \"SCTWA90N65G2V-4\"         650              119                35.417                  3.4783       \n     2      \"STMicroelectronics\"    \"SCTWA90N65G2V\"           650              119                35.417                  3.4783       \n     3      \"Wolfspeed\"             \"C3M0015065D\"             650              120                35.417                  4.3478       \n     4      \"Wolfspeed\"             \"C3M0015065K\"             650              120                35.417                  4.3478       \n     5      \"Wolfspeed\"             \"E4M0015075K1\"            750              128                 56.25                  11.304       \n\n","truncated":false}}
%---
