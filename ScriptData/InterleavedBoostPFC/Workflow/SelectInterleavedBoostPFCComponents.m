%[text] %[text:anchor:T_IPsel] # Select Interleaved Boost PFC Converter Components
%[text] This script rates the boost-leg and rectifier-bridge semiconductors of the `InterleavedBoostPFCConverter` model against the sized power stage. It then lists and applies the catalog parts that meet those ratings.
%[text:tableOfContents]{"heading":"Table of Contents"}
%[text] ## Semiconductor Device Model
%[text] Every leg spans the full DC bus, so interleaving splits the current but not the voltage: the per-leg **boost MOSFET** and **boost diode** keep a single-leg voltage rating while their current rating falls with the number of legs.
%[text] The four **bridge diodes** sit before the split, so they carry the whole line current and gain nothing from interleaving. They commutate at line frequency and are clamped to the line peak, never the bus.
%[text] Device fidelity comes from the plant block mask: **Interleaved Boost PFC model option** selects the **Simplified** or **Detailed** power stage. **Switch model**, **Diode model** and **Rectifier diode model** select the ideal or the detailed device in each position.
%[text] The ideal options take their parameters from the plant mask; the detailed devices take theirs from the applied catalog part.
%%
%[text] ## Select Boost-Leg and Bridge Devices
%[text] To get the rating each device position must meet, use the `selectInterleavedBoostPFCDeviceRating` function. It reads the sized design, whose ratings are already worst case at minimum line rather than nominal.
%[text] Each device is rated on what its datasheet limit means: the MOSFET on RMS current, both diode positions on average current. The per-leg rows already carry the current split, so at 2 kW and two legs the bridge diodes rate above the boost diodes.
  %[control:button:7d4f]{"position":[1,2]}
if ~exist('interleavedSpec','var') || ~exist('interleavedDesign','var');InterleavedBoostPFCDefaultInputParameters; end
deviceRating = selectInterleavedBoostPFCDeviceRating(interleavedSpec,Design = interleavedDesign,... %[output:group:f035111d] %[output:ef350f8a]
    SafetyFactor = 1.2,NearestCurrentMultiplier = 1,NearestVoltageMultiplier = 10); % 1 A steps; leg vs bridge ~2 A %[output:group:f035111d] %[output:ef350f8a]
%%
%[text] ### List the Catalog Parts That Meet the Rating
%[text] The `selectConverterParts` function lists the Simscape™ catalog parts that meet both ratings, one list per device role, ranked closest-first by the smallest combined over-margin.
%[text] The ranking measures rating fit, not loss, so compare `Rds` or `Vf` across the top ranks before you choose.
%[text] At this power level every catalog MOSFET qualifies: its lowest voltage class is 1200 V against a 520 V requirement. The ranking is therefore decided by current alone.
  %[control:button:8e5a]{"position":[1,2]}
partTable = selectConverterParts(deviceRating,NumberOfParts=5); %[output:4d99cde5]
%%
%[text] ### Apply the Selected Part to the Plant
%[text] Set the model and the rank you want from each list, then click **Apply parts to plant model**. The `applyConverterPart` function applies each part to the model with the Simscape™ part collection API. It also writes the matching ideal-fidelity values to the plant block mask. The model is saved after the parts are applied.
%[text] One part per role is applied to every leg, and to inactive variants as well. The legs stay identical and changing the model option later needs no reapply.
%[text] To apply a part that the lists above do not offer, name its manufacturer and part number instead of a rank. Both diode positions share one catalog, so name the device role as well. At the MATLAB Command Window, run:
%[text] ```matlabCodeExample
%[text] applyConverterPart("InterleavedBoostPFCConverter",DeviceRole="BoostDiode",Manufacturer="Infineon",PartNumber="IDD04SG60C")
%[text] ```
modelName = "InterleavedBoostPFCConverter"; % Model the parts are applied to
boostMOSFETPartRank    = 1; % Rank to apply from the BoostMOSFET list above, applied to both legs
boostDiodePartRank     = 1; % Rank to apply from the BoostDiode list above, applied to both legs
rectifierDiodePartRank = 1; % Rank to apply from the RectifierDiode list above
% Device roles in the order the rating table lists them. A role that no catalog part
% meets is dropped, so that position is left untouched instead of raising an error.
applyDeviceRole = unique(deviceRating.DeviceRole,'stable');
applyPartRank = [boostMOSFETPartRank; boostDiodePartRank; rectifierDiodePartRank];
isPartListed = ismember(applyDeviceRole,partTable.DeviceRole);
  %[control:button:9f6b]{"position":[1,2]}
