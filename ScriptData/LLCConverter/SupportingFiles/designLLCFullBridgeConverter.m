function [designTable, LLCDesign] = designLLCFullBridgeConverter(LLCSpec, options)
%   This function estimates suitable LLC resonant tank parameters for a full-bridge
%   LLC converter based on the provided electrical specifications, quality factor,
%   and inductance ratio. The function also computes related design values such as
%   transformer turns ratio, magnetizing and resonant inductances, resonant capacitance,
%   dead time, and output filter capacitance. Dead time is kept at a
%   minimum of 2% of the resonant cycle time.
%
%   Inputs:
%     LLCSpec   Struct containing LLC converter specifications. Required fields:
%                 - minInputVoltage: Minimum input voltage (simscape.Value)
%                 - maxInputVoltage: Maximum input voltage (simscape.Value)
%                 - minOutputVoltage: Minimum output voltage (simscape.Value)
%                 - maxOutputVoltage: Maximum output voltage (simscape.Value)
%                 - ratedOutputPower: Rated output power (simscape.Value)
%                 - resonantFrequency: Resonant frequency (simscape.Value)
%                 - qualityFactor: Quality factor (dimensionless)
%                 - k: Lm/Lr ratio (dimensionless)
%                 - mosfetDrainSourceCapacitance: MOSFET Cds (simscape.Value)
%                 - inductanceDistributionFactor: Fraction of Lr on primary side (0-1)
%                 - LLCModelOption: "Full-Bridge" or "Half-Bridge"
%                 - turnratioVoltageLevel: Which voltage pair anchors the turns ratio,
%                   see computeLLCTurnsRatio. Not read when the TurnsRatio option is set.
%                 - magCurrentPercentofInputCurrent: Magnetizing current limit (%)
%                 - minimumAllowedDeadTime: Shortest dead time the gate drive and
%                   processor can produce (simscape.Value, s)
%                 - maximumAllowedDeadTime: Longest acceptable dead time (simscape.Value, s)
%                 - Rco: Output filter capacitor ESR resistance (Ohm)
%                 - R1: Transformer primary resistance (Ohm)
%                 - R2: Transformer secondary resistance (Ohm)
%                 - Rcr: Resonant capacitor ESR (Ohm)
%
%     options   Structure with optional fields:
%                 - N1: Primary winding turns, the anchor for the winding counts
%                   (default: 50)
%                 - TurnsRatio: Turns ratio N1/N2 to use directly, instead of deriving one
%                   from turnratioVoltageLevel (default: [], which derives it). See
%                   computeLLCTurnsRatio. Give the same value to
%                   computeMagnetizingCurrentLimit and plotGainCurveLLCConverter, or the
%                   three describe different transformers.
%                 - DisplayTableFlag: Logical. If true, displays the design table.
%                   (default: true)
%
%   Outputs:
%     designTable   Table summarizing estimated design parameters and values.
%     LLCDesign     Structure containing calculated component values and design details.
%
%   Example:
%     LLCSpec.minInputVoltage = simscape.Value(380, "V");
%     LLCSpec.maxInputVoltage = simscape.Value(420, "V");
%     LLCSpec.minOutputVoltage = simscape.Value(48, "V");
%     LLCSpec.maxOutputVoltage = simscape.Value(54, "V");
%     LLCSpec.ratedOutputPower = simscape.Value(1000, "W");
%     LLCSpec.resonantFrequency = simscape.Value(100e3, "Hz");
%     LLCSpec.qualityFactor = 0.8;
%     LLCSpec.k = 3;
%     LLCSpec.mosfetDrainSourceCapacitance = simscape.Value(200e-12, "F");
%     LLCSpec.inductanceDistributionFactor = 0.5;
%     LLCSpec.LLCModelOption = "Full-Bridge";
%     LLCSpec.turnratioVoltageLevel = "Max Output Volttage and Min Input Voltage";
%     LLCSpec.magCurrentPercentofInputCurrent = 20;
%     LLCSpec.Rco = 0.01;
%     LLCSpec.R1 = 0.02;
%     LLCSpec.R2 = 0.02;
%     LLCSpec.Rcr = 0.01;
%     [designTable, LLCDesign] = designLLCFullBridgeConverter(LLCSpec);

