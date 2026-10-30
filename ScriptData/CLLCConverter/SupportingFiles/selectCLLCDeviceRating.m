function deviceRating = selectCLLCDeviceRating(CLLCSpec,options)
%   This function selects the voltage and current ratings for
%   the primary and secondary-side converter MOSFETs in a CLLC
%   full-bridge converter design. Ratings come from the converter specifications,
%   a safety factor, and rounding multipliers for standard device values.
%
%   Inputs:
%     CLLCSpec   Struct containing CLLC converter specifications. Required fields:
%                 - maxInputVoltage: Maximum input voltage (simscape.Value or numeric, V)
%                 - minInputVoltage: Minimum input voltage (simscape.Value or numeric, V)
%                 - maxOutputVoltage: Maximum output voltage (simscape.Value or numeric, V)
%                 - minOutputVoltage: Minimum output voltage (simscape.Value or numeric, V)
%                 - ratedOutputPower: Rated output power (simscape.Value or numeric, W)
%
%     options   Structure with optional fields:
%                 - SafetyFactor:              Multiplier for voltage/current safety margin
%                                              (default: 1.2)
%                 - NearestVoltageMultiplier:  Rounds voltage ratings up to nearest multiple
%                                              (default: 10)
%                 - NearestCurrentMultiplier:  Rounds current ratings up to nearest multiple
%                                              (default: 5)
%                 - MagnetizingInductance:     Magnetizing inductance of the transformer in the resonant tank 
%                                              (default: 100e-6 (Hz))
%                 - MinOperatingFreq:          Minimum operating frequency of the CLLC converter
%                                              (default: 60000 (Hz))
%
%   Output:
%     deviceRating   Table listing recommended device ratings, one row per rating:
%                      - Primary MOSFET voltage rating (V)
%                      - Primary MOSFET current rating (A)
%                      - Secondary MOSFET voltage rating (V)
%                      - Secondary MOSFET current rating (A)
%
%                    Columns:
%                      Device            human-readable rating name
%                      Rating            numeric value in the unit given by Unit
%                      Unit              'V' or 'A' - the same unit the Simscape
%                                        Electrical part collection stores the
%                                        corresponding metadata field in
%                      MetadataField     the part-collection metadata field this
%                                        rating is compared against:
%                                        VdsMax / IdsMaxDC (both bridges are MOSFETs)
%                      DeviceRole        plant device role key, matching the
%                                        .parts descriptor in converterRegistry
%                                        ("PrimaryMOSFET" / "SecondaryMOSFET")
%                      ModelingEntityId  Simscape modeling entity the part
%                                        collection is keyed on
%                                        ('ee.semiconductors.ideal.mosfet')
%
%                    The last three columns let the table go
%                    straight to selectConverterParts without any further
%                    converter-specific code.
%
%   Method:
%     - Voltage ratings are calculated as max voltage * safety factor, rounded up.
%     - Current ratings are estimated as output power / input (or output) voltage * sqrt(2)
%       * safety factor, plus half the peak-to-peak magnetizing current on that side,
%       rounded up.
%     - Results are rounded up to the specified voltage and current multipliers.
%
%   Example:
%     CLLCSpec.maxInputVoltage = simscape.Value(420, "V");
%     CLLCSpec.minInputVoltage = simscape.Value(380, "V");
%     CLLCSpec.maxOutputVoltage = simscape.Value(54, "V");
%     CLLCSpec.minOutputVoltage = simscape.Value(48, "V");
%     CLLCSpec.ratedOutputPower = simscape.Value(1000, "W");
%     options.SafetyFactor = 1.3;
%     deviceRating = selectCLLCDeviceRating(CLLCSpec, options);
%
%   See also selectConverterParts, applyConverterPart, applyPartToDeviceRole,
%   converterRegistry.

% Copyright 2025-2026 The MathWorks, Inc.

    arguments
        CLLCSpec struct  
        options.MagnetizingInductance  = simscape.Value(100e-6,"H"); % Magnetizing inductance
        options.TurnsRatio  = 1; % Turns ratio
        options.MinOperatingFreq  = simscape.Value(60e3,"Hz"); % Minimum operating frequency
        options.SafetyFactor (1,1) {mustBeNonnegative} = 1.2; 
        options.NearestVoltageMultiplier (1,1) {mustBeNonnegative} = 10; 
        options.NearestCurrentMultiplier (1,1) {mustBeNonnegative} = 5; 
    end

    % Estimate maximum possible magnetizing current
    delT = 0.5/options.MinOperatingFreq.value;
    peak2peakMagCurrent = CLLCSpec.maxInputVoltage.value*delT/options.MagnetizingInductance.value;
    magLSecondary = options.MagnetizingInductance.value/(options.TurnsRatio*options.TurnsRatio);
    peak2peakSecondaryMagCurrent = CLLCSpec.maxOutputVoltage.value*delT/magLSecondary;

    % Round up, never down. The rating is a floor that the
    % selected part must meet or exceed, so rounding to the nearest multiple can
    % return a rating below the safety-factored value and give up part of
    % the safety margin.
    primaryMOSFETVoltageRating = ceil(CLLCSpec.maxInputVoltage.value*options.SafetyFactor...
        /options.NearestVoltageMultiplier)*options.NearestVoltageMultiplier;
    primaryMOSFETCurrentRating = ceil((0.5*peak2peakMagCurrent+(CLLCSpec.ratedOutputPower.value/CLLCSpec.minInputVoltage.value)*sqrt(2))*...
        options.SafetyFactor/options.NearestCurrentMultiplier)*options.NearestCurrentMultiplier;
    secondaryMOSFETVoltageRating = ceil(CLLCSpec.maxOutputVoltage.value*options.SafetyFactor...
        /options.NearestVoltageMultiplier)*options.NearestVoltageMultiplier;
    secondaryMOSFETCurrentRating = ceil((0.5*peak2peakSecondaryMagCurrent+(CLLCSpec.ratedOutputPower.value/CLLCSpec.minOutputVoltage.value)*sqrt(2))*...
        options.SafetyFactor/options.NearestCurrentMultiplier)*options.NearestCurrentMultiplier;


    % Each rating row also carries the part-collection metadata field it is compared
    % against, the plant device role and the Simscape modeling entity the collection
    % is keyed on. selectConverterParts reads those three columns and needs nothing
    % else, which keeps part selection converter-agnostic.
    %
    % Both CLLC bridges are MOSFET (Ideal, Switching) blocks - the converter is
    % bidirectional, so the secondary side switches rather than rectifies - hence one
    % modeling entity and one pair of metadata fields serves both roles. The rating
    % units are the units the part collection stores these fields in (V and A), so no
    % conversion is needed.
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
    % Display only the engineering columns - the three machine-readable ones are
    % for selectConverterParts and widen the printout.
    disp(table(deviceRating(:,{'Device','Rating','Unit','MetadataField'}), ...
        'VariableNames',"Primary and Secondary MOSFET Rating"));
end