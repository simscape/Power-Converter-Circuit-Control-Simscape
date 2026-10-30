function magCurrentLimit = computeCLLCMagnetizingCurrentLimit(CLLCSpec, options)
%   This function estimates the minimum k*Q product and the feasible magnetizing
%   inductance window of a CLLC resonant converter from the specification alone, before
%   any quality factor or inductance ratio is chosen. Use it as a pre-design gate: it
%   tells you which k and Q combinations can meet the magnetizing current limit and the
%   dead-time limits at all.
%
%   Because the converter is bidirectional, the magnetizing current is evaluated in both
%   power-flow directions and the worse of the two sets the limits.
%
%   Inputs:
%     CLLCSpec   Struct containing CLLC converter specifications. Required fields:
%                 - minInputVoltage / maxInputVoltage   (simscape.Value, V)
%                 - minOutputVoltage / maxOutputVoltage (simscape.Value, V)
%                 - ratedOutputPower: Rated output power (simscape.Value, W)
%                 - resonantFrequency: Resonant frequency (simscape.Value, Hz)
%                 - mosfetDrainSourceCapacitance: Device output capacitance of one switch,
%                   entered as the charge-equivalent value Qoss/Vds (simscape.Value, F)
%                 - maxSwitchingFrequency: Highest switching frequency in service
%                   (simscape.Value, Hz). Optional, and used only to size the dead time.
%                 - turnratioVoltageLevel: Which voltage pair anchors the turns ratio,
%                   see computeCLLCTurnsRatio. Not read when the TurnsRatio option is set.
%                 - magCurrentPercentofInputCurrent: Peak magnetizing current limit, as a
%                   percentage of the rated current of the port that is sourcing power (%).
%                   That port swaps with the power flow, so the limit is evaluated per
%                   direction: primary current P/Vin_avg forward, secondary current
%                   P/Vout_avg referred to the primary reverse.
%                 - minimumAllowedDeadTime / maximumAllowedDeadTime (simscape.Value, s)
%
%     options   Structure with optional fields:
%                 - N2: Secondary winding turns (default: 10). Must match the value
%                   given to designCLLCFullBridgeConverter, because the reverse-direction
%                   magnetizing voltage depends on the realized turns ratio.
%                 - TurnsRatio: Turns ratio N1/N2 to use directly, instead of deriving one
%                   from turnratioVoltageLevel (default: [], which derives it). See
%                   computeCLLCTurnsRatio. Must match the value given to
%                   designCLLCFullBridgeConverter, for the same reason as N2.
%                 - DisplayTableFlag: Logical. If true, displays the summary table.
%                   (default: true)
%
%   Output:
%     magCurrentLimit   Struct with fields:
%                 - minimumKQProduct: Smallest k*Q that keeps the peak magnetizing
%                   current within the limit in both directions. k*Q = w1*Lm/Reffective
%                   is independent of how the tank splits into L1 and C1, which is why a
%                   single number can gate the design before k and Q are picked.
%                 - minimumKQProductForward / minimumKQProductReverse: The same figure per
%                   direction, before the worse of the two is taken.
%                 - maxMagCurrent_A: The worst-case peak magnetizing current limit (A).
%                 - maxMagCurrentForward_A / maxMagCurrentReverse_A: Per-direction limits.
%                 - ratedSourceCurrentForward_A / ratedSourceCurrentReverse_A: The
%                   primary-referred rated current of the sourcing port in each direction,
%                   which is what magCurrentPercentofInputCurrent is a percentage of.
%                 - minimumLm_uH: Smallest Lm allowed by the magnetizing current limit.
%                 - maximumLm_uH: Largest Lm allowed by maximumAllowedDeadTime.
%                 - hardwareDeadTimeLm_uH: Lm below which the dead time is set by
%                   minimumAllowedDeadTime rather than by the soft-switching requirement.
%                 - deadTimeAtMinimumLm_ns: Dead time required at minimumLm.
%                 - VLmForward_V / VLmReverse_V: Primary-referred voltage across Lm in
%                   each direction.
%                 - designTurnsRatio / realizedTurnsRatio: See computeCLLCTurnsRatio.
%                 - Reffective_Ohm: Primary-referred FHA load resistance at rated power.
%
%   Example:
%     CLLCConverterDefaultInputParameters;
%     magCurrentLimit = computeCLLCMagnetizingCurrentLimit(CLLCSpec);

% Copyright 2025-2026 The MathWorks, Inc.

arguments
    CLLCSpec struct
    options.N2 (1,1) {mustBePositive, mustBeInteger} = 10
    options.TurnsRatio {mustBeScalarOrEmpty, mustBePositive} = []
    options.DisplayTableFlag (1,1) {mustBeNumericOrLogical} = true
end