%%
%[text] ## Interleaved Boost PFC Converter Model
%[text] You can build the power converter model using your designed power stage, controller, and the parameterized boost-leg and bridge devices.
%[text] To open the parameterized interleaved boost PFC converter model, at the MATLAB Command Window, run:
%[text] ```matlabCodeExample
%[text] open_system("InterleavedBoostPFCConverter");
%[text] ```
%%
%[text] %[text:anchor:TMP_IPsel] Copyright 2026 The MathWorks, Inc.

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":27.8}
%---
%[control:button:7d4f]
%   data: {"label":"Estimate device rating","run":"Section"}
%---
%[control:button:8e5a]
%   data: {"label":"List candidate parts","run":"Section"}
%---
%[control:button:9f6b]
%   data: {"callbackCode":"applyConverterPart(modelName,PartTable=partTable,DeviceRole=applyDeviceRole(isPartListed),Rank=applyPartRank(isPartListed),SaveModel=true);","label":"Apply parts to plant model","run":"Callback"}
%---
%[output:ef350f8a]
%   data: {"dataType":"text","outputData":{"text":"                    <strong>2-Leg Interleaved Boost PFC Device Rating at Minimum line voltage<\/strong>                \n    <strong>_________________________________________________________________________________________________<\/strong>\n\n                       <strong>Device<\/strong>                        <strong>Rating<\/strong>    <strong>Unit<\/strong>            <strong>MetadataField<\/strong>         \n    <strong>_____________________________________________<\/strong>    <strong>______<\/strong>    <strong>____<\/strong>    <strong>______________________________<\/strong>\n                                                                                                     \n    Boost MOSFET voltage rating (per leg)             520       V      \"VdsMax\"                      \n    Boost MOSFET current rating (RMS, per leg)          4       A      \"IdsMaxDC\"                    \n    Boost diode voltage rating (per leg)              520       V      \"RepetitivePeakReverseVoltage\"\n    Boost diode current rating (average, per leg)       3       A      \"RatedForwardCurrent\"         \n    Bridge diode voltage rating                       490       V      \"RepetitivePeakReverseVoltage\"\n    Bridge diode current rating (average)               6       A      \"RatedForwardCurrent\"         \n\n","truncated":false}}
%---
%[output:4d99cde5]
%   data: {"dataType":"text","outputData":{"text":"\nBoostMOSFET - 145 of 145 catalog parts meet 520 V and 4 A (closest first):\n    <strong>Rank<\/strong>    <strong>Manufacturer<\/strong>      <strong>PartNumber<\/strong>       <strong>VoltageRating<\/strong>    <strong>CurrentRating<\/strong>    <strong>VoltageMarginPercent<\/strong>    <strong>CurrentMarginPercent<\/strong>\n    <strong>____<\/strong>    <strong>____________<\/strong>    <strong>_______________<\/strong>    <strong>_____________<\/strong>    <strong>_____________<\/strong>    <strong>____________________<\/strong>    <strong>____________________<\/strong>\n\n     1      \"Infineon\"      \"IMW120R350M1H\"        1200              4.7                130.77                   17.5        \n     2      \"Infineon\"      \"IMZ120R350M1H\"        1200              4.7                130.77                   17.5        \n     3      \"Wolfspeed\"     \"C3M0350120J\"          1200              7.2                130.77                     80        \n     4      \"Wolfspeed\"     \"C3M0350120D\"          1200              7.6                130.77                     90        \n     5      \"Wolfspeed\"     \"C3M0280090D\"           900             10.2                73.077                    155        \n\n\nBoostDiode - 25 of 50 catalog parts meet 520 V and 3 A (closest first):\n    <strong>Rank<\/strong>        <strong>Manufacturer<\/strong>         <strong>PartNumber<\/strong>      <strong>VoltageRating<\/strong>    <strong>CurrentRating<\/strong>    <strong>VoltageMarginPercent<\/strong>    <strong>CurrentMarginPercent<\/strong>\n    <strong>____<\/strong>    <strong>____________________<\/strong>    <strong>_____________<\/strong>    <strong>_____________<\/strong>    <strong>_____________<\/strong>    <strong>____________________<\/strong>    <strong>____________________<\/strong>\n\n     1      \"Infineon\"              \"IDD04SG60C\"          600               4                 15.385                  33.333       \n     2      \"Infineon\"              \"IDP08E65D1\"          650               8                     25                  166.67       \n     3      \"STMicroelectronics\"    \"STPSC8065\"           650               8                     25                  166.67       \n     4      \"STMicroelectronics\"    \"STPSC8H065\"          650               8                     25                  166.67       \n     5      \"Infineon\"              \"AIDK10S65C5\"         650              10                     25                  233.33       \n\n\nRectifierDiode - 24 of 50 catalog parts meet 490 V and 6 A (closest first):\n    <strong>Rank<\/strong>        <strong>Manufacturer<\/strong>         <strong>PartNumber<\/strong>      <strong>VoltageRating<\/strong>    <strong>CurrentRating<\/strong>    <strong>VoltageMarginPercent<\/strong>    <strong>CurrentMarginPercent<\/strong>\n    <strong>____<\/strong>    <strong>____________________<\/strong>    <strong>_____________<\/strong>    <strong>_____________<\/strong>    <strong>_____________<\/strong>    <strong>____________________<\/strong>    <strong>____________________<\/strong>\n\n     1      \"Infineon\"              \"IDP08E65D1\"          650               8                 32.653                  33.333       \n     2      \"STMicroelectronics\"    \"STPSC8065\"           650               8                 32.653                  33.333       \n     3      \"STMicroelectronics\"    \"STPSC8H065\"          650               8                 32.653                  33.333       \n     4      \"Infineon\"              \"AIDK10S65C5\"         650              10                 32.653                  66.667       \n     5      \"STMicroelectronics\"    \"STPSC10065\"          650              10                 32.653                  66.667       \n\n","truncated":false}}
%---
