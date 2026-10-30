function [designTable, CLLCDesign] = designCLLCFullBridgeConverter(CLLCSpec,options)
%   This function estimates suitable CLLC resonant tank parameters for a full-bridge
%   CLLC converter based on the provided electrical specifications, quality factor,
%   and inductance ratio. The function also computes related design values such as
%   transformer turns ratio, magnetizing and resonant inductances, resonant capacitance,
%   dead time, and output filter capacitance. Dead time is computed from the
%   soft-switching requirement and then clamped to the allowed dead-time window.
%
%   Inputs:
%     CLLCSpec   Struct containing CLLC converter specifications. The voltage, power,
%                frequency, capacitance and time fields must be simscape.Value objects;
%                the dimensionless and resistance fields are plain numbers. Required
%                fields:
%                 - minInputVoltage: Minimum input voltage (simscape.Value, V)
%                 - maxInputVoltage: Maximum input voltage (simscape.Value, V)
%                 - minOutputVoltage: Minimum output voltage (simscape.Value, V)
%                 - maxOutputVoltage: Maximum output voltage (simscape.Value, V)
%                 - ratedOutputPower: Rated output power (simscape.Value, W)
%                 - resonantFrequency: Resonant frequency (simscape.Value, Hz)
%                 - qualityFactor: Quality factor (dimensionless)
%                 - k: Lm/Lr ratio (dimensionless)
%                 - mosfetDrainSourceCapacitance: Device output capacitance of one switch,
%                   entered as the charge-equivalent value Qoss/Vds (simscape.Value, F)
%                 - maxSwitchingFrequency: Highest switching frequency in service
%                   (simscape.Value, Hz). Optional. The dead time is sized at
%                   max(resonantFrequency, maxSwitchingFrequency), so omitting it sizes the
%                   dead time at the resonant frequency alone.
%                 - a: Resonant inductance ratio
%                 - b: Resonant capacitance ratio
%                 - turnratioVoltageLevel: Which voltage pair anchors the turns ratio,
%                   see computeCLLCTurnsRatio. Not read when the TurnsRatio option is set.
%                 - magCurrentPercentofInputCurrent: Peak magnetizing current limit, as a
%                   percentage of the rated current of the port that is sourcing power (%).
%                   That port swaps with the power flow, so the limit is evaluated per
%                   direction: primary current P/Vin_avg forward, secondary current
%                   P/Vout_avg referred to the primary reverse.
%                 - minimumAllowedDeadTime: Shortest dead time the gate drive and
%                   processor can produce (simscape.Value, s)
%                 - maximumAllowedDeadTime: Longest acceptable dead time, typically a
%                   few percent of the switching period (simscape.Value, s)
%                 - Rco: Output filter capacitor ESR (Ohm)
%                 - R1: Transformer primary resistance (Ohm)
%                 - R2: Transformer secondary resistance (Ohm)
%                 - Rcr1: Primary resonant capacitor ESR (Ohm)
%                 - Rcr2: Secondary resonant capacitor ESR (Ohm)
%
%     options   Structure with optional fields:
%                 - N2: Secondary winding turns, the anchor for the winding counts
%                   (default: 10)
%                 - TurnsRatio: Turns ratio N1/N2 to use directly, instead of deriving one
%                   from turnratioVoltageLevel (default: [], which derives it). See
%                   computeCLLCTurnsRatio. Give the same value to
%                   computeCLLCMagnetizingCurrentLimit and plotGainCurveCLLCConverter, or
%                   the three describe different transformers.
%                 - DisplayTableFlag: Logical. If true, displays the design table.
%                   (default: true)
%
%   Outputs:
%     designTable   Table summarizing estimated design parameters and values.
%     CLLCDesign     Structure containing calculated component values and design details.
%
%   Method:
%     - Uses average values of input and output voltages for calculations.
%     - Calculates transformer turns ratio, effective load resistance, resonant tank
%       components (L1, L2, C1, C2, Lm), dead time, and output filter capacitance.
%     - Refers L2 and C2 through the realized (integer-winding) turns ratio, so the
%       requested inductance ratio a and capacitance ratio b are the ones the model sees.
%     - Estimates the peak magnetizing current in BOTH power-flow directions and compares
%       each against the rated current of the port sourcing power in that direction, then
%       reports the worse ratio. Fields ImLimitFwd / ImLimitRev and ratedSourceCurrentFwd /
%       ratedSourceCurrentRev expose the per-direction references.
%     - Assembles results into a summary table.
%
%   Example:
%     CLLCSpec.minInputVoltage = simscape.Value(380, "V");
%     CLLCSpec.maxInputVoltage = simscape.Value(420, "V");
%     CLLCSpec.minOutputVoltage = simscape.Value(48, "V");
%     CLLCSpec.maxOutputVoltage = simscape.Value(54, "V");
%     CLLCSpec.ratedOutputPower = simscape.Value(1000, "W");
%     CLLCSpec.resonantFrequency = simscape.Value(100e3, "Hz");
%     CLLCSpec.maxSwitchingFrequency = simscape.Value(170e3, "Hz");
%     CLLCSpec.qualityFactor = 0.8;
%     CLLCSpec.k = 3;
%     CLLCSpec.mosfetDrainSourceCapacitance = simscape.Value(200e-12, "F");
%     CLLCSpec.a = 1;
%     CLLCSpec.b = 1;
%     CLLCSpec.turnratioVoltageLevel = "Average Output and Input Voltage";
%     CLLCSpec.magCurrentPercentofInputCurrent = 40;
%     CLLCSpec.minimumAllowedDeadTime = simscape.Value(200e-9, "s");
%     CLLCSpec.maximumAllowedDeadTime = simscape.Value(800e-9, "s");
%     CLLCSpec.Rco = 0.01;
%     CLLCSpec.R1 = 0.02;
%     CLLCSpec.R2 = 0.02;
%     CLLCSpec.Rcr1 = 0.01;
%     CLLCSpec.Rcr2 = 0.01;
%     [designTable, CLLCDesign] = designCLLCFullBridgeConverter(CLLCSpec);

