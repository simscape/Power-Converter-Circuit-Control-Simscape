function deviceRating = selectTotemPoleDeviceRating(totemPoleSpec, options)
%SELECTTOTEMPOLEDEVICERATING Voltage and current ratings for the totem-pole PFC devices.
%
%   deviceRating = selectTotemPoleDeviceRating(totemPoleSpec, Name=Value) returns the
%   blocking voltage and the continuous current a real semiconductor must be rated for, in
%   each device position. This is step 1 of rating -> selectConverterParts ->
%   applyConverterPart. Every device blocks the DC bus rather than the line. The fast leg
%   chops at the switching frequency and is rated on RMS current. The slow leg commutates
%   once per line half cycle. Its catalog, its metadata fields and its current statistic
%   come from whichever of three builds the plant is set to.
%
%   Inputs:
%     totemPoleSpec  Converter specification: the AC input range, the bus voltage, the
%                    power level and the device voltage margin.
%
%   Name-value options:
%     SlowLegDevice             Slow-leg build, matching the plant's slowLegDeviceOption
%                               popup: "Diode", "MOSFET" or "Thyristor". Default "Diode".
%     Design                    Design structure from designTotemPoleBoostPFCConverter, to
%                               save re-running it. Default: computed here.
%     SafetyFactor              Current derating factor. Default 1.2.
%     VoltageSafetyFactor       Voltage derating factor. Default NaN, which takes the
%                               specification's own deviceVoltageMargin.
%     NearestVoltageMultiplier  Voltage ratings round up to this multiple (V). Default 10.
%     NearestCurrentMultiplier  Current ratings round up to this multiple (A). Default 5.
%
%   Outputs:
%     deviceRating  Table of Device, Rating, Unit, MetadataField, DeviceRole and
%                   ModelingEntityId, two rows per device role.
%
%   Example:
%     TotemPoleBoostPFCDefaultInputParameters;
%     deviceRating = selectTotemPoleDeviceRating(totemPoleSpec, ...
%         Design = totemPoleDesign, SlowLegDevice = "Diode");
%     partTable = selectConverterParts(deviceRating, NumberOfParts = 5);
%     applyConverterPart("TotemPoleBoostPFCConverter", PartTable = partTable, ...
%         DeviceRole = ["FastLegMOSFET" "SlowLegDiode"], Rank = [1 1]);
%
%   See also designTotemPoleBoostPFCConverter, selectConverterParts,
%   applyConverterPart, applyPartToDeviceRole, converterRegistry.

% Copyright 2026 The MathWorks, Inc.

arguments
    totemPoleSpec struct
    options.SlowLegDevice (1,1) string ...
        {mustBeMember(options.SlowLegDevice, ["Diode" "MOSFET" "Thyristor"])} = "Diode"
    options.Design struct = struct.empty
    options.SafetyFactor (1,1) double {mustBePositive} = 1.2
    options.VoltageSafetyFactor (1,1) double = NaN
    options.NearestVoltageMultiplier (1,1) double {mustBePositive} = 10
    options.NearestCurrentMultiplier (1,1) double {mustBePositive} = 5
end

% ---- The sized design, which carries the device currents at each AC input -----
% Rate against the worst case the design reports, at minimum line, so no device is rated
% short by the line tolerance.
if isempty(options.Design)
    [~, totemPoleDesign] = designTotemPoleBoostPFCConverter(totemPoleSpec, ...
        "DisplayTableFlag", false);
else
    totemPoleDesign = options.Design;
end

requiredDesignField = {'outputVoltage', 'fastLegDeviceCurrentRms', ...
    'slowLegDeviceCurrentRms', 'slowLegDeviceCurrentAvg'};
missingField = requiredDesignField(~isfield(totemPoleDesign, requiredDesignField));
if ~isempty(missingField)
    error('selectTotemPoleDeviceRating:incompleteDesign', ...
        ['The design struct is missing field(s) %s. Pass the second output of ' ...
         'designTotemPoleBoostPFCConverter, or omit Design to have it computed.'], ...
        strjoin(missingField, ', '));
end

% ---- Blocking voltage --------------------------------------------------------
% Both legs sit across the output capacitor, so every device blocks the DC bus, not the
% line - the bridgeless topology's one voltage simplification.
busVoltage = scalarValue(totemPoleDesign.outputVoltage);

% deviceVoltageMargin IS the device-voltage decision, so it is the default and keeps ONE
% device voltage across the two workflows. Applying SafetyFactor as well would derate
% twice and push the selection into a higher voltage class.
voltageSafetyFactor = options.VoltageSafetyFactor;
if isnan(voltageSafetyFactor)
    if isfield(totemPoleSpec, 'deviceVoltageMargin')
        voltageSafetyFactor = scalarValue(totemPoleSpec.deviceVoltageMargin);
    else
        voltageSafetyFactor = options.SafetyFactor;
    end
end
deviceVoltageRating = roundUpTo(busVoltage*voltageSafetyFactor, ...
    options.NearestVoltageMultiplier);

