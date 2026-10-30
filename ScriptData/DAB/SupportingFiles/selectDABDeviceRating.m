function deviceRating = selectDABDeviceRating(DABSpec,options)
%SELECTDABDEVICERATING Voltage and current ratings for the two DAB bridges.
%
%   deviceRating = selectDABDeviceRating(DABSpec, Name=Value) returns the blocking voltage
%   and the continuous current each bridge MOSFET must be rated for under single-phase-shift
%   control. This is step 1 of rating -> selectConverterParts -> applyConverterPart. The
%   voltage ratings follow each bridge's own DC bus. The current ratings follow the peak
%   series current at rated power, taken as the worst of all four V1 and V2 combinations in
%   both power directions. Every rating rounds up to a catalog multiplier.
%
%   Inputs:
%     DABSpec  Converter specification: the voltage ranges, the rated power and the
%              switching frequency.
%
%   Name-value options:
%     TurnsRatio                Primary-to-secondary turns ratio. Default 1.
%     SeriesInductance          Primary-referred series inductance. Default 50 uH.
%     MagnetizingInductance     Transformer magnetizing inductance. Default Inf.
%     SafetyFactor              Derating factor on both voltage and current. Default 1.2.
%     NearestVoltageMultiplier  Voltage ratings round up to this multiple (V). Default 10.
%     NearestCurrentMultiplier  Current ratings round up to this multiple (A). Default 5.
%
%   Outputs:
%     deviceRating  Table of Device, Rating, Unit, MetadataField, DeviceRole and
%                   ModelingEntityId, two rows per bridge.
%
%   Example:
%     DABDefaultInputParameters;
%     deviceRating = selectDABDeviceRating(DABSpec, ...
%         TurnsRatio = DABDesign.turnsRatio, ...
%         SeriesInductance = DABDesign.seriesInductance, ...
%         MagnetizingInductance = DABDesign.Lm, ...
%         SafetyFactor = 1.2);
%
%   See also DABSPSPhysics, designDABConverter, selectConverterParts,
%   applyConverterPart, applyPartToDeviceRole, converterRegistry.

