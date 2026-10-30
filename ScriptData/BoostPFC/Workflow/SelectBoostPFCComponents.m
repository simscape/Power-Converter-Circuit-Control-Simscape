%[text] %[text:anchor:T_BPsel] # Select Boost PFC Converter Components
%[text] This script rates the boost-leg and rectifier-bridge semiconductors of the `BoostPFCConverter` model against the sized power stage. It then lists and applies the catalog parts that meet those ratings.
%[text:tableOfContents]{"heading":"Table of Contents"}
%[text] ## Semiconductor Device Model
%[text] The boost MOSFET and boost diode switch at the switching frequency and stand off the DC bus, so they set the switching loss. The four bridge diodes commutate at line frequency and are clamped to the line peak, so they are rated lower.
%[text] Device fidelity comes from the plant block mask: **Boost PFC model option** selects the **Simplified** or **Detailed** power stage. **Switch model**, **Diode model** and **Rectifier diode model** select the ideal or the detailed device in each position.
%[text] The ideal options take their parameters from the plant mask; the detailed devices take theirs from the applied catalog part.
%%
%[text] ## Select Boost-Leg and Bridge Devices
%[text] To get the rating each device position must meet, use the `selectBoostPFCDeviceRating` function. The sized design ratings are already worst case at minimum line.
%[text] The MOSFET is rated on RMS current and both diode positions on average current.
  %[control:button:4a1c]{"position":[1,2]}
if ~exist('boostPFCSpec','var') || ~exist('boostPFCDesign','var');BoostPFCDefaultInputParameters; end % Load defaults
deviceRating = selectBoostPFCDeviceRating(boostPFCSpec,Design = boostPFCDesign,... %[output:group:05e84b61] %[output:04e849ce]
    SafetyFactor = 1.2,NearestCurrentMultiplier = 1,NearestVoltageMultiplier = 10); % 1 A steps, positions ~1 A apart %[output:group:05e84b61] %[output:04e849ce]
%%
%[text] ### List the Catalog Parts That Meet the Rating
%[text] The `selectConverterParts` function lists the Simscape™ catalog parts that meet both ratings, one list per device role, ranked by the smallest combined over-margin.
%[text] The ranking measures rating fit, not loss, so compare `Rds` or `Vf` across the top ranks before you choose.
%[text] At this power level, the lowest catalog voltage class of 1200 V meets the 520 V requirement, so current alone decides the ranking.
  %[control:button:5b2d]{"position":[1,2]}
partTable = selectConverterParts(deviceRating,NumberOfParts=5); %[output:e34c3ea9]
%%
%[text] ### Apply the Selected Part to the Plant
%[text] Set the model and the rank you want from each list, then click **Apply parts to plant model**. The `applyConverterPart` function applies each part to the model with the Simscape™ part collection API. It also writes the matching ideal-fidelity values to the plant block mask. The model is saved after the parts are applied.
%[text] Each part is applied to every device in its position, including inactive variants, so a later model option change needs no reapply.
%[text] To apply a part that the lists above do not offer, name its manufacturer and part number instead of a rank. Both diode positions share one catalog, so name the device role as well. In the MATLAB Command Window, enter:
%[text] ```matlabCodeExample
%[text] applyConverterPart("BoostPFCConverter",DeviceRole="BoostDiode",Manufacturer="Infineon",PartNumber="IDD04SG60C")
%[text] ```
modelName = "BoostPFCConverter"; % Model the parts are applied to
boostMOSFETPartRank    = 1; % Rank to apply from the BoostMOSFET list above
boostDiodePartRank     = 1; % Rank to apply from the BoostDiode list above
rectifierDiodePartRank = 1; % Rank to apply from the RectifierDiode list above
% Device roles in the order the rating table lists them. A role that no catalog part
% meets is dropped and its position is left unchanged.
applyDeviceRole = unique(deviceRating.DeviceRole,'stable');
applyPartRank = [boostMOSFETPartRank; boostDiodePartRank; rectifierDiodePartRank];
isPartListed = ismember(applyDeviceRole,partTable.DeviceRole);
  %[control:button:6c3e]{"position":[1,2]}