% Copyright 2025-2026 The MathWorks, Inc.

arguments
    LLCSpec struct
    options.N1 (1,1) {mustBePositive, mustBeInteger} = 50 % Primary winding turns
    options.TurnsRatio {mustBeScalarOrEmpty, mustBePositive} = [] % Specified turns ratio N1/N2
    options.DisplayTableFlag (1,1) {mustBeNumericOrLogical} = true
end

% Simscape arithmetic preserves units throughout computation
avgInputVoltage = (LLCSpec.minInputVoltage + LLCSpec.maxInputVoltage) / 2;
avgOutputVoltage = (LLCSpec.minOutputVoltage + LLCSpec.maxOutputVoltage) / 2;

% Topology-dependent voltage scaling factor
topologyFactor = llcPrimaryBridgeTopologyFactor(LLCSpec.LLCModelOption);

% Gain range (extract as plain doubles in SI for consistent downstream use)
LLCDesign.minGain = topologyFactor * value(LLCSpec.minOutputVoltage, "V") / value(LLCSpec.maxInputVoltage, "V");
LLCDesign.maxGain = topologyFactor * value(LLCSpec.maxOutputVoltage, "V") / value(LLCSpec.minInputVoltage, "V");
LLCDesign.avgGain = topologyFactor * value(avgOutputVoltage, "V") / value(avgInputVoltage, "V");

% The turns ratio either comes from the TurnsRatio option or follows from the voltage pair
% the user selected, but the transformer needs integer winding counts, so the ratio the
% converter actually realizes is N1/N2. Both are needed below: the designed (unrounded)
% ratio sizes the tank and the windings, the realized ratio is what the secondary-to-primary
% referral of the leakage inductance must use. The strategy lives in computeLLCTurnsRatio so
% that this function and computeMagnetizingCurrentLimit cannot disagree about it.
turnsRatioData = computeLLCTurnsRatio(LLCSpec, N1=options.N1, TurnsRatio=options.TurnsRatio);
designTurnsRatio = turnsRatioData.designTurnsRatio;

% Effective AC load resistance. The tank is sized before the windings are rounded, so this
% uses the designed ratio. Using the realized ratio here instead would change L, C and Lm,
% that is, it would redesign the tank rather than refer to it.
Ro = avgOutputVoltage^2 / LLCSpec.ratedOutputPower;
Reffective = Ro * 8 * designTurnsRatio^2 / pi^2;

% Resonant tank components (Simscape propagates units: H, F)
LbyC = LLCSpec.qualityFactor^2 * Reffective^2;
C = 1 / (2 * pi * sqrt(LbyC) * LLCSpec.resonantFrequency);
L = LbyC * C;
Lm = LLCSpec.k * L;

% Dead time: compute from circuit, clamp to user-specified bounds
deadTimeComputed = value(1.2 * 16 * LLCSpec.mosfetDrainSourceCapacitance * Lm * LLCSpec.resonantFrequency, "s");
TdMin = value(LLCSpec.minimumAllowedDeadTime, "s");
TdMax = value(LLCSpec.maximumAllowedDeadTime, "s");
LLCDesign.deadTime = min(max(deadTimeComputed, TdMin), TdMax);
deadTimeExceedsMax = deadTimeComputed > TdMax;

% Output filter capacitance (1% voltage dip over 5 cycles)
outputCharge = 10 * LLCSpec.ratedOutputPower / (LLCSpec.resonantFrequency * avgOutputVoltage);
Co = outputCharge / (0.01 * avgOutputVoltage);

