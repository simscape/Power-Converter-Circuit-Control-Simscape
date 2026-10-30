% Totem-pole boost PFC converter default input parameters

% Copyright 2026 The MathWorks, Inc.
totemPoleSpec.minInputVoltage = simscape.Value(207, "V");
totemPoleSpec.nomInputVoltage = simscape.Value(230, "V");
totemPoleSpec.maxInputVoltage = simscape.Value(264, "V");
totemPoleSpec.lineFrequency   = simscape.Value(50, "Hz");

totemPoleSpec.outputVoltage    = simscape.Value(400, "V");
totemPoleSpec.ratedPower       = simscape.Value(3000, "W");

totemPoleSpec.switchingFrequency = simscape.Value(100e3, "Hz");   % fast leg
totemPoleSpec.inductorCurrentRippleFraction = 0.30;
totemPoleSpec.outputVoltageRippleFraction   = 0.05;

totemPoleSpec.holdUpTime       = simscape.Value(8e-3, "s");
totemPoleSpec.minHoldUpVoltage = simscape.Value(340, "V");

totemPoleSpec.boostVoltageMargin  = 1.05;
totemPoleSpec.deviceVoltageMargin = 1.30;

totemPoleSpec.inductorESR  = simscape.Value(0.02, "Ohm");
totemPoleSpec.capacitorESR = simscape.Value(0.01, "Ohm");
totemPoleSpec.initialCapacitorVoltage = totemPoleSpec.outputVoltage; % 0 V to study start-up
totemPoleSpec.slowLegDiodeForwardVoltage = simscape.Value(0.7, "V");

[designTable, totemPoleDesign] = designTotemPoleBoostPFCConverter(totemPoleSpec, ...
    "DisplayTableFlag", false);

% Operating point
acInputRMS       = simscape.Value(totemPoleDesign.nomInputVoltage.value, "V");
lineFrequency    = simscape.Value(totemPoleDesign.lineFrequency.value, "Hz");
voltageReference = simscape.Value(totemPoleDesign.outputVoltage.value, "V");
outputLoadPower  = simscape.Value(0.5*totemPoleDesign.ratedPower.value, "W");   % half rated power
simulationTime   = simscape.Value(60e-3, "s");   % three line cycles

VacAmp  = acInputRMS.value * sqrt(2);                         % source peak (V)
Fline   = lineFrequency.value;                                % Hz
Vref    = voltageReference.value;                             % V
Rload_R = voltageReference.value^2 / outputLoadPower.value;   % Ohm
switchingFrequency = totemPoleDesign.switchingFrequency;

% Controller tuning
totemPoleControllerSpec.phaseMargin           = 60;
totemPoleControllerSpec.currentCrossoverRatio = 20;
totemPoleControllerSpec.voltageCrossoverFrequency = simscape.Value(3,"Hz");
totemPoleControllerSpec.iRefPeakMaxPu = 1.2;
totemPoleControllerSpec.loadFraction  = outputLoadPower.value / totemPoleDesign.ratedPower.value;
totemPoleControllerSpec.gateVoltageOn  = simscape.Value(15,"V");
totemPoleControllerSpec.gateVoltageOff = simscape.Value(0,"V");

[controllerTable, totemPoleController] = designTotemPoleBoostPFCController(totemPoleDesign, ...
    totemPoleControllerSpec);

totemPoleController.fastLegDeadTime    = 300e-9;   % both edges, every Fsw period (s)
totemPoleController.slowLegTurnOnDelay = 10e-6;   % after the zero crossing (s)