avgInputVoltage = (value(CLLCSpec.minInputVoltage,"V") + value(CLLCSpec.maxInputVoltage,"V")) / 2;
avgOutputVoltage = (value(CLLCSpec.minOutputVoltage,"V") + value(CLLCSpec.maxOutputVoltage,"V")) / 2;
ratedOutputPower = value(CLLCSpec.ratedOutputPower,"W");
resonantFrequency = value(CLLCSpec.resonantFrequency,"Hz");
mosfetOutputCapacitance = value(CLLCSpec.mosfetDrainSourceCapacitance,"F");

turnsRatioData = computeCLLCTurnsRatio(CLLCSpec, N2=options.N2, TurnsRatio=options.TurnsRatio);

% Primary-referred voltage across Lm at the resonant frequency. Forward, the primary
% bridge drives the tank, so the amplitude is the input voltage. Reverse, the secondary
% bridge drives it, so the amplitude is the output voltage referred through the realized
% turns ratio. The two differ only by the integer-winding rounding of that ratio, and the
% larger one sets the worst-case magnetizing current.
VLmForward = avgInputVoltage;
VLmReverse = turnsRatioData.realizedTurnsRatio * avgOutputVoltage;
VLmWorstCase = max(VLmForward, VLmReverse);

% Primary-referred FHA load resistance at rated power. The rectifier and load together
% present 8/pi^2 times the DC load resistance, referred through the designed turns ratio
% because the tank is sized before the windings are rounded.
loadResistance = avgOutputVoltage^2 / ratedOutputPower;
Reffective = loadResistance * 8 * turnsRatioData.designTurnsRatio^2 / pi^2;

% The magnetizing current circulates without delivering power, so it is limited relative to
% the rated current of the port that is sourcing power - and that port swaps when the power
% flow reverses. Forward, the source is the primary at avgInputVoltage, so the reference is
% the primary current P/avgInputVoltage. Reverse, the source is the secondary at
% avgOutputVoltage, so the reference is the secondary current P/avgOutputVoltage referred to
% the primary through the realized turns ratio, that is P/(turnsRatio*avgOutputVoltage).
% Both references are therefore P/VLm for that direction, which makes the two limits differ
% only by the integer-winding rounding of the turns ratio.
ratedSourceCurrentForward = ratedOutputPower / VLmForward;
ratedSourceCurrentReverse = ratedOutputPower / VLmReverse;
maxMagCurrentForward = CLLCSpec.magCurrentPercentofInputCurrent * ratedSourceCurrentForward / 100;
maxMagCurrentReverse = CLLCSpec.magCurrentPercentofInputCurrent * ratedSourceCurrentReverse / 100;

% Smallest k*Q that respects the limit. Substituting Im_peak = VLm/(4*fr*Lm) into
% k*Q = w1*Lm/Reffective eliminates Lm and leaves pi*VLm/(2*Im_max*Reffective). Because
% Im_max is itself proportional to 1/VLm, the requirement grows as VLm^2, so it is
% evaluated per direction and the larger value gates the design.
minimumKQProductForward = pi * VLmForward / (2 * maxMagCurrentForward * Reffective);
minimumKQProductReverse = pi * VLmReverse / (2 * maxMagCurrentReverse * Reffective);
minimumKQProduct = max(minimumKQProductForward, minimumKQProductReverse);

% The worst-case direction, and the limit and Lm bound that go with it.
if minimumKQProductReverse >= minimumKQProductForward
    maxMagCurrent = maxMagCurrentReverse;
else
    maxMagCurrent = maxMagCurrentForward;
end

% Lm bounds. The magnetizing current falls as Lm rises, so the current limit sets a
% LOWER bound on Lm. The required dead time rises with Lm, so the longest acceptable dead
% time sets an UPPER bound. Below hardwareDeadTimeLm the soft-switching requirement asks
% for less dead time than the hardware can produce, so the hardware minimum applies
% instead; that is informational, not a bound.
% The dead time the charge condition asks for per henry of Lm, which is
% margin*8*Cparasitic*max(fr,fsMax). It is evaluated at the highest switching frequency in
% service because the peak magnetizing current falls as that frequency rises. The derivation
% is in estimateCLLCMaximumMagnetizingInductance.
minimumLm = VLmWorstCase / (maxMagCurrent * 4 * resonantFrequency);
if isfield(CLLCSpec, "maxSwitchingFrequency")
    zvsSizingFrequency = max(resonantFrequency, value(CLLCSpec.maxSwitchingFrequency,"Hz"));
else
    zvsSizingFrequency = resonantFrequency;
