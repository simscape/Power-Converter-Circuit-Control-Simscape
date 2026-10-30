function deviceRating = selectNonIsolatedDCDCDeviceRating(nonIsolatedDCDCSpec, options)
%SELECTNONISOLATEDDCDCDEVICERATING Voltage and current ratings for the DC-DC devices.
%
%   deviceRating = selectNonIsolatedDCDCDeviceRating(nonIsolatedDCDCSpec, Name=Value)
%   returns the blocking voltage and continuous current a real device must be rated for,
%   in each position of a buck, boost or buck-boost stage. This is step 1 of rating ->
%   selectConverterParts -> applyConverterPart. The topology comes off the design and
%   decides how many device roles there are: a non-synchronous converter has a main
%   switch MOSFET and a freewheeling diode, a synchronous one a single MOSFET role
%   serving both positions. Each current is the statistic its catalog metadata field
%   expects, RMS for a MOSFET and average for a diode.
%
%   Inputs:
%     nonIsolatedDCDCSpec  Converter specification structure.
%
%   Name-value options:
%     Design                    Design structure from designNonIsolatedDCDCConverter, to
%                               save re-running it. Default: computed here.
%     SafetyFactor              Current derating factor. Default 1.2.
%     VoltageSafetyFactor       Voltage derating factor. Default NaN, which takes the
%                               design's own voltage margin.
%     NearestVoltageMultiplier  Voltage ratings round up to this multiple (V). Default 10.
%     NearestCurrentMultiplier  Current ratings round up to this multiple (A). Default 1.
%
%   Outputs:
%     deviceRating  Table of Device, Rating, Unit, MetadataField, DeviceRole and
%                   ModelingEntityId, two rows per device role.
%
%   Example:
%     % Synchronous boost - one switch role, both positions share the part.
%     [~, nonIsolatedDCDCDesign] = designNonIsolatedDCDCConverter(nonIsolatedDCDCSpec);
%     deviceRating = selectNonIsolatedDCDCDeviceRating(nonIsolatedDCDCSpec, ...
%         Design = nonIsolatedDCDCDesign);
%     partTable = selectConverterParts(deviceRating, NumberOfParts = 5);
%     applyConverterPart("NonIsolatedDCDCConverter", PartTable = partTable, ...
%         DeviceRole = "SwitchMOSFET", Rank = 1);
%
%   See also designNonIsolatedDCDCConverter, selectConverterParts,
%   applyConverterPart, applyPartToDeviceRole, converterRegistry.

% Copyright 2026 The MathWorks, Inc.

arguments
    nonIsolatedDCDCSpec struct
    options.Design struct = struct.empty
    options.SafetyFactor (1,1) double {mustBePositive} = 1.2
    options.VoltageSafetyFactor (1,1) double = NaN
    options.NearestVoltageMultiplier (1,1) double {mustBePositive} = 10
    options.NearestCurrentMultiplier (1,1) double {mustBePositive} = 1
end

% ---- The sized design, which carries the device currents at each input --------
if isempty(options.Design)
    [~, nonIsolatedDCDCDesign] = designNonIsolatedDCDCConverter(nonIsolatedDCDCSpec, ...
        "DisplayTableFlag", false);
else
    nonIsolatedDCDCDesign = options.Design;
end

requiredDesignField = {'topology', 'isSynchronous', 'deviceBlockingVoltage', ...
    'deviceVoltageRating', 'mainSwitchCurrentRms', 'secondDeviceCurrentRms', ...
    'secondDeviceCurrentAvg'};
missingField = requiredDesignField(~isfield(nonIsolatedDCDCDesign, requiredDesignField));
if ~isempty(missingField)
    error('selectNonIsolatedDCDCDeviceRating:incompleteDesign', ...
        ['The design struct is missing field(s) %s. Pass the second output of ' ...
         'designNonIsolatedDCDCConverter, or omit Design to have it computed.'], ...
        strjoin(missingField, ', '));
end

% ---- Blocking voltage --------------------------------------------------------
% The design already holds the blocking voltage times the spec's margin, and taking that
% product keeps ONE device voltage across the estimate and selection workflows. Applying
% SafetyFactor as well would derate twice and push the selection into a higher voltage class.
voltageSafetyFactor = options.VoltageSafetyFactor;
if isnan(voltageSafetyFactor)
    % deviceVoltageRating IS blockingVoltage*deviceVoltageMargin, so no factor is re-applied.
    deviceVoltageRating = roundUpTo(scalarValue(nonIsolatedDCDCDesign.deviceVoltageRating), ...
        options.NearestVoltageMultiplier);
else
    deviceVoltageRating = roundUpTo( ...
        scalarValue(nonIsolatedDCDCDesign.deviceBlockingVoltage)*voltageSafetyFactor, ...
        options.NearestVoltageMultiplier);
