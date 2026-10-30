% Interleaved boost PFC converter default input parameters

% Copyright 2026 The MathWorks, Inc.
interleavedSpec.minInputVoltage = simscape.Value(207, "V");
interleavedSpec.nomInputVoltage = simscape.Value(230, "V");
interleavedSpec.maxInputVoltage = simscape.Value(264, "V");
interleavedSpec.lineFrequency   = simscape.Value(50, "Hz");

interleavedSpec.outputVoltage    = simscape.Value(400, "V");
interleavedSpec.ratedPower       = simscape.Value(2000, "W");
interleavedSpec.numberOfLegs = 2;

interleavedSpec.switchingFrequency = simscape.Value(65e3, "Hz");   % per leg
interleavedSpec.inductorCurrentRippleFraction = 0.30;              % per leg
interleavedSpec.outputVoltageRippleFraction   = 0.05;

interleavedSpec.holdUpTime       = simscape.Value(16e-3, "s");
interleavedSpec.minHoldUpVoltage = simscape.Value(340, "V");

interleavedSpec.boostVoltageMargin  = 1.05;
interleavedSpec.deviceVoltageMargin = 1.30;

interleavedSpec.inductorResistance  = simscape.Value(0.03, "Ohm");   % per leg
interleavedSpec.capacitorResistance = simscape.Value(0.01, "Ohm");
interleavedSpec.initialCapacitorVoltage = interleavedSpec.outputVoltage; % 0 V to study start-up
interleavedSpec.bridgeDiodeForwardVoltage = simscape.Value(0.7, "V");

[designTable, interleavedDesign] = designInterleavedBoostPFCConverter(interleavedSpec, ...
    "DisplayTableFlag", false);

% Operating point
acInputRMS       = simscape.Value(interleavedDesign.nomInputVoltage.value, "V");
lineFrequency    = simscape.Value(interleavedDesign.lineFrequency.value, "Hz");
voltageReference = simscape.Value(interleavedDesign.outputVoltage.value, "V");
outputLoadPower  = simscape.Value(interleavedDesign.ratedPower.value, "W");
simulationTime   = simscape.Value(60e-3, "s");   % three line cycles

VacAmp  = acInputRMS.value * sqrt(2);                         % source peak (V)
Fline   = lineFrequency.value;                                % Hz
Vref    = voltageReference.value;                             % V
Rload_R = voltageReference.value^2 / outputLoadPower.value;   % Ohm
switchingFrequency = interleavedDesign.switchingFrequency;

% Controller tuning
[controllerTable, interleavedController] = designInterleavedBoostPFCController(interleavedDesign, ...
    PhaseMargin = 60, ...
    CurrentCrossoverRatio = 20, ...
    VoltageCrossoverFrequency = 3, ...
    BalanceCrossoverRatio = 100, ...
    DutyBalanceMax = 0.1, ...
    IrefPeakMaxPu = 1.3, ...
    LoadFraction = outputLoadPower.value / interleavedDesign.ratedPower.value, ...
    ModulatorGuardTime = 100e-9, ...
    PwmStepsPerPeriod = 20, ...
    GateVoltageOn = 15, GateVoltageOff = 0);