end
deadTimePerHenry = cllcZVSDeadTimeMarginFactor * 8 * mosfetOutputCapacitance * zvsSizingFrequency;
hardwareDeadTimeLm = value(CLLCSpec.minimumAllowedDeadTime,"s") / deadTimePerHenry;
maximumLm = value(CLLCSpec.maximumAllowedDeadTime,"s") / deadTimePerHenry;
deadTimeAtMinimumLm = deadTimePerHenry * minimumLm;

% Build output struct with values in engineering units
magCurrentLimit.minimumKQProduct = minimumKQProduct;
magCurrentLimit.minimumKQProductForward = minimumKQProductForward;
magCurrentLimit.minimumKQProductReverse = minimumKQProductReverse;
magCurrentLimit.maxMagCurrent_A = maxMagCurrent;
magCurrentLimit.maxMagCurrentForward_A = maxMagCurrentForward;
magCurrentLimit.maxMagCurrentReverse_A = maxMagCurrentReverse;
magCurrentLimit.ratedSourceCurrentForward_A = ratedSourceCurrentForward;
magCurrentLimit.ratedSourceCurrentReverse_A = ratedSourceCurrentReverse;
magCurrentLimit.minimumLm_uH = minimumLm * 1e6;
magCurrentLimit.maximumLm_uH = maximumLm * 1e6;
magCurrentLimit.hardwareDeadTimeLm_uH = hardwareDeadTimeLm * 1e6;
magCurrentLimit.deadTimeAtMinimumLm_ns = deadTimeAtMinimumLm * 1e9;
magCurrentLimit.VLmForward_V = VLmForward;
magCurrentLimit.VLmReverse_V = VLmReverse;
magCurrentLimit.designTurnsRatio = turnsRatioData.designTurnsRatio;
magCurrentLimit.realizedTurnsRatio = turnsRatioData.realizedTurnsRatio;
magCurrentLimit.Reffective_Ohm = Reffective;

% Display summary table
if options.DisplayTableFlag
    if VLmReverse >= VLmForward
        worstCaseDirection = 'reverse';
    else
        worstCaseDirection = 'forward';
    end
    % The turns ratio leads the table, because every row below is computed from it and you
    % may have let the voltage specification derive it.
    ComponentName = { ...
        'Transformer turns ratio (n)'; ...
        'Minimum k*Q required to keep the magnetizing current under the limit'; ...
        'Minimum k*Q required, forward power flow'; ...
        'Minimum k*Q required, reverse power flow'; ...
        'Peak magnetizing current limit, forward'; ...
        'Peak magnetizing current limit, reverse'; ...
        'Primary-referred rated current of the sourcing port, forward'; ...
        'Primary-referred rated current of the sourcing port, reverse'; ...
        'Minimum Lm set by the magnetizing current limit'; ...
        'Maximum Lm set by the maximum allowed dead time'; ...
        'Lm below which the dead time is set by hardware, not soft switching'; ...
        'Dead time required at the minimum Lm'; ...
        'Primary-referred voltage across Lm, forward'; ...
        'Primary-referred voltage across Lm, reverse'};
    Value = [ ...
        turnsRatioData.designTurnsRatio; ...
        minimumKQProduct; ...
        minimumKQProductForward; ...
        minimumKQProductReverse; ...
        maxMagCurrentForward; ...
        maxMagCurrentReverse; ...
        ratedSourceCurrentForward; ...
        ratedSourceCurrentReverse; ...
        minimumLm * 1e6; ...
        maximumLm * 1e6; ...
        hardwareDeadTimeLm * 1e6; ...
        deadTimeAtMinimumLm * 1e9; ...
        VLmForward; ...
        VLmReverse];
    Unit = {'-'; '-'; '-'; '-'; 'A'; 'A'; 'A'; 'A'; 'uH'; 'uH'; 'uH'; 'ns'; 'V'; 'V'};

    tableHeaderNames = {'Parameter', 'Value', 'Unit'};
    designTable = table(char(ComponentName), Value, char(Unit), 'VariableNames', tableHeaderNames);
    fprintf("       Magnetizing Inductance (Lm) and Current Limits at the Resonant Frequency\n");
    fprintf("       (Worst case is the %s direction. Feasible Lm range: %.2f uH to %.2f uH,\n", ...
        worstCaseDirection, minimumLm*1e6, maximumLm*1e6);
    fprintf("        which needs k*Q of at least %.3f)\n", minimumKQProduct);
    disp(table(designTable, 'VariableNames', " "));

    if minimumLm > maximumLm
        warning("computeCLLCMagnetizingCurrentLimit:InfeasibleRange", ...
            "No feasible Lm exists: the magnetizing current limit needs at least %.2f uH " + ...
            "but the maximum allowed dead time permits at most %.2f uH. Relax " + ...
            "magCurrentPercentofInputCurrent or increase maximumAllowedDeadTime.", ...
            minimumLm*1e6, maximumLm*1e6);
    end
end

end