% Copyright 2026 The MathWorks, Inc.

    arguments
        DABSpec struct
        options.TurnsRatio = 1;                                    % n = N1/N2
        options.SeriesInductance = simscape.Value(50e-6,"H");      % Primary-referred series inductance
        options.MagnetizingInductance = simscape.Value(Inf,"H");   % Inf leaves out the magnetizing current
        options.SafetyFactor (1,1) {mustBeNonnegative} = 1.2;
        options.NearestVoltageMultiplier (1,1) {mustBeNonnegative} = 10;
        options.NearestCurrentMultiplier (1,1) {mustBeNonnegative} = 5;
    end

    % Plain doubles from here on: the ratings are rounded to catalog multipliers and
    % compared against part metadata that carries its own units.
    minInputVoltage    = scalarValue(DABSpec.minInputVoltage);
    maxInputVoltage    = scalarValue(DABSpec.maxInputVoltage);
    minOutputVoltage   = scalarValue(DABSpec.minOutputVoltage);
    maxOutputVoltage   = scalarValue(DABSpec.maxOutputVoltage);
    ratedPower         = scalarValue(DABSpec.ratedPower);
    switchingFrequency = scalarValue(DABSpec.switchingFrequency);

    turnsRatio            = scalarValue(options.TurnsRatio);
    seriesInductance      = scalarValue(options.SeriesInductance);
    magnetizingInductance = scalarValue(options.MagnetizingInductance);

    % Im_pk = V1max/(4*fsw*Lm), from the largest primary voltage Lm sees over a half
    % cycle. Load independent, and added in full to the primary current below, which is
    % the conservative choice for a rating.
    peakMagnetizingCurrent = maxInputVoltage/(4*switchingFrequency*magnetizingInductance);

    % The same physics object the design function uses, so the device currents here and the
    % soft-switching limits come from one implementation.
    sps = DABSPSPhysics(turnsRatio, switchingFrequency, seriesInductance);

    % A DAB runs in both directions, so the rating is taken over both signs of the phase
    % shift. Reversing the flow time-reverses the waveform, so it moves the larger
    % commutation current to the other switching instant and leaves both magnitudes alone.
    voltageCorners = [ ...
        minInputVoltage minOutputVoltage
        minInputVoltage maxOutputVoltage
        maxInputVoltage minOutputVoltage
        maxInputVoltage maxOutputVoltage];
    peakSeriesCurrent = 0;
    cornersBelowRatedPower = strings(0,1);
    for k = 1:size(voltageCorners,1)
        cornerInputVoltage  = voltageCorners(k,1);
        cornerOutputVoltage = voltageCorners(k,2);
        if ratedPower > sps.maxPower(cornerInputVoltage, cornerOutputVoltage)
            % Rated power is out of reach at any phase shift, so the highest attainable
            % current is the one at the pi/2 ceiling.
            dutyRatio = 0.5;
            cornersBelowRatedPower(end+1) = sprintf('%g V / %g V', ...
                cornerInputVoltage, cornerOutputVoltage); %#ok<AGROW>
        else
            dutyRatio = sps.dutyForPower(ratedPower, cornerInputVoltage, cornerOutputVoltage);
        end
        for flowDirection = [1 -1]   % forward and reverse power transfer
            peakSeriesCurrent = max(peakSeriesCurrent, ...
                sps.peakSeriesCurrent(flowDirection*dutyRatio, ...
                cornerInputVoltage, cornerOutputVoltage));
        end
    end
    if ~isempty(cornersBelowRatedPower)
        warning('selectDABDeviceRating:voltagePairBelowRatedPower', ...
            ['These V1 and V2 combinations cannot transfer the rated %g W with the given ' ...
            'series inductance, so they are rated at the maximum phase shift ' ...
            'instead: %s. Check the series inductance and turns ratio.'], ...
            ratedPower, strjoin(cornersBelowRatedPower, '; '));
    end

    % Adding the two peaks is deliberately conservative: Im peaks at the primary
    % commutation, which is not always where the series current peaks, so this is an upper
    % bound on the true device peak.
    peakPrimaryCurrent = peakSeriesCurrent + peakMagnetizingCurrent;
    peakSecondaryCurrent = turnsRatio*peakSeriesCurrent;

    % Each bridge blocks only its own DC bus, so its voltage rating is that bus at maximum.
    % Up, never down: a rating is a floor, so rounding to the NEAREST multiple could give
    % back part of the safety margin.
    primaryMOSFETVoltageRating = ceil(maxInputVoltage*options.SafetyFactor...
        /options.NearestVoltageMultiplier)*options.NearestVoltageMultiplier;
    primaryMOSFETCurrentRating = ceil(peakPrimaryCurrent*options.SafetyFactor...
        /options.NearestCurrentMultiplier)*options.NearestCurrentMultiplier;
    secondaryMOSFETVoltageRating = ceil(maxOutputVoltage*options.SafetyFactor...
        /options.NearestVoltageMultiplier)*options.NearestVoltageMultiplier;
    secondaryMOSFETCurrentRating = ceil(peakSecondaryCurrent*options.SafetyFactor...
        /options.NearestCurrentMultiplier)*options.NearestCurrentMultiplier;

    % The units are the catalog's own, so nothing is converted downstream. One entity serves
    % both roles: the converter is bidirectional, so the secondary bridge switches rather
    % than rectifies and is a MOSFET too.
    mosfetEntityId = 'ee.semiconductors.ideal.mosfet';

    ComponentName{1} = 'Primary MOSFET voltage rating';
    Value(1) = primaryMOSFETVoltageRating;
    Unit{1} = 'V';
    MetadataField{1} = 'VdsMax';
    DeviceRole{1} = 'PrimaryMOSFET';
    ModelingEntityId{1} = mosfetEntityId;

    ComponentName{2} = 'Primary MOSFET current rating';
    Value(2) = primaryMOSFETCurrentRating;
    Unit{2} = 'A';
    MetadataField{2} = 'IdsMaxDC';
    DeviceRole{2} = 'PrimaryMOSFET';
    ModelingEntityId{2} = mosfetEntityId;

    ComponentName{3} = 'Secondary MOSFET voltage rating';
    Value(3) = secondaryMOSFETVoltageRating;
    Unit{3} = 'V';
    MetadataField{3} = 'VdsMax';
    DeviceRole{3} = 'SecondaryMOSFET';
    ModelingEntityId{3} = mosfetEntityId;

    ComponentName{4} = 'Secondary MOSFET current rating';
    Value(4) = secondaryMOSFETCurrentRating;
    Unit{4} = 'A';
    MetadataField{4} = 'IdsMaxDC';
    DeviceRole{4} = 'SecondaryMOSFET';
    ModelingEntityId{4} = mosfetEntityId;

    tableHeaderNames = {'Device', 'Rating', 'Unit', 'MetadataField', 'DeviceRole', 'ModelingEntityId'};
    deviceRating = table(char(ComponentName'),Value', char(Unit'), ...
        string(MetadataField'), string(DeviceRole'), string(ModelingEntityId'), ...
        'VariableNames',tableHeaderNames);
    % Display only the engineering columns; the machine-readable three would widen it.
    disp(table(deviceRating(:,{'Device','Rating','Unit','MetadataField'}), ...
        'VariableNames',"Primary and Secondary MOSFET Rating"));
end

% ======================================================================
function numericValue = scalarValue(quantity)
% Read a scalar out of either a simscape.Value or a plain double: the shipped spec and
% design structs use simscape.Value, but a hand-built spec often does not.
if isa(quantity, 'simscape.Value')
    numericValue = quantity.value;
else
    numericValue = quantity;
end
end
