%[text] %[text:anchor:T_453a] # Select LLC Resonant Converter Components
%[text] This script helps you select the rating of the primary inverter MOSFET and the secondary rectifier diodes for the `LLCResonantConverterFullBridge` model, and then pick catalog parts that meet those ratings.
%[text:tableOfContents]{"heading":"Table of Contents"}
%[text] ## Semiconductor Device Model
%[text] This design solution uses the Simscape™ MOSFET (Ideal, Switching) library block to model the primary MOSFET device, it provides two levels of model fidelity: thermal and non-thermal. The secondary diode is modeled using either the Simscape™ Foundation Library Diode block or the Simscape Electrical™ library Diode block, which also offers two fidelity levels.
%[text] To estimate switching losses and efficiency, the thermal variants of the MOSFET and tabulated diode blocks must be used. This configuration enables loss and temperature rise analysis of the converter.
%[text] Use the non-thermal variant of the MOSFET and the Foundation Library Diode block to tune the controller and analyze voltage and current across different components. This option gives faster simulation speeds and hence supports exploration of the design space better. To support easy switching between fidelity configurations, Simulink® subsystem reference models are used. You can modify the MOSFET and diode parameters within their respective subsystem reference models.
%[text] ## Select MOSFET and Diode Part
%[text] Select the primary MOSFETs and secondary diodes based on the voltage and peak current ratings required by your converter. Use the `selectDeviceRating` MATLAB® function to determine the appropriate device ratings. To simulate the primary inverter, use the Simscape MOSFET (Ideal, Switching) library block. To model zero-voltage switching (ZVS), add an external drain-to-source parasitic capacitor in parallel with the MOSFET (Ideal, Switching) block.
  %[control:button:1bcd]{"position":[1,2]}
if ~exist('LLCSpec', 'var');LLCConverterDefaultInputParameters; end % Loading the specification data
deviceRating = selectDeviceRating(LLCSpec,SafetyFactor = 1.2,NearestCurrentMultiplier=5,NearestVoltageMultiplier=10,... %[output:group:126ddfaf] %[output:2385574c]
    MagnetizingInductance=simscape.Value(LLCDesign.Lm,"H"),MinOperatingFreq=simscape.Value(frequencyRange.minFreq,"Hz")); %[output:group:126ddfaf] %[output:2385574c]
%%
%[text] ### List the Catalog Parts That Meet the Rating
%[text] Based on the required ratings, you can either use existing parameterized MOSFET (Ideal, Switching) parts or parameterize the block using OEM datasheets and loss table XML files. In this design solution, pre-parameterized parts are used to select suitable MOSFETs and diodes. To select the appropriate MOSFET and Diode part, the `selectConverterParts` function takes the rating table above and lists the Simscape™ catalog parts that match it, with one ranked list per device role. A part qualifies only if it meets or exceeds **both** the voltage and the current rating. Qualifying parts are then ranked by the smallest combined over-margin, so the closest sufficient part comes first and an under-rated part is never listed. If fewer parts qualify than you asked for, the function reports the shortfall rather than padding the list.
  %[control:button:2a1f]{"position":[1,2]}
partTable = selectConverterParts(deviceRating,NumberOfParts=5); %[output:27c35287]
%%
%[text] ### Apply the Selected Part to the Plant
%[text] Set the model and the rank you want from each list above, then click Apply parts to plant model. The `applyConverterPart` function loads the model, applies each part with the Simscape™ part collection API, and writes the matching ideal-fidelity values to the plant block mask. The model is saved after the parts are applied.
%[text] Each part is applied to every device of its role, including devices in inactive variants, so changing the bridge topology later needs no reapply. The part thermal data stays on the device, with the thermal network topology set to external because the plant supplies its own thermal network.
%[text] To apply a part that the lists above do not offer, name its manufacturer and part number instead of a rank, at the MATLAB Command Window, run: 
%[text] ```matlabCodeExample
%[text] applyConverterPart("LLCResonantConverterFullBridge",Manufacturer="Wolfspeed",PartNumber="C3M0025065L")
%[text] ```
modelName = "LLCResonantConverterFullBridge"; % Model the parts are applied to
mosfetPartRank = 1; % Rank to apply from the PrimaryMOSFET list above
diodePartRank = 1;  % Rank to apply from the SecondaryDiode list above
  %[control:button:3b7c]{"position":[1,2]}