%%
%[text] ## Boost PFC Converter Model
%[text] The power converter model uses the designed power stage, the controller, and the parameterized boost-leg and bridge devices.
%[text] To open the parameterized boost PFC converter model, in the MATLAB Command Window, enter:
%[text] ```matlabCodeExample
%[text] open_system("BoostPFCConverter");
%[text] ```
%%
%[text] %[text:anchor:TMP_BPsel] Copyright 2026 The MathWorks, Inc.

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":27.8}
%---
%[control:button:4a1c]
%   data: {"label":"Estimate device rating","run":"Section"}
%---
%[control:button:5b2d]
%   data: {"label":"List candidate parts","run":"Section"}
%---
%[control:button:6c3e]
%   data: {"callbackCode":"applyConverterPart(modelName,PartTable=partTable,DeviceRole=applyDeviceRole(isPartListed),Rank=applyPartRank(isPartListed),SaveModel=true);","label":"Apply parts to plant model","run":"Callback"}
%---
%[output:04e849ce]
%   data: {"dataType":"text","outputData":{"text":"                         <strong>Boost PFC Device Rating at Minimum line voltage<\/strong>                     \n    <strong>_________________________________________________________________________________________<\/strong>\n\n                   <strong>Device<\/strong>                    <strong>Rating<\/strong>    <strong>Unit<\/strong>            <strong>MetadataField<\/strong>         \n    <strong>_____________________________________<\/strong>    <strong>______<\/strong>    <strong>____<\/strong>    <strong>______________________________<\/strong>\n                                                                                             \n    Boost MOSFET voltage rating               520       V      \"VdsMax\"                      \n    Boost MOSFET current rating (RMS)           4       A      \"IdsMaxDC\"                    \n    Boost diode voltage rating                520       V      \"RepetitivePeakReverseVoltage\"\n    Boost diode current rating (average)        3       A      \"RatedForwardCurrent\"         \n    Bridge diode voltage rating               490       V      \"RepetitivePeakReverseVoltage\"\n    Bridge diode current rating (average)       3       A      \"RatedForwardCurrent\"         \n\n","truncated":false}}
%---
%[output:e34c3ea9]
%   data: {"dataType":"text","outputData":{"text":"\nBoostMOSFET - 145 of 145 catalog parts meet 520 V and 4 A (closest first):\n    <strong>Rank<\/strong>    <strong>Manufacturer<\/strong>      <strong>PartNumber<\/strong>       <strong>VoltageRating<\/strong>    <strong>CurrentRating<\/strong>    <strong>VoltageMarginPercent<\/strong>    <strong>CurrentMarginPercent<\/strong>\n    <strong>____<\/strong>    <strong>____________<\/strong>    <strong>_______________<\/strong>    <strong>_____________<\/strong>    <strong>_____________<\/strong>    <strong>____________________<\/strong>    <strong>____________________<\/strong>\n\n     1      \"Infineon\"      \"IMW120R350M1H\"        1200              4.7                130.77                   17.5        \n     2      \"Infineon\"      \"IMZ120R350M1H\"        1200              4.7                130.77                   17.5        \n     3      \"Wolfspeed\"     \"C3M0350120J\"          1200              7.2                130.77                     80        \n     4      \"Wolfspeed\"     \"C3M0350120D\"          1200              7.6                130.77                     90        \n     5      \"Wolfspeed\"     \"C3M0280090D\"           900             10.2                73.077                    155        \n\n\nBoostDiode - 25 of 50 catalog parts meet 520 V and 3 A (closest first):\n    <strong>Rank<\/strong>        <strong>Manufacturer<\/strong>         <strong>PartNumber<\/strong>      <strong>VoltageRating<\/strong>    <strong>CurrentRating<\/strong>    <strong>VoltageMarginPercent<\/strong>    <strong>CurrentMarginPercent<\/strong>\n    <strong>____<\/strong>    <strong>____________________<\/strong>    <strong>_____________<\/strong>    <strong>_____________<\/strong>    <strong>_____________<\/strong>    <strong>____________________<\/strong>    <strong>____________________<\/strong>\n\n     1      \"Infineon\"              \"IDD04SG60C\"          600               4                 15.385                  33.333       \n     2      \"Infineon\"              \"IDP08E65D1\"          650               8                     25                  166.67       \n     3      \"STMicroelectronics\"    \"STPSC8065\"           650               8                     25                  166.67       \n     4      \"STMicroelectronics\"    \"STPSC8H065\"          650               8                     25                  166.67       \n     5      \"Infineon\"              \"AIDK10S65C5\"         650              10                     25                  233.33       \n\n\nRectifierDiode - 25 of 50 catalog parts meet 490 V and 3 A (closest first):\n    <strong>Rank<\/strong>        <strong>Manufacturer<\/strong>         <strong>PartNumber<\/strong>      <strong>VoltageRating<\/strong>    <strong>CurrentRating<\/strong>    <strong>VoltageMarginPercent<\/strong>    <strong>CurrentMarginPercent<\/strong>\n    <strong>____<\/strong>    <strong>____________________<\/strong>    <strong>_____________<\/strong>    <strong>_____________<\/strong>    <strong>_____________<\/strong>    <strong>____________________<\/strong>    <strong>____________________<\/strong>\n\n     1      \"Infineon\"              \"IDD04SG60C\"          600               4                 22.449                  33.333       \n     2      \"Infineon\"              \"IDP08E65D1\"          650               8                 32.653                  166.67       \n     3      \"STMicroelectronics\"    \"STPSC8065\"           650               8                 32.653                  166.67       \n     4      \"STMicroelectronics\"    \"STPSC8H065\"          650               8                 32.653                  166.67       \n     5      \"Infineon\"              \"AIDK10S65C5\"         650              10                 32.653                  233.33       \n\n","truncated":false}}
%---
