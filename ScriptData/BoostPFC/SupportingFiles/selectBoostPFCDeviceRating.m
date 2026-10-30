function deviceRating = selectBoostPFCDeviceRating(boostPFCSpec, options)
%SELECTBOOSTPFCDEVICERATING Voltage and current ratings for the boost PFC devices.
%
%   deviceRating = selectBoostPFCDeviceRating(boostPFCSpec, Name=Value) returns the blocking
%   voltage and the continuous current a real semiconductor must be rated for, in each of the
%   three device positions. This is step 1 of rating -> selectConverterParts ->
%   applyConverterPart. The switch and the boost diode block the DC bus, while the input
%   rectifier blocks the line peak. The current statistic follows the field a datasheet
%   quotes: RMS for the MOSFET, average for either diode.
%
%   Inputs:
%     boostPFCSpec  Converter specification: the AC input range, the bus voltage, the power
%                   level and the device voltage margin.
%
%   Name-value options:
%     Design                    Design structure from designBoostPFCConverter, to save
%                               re-running it. Default: computed here.
%     SafetyFactor              Current derating factor. Default 1.2.
%     VoltageSafetyFactor       Voltage derating factor. Default NaN, which takes the
%                               specification's own deviceVoltageMargin.
%     NearestVoltageMultiplier  Voltage ratings round up to this multiple (V). Default 10.
%     NearestCurrentMultiplier  Current ratings round up to this multiple (A). Default 1.
%
%   Outputs:
%     deviceRating  Table of Device, Rating, Unit, MetadataField, DeviceRole and
%                   ModelingEntityId, two rows per device role.
%
%   Example:
%     BoostPFCDefaultInputParameters;
%     deviceRating = selectBoostPFCDeviceRating(boostPFCSpec, Design=boostPFCDesign);
%     partTable = selectConverterParts(deviceRating, NumberOfParts=5);
%
%   See also designBoostPFCConverter, selectConverterParts, applyConverterPart,
%   converterRegistry.

% Copyright 2026 The MathWorks, Inc.

arguments
    boostPFCSpec struct
    options.Design struct = struct.empty
    options.SafetyFactor (1,1) double {mustBePositive} = 1.2
    options.VoltageSafetyFactor (1,1) double = NaN
    options.NearestVoltageMultiplier (1,1) double {mustBePositive} = 10
    % 1 A steps: at this rating the three device positions differ by about 1 A.
    options.NearestCurrentMultiplier (1,1) double {mustBePositive} = 1
end

% ---- The sized design, which carries the device currents at each AC input ----
% Rate against the worst case the design reports, at minimum line, so no device is rated
% short by the line tolerance.
if isempty(options.Design)
    [~, boostPFCDesign] = designBoostPFCConverter(boostPFCSpec, ...
        "DisplayTableFlag", false);
else
    boostPFCDesign = options.Design;
end

requiredDesignField = {'outputVoltage', 'maxInputVoltage', 'switchCurrentRms', ...
    'boostDiodeCurrentAvg', 'rectifierDiodeCurrentAvg'};
missingField = requiredDesignField(~isfield(boostPFCDesign, requiredDesignField));
if ~isempty(missingField)
    error('selectBoostPFCDeviceRating:incompleteDesign', ...
        ['The design struct is missing field(s) %s. Pass the second output of ' ...
         'designBoostPFCConverter, or omit Design to have it computed.'], ...
        strjoin(missingField, ', '));
end

% ---- Blocking voltage: two different requirements ---------------------------
% Switch and boost diode sit across the DC bus, so they block Vout. A bridge diode never
% sees the bus - the conducting pair clamps the bridge output to |vac| - so it stands off
% the line peak only.
busVoltage = scalarValue(boostPFCDesign.outputVoltage);
acPeakVoltageMax = sqrt(2) * scalarValue(boostPFCDesign.maxInputVoltage);