% Copyright 2025-2026 The MathWorks, Inc.

arguments
    CLLCSpec struct
    options.N2 (1,1) {mustBePositive, mustBeInteger} = 10; % Secondary winding turns
    options.TurnsRatio {mustBeScalarOrEmpty, mustBePositive} = []; % Specified turns ratio N1/N2
    options.DisplayTableFlag (1,1) {mustBeNumericOrLogical} = true; % Display the table
end

avgInputVoltage = (CLLCSpec.minInputVoltage+CLLCSpec.maxInputVoltage)/2;
avgOutputVoltage = (CLLCSpec.minOutputVoltage+CLLCSpec.maxOutputVoltage)/2;
CLLCDesign.minGainFwd = CLLCSpec.minOutputVoltage/CLLCSpec.maxInputVoltage;
CLLCDesign.maxGainFwd = CLLCSpec.maxOutputVoltage/CLLCSpec.minInputVoltage;
CLLCDesign.avgGainFwd = avgOutputVoltage/avgInputVoltage;

CLLCDesign.maxGainRev = CLLCSpec.maxInputVoltage/CLLCSpec.minOutputVoltage;
CLLCDesign.minGainRev = CLLCSpec.minInputVoltage/CLLCSpec.maxOutputVoltage;
CLLCDesign.avgGainRev = avgInputVoltage/avgOutputVoltage;

% The turns ratio either comes from the TurnsRatio option or follows from the voltage pair
% you selected, but the transformer needs integer winding counts, so the ratio the
% converter realizes is N1/N2. Both are needed below: the designed
% (unrounded) ratio sizes the tank and the windings, the realized ratio is what every
% secondary-to-primary referral must use. The strategy lives in computeCLLCTurnsRatio so
% that this function and computeCLLCMagnetizingCurrentLimit cannot disagree about it.
turnsRatioData = computeCLLCTurnsRatio(CLLCSpec, N2=options.N2, TurnsRatio=options.TurnsRatio);
designTurnsRatio = turnsRatioData.designTurnsRatio;
CLLCDesign.N1 = turnsRatioData.N1;
CLLCDesign.N2 = turnsRatioData.N2;
CLLCDesign.turnsRatio = turnsRatioData.realizedTurnsRatio;

