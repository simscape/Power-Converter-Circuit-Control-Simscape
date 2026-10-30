%[text] %[text:anchor:T_NIDsel] # Select Non-Isolated DC-DC Converter Components
%[text] This script helps you select the voltage and current ratings of the semiconductors for the `NonIsolatedDCDCConverter` model. It then helps you pick catalog parts that meet those ratings.
%[text:tableOfContents]{"heading":"Table of Contents"}
%[text] ## Semiconductor Device Model
%[text] The plant block mask **Topology** parameter selects one of six power stages: **Buck**, **Boost**, and **Buck-Boost**, each with a diode in the second device position, and their **Synchronous** counterparts, which replace that diode with a second MOSFET.
%[text] Switch model fidelity from the plant block mask: **Main switch device** selects the ideal or the detailed MOSFET, and **Diode device** does the same for the diode. The ideal options take their parameters from the plant mask; the detailed devices take theirs from the applied catalog part. Applying a part below writes both, so the two fidelities stay consistent.
%[text] ## Select the Device Ratings
%[text] To determine the device ratings for the specified topology, use the `selectNonIsolatedDCDCDeviceRating` function. Set **Topology** on the plant block mask to the same choice.
%[text] The function reads the device rating from your sized design, which uses the worst case over the input range. For a boost, that is minimum input, where rated power is drawn at the lowest voltage.
%[text] Each device is rated on what its datasheet limit means: a MOSFET's `IdsMaxDC` is a continuous limit, so RMS current; a diode's `RatedForwardCurrent` is an IF(AV) limit, so average current.
%[text] The topology sets how many device roles you get. A synchronous topology has one: the plant carries a single **RdsOn**, **GdsOff** and **Vth** triple shared by both switches, so both take the same part, rated at whichever works harder. A non-synchronous topology has two, the main switch and the freewheeling diode.
%[text] For a different topology, change `nonIsolatedDCDCSpec.topology` in the [Estimate Non-Isolated DC-DC Converter Parameters](matlab:edit('EstimateNonIsolatedDCDCParameters.m')) script and re-run it. That changes the sizing as well as the ratings, so the output voltage must stay reachable.
  %[control:button:2a71]{"position":[1,2]}
if ~exist('nonIsolatedDCDCSpec','var') || ~exist('nonIsolatedDCDCDesign','var');NonIsolatedDCDCDefaultInputParameters; end % Loading the specification data
deviceRating = selectNonIsolatedDCDCDeviceRating(nonIsolatedDCDCSpec,Design = nonIsolatedDCDCDesign,... %[output:group:ecd3ecca] %[output:edd3ee5d]
    SafetyFactor = 1.2,NearestCurrentMultiplier = 1,NearestVoltageMultiplier = 10); %[output:group:ecd3ecca] %[output:edd3ee5d]
%%
%[text] ### List the Catalog Parts That Meet the Rating
%[text] The `selectConverterParts` function lists the Simscape™ catalog parts that meet both ratings, one ranked list per device role, ranked closest-first by the smallest combined over-margin.
%[text] The ranking measures rating fit, not loss. The MOSFET catalog is dominated by 900 V and 1200 V silicon-carbide devices. The closest part to a 520 V requirement therefore still carries a large voltage margin. On-resistance can differ several-fold at the same margin. Compare `Rds` or `Vf` across the top ranks before you choose.
  %[control:button:5c93]{"position":[1,2]}
