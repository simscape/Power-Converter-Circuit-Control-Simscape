function [designTable, LLCDesign] = designLLCFullBridgeConverter(LLCSpec,options)
%   This function estimates suitable LLC resonant tank parameters for a full-bridge
%   LLC converter based on the provided electrical specifications, quality factor,
%   and inductance ratio. The function also computes related design values such as
%   transformer turns ratio, magnetizing and resonant inductance's, resonant capacitance,
%   dead time, and output filter capacitance. Dead time is kept at a
%   minimum of 2 % of the resonant cycle time.
%
%   Inputs:
%     LLCSpec   Struct containing LLC converter specifications. Required fields:
%                 - minInputVoltage: Minimum input voltage (V)
%                 - maxInputVoltage: Maximum input voltage (V)
%                 - minOutputVoltage: Minimum output voltage (V)
%                 - maxOutputVoltage: Maximum output voltage (V)
%                 - ratedOutputPower: Rated output power (W)
%                 - resonantFrequency: Resonant frequency (simscape.Value or numeric, Hz)
%                 - qualityFactor: Quality factor (dimensionless)
%                 - k: Lm/Lr ratio (dimensionless)
%                 - mosfetDrainSourceCapacitance: MOSFET Cds (simscape.Value or numeric, F)
%                 - inductanceDistributionFactor: Fraction of Lr on primary side (0-1)
%                 - Rco: Output filter capacitor ESR (Ohm)
%                 - R1: Transformer primary resistance (Ohm)
%                 - R2: Transformer secondary resistance (Ohm)
%                 - Rcr: Resonant capacitor ESR (Ohm)
%
%     options   Structure with optional field:
%                 - DisplayTableFlag: Logical. If true, displays the design table.
%                   (default: true)
%
%   Outputs:
%     designTable   Table summarizing estimated design parameters and values.
%     LLCDesign     Structure containing calculated component values and design details.
%
%   Method:
%     - Uses average values of input and output voltages for calculations.
%     - Calculates transformer turns ratio, effective load resistance, resonant tank
%       components (Lr, Cr, Lm), dead time, and output filter capacitance.
%     - Estimates peak-peak magnetizing current and other key converter parameters.
%     - Assembles results into a summary table for convenient review.
%
%   Example:
%     LLCSpec.minInputVoltage = 380;
%     LLCSpec.maxInputVoltage = 420;
%     LLCSpec.minOutputVoltage = 48;
%     LLCSpec.maxOutputVoltage = 54;
%     LLCSpec.ratedOutputPower = 1000;
%     LLCSpec.resonantFrequency = simscape.Value(100e3, "Hz");
%     LLCSpec.qualityFactor = 0.8;
%     LLCSpec.k = 3;
%     LLCSpec.mosfetDrainSourceCapacitance = simscape.Value(200e-12, "F");
%     LLCSpec.inductanceDistributionFactor = 0.5;
%     LLCSpec.Rco = 0.01;
%     LLCSpec.R1 = 0.02;
%     LLCSpec.R2 = 0.02;
%     LLCSpec.Rcr = 0.01;
%     [designTable, LLCDesign] = designLLCFullBridgeConverter(LLCSpec);

% Copyright 2025-2026 The MathWorks, Inc.

arguments
    LLCSpec struct
    options.DisplayTableFlag (1,1) {mustBeNumericOrLogical} = true; % Display the table
end

avgInputVoltage = (LLCSpec.minInputVoltage+LLCSpec.maxInputVoltage)/2;
avgOutputVoltage = (LLCSpec.minOutputVoltage+LLCSpec.maxOutputVoltage)/2;
LLCDesign.minGain = LLCSpec.minOutputVoltage/LLCSpec.maxInputVoltage;
LLCDesign.maxGain = LLCSpec.maxOutputVoltage/LLCSpec.minInputVoltage;
LLCDesign.avgGain = avgOutputVoltage/avgInputVoltage;

