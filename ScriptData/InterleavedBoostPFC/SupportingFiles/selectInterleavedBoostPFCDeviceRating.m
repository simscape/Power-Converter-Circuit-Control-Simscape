function deviceRating = selectInterleavedBoostPFCDeviceRating(interleavedSpec, options)
%SELECTINTERLEAVEDBOOSTPFCDEVICERATING Voltage and current ratings for the interleaved devices.
%
%   deviceRating = selectInterleavedBoostPFCDeviceRating(interleavedSpec, Name=Value) returns
%   the blocking voltage and the continuous current a real semiconductor must be rated for, in
%   each of the three device positions. This is step 1 of rating -> selectConverterParts ->
%   applyConverterPart. Interleaving splits the current but not the voltage: each leg is rated
%   on 1/numberOfLegs of the line current, while the rectifier bridge sits before the split and
%   carries all of it. The current statistic follows the field a datasheet quotes: RMS for the
%   MOSFET, average for either diode.
%
%   Inputs:
%     interleavedSpec  Converter specification: the AC input range, the bus voltage, the
%                      power level, the leg count and the device voltage margin.
%
%   Name-value options:
%     Design                    Design structure from designInterleavedBoostPFCConverter, to
%                               save re-running it. Default: computed here.
%     SafetyFactor              Current derating factor. Default 1.2.
%     VoltageSafetyFactor       Voltage derating factor. Default NaN, which takes the
%                               specification's own deviceVoltageMargin.
%     NearestVoltageMultiplier  Voltage ratings round up to this multiple (V). Default 10.
%     NearestCurrentMultiplier  Current ratings round up to this multiple (A). Default 1.
%
%   Outputs:
%     deviceRating  Table of Device, Rating, Unit, MetadataField, DeviceRole and
%                   ModelingEntityId, two rows per device role. One part per role covers
%                   every leg.
%
%   Example:
%     InterleavedBoostPFCDefaultInputParameters;
%     deviceRating = selectInterleavedBoostPFCDeviceRating(interleavedSpec, ...
%         Design=interleavedDesign);
%     partTable = selectConverterParts(deviceRating, NumberOfParts=5);
%
%   See also designInterleavedBoostPFCConverter, selectConverterParts,
%   applyConverterPart, converterRegistry.

% Copyright 2026 The MathWorks, Inc.

arguments
    interleavedSpec struct
    options.Design struct = struct.empty
    options.SafetyFactor (1,1) double {mustBePositive} = 1.2
    options.VoltageSafetyFactor (1,1) double = NaN
    options.NearestVoltageMultiplier (1,1) double {mustBePositive} = 10
    % 1 A steps: the per-leg and bridge positions differ by only a couple of amps.
    options.NearestCurrentMultiplier (1,1) double {mustBePositive} = 1
end

% ---- The sized design, which carries the device currents at each AC input ----
% Rate against the worst case the design reports, at minimum line, so no device is rated
% short by the line tolerance.
if isempty(options.Design)
    [~, interleavedDesign] = designInterleavedBoostPFCConverter(interleavedSpec, ...
        "DisplayTableFlag", false);
else
    interleavedDesign = options.Design;
end

requiredDesignField = {'outputVoltage', 'maxInputVoltage', 'numberOfLegs', ...
    'switchCurrentRms', 'boostDiodeCurrentAvg', 'rectifierDiodeCurrentAvg'};
missingField = requiredDesignField(~isfield(interleavedDesign, requiredDesignField));
if ~isempty(missingField)
    error('selectInterleavedBoostPFCDeviceRating:incompleteDesign', ...
        ['The design struct is missing field(s) %s. Pass the second output of ' ...
         'designInterleavedBoostPFCConverter, or omit Design to have it computed.'], ...
        strjoin(missingField, ', '));
end

% ---- Blocking voltage: two different requirements ---------------------------
% Every leg spans the same DC bus, so its switch and boost diode block Vout. A bridge diode
% never sees the bus - the conducting pair clamps the bridge output to |vac| - so it stands
% off the LINE peak only.
busVoltage = scalarValue(interleavedDesign.outputVoltage);
acPeakVoltageMax = sqrt(2) * scalarValue(interleavedDesign.maxInputVoltage);
numberOfLegs = scalarValue(interleavedDesign.numberOfLegs);

% deviceVoltageMargin IS the device-voltage decision, so it is the default. Applying
% SafetyFactor as well would derate twice.
voltageSafetyFactor = options.VoltageSafetyFactor;
if isnan(voltageSafetyFactor)
    if isfield(interleavedSpec, 'deviceVoltageMargin')
        voltageSafetyFactor = scalarValue(interleavedSpec.deviceVoltageMargin);
    else
        voltageSafetyFactor = options.SafetyFactor;
    end
end
busDeviceVoltageRating = roundUpTo(busVoltage*voltageSafetyFactor, ...
    options.NearestVoltageMultiplier);
rectifierVoltageRating = roundUpTo(acPeakVoltageMax*voltageSafetyFactor, ...
    options.NearestVoltageMultiplier);

% ---- Current: the statistic follows the datasheet field ---------------------
% IdsMaxDC is continuous, so each leg switch is rated on RMS. RatedForwardCurrent is IF(AV),
% so both diode positions are rated on AVERAGE current. The per-leg figures already carry the
% 1/numberOfLegs split; the bridge figures do not, being upstream of it.
switchCurrentRating = roundUpTo( ...
    scalarValue(interleavedDesign.switchCurrentRms)*options.SafetyFactor, ...
    options.NearestCurrentMultiplier);
boostDiodeCurrentRating = roundUpTo( ...
    scalarValue(interleavedDesign.boostDiodeCurrentAvg)*options.SafetyFactor, ...
    options.NearestCurrentMultiplier);
rectifierCurrentRating = roundUpTo( ...
    scalarValue(interleavedDesign.rectifierDiodeCurrentAvg)*options.SafetyFactor, ...
    options.NearestCurrentMultiplier);

% ---- Assemble the rating table ----------------------------------------------
% Two rows per role, voltage then current. The last three columns are all selectConverterParts
% needs, which is what keeps it converter-agnostic. One part per role is applied to every leg,
% so the legs stay identical.
mosfetEntityId = 'ee.semiconductors.ideal.mosfet';
diodeEntityId = 'ee.semiconductors.diode';

componentName = { ...
    'Boost MOSFET voltage rating (per leg)'
    'Boost MOSFET current rating (RMS, per leg)'
    'Boost diode voltage rating (per leg)'
    'Boost diode current rating (average, per leg)'
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
    'VariableNames', sprintf("%d-Leg Interleaved Boost PFC Device Rating at %s", ...
    numberOfLegs, interleavedDesign.ratingSetByInputVoltage)));
end

% ======================================================================
function roundedValue = roundUpTo(rawValue, multiplier)
% Up, never down: a rating is a floor, so rounding to the NEAREST multiple could give back
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
