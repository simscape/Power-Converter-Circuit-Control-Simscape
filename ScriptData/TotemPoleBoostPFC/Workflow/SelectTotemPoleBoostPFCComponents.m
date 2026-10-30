%[text] %[text:anchor:T_TPsel] # Select Totem-Pole Boost PFC Converter Components
%[text] This script rates the fast-leg and slow-leg semiconductors for the `TotemPoleBoostPFCConverter` model and lists catalog parts that meet those ratings.
%[text:tableOfContents]{"heading":"Table of Contents"}
%[text] ## Semiconductor Device Model
%[text] The fast leg switches at the switching frequency and uses the Simscape™ MOSFET (Ideal, Switching) library block. The slow leg commutates at line frequency. It can be built from a diode, a MOSFET, or a thyristor, selected by the Slow Leg Device mask parameter.
%[text] Switch model fidelity from the plant block mask: Totem-Pole Boost PFC Model Option selects the Simplified or Detailed power stage. Fast Leg Device, MOSFET Device, and Diode Device select the ideal or the detailed device in each position. The ideal options take their parameters from the plant mask; the detailed devices take theirs from the applied catalog part.
%[text] ## Select Fast-Leg and Slow-Leg Devices
%[text] Choose how the slow leg is built. To determine the required device ratings, use the `selectTotemPoleDeviceRating` function. Set Slow Leg Device on the plant block mask to the same choice.
%[text] The function rates each device at every AC input voltage in your specification. MOSFETs are rated on RMS current and diodes and thyristors on average current, to match their datasheet current limits.
  %[control:button:1b4e]{"position":[1,2]}
if ~exist('totemPoleSpec','var') || ~exist('totemPoleDesign','var');TotemPoleBoostPFCDefaultInputParameters; end
slowLegDevice = "MOSFET"; % How the slow leg is built %[control:dropdown:4e7b]{"position":[17,25]}
deviceRating = selectTotemPoleDeviceRating(totemPoleSpec,SlowLegDevice = slowLegDevice,Design = totemPoleDesign,... %[output:group:4b2f9d10] %[output:7a1c4e30]
    SafetyFactor = 1.2,NearestCurrentMultiplier = 5,NearestVoltageMultiplier = 10); %[output:group:4b2f9d10] %[output:7a1c4e30]
%%
%[text] ### List the Catalog Parts That Meet the Rating
%[text] The `selectConverterParts` function lists the Simscape™ catalog parts that meet the ratings above, with one ranked list per device role. A part qualifies only if it meets or exceeds both ratings, and the qualifying parts are ranked closest-first by the smallest combined over-margin. The ranking measures rating fit, not loss, so compare `Rds` or `Vf` across the top ranks before you choose.
%[text] No thyristor part collection ships with Simscape Electrical™, so a thyristor slow leg is rated but not listed. Select that device from a vendor datasheet.
  %[control:button:2c5f]{"position":[1,2]}
partTable = selectConverterParts(deviceRating,NumberOfParts=5); %[output:3e8d5a21]
%%
%[text] ### Apply the Selected Part to the Plant
%[text] Set the model and the rank you want from each list above, then click **Apply parts to plant model**. The `applyConverterPart` function loads the model and applies each part with the Simscape™ part collection API. It also writes the matching ideal-fidelity values to the plant block mask. The model is saved after the parts are applied.
%[text] Each part is applied to both devices of its own leg, including devices in inactive variants, so changing the model option later needs no reapply.
%[text] To apply a part that the lists above do not offer, name its manufacturer and part number instead of a rank. Both legs can be MOSFETs and share one catalog, so name the device role as well. In the MATLAB Command Window, enter:
%[text] ```matlabCodeExample
%[text] applyConverterPart("TotemPoleBoostPFCConverter",DeviceRole="FastLegMOSFET",Manufacturer="Wolfspeed",PartNumber="C3M0120065J")
%[text] ```
modelName = "TotemPoleBoostPFCConverter"; % Model the parts are applied to
fastLegMOSFETPartRank = 1; % Rank to apply from the FastLegMOSFET list above
slowLegDevicePartRank = 1; % Rank to apply from the slow-leg list above
% Device roles in the order the rating table lists them - fast leg, then whichever
% slow-leg role the choice above selected. A role with no catalog list is dropped, so
% a thyristor slow leg applies the fast-leg part and leaves the slow leg untouched.
applyDeviceRole = unique(deviceRating.DeviceRole,'stable');
applyPartRank = [fastLegMOSFETPartRank; slowLegDevicePartRank];
isPartListed = ismember(applyDeviceRole,partTable.DeviceRole);
  %[control:button:3d6a]{"position":[1,2]}
