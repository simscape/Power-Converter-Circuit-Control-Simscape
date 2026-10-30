function magCurrentLimit = computeMagnetizingCurrentLimit(LLCSpec, options)
% Estimate K*Q factor and magnetizing inductance limits for LLC converter
% based on maximum magnetizing current constraint at resonant frequency.
%
%   Inputs:
%     LLCSpec   Struct containing LLC converter specifications. Required fields are the
%               voltage, power and frequency ratings, LLCModelOption,
%               turnratioVoltageLevel, mosfetDrainSourceCapacitance,
%               magCurrentPercentofInputCurrent, and the two dead-time limits.
%
%     options   Structure with optional fields:
%                 - N1: Primary winding turns (default: 50). Must match the value given to
%                   designLLCFullBridgeConverter, so both describe one transformer.
%                 - TurnsRatio: Turns ratio N1/N2 to use directly, instead of deriving one
%                   from turnratioVoltageLevel (default: [], which derives it). See
%                   computeLLCTurnsRatio. Must match the value given to
%                   designLLCFullBridgeConverter, for the same reason as N1.
%                 - DisplayTableFlag: Logical. If true, displays the summary table.
%                   (default: true)
%
%   Output:
%     magCurrentLimit   Struct holding the minimum k*Q, the magnetizing current limit, the
%                       feasible Lm window, the dead time at the minimum Lm, the turns
%                       ratio used and the effective load resistance.

% Copyright 2025-2026 The MathWorks, Inc.

arguments
    LLCSpec struct
    options.N1 (1,1) {mustBePositive, mustBeInteger} = 50 % Primary winding turns
    options.TurnsRatio {mustBeScalarOrEmpty, mustBePositive} = [] % Specified turns ratio N1/N2
    options.DisplayTableFlag (1,1) {mustBeNumericOrLogical} = true
end

avgInputVoltage = (value(LLCSpec.minInputVoltage,"V") + value(LLCSpec.maxInputVoltage,"V")) / 2;
avgOutputVoltage = (value(LLCSpec.minOutputVoltage,"V") + value(LLCSpec.maxOutputVoltage,"V")) / 2;
fr = value(LLCSpec.resonantFrequency,"Hz");
Coss = value(LLCSpec.mosfetDrainSourceCapacitance,"F");

% Topology-dependent voltage scaling factor
topologyFactor = llcPrimaryBridgeTopologyFactor(LLCSpec.LLCModelOption);

% The turns ratio either comes from the TurnsRatio option or follows from the voltage pair
% the user selected. The designed (unrounded) ratio is the one that sets the effective load
% resistance, so it is the one this function reads. The strategy lives in
% computeLLCTurnsRatio so that this function and designLLCFullBridgeConverter cannot
% disagree about it.
turnsRatioData = computeLLCTurnsRatio(LLCSpec, N1=options.N1, TurnsRatio=options.TurnsRatio);
turnsRatio = turnsRatioData.designTurnsRatio;

% Voltage across Lm at resonant frequency
VLm = avgInputVoltage / topologyFactor;

% Effective AC load resistance
Ro = avgOutputVoltage^2 / value(LLCSpec.ratedOutputPower,"W");
Reffective = Ro * 8 * turnsRatio^2 / pi^2;

% Magnetizing current limit
ratedInputCurrent = value(LLCSpec.ratedOutputPower,"W") / avgInputVoltage;
maxMagCurrent = LLCSpec.magCurrentPercentofInputCurrent * ratedInputCurrent / 100;

% K*Q ratio required to satisfy magnetizing current limit
KQratio = pi * VLm / (2 * maxMagCurrent * Reffective);

% Magnetizing inductance from max magnetizing current constraint
LmFromMagCurrent = VLm / (maxMagCurrent * 4 * fr);

% Magnetizing inductance from dead time constraints
TdMin = value(LLCSpec.minimumAllowedDeadTime,"s");
TdMax = value(LLCSpec.maximumAllowedDeadTime,"s");
LmFromMinDeadTime = TdMin / (16 * Coss * fr);
LmFromMaxDeadTime = TdMax / (16 * Coss * fr);

% Dead time required at the minimum Lm (from mag current constraint)
deadTimeAtMinLm = 16 * Coss * LmFromMagCurrent * fr;

% Build output struct with values in engineering units
magCurrentLimit.KQratio = KQratio;
magCurrentLimit.maxMagCurrent_A = maxMagCurrent;
magCurrentLimit.LmFromMagCurrent_uH = LmFromMagCurrent * 1e6;
magCurrentLimit.LmFromMinDeadTime_uH = LmFromMinDeadTime * 1e6;
magCurrentLimit.LmFromMaxDeadTime_uH = LmFromMaxDeadTime * 1e6;
magCurrentLimit.deadTimeAtMinLm_ns = deadTimeAtMinLm * 1e9;
magCurrentLimit.turnsRatio = turnsRatio;
magCurrentLimit.Reffective_Ohm = Reffective;

% Display summary table
if options.DisplayTableFlag
    % The turns ratio leads the table, because every row below is computed from it and the
    % user may have let the voltage specification derive it rather than setting it directly.
    ComponentName = { ...
        'Transformer turns ratio (n)'; ...
        'Minimum k*Q required to keep magnetizing current under the limit'; ...
        'Maximum magnetizing current'; ...
        'Minimum Lm to limit the magnetizing current'; ...
        'Maximum Lm to achieve soft-switching at minimum dead time'; ...
        'Maximum Lm to achieve soft-switching at maximum dead time'; ...
        'Required dead time at min Lm'};
    Value = [ ...
        turnsRatio; ...
        KQratio; ...
        maxMagCurrent; ...
        LmFromMagCurrent * 1e6; ...
        LmFromMinDeadTime * 1e6; ...
        LmFromMaxDeadTime * 1e6; ...
        deadTimeAtMinLm * 1e9];
    Unit = {'-'; '-'; 'A'; 'uH'; 'uH'; 'uH'; 'ns'};

    tableHeaderNames = {'Parameter', 'Value', 'Unit'};
    designTable = table(char(ComponentName), Value, char(Unit), 'VariableNames', tableHeaderNames);
    fprintf("       Magnetizing Inductance (Lm) and Current Limit Estimates at Resonant Frequency\n");
    fprintf("       (Recommended Lm range: %.2f uH to %.2f uH)\n", LmFromMagCurrent*1e6, LmFromMaxDeadTime*1e6);
    disp(table(designTable, 'VariableNames', " "));

    if LmFromMagCurrent > LmFromMaxDeadTime
        warning("computeMagnetizingCurrentLimit:InfeasibleRange", ...
            "No feasible Lm exists: magnetizing current limit (%.2f uH) exceeds dead time constraint (%.2f uH). " + ...
            "Relax the magnetizing current limit or increase the maximum allowed dead time.", ...
            LmFromMagCurrent*1e6, LmFromMaxDeadTime*1e6);
    end
end

end