% The tank is sized before the windings are rounded, so the effective AC load resistance
% uses the designed ratio. Using the realized ratio here instead would change L1, C1, Lm
% and the dead time, that is, it would redesign the tank rather than refer to it.
Ro = avgOutputVoltage^2/CLLCSpec.ratedOutputPower;
ReffectiveFwd = Ro*8*designTurnsRatio^2/pi^2;
LbyC = CLLCSpec.qualityFactor^2*ReffectiveFwd^2;
C1 = 1/(2*pi*sqrt(LbyC)*CLLCSpec.resonantFrequency);
L1 = LbyC*C1;
Lm = CLLCSpec.k*L1;

% Dead time: the interval the peak magnetizing current needs to move the charge stored on
% the device output capacitances of one bridge leg pair, with a 20 % margin, then clamped
% to the window the hardware allows. A dead time below minimumAllowedDeadTime cannot be
% produced by the gate drive and processor; one above maximumAllowedDeadTime wastes too
% much of the switching period and distorts the tank waveforms.
%
%     Tdead = margin*8*Cparasitic*Lm*max(fr,fsMax)
%
% The peak magnetizing current is Vin/(4*Lm*max(fr,fs)), so it is smallest at the highest
% switching frequency in service. That is the worst case for soft switching, which is why
% maxSwitchingFrequency and not the resonant frequency alone sizes the dead time. The
% derivation is in estimateCLLCMaximumMagnetizingInductance.
resonantFrequencyHz = value(CLLCSpec.resonantFrequency, "Hz");
if isfield(CLLCSpec, "maxSwitchingFrequency")
    zvsSizingFrequency = max(resonantFrequencyHz, value(CLLCSpec.maxSwitchingFrequency, "Hz"));
else
    zvsSizingFrequency = resonantFrequencyHz;
end
deadTimeComputed = cllcZVSDeadTimeMarginFactor()*8* ...
    value(CLLCSpec.mosfetDrainSourceCapacitance, "F")*value(Lm, "H")*zvsSizingFrequency;
minAllowedDeadTime = value(CLLCSpec.minimumAllowedDeadTime, "s");
maxAllowedDeadTime = value(CLLCSpec.maximumAllowedDeadTime, "s");
CLLCDesign.deadTime = min(max(deadTimeComputed, minAllowedDeadTime), maxAllowedDeadTime);
deadTimeExceedsMax = deadTimeComputed > maxAllowedDeadTime;
% Kept so the caller can see what the clamp did, and at which frequency.
CLLCDesign.deadTimeForSoftSwitching = deadTimeComputed;
CLLCDesign.zvsSizingFrequency = zvsSizingFrequency;

% L2 and C2 are referred through the REALIZED turns ratio, not the ideal one. The
% ratios a = N^2*L2/L1 and b = C2/(N^2*C1) are the symmetry knobs the CLLC design
% rests on, and the model refers the secondary through its integer winding counts.
% Referring with the ideal ratio here would move the realized a and b several percent
% off the requested values. L2*C2 = a*b*L1*C1 regardless, so the secondary
% resonant frequency f2 does not depend on which ratio is used.
L2 = CLLCSpec.a*L1/CLLCDesign.turnsRatio^2;
C2 = CLLCSpec.b*C1*CLLCDesign.turnsRatio^2;


% Estimating output filter capacitance
% Assume a 1% voltage dip after supplying current for 15 cycles
outputCharge = 15*CLLCSpec.ratedOutputPower/(CLLCSpec.resonantFrequency*avgOutputVoltage);
Co = outputCharge/(0.01*avgOutputVoltage);

CLLCDesign.Co = Co.value;
CLLCDesign.C1 = C1.value;
CLLCDesign.L1 = L1.value;
CLLCDesign.C2 = C2.value;
CLLCDesign.L2 = L2.value;
CLLCDesign.Lm = Lm.value;
CLLCDesign.resonantFreq = CLLCSpec.resonantFrequency.value;
CLLCDesign.Cparasitic = CLLCSpec.mosfetDrainSourceCapacitance.value;
CLLCDesign.Llk1 = CLLCDesign.L1;
CLLCDesign.Llk2 = CLLCDesign.L2;

% Parasitic resistances
CLLCDesign.Rco = CLLCSpec.Rco; % Output filter capacitor ESR (Ohm)
CLLCDesign.R1 = CLLCSpec.R1; % Transformer primary resistance (Ohm)
CLLCDesign.R2 = CLLCSpec.R2; % Transformer secondary resistance (Ohm)
CLLCDesign.Rcr1 = CLLCSpec.Rcr1; % Primary resonant capacitor resistance (Ohm)
CLLCDesign.Rcr2 = CLLCSpec.Rcr2; % Secondary resonant capacitor resistance (Ohm)

