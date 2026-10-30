% Boost PFC converter default input parameters

% Copyright 2026 The MathWorks, Inc.
boostPFCSpec.minInputVoltage = simscape.Value(207, "V");
boostPFCSpec.nomInputVoltage = simscape.Value(230, "V");
boostPFCSpec.maxInputVoltage = simscape.Value(264, "V");
boostPFCSpec.lineFrequency   = simscape.Value(50, "Hz");

boostPFCSpec.outputVoltage    = simscape.Value(400, "V");
boostPFCSpec.ratedPower       = simscape.Value(1000, "W");

boostPFCSpec.switchingFrequency = simscape.Value(65e3, "Hz");
boostPFCSpec.inductorCurrentRippleFraction = 0.30;
boostPFCSpec.outputVoltageRippleFraction   = 0.05;

boostPFCSpec.holdUpTime       = simscape.Value(16e-3, "s");
boostPFCSpec.minHoldUpVoltage = simscape.Value(340, "V");

boostPFCSpec.boostVoltageMargin  = 1.05;
boostPFCSpec.deviceVoltageMargin = 1.30;

boostPFCSpec.inductorResistance  = simscape.Value(0.05, "Ohm");
boostPFCSpec.capacitorResistance = simscape.Value(0.01, "Ohm");
boostPFCSpec.initialCapacitorVoltage = boostPFCSpec.outputVoltage; % 0 V to study start-up
boostPFCSpec.bridgeDiodeForwardVoltage = simscape.Value(0.7, "V");

[designTable, boostPFCDesign] = designBoostPFCConverter(boostPFCSpec, ...
    "DisplayTableFlag", false);

% Operating point
acInputRMS       = simscape.Value(boostPFCDesign.nomInputVoltage.value, "V");
lineFrequency    = simscape.Value(boostPFCDesign.lineFrequency.value, "Hz");
voltageReference = simscape.Value(boostPFCDesign.outputVoltage.value, "V");
outputLoadPower  = simscape.Value(boostPFCDesign.ratedPower.value, "W");
simulationTime   = simscape.Value(60e-3, "s");   % three line cycles

VacAmp  = acInputRMS.value * sqrt(2);                         % source peak (V)
Fline   = lineFrequency.value;                                % Hz
Vref    = voltageReference.value;                             % V
Rload_R = voltageReference.value^2 / outputLoadPower.value;   % Ohm
switchingFrequency = boostPFCDesign.switchingFrequency;

% Controller tuning
[controllerTable, boostPFCController] = designBoostPFCController(boostPFCDesign, ...
    PhaseMargin = 60, ...
    CurrentCrossoverRatio = 20, ...
    VoltageCrossoverFrequency = 3, ...
    IrefPeakMaxPu = 1.3, ...
    LoadFraction = outputLoadPower.value / boostPFCDesign.ratedPower.value, ...
    ModulatorGuardTime = 100e-9, ...
    PwmStepsPerPeriod = 200, ...
    GateVoltageOn = 15, GateVoltageOff = 0);
