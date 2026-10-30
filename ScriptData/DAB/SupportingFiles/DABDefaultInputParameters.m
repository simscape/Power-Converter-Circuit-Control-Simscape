% Dual-active-bridge converter default input parameters

% Copyright 2026 The MathWorks, Inc.
DABSpec.minInputVoltage  = simscape.Value(700, "V");
DABSpec.maxInputVoltage  = simscape.Value(800, "V");
DABSpec.minOutputVoltage = simscape.Value(450, "V");
DABSpec.maxOutputVoltage = simscape.Value(600, "V");

DABSpec.ratedPower         = simscape.Value(10000, "W");
DABSpec.minSoftSwitchPower = simscape.Value(6000, "W");   % ZVS holds above this
DABSpec.switchingFrequency = simscape.Value(100e3, "Hz");

DABSpec.mosfetOutputCapacitance = simscape.Value(200e-12, "F");   % Coss
DABSpec.peakPowerHeadroom = 1.15;    % SPS peak power over rated
DABSpec.magCurrentFraction = 0.1;    % of rated primary current

DABSpec.minimumAllowedDeadTime = simscape.Value(200e-9, "s");
DABSpec.maximumAllowedDeadTime = simscape.Value(0.08 / DABSpec.switchingFrequency.value, "s");

DABSpec.outputDischargeCycles = 3;
DABSpec.outputVoltageRippleFraction = 0.05;

DABSpec.seriesInductorESR = 0.01;   % Ohm
DABSpec.primaryWindingR   = 0.01;   % Ohm
DABSpec.secondaryWindingR = 0.01;   % Ohm

DABSpec.seriesInductanceOption = "Use transformer leakage inductance";   % or "Use external inductance"
DABSpec.leakageDistributionFactor = 0.8;   % Primary share of the transformer leakage

[designTable, DABDesign] = designDABConverter(DABSpec, ...
    "DisplayTableFlag", false, "DisplaySoftSwitchingTable", false);

% Controller tuning: independent CC and CV loops, each producing the phase shift
DABController.voltageLoopProportionalGain = 0.0075;
DABController.voltageLoopIntegralGain     = 600;

DABController.currentLoopProportionalGain = 0.0008;
DABController.currentLoopIntegralGain     = 600;

DABController.sampleTime    = 1e-7;   % s
DABController.phaseShiftMax = pi / 2;   % rad
DABController.phaseShiftMin = -pi / 2;  % rad

% Operating point: forward power flow, voltage control
inputDCVoltage   = simscape.Value(DABDesign.V1nom.value, "V");
voltageReference = simscape.Value(DABDesign.V2nom.value, "V");
outputLoadPower  = simscape.Value(8000, "W");

Vin_dc  = inputDCVoltage.value;                               % V
Vref    = voltageReference.value;                             % V
Rload_R = voltageReference.value^2 / outputLoadPower.value;   % Ohm

switchingFrequency = DABSpec.switchingFrequency;

DABController.gateVoltage = 15;   % V, applied to the 8-wide gate vector