% Peak magnetizing current, in both power-flow directions.
%
% Lm is a winding-1 (primary) inductance, so the voltage driving it must be
% primary-referred. At the series resonance f1 the tank arm on the driving side is
% nearly a short circuit, so the full square wave of the driving bridge appears across
% Lm, and the magnetizing current ramps linearly over a quarter cycle to its PEAK value.
%
% Forward: the primary bridge drives, so the amplitude is the input voltage.
% Reverse: the secondary bridge drives, so the amplitude is the output voltage referred
% to the primary through the REALIZED turns ratio. With a > 0 and b > 0 close to unity
% the secondary arm is the mirror of the primary arm and is equally close to a short at
% f1, so the same argument applies.
%
% The two directions differ only through turnsRatio*avgOutputVoltage versus
% avgInputVoltage, that is, only by the integer-winding rounding of the turns ratio.
% Whichever is larger is the one that gates the design.
VLmFwd = value(avgInputVoltage, "V");
VLmRev = CLLCDesign.turnsRatio*value(avgOutputVoltage, "V");
CLLCDesign.Im_peakFwd = VLmFwd/(CLLCDesign.Lm*4*CLLCDesign.resonantFreq);
CLLCDesign.Im_peakRev = VLmRev/(CLLCDesign.Lm*4*CLLCDesign.resonantFreq);
CLLCDesign.Im_peak = max(CLLCDesign.Im_peakFwd, CLLCDesign.Im_peakRev);

% Magnetizing current limit, evaluated separately per direction.
%
% magCurrentPercentofInputCurrent limits the circulating magnetizing current relative to
% the rated current of the port that is sourcing power, and that port swaps when the power
% flow reverses. Forward, the source is the primary at avgInputVoltage, so the rated source
% current is P/avgInputVoltage and it is already a primary current, directly comparable
% with Im. Reverse, the source is the secondary at avgOutputVoltage, so the rated source
% current is P/avgOutputVoltage - a SECONDARY current. Im flows in Lm on the primary, so
% one of the two must be referred through the transformer before they can be compared.
% Referring the secondary source current to the primary divides it by the realized turns
% ratio, which gives P/(turnsRatio*avgOutputVoltage) = P/VLmRev.
%
% Referring the other way instead - comparing turnsRatio*Im against P/avgOutputVoltage on
% the secondary - yields exactly the same ratio, so the choice of reference side does not
% matter. What does matter is that the reverse limit is NOT P/avgInputVoltage: using the
% primary current in both directions charges the reverse case against a port that is
% sinking rather than sourcing.
%
% The result is symmetric: ImRatio = VLm^2/(4*fr*Lm*(magCurrentPercent/100)*P) in each
% direction, so the two differ by (VLmRev/VLmFwd)^2, that is, only by the integer-winding
% rounding of the turns ratio, squared. An exact winding pair makes them identical.
ratedOutputPower = value(CLLCSpec.ratedOutputPower, "W");
CLLCDesign.ratedSourceCurrentFwd = ratedOutputPower/VLmFwd;
CLLCDesign.ratedSourceCurrentRev = ratedOutputPower/VLmRev;
CLLCDesign.ImLimitFwd = CLLCSpec.magCurrentPercentofInputCurrent*CLLCDesign.ratedSourceCurrentFwd/100;
CLLCDesign.ImLimitRev = CLLCSpec.magCurrentPercentofInputCurrent*CLLCDesign.ratedSourceCurrentRev/100;
CLLCDesign.ImRatioFwd = CLLCDesign.Im_peakFwd/CLLCDesign.ImLimitFwd;
CLLCDesign.ImRatioRev = CLLCDesign.Im_peakRev/CLLCDesign.ImLimitRev;
CLLCDesign.ImRatio = max(CLLCDesign.ImRatioFwd, CLLCDesign.ImRatioRev);
% The worst-case limit, reported alongside CLLCDesign.Im_peak.
if CLLCDesign.ImRatioRev >= CLLCDesign.ImRatioFwd
    CLLCDesign.ImLimit = CLLCDesign.ImLimitRev;