% ---- Fast leg ----------------------------------------------------------------
% Each fast-leg MOSFET is boost switch for half the line cycle and synchronous rectifier for
% the other, so the thermal limit is the full-cycle RMS current, and IdsMaxDC is continuous.
fastLegCurrentRating = roundUpTo( ...
    scalarValue(totemPoleDesign.fastLegDeviceCurrentRms)*options.SafetyFactor, ...
    options.NearestCurrentMultiplier);

% ---- Slow leg ----------------------------------------------------------------
% The device type decides the current statistic, the metadata fields and the modeling
% entity together, so all three are chosen in one place.
mosfetEntityId = 'ee.semiconductors.ideal.mosfet';
switch options.SlowLegDevice
    case "MOSFET"
        slowLegRoleName    = 'SlowLegMOSFET';
        slowLegDisplayName = 'Slow-leg MOSFET';
        slowLegEntityId    = mosfetEntityId;
        slowLegVoltageField = 'VdsMax';
        slowLegCurrentField = 'IdsMaxDC';
        % Continuous rating -> RMS current.
        slowLegCurrent      = scalarValue(totemPoleDesign.slowLegDeviceCurrentRms);
        slowLegCurrentBasis = 'RMS';
    case "Diode"
        slowLegRoleName    = 'SlowLegDiode';
        slowLegDisplayName = 'Slow-leg diode';
        slowLegEntityId    = 'ee.semiconductors.diode';
        slowLegVoltageField = 'RepetitivePeakReverseVoltage';
        slowLegCurrentField = 'RatedForwardCurrent';
        % IF(AV) is an AVERAGE rating. The RMS value would over-rate the diode by the
        % half-cycle form factor, about 1.57x.
        slowLegCurrent      = scalarValue(totemPoleDesign.slowLegDeviceCurrentAvg);
        slowLegCurrentBasis = 'average';
    case "Thyristor"
        slowLegRoleName    = 'SlowLegThyristor';
        slowLegDisplayName = 'Slow-leg thyristor';
        slowLegEntityId    = 'ee.semiconductors.ideal.thyristor';
        % Datasheet-conventional names, unchecked against a schema because no thyristor
        % collection is installed. Re-verify them when one is - see the warning below.
        slowLegVoltageField = 'RepetitivePeakOffStateVoltage';
        slowLegCurrentField = 'AverageOnStateCurrent';
        % IT(AV) is an average rating, like a diode's.
        slowLegCurrent      = scalarValue(totemPoleDesign.slowLegDeviceCurrentAvg);
        slowLegCurrentBasis = 'average on-state';
        warning('selectTotemPoleDeviceRating:noThyristorCatalog', ...
            ['The slow-leg thyristor is rated below, but no thyristor part ' ...
             'collection is installed for modeling entity "%s", so ' ...
             'selectConverterParts will have nothing to list for role "%s". Use ' ...
             'the rating to choose a device from a vendor datasheet, or select ' ...
             'SlowLegDevice="Diode" or "MOSFET" to use the catalog.'], ...
            slowLegEntityId, slowLegRoleName);
end
slowLegCurrentRating = roundUpTo(slowLegCurrent*options.SafetyFactor, ...
    options.NearestCurrentMultiplier);

% ---- Assemble the rating table ----------------------------------------------
% Two rows per role, voltage then current. The last three columns are all
% selectConverterParts needs, which is what keeps it converter-agnostic. The units are
% the catalog's own, so nothing is converted downstream.
componentName = { ...
    'Fast-leg MOSFET voltage rating'
    'Fast-leg MOSFET current rating (RMS)'
    [slowLegDisplayName ' voltage rating']
    [slowLegDisplayName ' current rating (' slowLegCurrentBasis ')'] };
ratingValue = [ ...
    deviceVoltageRating
    fastLegCurrentRating
    deviceVoltageRating
    slowLegCurrentRating ];
ratingUnit = {'V'; 'A'; 'V'; 'A'};
metadataField = { ...
    'VdsMax'
    'IdsMaxDC'
    slowLegVoltageField
    slowLegCurrentField };
deviceRole = { ...
    'FastLegMOSFET'
    'FastLegMOSFET'
    slowLegRoleName
    slowLegRoleName };
modelingEntityId = { ...
    mosfetEntityId
    mosfetEntityId
    slowLegEntityId
    slowLegEntityId };

deviceRating = table(char(componentName), ratingValue, char(ratingUnit), ...
    string(metadataField), string(deviceRole), string(modelingEntityId), ...
    'VariableNames', {'Device', 'Rating', 'Unit', 'MetadataField', ...
    'DeviceRole', 'ModelingEntityId'});

% Display only the engineering columns; the machine-readable three would widen it.
disp(table(deviceRating(:,{'Device','Rating','Unit','MetadataField'}), ...
    'VariableNames', "Fast-Leg and Slow-Leg (" + options.SlowLegDevice + ") Device Rating"));
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