%%
%[text] ## Totem-Pole Boost PFC Converter Model
%[text] You can build the power converter model using your designed power stage, controller, and the parameterized fast-leg and slow-leg devices.
%[text] To open the parameterized model, enter this command in the MATLAB Command Window:
%[text] ```matlabCodeExample
%[text] open_system("TotemPoleBoostPFCConverter");
%[text] ```
%%
%[text] %[text:anchor:TMP_TPsel] Copyright 2026 The MathWorks, Inc.

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":27.8}
%---
%[control:button:1b4e]
%   data: {"label":"Estimate device rating","run":"Section"}
%---
%[control:dropdown:4e7b]
%   data: {"defaultValue":"\"Diode\"","itemLabels":["Diode","MOSFET","Thyristor"],"items":["\"Diode\"","\"MOSFET\"","\"Thyristor\""],"label":"Slow leg device","run":"Section"}
%---
%[control:button:2c5f]
%   data: {"label":"List candidate parts","run":"Section"}
%---
%[control:button:3d6a]
%   data: {"callbackCode":"applyConverterPart(modelName,PartTable=partTable,DeviceRole=applyDeviceRole(isPartListed),Rank=applyPartRank(isPartListed),SaveModel=true);","label":"Apply parts to plant model","run":"Callback"}
%---
%[output:7a1c4e30]
%   data: {"dataType":"text","outputData":{"text":"                 <strong>Fast-Leg and Slow-Leg (MOSFET) Device Rating<\/strong>              \n    <strong>_______________________________________________________________________<\/strong>\n\n                   <strong>Device<\/strong>                   <strong>Rating<\/strong>    <strong>Unit<\/strong>    <strong>MetadataField<\/strong>\n    <strong>____________________________________<\/strong>    <strong>______<\/strong>    <strong>____<\/strong>    <strong>_____________<\/strong>\n                                                                           \n    Fast-leg MOSFET voltage rating           520       V       \"VdsMax\"    \n    Fast-leg MOSFET current rating (RMS)      15       A       \"IdsMaxDC\"  \n    Slow-leg MOSFET voltage rating           520       V       \"VdsMax\"    \n    Slow-leg MOSFET current rating (RMS)      15       A       \"IdsMaxDC\"  \n\n","truncated":false}}
%---
%[output:3e8d5a21]
%   data: {"dataType":"text","outputData":{"text":"\nFastLegMOSFET - 131 of 145 catalog parts meet 520 V and 15 A (closest first):\n    <strong>Rank<\/strong>    <strong>Manufacturer<\/strong>     <strong>PartNumber<\/strong>      <strong>VoltageRating<\/strong>    <strong>CurrentRating<\/strong>    <strong>VoltageMarginPercent<\/strong>    <strong>CurrentMarginPercent<\/strong>\n    <strong>____<\/strong>    <strong>____________<\/strong>    <strong>_____________<\/strong>    <strong>_____________<\/strong>    <strong>_____________<\/strong>    <strong>____________________<\/strong>    <strong>____________________<\/strong>\n\n     1      \"Wolfspeed\"     \"C3M0120065J\"         650              21                   25                        40       \n     2      \"Wolfspeed\"     \"C3M0120065L\"         650              21                   25                        40       \n     3      \"Wolfspeed\"     \"C3M0120065D\"         650              22                   25                    46.667       \n     4      \"Wolfspeed\"     \"C3M0120065K\"         650              22                   25                    46.667       \n     5      \"Wolfspeed\"     \"C3M0060065D\"         650              29                   25                    93.333       \n\n\nSlowLegDiode - 21 of 50 catalog parts meet 520 V and 10 A (closest first):\n    <strong>Rank<\/strong>        <strong>Manufacturer<\/strong>          <strong>PartNumber<\/strong>       <strong>VoltageRating<\/strong>    <strong>CurrentRating<\/strong>    <strong>VoltageMarginPercent<\/strong>    <strong>CurrentMarginPercent<\/strong>\n    <strong>____<\/strong>    <strong>____________________<\/strong>    <strong>_______________<\/strong>    <strong>_____________<\/strong>    <strong>_____________<\/strong>    <strong>____________________<\/strong>    <strong>____________________<\/strong>\n\n     1      \"Infineon\"              \"AIDK10S65C5\"           650              10                   25                       0         \n     2      \"STMicroelectronics\"    \"STPSC10065\"            650              10                   25                       0         \n     3      \"STMicroelectronics\"    \"STPSC10H065BY\"         650              10                   25                       0         \n     4      \"STMicroelectronics\"    \"STPSC10H065\"           650              10                   25                       0         \n     5      \"Infineon\"              \"AIDK12S65C5\"           650              12                   25                      20         \n\n","truncated":false}}
%---
