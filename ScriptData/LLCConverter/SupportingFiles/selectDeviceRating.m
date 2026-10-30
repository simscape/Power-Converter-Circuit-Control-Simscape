function deviceRating = selectDeviceRating(LLCSpec,options)
%   This function estimates and selects appropriate voltage and current ratings for
%   the primary-side inverter MOSFETs and secondary-side rectifier diodes in an LLC
%   full-bridge converter design. Ratings are determined based on converter specs,
%   a user-defined safety factor, and rounding multipliers for standard device values.
%
%   Inputs:
%     LLCSpec   Struct containing LLC converter specifications. Required fields:
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
%                 - MinOperatingFreq:          Minimum operating frequency of the LLC converter
%                                              (default: 60000 (Hz))
%
%   Output:
%     deviceRating   Table listing recommended device ratings, one row per rating:
%                      - Inverter MOSFET voltage rating (V)
%                      - Inverter MOSFET current rating (A)
%                      - Rectifier Diode voltage rating (V)
%                      - Rectifier Diode current rating (A)
%
%                    Columns:
%                      Device            human-readable rating name
%                      Rating            numeric value in the unit given by Unit
%                      Unit              'V' or 'A' - the SAME unit the Simscape
%                                        Electrical part collection stores the
%                                        corresponding metadata field in
%                      MetadataField     the part-collection metadata field this
%                                        rating is compared against:
%                                          VdsMax / IdsMaxDC                    (MOSFET)
%                                          RepetitivePeakReverseVoltage /
%                                          RatedForwardCurrent                  (Diode)
%                      DeviceRole        plant device role key, matching the
%                                        .parts descriptor in converterRegistry
%                                        ("PrimaryMOSFET" / "SecondaryDiode")
%                      ModelingEntityId  Simscape modeling entity the part
%                                        collection is keyed on
%                                        ('ee.semiconductors.ideal.mosfet' /
%                                         'ee.semiconductors.diode')
%
%                    The last three columns exist so the table can be handed
%                    straight to selectConverterParts without any further
%                    converter-specific glue.
%
%   Method:
%     - Voltage ratings are calculated as max voltage × safety factor, rounded up.
%     - Current ratings are estimated as output power / input (or output) voltage × sqrt(2)
%       × safety factor, rounded up.
%     - Results are rounded to the nearest specified voltage and current multipliers.
%
%   Example:
%     LLCSpec.maxInputVoltage = simscape.Value(420, "V");
%     LLCSpec.minInputVoltage = simscape.Value(380, "V");
%     LLCSpec.maxOutputVoltage = simscape.Value(54, "V");
%     LLCSpec.minOutputVoltage = simscape.Value(48, "V");
%     LLCSpec.ratedOutputPower = simscape.Value(1000, "W");
%     options.SafetyFactor = 1.3;
%     deviceRating = selectDeviceRating(LLCSpec, options);
%
%   See also selectConverterParts, applyConverterPart, applyPartToDeviceRole,
%   converterRegistry.

% Copyright 2025-2026 The MathWorks, Inc.

    arguments
        LLCSpec struct  
        options.MagnetizingInductance  = simscape.Value(100e-6,"H"); % Magnetizing inductance
        options.MinOperatingFreq  = simscape.Value(60e3,"Hz"); % Minimum operating frequency
        options.SafetyFactor (1,1) {mustBeNonnegative} = 1.2; 
        options.NearestVoltageMultiplier (1,1) {mustBeNonnegative} = 10; 
        options.NearestCurrentMultiplier (1,1) {mustBeNonnegative} = 5; 
    end

    % Estimate maximum possible magnetizing current
    delT = 0.5/options.MinOperatingFreq.value;
    peak2peakMagCurrent = LLCSpec.maxInputVoltage.value*delT/options.MagnetizingInductance.value;

    % Round UP to the nearest multiplier, never down. The rating is a floor that the
    % selected part must meet or exceed, so rounding to the nearest multiple could
    % return a rating below the safety-factored value and silently give back part of
    % the safety margin.
    mosfetVoltageRating = ceil(LLCSpec.maxInputVoltage.value*options.SafetyFactor...
        /options.NearestVoltageMultiplier)*options.NearestVoltageMultiplier;
    mosfetCurrentRating = ceil((0.5*peak2peakMagCurrent+(LLCSpec.ratedOutputPower.value/LLCSpec.minInputVoltage.value)*sqrt(2))*...
        options.SafetyFactor/options.NearestCurrentMultiplier)*options.NearestCurrentMultiplier;
    diodeVoltageRating = ceil(LLCSpec.maxOutputVoltage.value*options.SafetyFactor...
        /options.NearestVoltageMultiplier)*options.NearestVoltageMultiplier;
    diodeCurrentRating = ceil((LLCSpec.ratedOutputPower.value/LLCSpec.minOutputVoltage.value)*sqrt(2)*...
        options.SafetyFactor/options.NearestCurrentMultiplier)*options.NearestCurrentMultiplier;


    % Each rating row also carries the part-collection metadata field it is
    % compared against, the plant device role and the Simscape modeling entity
    % the collection is keyed on. selectConverterParts reads those three columns
    % and needs nothing else, which is what keeps part selection converter-agnostic.
    %
    % The rating units below are deliberately the units the Simscape Electrical
    % part collection stores these fields in (V and A), so no conversion is needed
    % on the way in. Note the collection is NOT internally consistent on current:
    % RatedForwardCurrent is stored in 'A' for most diodes but in 'mA' for
    % small-signal ones, so selectConverterParts normalizes every queried value
    % against its own per-part unit before comparing.
    mosfetEntityId = 'ee.semiconductors.ideal.mosfet';
    diodeEntityId  = 'ee.semiconductors.diode';

    ComponentName{1} = 'Inverter MOSFET voltage rating';
    Value(1) = mosfetVoltageRating;
    Unit{1} = 'V';
    MetadataField{1} = 'VdsMax';
    DeviceRole{1} = 'PrimaryMOSFET';
    ModelingEntityId{1} = mosfetEntityId;

    ComponentName{2} = 'Inverter MOSFET current rating';
    Value(2) = mosfetCurrentRating;
    Unit{2} = 'A';
    MetadataField{2} = 'IdsMaxDC';
    DeviceRole{2} = 'PrimaryMOSFET';
    ModelingEntityId{2} = mosfetEntityId;

    ComponentName{3} = 'Rectifier Diode voltage rating';
    Value(3) = diodeVoltageRating;
    Unit{3} = 'V';
    MetadataField{3} = 'RepetitivePeakReverseVoltage';
    DeviceRole{3} = 'SecondaryDiode';
    ModelingEntityId{3} = diodeEntityId;

    ComponentName{4} = 'Rectifier Diode current rating';
    Value(4) = diodeCurrentRating;
    Unit{4} = 'A';
    MetadataField{4} = 'RatedForwardCurrent';
    DeviceRole{4} = 'SecondaryDiode';
    ModelingEntityId{4} = diodeEntityId;

    tableHeaderNames = {'Device', 'Rating', 'Unit', 'MetadataField', 'DeviceRole', 'ModelingEntityId'};
    deviceRating = table(char(ComponentName'),Value', char(Unit'), ...
        string(MetadataField'), string(DeviceRole'), string(ModelingEntityId'), ...
        'VariableNames',tableHeaderNames);
    % Display only the engineering columns - the three machine-readable ones are
    % plumbing for selectConverterParts and would just make the printout wide.
    disp(table(deviceRating(:,{'Device','Rating','Unit','MetadataField'}), ...
        'VariableNames',"MOSFET and Diode Rating"));
end