% deviceVoltageMargin is the device-voltage decision, so it is the default. Applying
% SafetyFactor as well would derate twice.
voltageSafetyFactor = options.VoltageSafetyFactor;
if isnan(voltageSafetyFactor)
    if isfield(boostPFCSpec, 'deviceVoltageMargin')
        voltageSafetyFactor = scalarValue(boostPFCSpec.deviceVoltageMargin);
    else
        voltageSafetyFactor = options.SafetyFactor;
    end
end
busDeviceVoltageRating = roundUpTo(busVoltage*voltageSafetyFactor, ...
    options.NearestVoltageMultiplier);
rectifierVoltageRating = roundUpTo(acPeakVoltageMax*voltageSafetyFactor, ...
    options.NearestVoltageMultiplier);

% ---- Current: the statistic follows the datasheet field ---------------------
% IdsMaxDC is continuous, so the switch is rated on RMS. RatedForwardCurrent is IF(AV), so
% both diode positions are rated on average current.
switchCurrentRating = roundUpTo( ...
    scalarValue(boostPFCDesign.switchCurrentRms)*options.SafetyFactor, ...
    options.NearestCurrentMultiplier);
boostDiodeCurrentRating = roundUpTo( ...
    scalarValue(boostPFCDesign.boostDiodeCurrentAvg)*options.SafetyFactor, ...
    options.NearestCurrentMultiplier);
rectifierCurrentRating = roundUpTo( ...
    scalarValue(boostPFCDesign.rectifierDiodeCurrentAvg)*options.SafetyFactor, ...
    options.NearestCurrentMultiplier);

% ---- Assemble the rating table ----------------------------------------------
% Two rows per role, voltage then current. The last three columns are all selectConverterParts
% needs, which is what keeps it converter-agnostic.
mosfetEntityId = 'ee.semiconductors.ideal.mosfet';
diodeEntityId = 'ee.semiconductors.diode';

componentName = { ...
    'Boost MOSFET voltage rating'
    'Boost MOSFET current rating (RMS)'
    'Boost diode voltage rating'
    'Boost diode current rating (average)'
    'Bridge diode voltage rating'
    'Bridge diode current rating (average)' };
ratingValue = [ ...
    busDeviceVoltageRating
    switchCurrentRating
    busDeviceVoltageRating
    boostDiodeCurrentRating
    rectifierVoltageRating
    rectifierCurrentRating ];
ratingUnit = {'V'; 'A'; 'V'; 'A'; 'V'; 'A'};
metadataField = { ...
    'VdsMax'
    'IdsMaxDC'
    'RepetitivePeakReverseVoltage'
    'RatedForwardCurrent'
    'RepetitivePeakReverseVoltage'
    'RatedForwardCurrent' };
deviceRole = { ...
    'BoostMOSFET'
    'BoostMOSFET'
    'BoostDiode'
    'BoostDiode'
    'RectifierDiode'
    'RectifierDiode' };
modelingEntityId = { ...
    mosfetEntityId
    mosfetEntityId
    diodeEntityId
    diodeEntityId
    diodeEntityId
    diodeEntityId };

deviceRating = table(char(componentName), ratingValue, char(ratingUnit), ...
    string(metadataField), string(deviceRole), string(modelingEntityId), ...
    'VariableNames', {'Device', 'Rating', 'Unit', 'MetadataField', ...
    'DeviceRole', 'ModelingEntityId'});

% Display only the engineering columns; the machine-readable three would widen it.
disp(table(deviceRating(:,{'Device','Rating','Unit','MetadataField'}), ...
    'VariableNames', "Boost PFC Device Rating at " + boostPFCDesign.ratingSetByInputVoltage));
end

% ======================================================================
function roundedValue = roundUpTo(rawValue, multiplier)
% Up, never down: a rating is a floor, so rounding to the nearest multiple can give back
% part of the margin.
roundedValue = ceil(rawValue/multiplier)*multiplier;
end

% ======================================================================
function numericValue = scalarValue(quantity)
% Read a scalar out of either a simscape.Value or a plain double.
if isa(quantity, 'simscape.Value')
    numericValue = quantity.value;
else
    numericValue = quantity;
end
end