turnsRatio = avgInputVoltage/avgOutputVoltage;
Ro = avgOutputVoltage^2/LLCSpec.ratedOutputPower;
Reffective = Ro*8*turnsRatio^2/pi^2;
LbyC = LLCSpec.qualityFactor^2*Reffective^2;
C = 1/(2*pi*sqrt(LbyC)*LLCSpec.resonantFrequency);
L = LbyC*C;
Lm = LLCSpec.k*L-L;
deadTimeInitial = 1.2*16*LLCSpec.mosfetDrainSourceCapacitance.value*Lm.value*LLCSpec.resonantFrequency.value;
LLCDesign.deadTime = max(deadTimeInitial, 0.02*1/LLCSpec.resonantFrequency.value);

% Estimating output filter capacitance
% Assuming voltage dip by 1% after supplying current for 5 cycle
outputCharge = 10*LLCSpec.ratedOutputPower/(LLCSpec.resonantFrequency*avgOutputVoltage);
Co = outputCharge/(0.01*avgOutputVoltage);

LLCDesign.Co = Co.value;
LLCDesign.C = C.value;
LLCDesign.L = L.value;
LLCDesign.Lm = Lm.value;
LLCDesign.N2 = 10;
LLCDesign.N1 = round(turnsRatio*LLCDesign.N2);
LLCDesign.resonantFreq = LLCSpec.resonantFrequency.value;
LLCDesign.Cparasitic = LLCSpec.mosfetDrainSourceCapacitance.value;
LLCDesign.Llk1 = LLCSpec.inductanceDistributionFactor*LLCDesign.L;
LLCDesign.Llk2 = (1-LLCSpec.inductanceDistributionFactor)*LLCDesign.L/...
    (LLCDesign.N1/LLCDesign.N2)^2;

% Getting parasitics
LLCDesign.Rco = LLCSpec.Rco; % Output filter capacitor ESR resistance (Ohm)
LLCDesign.R1 = LLCSpec.R1; % Transformer primary resistance (Ohm)
LLCDesign.R2 = LLCSpec.R2; % Transformer secondary resistance (Ohm)
LLCDesign.Rcr = LLCSpec.Rcr; % Resonant capacitor resistance (Ohm)

ComponentName{1} = 'Transformer turns ratio (N1)';
Value(1) = round(LLCDesign.N1/LLCDesign.N2,2);
Unit{1} = '1';
ComponentName{2} = 'Magnetizing inductance (Lm)';
Value(2) = LLCDesign.Lm*1e6;
Unit{2} = 'uH';
ComponentName{3} = 'Series resonant inductance (Lr)';
Value(3) = LLCDesign.L*1e6;
Unit{3} = 'uH';
ComponentName{4} = 'Resonant capacitance (Cr)';
Value(4) = LLCDesign.C*1e6;
Unit{4} = 'uF';
ComponentName{5} = 'Transformer primary Leakage inductance (Llk1)';
Value(5) = LLCDesign.Llk1*1e6;
Unit{5} = 'uH';
ComponentName{6} = 'Transformer secondary leakage inductance (Llk2)';
Value(6) = LLCDesign.Llk1*1e6;
Unit{6} = 'uH';
ComponentName{7} = 'Ouput DC filter capacitance (Co)';
Value(7) = LLCDesign.Co*1e6;
Unit{7} = 'uF';
ComponentName{8} = 'Resonant frequency (fr)';
Value(8) = LLCDesign.resonantFreq*1e-3;
Unit{8} = 'kHz';
ComponentName{9} = 'Peak-peak magnetizing current (Im)';
Value(9) = (avgOutputVoltage.value/LLCDesign.Lm)*0.5/LLCSpec.resonantFrequency.value;
Unit{9} = 'A';
ComponentName{10} = 'Dead time (Td)';
Value(10) = LLCDesign.deadTime*1e9;
Unit{10} = 'ns';

tableHeaderNames = {'Parameter', 'Value', 'Unit'};
designTable = table(char(ComponentName'),Value', char(Unit'),'VariableNames',tableHeaderNames);
if options.DisplayTableFlag == true
    disp(table(designTable,'VariableNames',"LLC Converter Estimated Design Parameters"));
end
end