else
    CLLCDesign.ImLimit = CLLCDesign.ImLimitFwd;
end

ComponentName{1} = 'Transformer turns ratio (N1/N2)';
Value(1) = round(CLLCDesign.N1/CLLCDesign.N2,2);
Unit{1} = '-';
ComponentName{2} = 'Magnetizing inductance (Lm)';
Value(2) = CLLCDesign.Lm*1e6;
Unit{2} = 'uH';
ComponentName{3} = 'Series primary resonant inductance (L1)';
Value(3) = CLLCDesign.L1*1e6;
Unit{3} = 'uH';
ComponentName{4} = 'Series secondary resonant inductance (L2)';
Value(4) = CLLCDesign.L2*1e6;
Unit{4} = 'uH';
ComponentName{5} = 'Resonant primary capacitance (C1)';
Value(5) = CLLCDesign.C1*1e6;
Unit{5} = 'uF';
ComponentName{6} = 'Resonant secondary capacitance (C2)';
Value(6) = CLLCDesign.C2*1e6;
Unit{6} = 'uF';
ComponentName{7} = 'Output DC filter capacitance (Co)';
Value(7) = CLLCDesign.Co*1e6;
Unit{7} = 'uF';
ComponentName{8} = 'Resonant frequency (f1)';
Value(8) = CLLCDesign.resonantFreq*1e-3;
Unit{8} = 'kHz';
ComponentName{9} = 'Peak magnetizing current, forward (Im)';
Value(9) = CLLCDesign.Im_peakFwd;
Unit{9} = 'A';
ComponentName{10} = 'Peak magnetizing current, reverse (Im)';
Value(10) = CLLCDesign.Im_peakRev;
Unit{10} = 'A';
ComponentName{11} = 'Peak magnetizing current limit, forward (Im limit)';
Value(11) = CLLCDesign.ImLimitFwd;
Unit{11} = 'A';
ComponentName{12} = 'Peak magnetizing current limit, reverse (Im limit)';
Value(12) = CLLCDesign.ImLimitRev;
Unit{12} = 'A';
ComponentName{13} = 'Dead time (Td)';
Value(13) = CLLCDesign.deadTime*1e9;
Unit{13} = 'ns';

tableHeaderNames = {'Parameter', 'Value', 'Unit'};
designTable = table(char(ComponentName'),Value', char(Unit'),'VariableNames',tableHeaderNames);
if options.DisplayTableFlag == true
    disp(table(designTable,'VariableNames',"CLLC Converter Estimated Design Parameters"));
    if deadTimeExceedsMax
        warning("designCLLCFullBridgeConverter:DeadTimeExceedsMax", ...
            "Computed dead time (%.1f ns) exceeds the maximum allowed dead time (%.1f ns). " + ...
            "Reduce the magnetizing inductance or increase maximumAllowedDeadTime.", ...
            deadTimeComputed*1e9, maxAllowedDeadTime*1e9);
    end
    if CLLCDesign.ImRatio > 1
        if CLLCDesign.ImRatioRev >= CLLCDesign.ImRatioFwd
            bindingSourceCurrent = CLLCDesign.ratedSourceCurrentRev;
        else
            bindingSourceCurrent = CLLCDesign.ratedSourceCurrentFwd;
        end
        warning("designCLLCFullBridgeConverter:MagnetizingCurrentExceedsLimit", ...
            "Peak magnetizing current (%.2f A %s) is %.2f times the limit of %.2f A " + ...
            "(%.0f %% of the %.2f A primary-referred rated current of the sourcing port " + ...
            "in that direction). Increase the magnetizing inductance by raising k or the " + ...
            "quality factor, or relax magCurrentPercentofInputCurrent.", ...
            CLLCDesign.Im_peak, worseDirection(CLLCDesign), CLLCDesign.ImRatio, ...
            CLLCDesign.ImLimit, CLLCSpec.magCurrentPercentofInputCurrent, ...
            bindingSourceCurrent);
    end
end
end


% Name the power-flow direction that produces the larger peak magnetizing current, so
% the warning says which one it is.
function directionName = worseDirection(CLLCDesign)
    if CLLCDesign.Im_peakRev >= CLLCDesign.Im_peakFwd
        directionName = "in reverse";
    else
        directionName = "in forward";
    end
end