% LLC Converter default input parameters

% Copyright 2025-2026 The MathWorks, Inc.
modelName = "LLCResonantConverterFullBridge";
LLCSpec.LLCModelOption = "Full-Bridge";
LLCSpec.minInputVoltage =  simscape.Value(380,"V");
LLCSpec.maxInputVoltage =  simscape.Value(400,"V");
LLCSpec.minOutputVoltage = simscape.Value(350,"V");
LLCSpec.maxOutputVoltage = simscape.Value(400,"V");
LLCSpec.ratedOutputPower = simscape.Value(10000,"W");
LLCSpec.resonantFrequency = simscape.Value(100e3,"Hz");
LLCSpec.mosfetDrainSourceCapacitance = simscape.Value(200e-12,"F"); % MOSFET Coss
LLCSpec.inductanceDistributionFactor = 0.95; % h
LLCSpec.turnratioVoltageLevel = "Max Output Volttage and Min Input Voltage"; % voltage pair sizing the turns ratio
LLCSpec.magCurrentPercentofInputCurrent = 40; % % of rated input current at resonance
LLCSpec.minimumAllowedDeadTime = simscape.Value(200e-9,"s"); % processor/device floor
LLCSpec.maximumAllowedDeadTime = simscape.Value(0.08/LLCSpec.resonantFrequency.value,"s");

LLCSpec.Rco = 0.02; % output capacitor ESR (Ohm)
LLCSpec.R1 = 0.01;  % transformer primary resistance (Ohm)
LLCSpec.R2 = 0.01;  % transformer secondary resistance (Ohm)
LLCSpec.Rcr = 1e-4; % resonant capacitor resistance (Ohm)
LLCSpec.qualityFactor = 0.45;
LLCSpec.k = 13; % (Lm+Lr)/Lr
% Turns ratio N1/N2 set directly, the value the estimate script selects. Leave it empty to
% derive the ratio from the voltage specification instead.
specifiedTurnsRatio = 0.9595;
[designTable, LLCDesign]  = designLLCFullBridgeConverter(LLCSpec, ...
    TurnsRatio=specifiedTurnsRatio,DisplayTableFlag=false);
nominalOutputVoltage = (LLCSpec.minOutputVoltage.value+LLCSpec.maxOutputVoltage.value)/2;
LLCController.Kp = 3.5;
LLCController.Ki = 5;
LLCController.Kd = 0;
LLCController.Ts = 1e-6; % s
frequencyRange.minFreq = 80e3;
frequencyRange.maxFreq = 200e3;
llcCompensator.numSDomain = [1 5.6532e+03    5.6475e+07];
llcCompensator.denSDomain = [1 8.4698e+04 0];
llcCompensator.numZDomain = [1.0000    -1.9946 0.9946];
llcCompensator.denZDomain = [1 -1.9188 0.9188];
llcCompensator.wn = 1.1223e+03;
llcCompensator.Ki = 1;
llcCompensator.constantVCOGain = 1;
llcCompensator.resonantFrequency = LLCSpec.resonantFrequency.value;
llcCompensator.minPUfrequency = 0.8;
llcCompensator.maxPUfrequency = 2;
llcCompensator.deadTime = 2.5e-7;
LLCController.vcoGainVec = [1,1.2]; % VCO gain (V per pu frequency)
freqOffsetPU = 0; % pu
Rload = 10; % Ohm
switchingFrequency = 100e3; % Hz, linearization point
inputVoltage = 380; % V
primaryMOSFETBlock =  "MOSFET (Ideal, Switching) without Thermal";
secondaryDiodeBlock = "Ideal Diode";
Rload_Ohm = simscape.Value(20.6, "Ohm");
inputVoltage_V = simscape.Value(380, "V");
primaryBridgeOption = LLCSpec.LLCModelOption; % primary inverter of the frequency response model
primaryBridgeTopologyFactor = llcPrimaryBridgeTopologyFactor(primaryBridgeOption);
