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
%     deviceRating   Table listing recommended device ratings:
%                      - Inverter MOSFET voltage rating (V)
%                      - Inverter MOSFET current rating (A)
%                      - Rectifier Diode voltage rating (V)
%                      - Rectifier Diode current rating (A)
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

    mosfetVoltageRating = round(LLCSpec.maxInputVoltage.value*options.SafetyFactor...
        /options.NearestVoltageMultiplier)*options.NearestVoltageMultiplier;
    mosfetCurrentRating = round((0.5*peak2peakMagCurrent+(LLCSpec.ratedOutputPower.value/LLCSpec.minInputVoltage.value)*sqrt(2))*...
        options.SafetyFactor/options.NearestCurrentMultiplier)*options.NearestCurrentMultiplier;
    diodeVoltageRating = round(LLCSpec.maxOutputVoltage.value*options.SafetyFactor...
        /options.NearestVoltageMultiplier)*options.NearestVoltageMultiplier;
    diodeCurrentRating = round((LLCSpec.ratedOutputPower.value/LLCSpec.minOutputVoltage.value)*sqrt(2)*...
        options.SafetyFactor/options.NearestCurrentMultiplier)*options.NearestCurrentMultiplier;


    ComponentName{1} = 'Inverter MOSFET voltage rating';
    Value(1) = mosfetVoltageRating;
    Unit{1} = 'V';
    ComponentName{2} = 'Inverter MOSFET current rating';
    Value(2) = mosfetCurrentRating;
    Unit{2} = 'A';
    ComponentName{3} = 'Rectifier Diode voltage rating';
    Value(3) = diodeVoltageRating;
    Unit{3} = 'V';
    ComponentName{4} = 'Rectifier Diode current rating';
    Value(4) = diodeCurrentRating;
    Unit{4} = 'A';

    tableHeaderNames = {'Device', 'Rating', 'Unit'};
    deviceRating = table(char(ComponentName'),Value', char(Unit'),'VariableNames',tableHeaderNames);
    disp(table(deviceRating,'VariableNames',"MOSFET and Diode Rating"));   
end