partTable = selectConverterParts(deviceRating,NumberOfParts=5); %[output:714b95e2]
%%
%[text] ### Apply the Selected Part to the Plant
%[text] Set the model and the rank you want from each list, then click **Apply parts to plant model**. The `applyConverterPart` function applies each part to the model with the Simscape™ part collection API. It also writes the matching ideal-fidelity values to the plant block mask. The model is saved after the parts are applied.
%[text] Each part is applied to every block position of its own role across all six topology branches, including the inactive ones. Changing **Topology** later therefore needs no reapply.
%[text] To apply a part the lists do not offer, name its manufacturer and part number instead of a rank. Name the device role as well. In the MATLAB Command Window, run:
%[text] ```matlabCodeExample
%[text] applyConverterPart("NonIsolatedDCDCConverter",DeviceRole="SwitchMOSFET",Manufacturer="Wolfspeed",PartNumber="C3M0060065D")
%[text] ```
modelName = "NonIsolatedDCDCConverter"; % Model the parts are applied to
switchMOSFETPartRank  = 1; % Rank to apply from the SwitchMOSFET list above
freewheelDiodePartRank = 1; % Rank to apply from the FreewheelDiode list above
% Device roles in the order the rating table lists them - the switch first, then the
% freewheeling diode if the topology has one. A synchronous topology lists one role, so
% the rank vector is trimmed to match rather than assuming two.
applyDeviceRole = unique(deviceRating.DeviceRole,'stable');
applyPartRank = [switchMOSFETPartRank; freewheelDiodePartRank];
applyPartRank = applyPartRank(1:numel(applyDeviceRole));
% A role whose catalog list came back empty is dropped, so the parts that were found
% are still applied instead of the whole click failing.
isPartListed = ismember(applyDeviceRole,partTable.DeviceRole);
  %[control:button:8f24]{"position":[1,2]}
%%
%[text] ## Non-Isolated DC-DC Converter Model
%[text] You can build the power converter model using your designed power stage, controller, and the parameterized switch and diode devices.
%[text] To open the parameterized non-isolated DC-DC converter model, in the MATLAB Command Window, run:
%[text] ```matlabCodeExample
%[text] open_system("NonIsolatedDCDCConverter");
%[text] ```
%%
%[text] %[text:anchor:TMP_NIDsel] Copyright 2026 The MathWorks, Inc.

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":27.8}
%---
%[control:button:2a71]
%   data: {"label":"Estimate device rating","run":"Section"}
%---
%[control:button:5c93]
%   data: {"label":"List candidate parts","run":"Section"}
%---
%[control:button:8f24]
%   data: {"callbackCode":"applyConverterPart(modelName,PartTable=partTable,DeviceRole=applyDeviceRole(isPartListed),Rank=applyPartRank(isPartListed),SaveModel=true);","label":"Apply parts to plant model","run":"Callback"}
%---
%[output:edd3ee5d]
%   data: {"dataType":"text","outputData":{"text":"                                 <strong>Synchronous Boost Device Rating<\/strong>                              \n    <strong>__________________________________________________________________________________________<\/strong>\n\n                            <strong>Device<\/strong>                             <strong>Rating<\/strong>    <strong>Unit<\/strong>    <strong>MetadataField<\/strong>\n    <strong>_______________________________________________________<\/strong>    <strong>______<\/strong>    <strong>____<\/strong>    <strong>_____________<\/strong>\n                                                                                              \n    Main and synchronous switch MOSFET voltage rating           520       V       \"VdsMax\"    \n    Main and synchronous switch MOSFET current rating (RMS)       8       A       \"IdsMaxDC\"  \n\n","truncated":false}}
%---
%[output:714b95e2]
%   data: {"dataType":"text","outputData":{"text":"\nSwitchMOSFET - 139 of 145 catalog parts meet 520 V and 8 A (closest first):\n    <strong>Rank<\/strong>        <strong>Manufacturer<\/strong>         <strong>PartNumber<\/strong>      <strong>VoltageRating<\/strong>    <strong>CurrentRating<\/strong>    <strong>VoltageMarginPercent<\/strong>    <strong>CurrentMarginPercent<\/strong>\n    <strong>____<\/strong>    <strong>____________________<\/strong>    <strong>_____________<\/strong>    <strong>_____________<\/strong>    <strong>_____________<\/strong>    <strong>____________________<\/strong>    <strong>____________________<\/strong>\n\n     1      \"Wolfspeed\"             \"C3M0280090D\"         900             10.2                73.077                   27.5        \n     2      \"Wolfspeed\"             \"C3M0280090J\"         900               11                73.077                   37.5        \n     3      \"Wolfspeed\"             \"E3M0280090D\"         900             11.5                73.077                  43.75        \n     4      \"Wolfspeed\"             \"C2M0280120D\"        1200               11                130.77                   37.5        \n     5      \"STMicroelectronics\"    \"SCT10N120\"          1200               12                130.77                     50        \n\n","truncated":false}}
%---
