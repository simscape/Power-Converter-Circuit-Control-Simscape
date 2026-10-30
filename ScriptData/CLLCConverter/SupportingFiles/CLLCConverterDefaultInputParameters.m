%%
% CLLC Converter default input parameters

% Copyright 2025-2026 The MathWorks, Inc.
modelName = "CLLCResonantConverter";
CLLCSpec.minInputVoltage =  simscape.Value(380,"V");
CLLCSpec.maxInputVoltage =  simscape.Value(400,"V");
CLLCSpec.minOutputVoltage = simscape.Value(350,"V");
CLLCSpec.maxOutputVoltage = simscape.Value(400,"V");
CLLCSpec.ratedOutputPower = simscape.Value(10000,"W");
CLLCSpec.resonantFrequency = simscape.Value(100e3,"Hz");
% Highest switching frequency in service. The dead time is sized here, not at resonance,
% because the peak magnetizing current falls as the switching frequency rises.
CLLCSpec.maxSwitchingFrequency = simscape.Value(170e3,"Hz");
CLLCSpec.a = 0.99; % close to unity
CLLCSpec.b = 1.01; % close to unity
% Device output capacitance of one switch, as the charge-equivalent value Qoss/Vds. Enter
% Co(tr) from the data sheet, not the small-signal Coss, because the dead time follows from
% the charge the magnetizing current has to move.
CLLCSpec.mosfetDrainSourceCapacitance = simscape.Value(200e-12,"F");
% anchors the turns ratio at the hardest forward operating point, Vout maximum from Vin minimum
CLLCSpec.turnratioVoltageLevel = "Max Output Voltage and Min Input Voltage";
CLLCSpec.magCurrentPercentofInputCurrent = 70; % % of rated primary current at resonance
CLLCSpec.minimumAllowedDeadTime = simscape.Value(200e-9,"s"); % processor/device floor
CLLCSpec.maximumAllowedDeadTime = simscape.Value(0.08/CLLCSpec.resonantFrequency.value,"s");
CLLCSpec.Rco = 0.02;  % output capacitor ESR (Ohm)
CLLCSpec.R1 = 0.01;   % transformer primary resistance (Ohm)
CLLCSpec.R2 = 0.01;   % transformer secondary resistance (Ohm)
CLLCSpec.Rcr1 = 1e-3; % primary resonant capacitor resistance (Ohm)
CLLCSpec.Rcr2 = 1e-3; % secondary resonant capacitor resistance (Ohm)
CLLCSpec.qualityFactor = 0.19;
CLLCSpec.k = 15; % Lm/L1
% Secondary winding turns, the anchor for the integer winding pair. The design function
% defaults this to 10, so it is set here to the value the estimate script uses - otherwise
% the defaults and the estimate script describe different transformers.
secondaryWindingTurns = 29;
% Turns ratio N1/N2 set directly, the value the estimate script selects. Leave it empty to
% derive the ratio from the voltage specification instead.
specifiedTurnsRatio = 1.03;
[designTable, CLLCDesign]  = designCLLCFullBridgeConverter(CLLCSpec, ...
    N2=secondaryWindingTurns,TurnsRatio=specifiedTurnsRatio,DisplayTableFlag=false);
nominalOutputVoltage = (CLLCSpec.minOutputVoltage.value+CLLCSpec.maxOutputVoltage.value)/2;
CLLCController.Kp = 3.5;
CLLCController.Ki = 5;
CLLCController.Kd = 0;
CLLCController.TsCurrent = 1e-6; % s, current controller rate
% Service frequency range of this design, per power-flow direction, measured from its gain curve
% at 0.7 and 1.0 pu load and rounded outward to 0.1 kHz. The fields are the ones
% plotGainCurveCLLCConverter reports, so a range declared here and a range measured from a gain
% curve are interchangeable.
frequencyRange.minFreqFwd = 40.6e3;
frequencyRange.maxFreqFwd = 184.7e3;
frequencyRange.minFreqRev = 38.0e3;
frequencyRange.maxFreqRev = 173.3e3;
CLLCCompensator.numSDomain = [1 1.4630e+03 1.7947e+06];
CLLCCompensator.denSDomain = [1 2.7486e+03 0];
CLLCCompensator.numZDomain = [1.0000 -1.9985 0.9985];
CLLCCompensator.denZDomain = [1 -1.9973 0.9973];
CLLCCompensator.wn = 1.1223e+03;
CLLCCompensator.Ki = 1;
CLLCController.constantVCOGain = 1;
CLLCController.resonantFrequency = CLLCSpec.resonantFrequency.value;
CLLCController.minPUfrequency = 0.6;
CLLCController.maxPUfrequency = 2.015;
CLLCController.deadTime = 2.5e-7;
CLLCController.vcoGainVec = [1,1.2]; % VCO gain (V per pu frequency)
freqOffsetPU = 0; % pu
Rload = 10; % Ohm
switchingFrequency = 100e3; % Hz, linearization point
inputVoltage = 380; % V
% "Ideal Switch" or "MOSFET (Ideal, Switching) with Thermal", which the loss runs select
primaryMOSFETBlock =  "Ideal Switch";
secondaryMOSFETBlock = "Ideal Switch";
Rload_Ohm = simscape.Value(20.6, "Ohm");
inputVoltage_V = simscape.Value(380, "V");
CLLCCompensator.SRCurrentThreshold = 0.5; % A
CLLCCompensator.SRBandwidth = 300e3; % Hz
% numerical snubber, read by this name in the thermal MOSFET reference models
CLLCController.Kpv = 11;
CLLCController.Kiv = 5500;
CLLCController.TsVoltage = 1e-6; % s, outer voltage controller rate