% Transformer winding turns
LLCDesign.N1 = turnsRatioData.N1;
LLCDesign.N2 = turnsRatioData.N2;
LLCDesign.turnsRatio = turnsRatioData.realizedTurnsRatio;

% Store design values in SI base units for downstream use
LLCDesign.Co = value(Co, "F");
LLCDesign.C = value(C, "F");
LLCDesign.L = value(L, "H");
LLCDesign.Lm = value(Lm, "H");
LLCDesign.resonantFreq = value(LLCSpec.resonantFrequency, "Hz");
LLCDesign.Cparasitic = value(LLCSpec.mosfetDrainSourceCapacitance, "F");

% Leakage inductance distribution. The secondary share is referred through the REALIZED
% turns ratio, because that is the ratio the transformer block works with.
LLCDesign.Llk1 = LLCSpec.inductanceDistributionFactor * LLCDesign.L;
LLCDesign.Llk2 = (1 - LLCSpec.inductanceDistributionFactor) * LLCDesign.L / ...
    LLCDesign.turnsRatio^2;

% Parasitics
LLCDesign.Rco = LLCSpec.Rco;
LLCDesign.R1 = LLCSpec.R1;
LLCDesign.R2 = LLCSpec.R2;
LLCDesign.Rcr = LLCSpec.Rcr;

% Peak magnetizing current at resonant frequency
VLm = value(avgInputVoltage, "V") / topologyFactor;
Im_peak = VLm / (LLCDesign.Lm * 4 * LLCDesign.resonantFreq);

% Magnetizing current limit check
ratedInputCurrent = value(LLCSpec.ratedOutputPower, "W") / value(avgInputVoltage, "V");
ImLimit = LLCSpec.magCurrentPercentofInputCurrent * ratedInputCurrent / 100;
ImRatio = Im_peak / ImLimit;

LLCDesign.Im_peak = Im_peak;
LLCDesign.ImLimit = ImLimit;
LLCDesign.ImRatio = ImRatio;

% Build display table
ComponentName = { ...
    'Transformer turns ratio (N1/N2)'; ...
    'Magnetizing inductance (Lm)'; ...
    'Series resonant inductance (Lr)'; ...
    'Resonant capacitance (Cr)'; ...
    'Transformer primary leakage inductance (Llk1)'; ...
    'Transformer secondary leakage inductance (Llk2)'; ...
    'Output DC filter capacitance (Co)'; ...
    'Resonant frequency (fr)'; ...
    'Peak magnetizing current (Im)'; ...
    'Dead time (Td)'};
Value = [ ...
    round(LLCDesign.N1 / LLCDesign.N2, 2); ...
    LLCDesign.Lm * 1e6; ...
    LLCDesign.L * 1e6; ...
    LLCDesign.C * 1e6; ...
    LLCDesign.Llk1 * 1e6; ...
    LLCDesign.Llk2 * 1e6; ...
    LLCDesign.Co * 1e6; ...
    LLCDesign.resonantFreq * 1e-3; ...
    Im_peak; ...
    LLCDesign.deadTime * 1e9];
Unit = {'-'; 'uH'; 'uH'; 'uF'; 'uH'; 'uH'; 'uF'; 'kHz'; 'A'; 'ns'};

tableHeaderNames = {'Parameter', 'Value', 'Unit'};
designTable = table(char(ComponentName), Value, char(Unit), 'VariableNames', tableHeaderNames);

if options.DisplayTableFlag
    disp(table(designTable, 'VariableNames', LLCSpec.LLCModelOption + " LLC Converter Estimated Design Parameters"));
    if deadTimeExceedsMax
        warning("designLLCFullBridgeConverter:DeadTimeExceedsMax", ...
            "Computed dead time (%.1f ns) exceeds maximum allowed dead time (%.1f ns). " + ...
            "Reduce magnetizing inductance or increase maximum allowed dead time.", ...
            deadTimeComputed*1e9, TdMax*1e9);
    end
end

end