%%
%[text] ## LLC Resonant Converter Model
%[text] You can build the power converter model using your designed resonant tank, controller, parameterized MOSFETs, and diodes.
%[text] To open the parameterized LLC converter model, at the MATLAB Command Window, run: 
%[text] ```matlabCodeExample
%[text] open_system("LLCResonantConverterFullBridge");
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
%   data: {"callbackCode":"applyConverterPart(modelName,PartTable=partTable,DeviceRole=[\"PrimaryMOSFET\" \"SecondaryDiode\"],Rank=[mosfetPartRank diodePartRank],SaveModel=true);","label":"Apply parts to plant model","run":"Callback"}
%---
%[output:2385574c]
%   data: {"dataType":"text","outputData":{"text":"                                 <strong>MOSFET and Diode Rating<\/strong>                              \n    <strong>__________________________________________________________________________________<\/strong>\n\n                <strong>Device<\/strong>                <strong>Rating<\/strong>    <strong>Unit<\/strong>            <strong>MetadataField<\/strong>         \n    <strong>______________________________<\/strong>    <strong>______<\/strong>    <strong>____<\/strong>    <strong>______________________________<\/strong>\n                                                                                      \n    Inverter MOSFET voltage rating     480       V      \"VdsMax\"                      \n    Inverter MOSFET current rating      65       A      \"IdsMaxDC\"                    \n    Rectifier Diode voltage rating     480       V      \"RepetitivePeakReverseVoltage\"\n    Rectifier Diode current rating      50       A      \"RatedForwardCurrent\"         \n\n","truncated":false}}
%---
%[output:27c35287]
%   data: {"dataType":"text","outputData":{"text":"\nPrimaryMOSFET - 47 of 145 catalog parts meet 480 V and 65 A (closest first):\n    <strong>Rank<\/strong>    <strong>Manufacturer<\/strong>      <strong>PartNumber<\/strong>      <strong>VoltageRating<\/strong>    <strong>CurrentRating<\/strong>    <strong>VoltageMarginPercent<\/strong>    <strong>CurrentMarginPercent<\/strong>\n    <strong>____<\/strong>    <strong>____________<\/strong>    <strong>______________<\/strong>    <strong>_____________<\/strong>    <strong>_____________<\/strong>    <strong>____________________<\/strong>    <strong>____________________<\/strong>\n\n     1      \"Wolfspeed\"     \"C3M0025065L\"          650              77                 35.417                  18.462       \n     2      \"Wolfspeed\"     \"C3M0025065J1\"         650              80                 35.417                  23.077       \n     3      \"Wolfspeed\"     \"C3M0025075K1\"         750              80                  56.25                  23.077       \n     4      \"Wolfspeed\"     \"E4M0025075K1\"         750              80                  56.25                  23.077       \n     5      \"Wolfspeed\"     \"C3M0025065D\"          650              97                 35.417                  49.231       \n\n\nSecondaryDiode - 5 of 50 catalog parts meet 480 V and 50 A (closest first):\n    <strong>Rank<\/strong>    <strong>Manufacturer<\/strong>      <strong>PartNumber<\/strong>       <strong>VoltageRating<\/strong>    <strong>CurrentRating<\/strong>    <strong>VoltageMarginPercent<\/strong>    <strong>CurrentMarginPercent<\/strong>\n    <strong>____<\/strong>    <strong>____________<\/strong>    <strong>_______________<\/strong>    <strong>_____________<\/strong>    <strong>_____________<\/strong>    <strong>____________________<\/strong>    <strong>____________________<\/strong>\n\n     1       \"Infineon\"     \"IDW50E60\"              600               50                  25                       0         \n     2       \"Infineon\"     \"IDWD50E120D7\"         1200               51                 150                       2         \n     3       \"Infineon\"     \"IDW40G120C5B\"         1200               55                 150                      10         \n     4       \"Infineon\"     \"IDWD100E120D7\"        1200              105                 150                     110         \n     5       \"Infineon\"     \"IDWD120E120D7\"        1200              120                 150                     140         \n\n","truncated":false}}
%---
