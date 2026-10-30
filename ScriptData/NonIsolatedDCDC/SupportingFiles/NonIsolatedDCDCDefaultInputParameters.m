% Non-isolated DC-DC converter default input parameters

% Copyright 2026 The MathWorks, Inc.

% To size another topology, set DCDCTopology before running: "Buck" | "Synchronous Buck" |
% "Boost" | "Synchronous Boost" | "Buck-Boost" | "Synchronous Buck-Boost"
if ~exist('DCDCTopology','var')
    DCDCTopology = "Synchronous Boost";
end
nonIsolatedDCDCSpec.topology = DCDCTopology;

nonIsolatedDCDCSpec.minInputVoltage = simscape.Value(180, "V");
nonIsolatedDCDCSpec.nomInputVoltage = simscape.Value(200, "V");
nonIsolatedDCDCSpec.maxInputVoltage = simscape.Value(220, "V");

nonIsolatedDCDCSpec.outputVoltage    = simscape.Value(400, "V");
nonIsolatedDCDCSpec.ratedPower       = simscape.Value(1500, "W");

nonIsolatedDCDCSpec.switchingFrequency = simscape.Value(100e3, "Hz");
nonIsolatedDCDCSpec.inductorCurrentRippleFraction = 1/3;
nonIsolatedDCDCSpec.outputVoltageRippleFraction   = 0.01;

nonIsolatedDCDCSpec.loadStepFraction                 = 0.50;
nonIsolatedDCDCSpec.loadStepVoltageDeviationFraction = 0.02;

nonIsolatedDCDCSpec.voltageLoopCrossoverFrequency = simscape.Value(200, "Hz");   % sizes Cout

nonIsolatedDCDCSpec.conversionRatioMargin = 1.05;
nonIsolatedDCDCSpec.deviceVoltageMargin   = 1.30;

nonIsolatedDCDCSpec.inductorESR  = simscape.Value(0.05, "Ohm");
nonIsolatedDCDCSpec.capacitorESR = simscape.Value(0.02, "Ohm");

[designTable, nonIsolatedDCDCDesign] = designNonIsolatedDCDCConverter(nonIsolatedDCDCSpec, ...
    "DisplayTableFlag", false);

% Operating point
inputDCVoltage   = nonIsolatedDCDCDesign.inputVoltage;
voltageReference = nonIsolatedDCDCDesign.outputVoltage;
outputLoadPower  = nonIsolatedDCDCDesign.ratedPower;
simulationTime   = simscape.Value(20e-3, "s");   % 4 ms soft start plus steady state

Vin_dc  = inputDCVoltage.value;                        % V
Vref    = voltageReference.value;                      % V
Rload_R = nonIsolatedDCDCDesign.loadResistance.value;  % Ohm

switchingFrequency = nonIsolatedDCDCDesign.switchingFrequency;

% Controller tuning. The voltage-loop crossover comes from the design, not from here
nonIsolatedDCDCControllerSpec.currentLoopBandwidthRatio = 1/20;   % crossover as Fsw*ratio
nonIsolatedDCDCControllerSpec.currentLoopZeroRatio      = 1/10;   % PI zero over that crossover
nonIsolatedDCDCControllerSpec.voltageLoopDampingRatio   = 0.8;

nonIsolatedDCDCControllerSpec.currentSampleTimeRatio      = 1;    % ratio*(1/Fsw)
nonIsolatedDCDCControllerSpec.voltageToCurrentSampleRatio = 10;

nonIsolatedDCDCControllerSpec.currentLimitPu    = 1.5;
nonIsolatedDCDCControllerSpec.currentLimitMinPu = 0;

nonIsolatedDCDCControllerSpec.softStartTime = simscape.Value(4e-3, "s");

nonIsolatedDCDCControllerSpec.deadTime = simscape.Value(100e-9, "s");
nonIsolatedDCDCControllerSpec.dutyMax  = 0.95;
nonIsolatedDCDCControllerSpec.dutyMin  = 0.02;
nonIsolatedDCDCControllerSpec.modulatorSampleTime = simscape.Value(1e-8, "s"); % fixed step only

nonIsolatedDCDCControllerSpec.gateVoltageOn  = simscape.Value(15, "V");
nonIsolatedDCDCControllerSpec.gateVoltageOff = simscape.Value(0, "V");

[controllerTable, nonIsolatedDCDCController] = designNonIsolatedDCDCController( ...
    nonIsolatedDCDCDesign, nonIsolatedDCDCControllerSpec, "DisplayTableFlag", false);