end

% ---- Switch MOSFET role ------------------------------------------------------
% The design swept the three input voltages, so these currents are the worst one's. For
% a boost that is MINIMUM input, where a nominal-input figure under-rates every device by
% the input-tolerance ratio.
mosfetEntityId = 'ee.semiconductors.ideal.mosfet';
mainSwitchCurrentRms = scalarValue(nonIsolatedDCDCDesign.mainSwitchCurrentRms);

if nonIsolatedDCDCDesign.isSynchronous
    % Both positions are MOSFETs fed by ONE mask parameter triple, so rate on the
    % harder-working one.
    switchCurrentRms = max(mainSwitchCurrentRms, ...
        scalarValue(nonIsolatedDCDCDesign.secondDeviceCurrentRms));
    % The display name already says the rating covers both positions, so the basis stays
    % the bare statistic - a longer string is truncated by the table printout.
    switchDisplayName = 'Main and synchronous switch MOSFET';
else
    switchCurrentRms = mainSwitchCurrentRms;
    switchDisplayName = 'Main switch MOSFET';
end
% A MOSFET conducts through a resistance, so its loss is I_rms^2*Rds and its IdsMaxDC is
% a continuous rating.
switchCurrentBasis = 'RMS';
switchCurrentRating = roundUpTo(switchCurrentRms*options.SafetyFactor, ...
    options.NearestCurrentMultiplier);

% ---- Assemble the rating table ----------------------------------------------
% Two rows per role, voltage then current. The last three columns are all
% selectConverterParts needs, which is what keeps it converter-agnostic. The units are the
% catalog's own, so nothing is converted downstream.
componentName = { ...
    [switchDisplayName ' voltage rating']
    [switchDisplayName ' current rating (' switchCurrentBasis ')'] };
ratingValue = [deviceVoltageRating; switchCurrentRating];
ratingUnit = {'V'; 'A'};
metadataField = {'VdsMax'; 'IdsMaxDC'};
deviceRole = {'SwitchMOSFET'; 'SwitchMOSFET'};
modelingEntityId = {mosfetEntityId; mosfetEntityId};

% ---- Freewheeling diode role, non-synchronous topologies only ----------------
% A synchronous variant holds two MOSFET subsystems and no tabulated diode, so a diode role
% here would produce a rating no block could ever receive.
if ~nonIsolatedDCDCDesign.isSynchronous
    % A diode conducts through a voltage drop, so its loss is Vf*I_avg and IF(AV) is an
    % AVERAGE rating. The RMS value would over-rate it by the duty form factor.
    diodeCurrentRating = roundUpTo( ...
        scalarValue(nonIsolatedDCDCDesign.secondDeviceCurrentAvg)*options.SafetyFactor, ...
        options.NearestCurrentMultiplier);
    componentName = [componentName; { ...
        'Freewheeling diode voltage rating'
        'Freewheeling diode current rating (average)'}];
    ratingValue = [ratingValue; deviceVoltageRating; diodeCurrentRating];
    ratingUnit = [ratingUnit; {'V'; 'A'}];
    metadataField = [metadataField; ...
        {'RepetitivePeakReverseVoltage'; 'RatedForwardCurrent'}];
    deviceRole = [deviceRole; {'FreewheelDiode'; 'FreewheelDiode'}];
    modelingEntityId = [modelingEntityId; ...
        {'ee.semiconductors.diode'; 'ee.semiconductors.diode'}];
end

deviceRating = table(char(componentName), ratingValue, char(ratingUnit), ...
    string(metadataField), string(deviceRole), string(modelingEntityId), ...
    'VariableNames', {'Device', 'Rating', 'Unit', 'MetadataField', ...
    'DeviceRole', 'ModelingEntityId'});

% Display only the engineering columns; the machine-readable three would widen it.
disp(table(deviceRating(:,{'Device','Rating','Unit','MetadataField'}), ...
    'VariableNames', nonIsolatedDCDCDesign.topology + " Device Rating"));
end

% ======================================================================
function roundedValue = roundUpTo(rawValue, multiplier)
% Up, never down: a rating is a floor, so rounding to the NEAREST multiple could give
% back part of the safety margin.
roundedValue = ceil(rawValue/multiplier)*multiplier;
end

% ======================================================================
function numericValue = scalarValue(quantity)
% Read a scalar out of either a simscape.Value or a plain double: the shipped spec and
% design structs use simscape.Value, but a hand-built spec often does not, and
% simscape.Value has no double() conversion so the field is read rather than cast.
if isa(quantity, 'simscape.Value')
    numericValue = quantity.value;
else
    numericValue = quantity;
end
end
