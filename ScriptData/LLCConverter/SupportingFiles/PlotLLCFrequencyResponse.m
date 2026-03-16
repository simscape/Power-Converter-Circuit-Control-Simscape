%   This script linearizes the LLC resonant converter plant by estimating its
%   frequency response through the injection of a sinestream disturbance at the
%   switching frequency. The script uses Simulink Control Design tools to set up
%   linearization points, generates a sinestream input, and estimates the Bode
%   response (magnitude and phase) of the converter.
%
%   Main Steps:
%     1. Loads the specified Simulink model for frequency response analysis.
%     2. Sets up linearization input and output points.
%     3. Converts all key parameters (frequency, voltage, resistance) to base units.
%     4. Calculates sampling and simulation parameters for accurate frequency response estimation.
%     5. Finds the steady-state operating point at the switching frequency.
%     6. Defines and injects a sinestream disturbance input.
%     7. Estimates the frequency response using frestimate.
%     8. Plots both the time-domain output voltage waveform and the Bode magnitude/phase plots.
%
%   Required Workspace Variables:
%     freqRespModelName      - Name of the Simulink model (string/char)
%     switchingFrequency     - Switching frequency (simscape.Value or numeric, Hz)
%     inputVoltage           - Input voltage (simscape.Value or numeric, V)
%     frequencyVector        - Frequency vector for estimation (simscape.Value or numeric, Hz)
%     Rload                  - Load resistance (simscape.Value or numeric, Ohm)
%     numberPeriod           - Number of periods for each frequency (numeric vector)
%     steadyStateTime        - Time to reach steady-state (simscape.Value or numeric, s)
%     LLCDesign              - Struct with resonant frequency and design parameters
%     sinestreamMagnitude    - Amplitude of injected sinestream input (numeric)
%
%   Output:
%     - Time-domain plot of converter output voltage during frequency sweep.
%     - Bode plot (magnitude and phase) of the estimated frequency response.
%
%   Notes:
%     - Requires Simulink Control Design Toolbox.
%     - The model must be parameterized to accept the variables as set above.
%     - Make sure to configure linearization points (input/output) in the model.


% Copyright 2025-2026 The MathWorks, Inc.

% Load the linearization model
load_system(freqRespModelName);

% Define linearization ports
% Input port
inputBlock = strcat(freqRespModelName, "/finput");
inputPort = 1;
inputType = 'openinput';

% Output port
outputBlock = strcat(freqRespModelName, "/Vomeas");
outputPort = 1;
outputType = 'openoutput';

% Creating linearization input-output points
io(1) = linio(inputBlock,inputPort,inputType);
io(2) = linio(outputBlock,outputPort,outputType);

% Set the linearization points into the model
setlinio(freqRespModelName,io);

% Convert simscape parameters into required units
switchingFrequency_Hz   = convert(switchingFrequency,"Hz");
inputVoltage_V          = convert(inputVoltage,"V");
frequencyVector_Hz = convert(frequencyVector,"Hz") ;
Rload_Ohm = convert(Rload, "Ohm");

% Minimum number of period
numberPeriod(numberPeriod<7) = 7; 

steadyStateTime_s = convert(steadyStateTime, "s");

% Finding statedy state operating point at switching frequency
freqOffsetPU = (switchingFrequency_Hz.value-LLCDesign.resonantFreq)/LLCDesign.resonantFreq;
op = findop(freqRespModelName,steadyStateTime_s.value);

% Calculate samples per period and ramp period
maxCircuitFrequency = max(switchingFrequency_Hz.value,LLCDesign.resonantFreq);
sampleTimeRequired = 1./(10*(frequencyVector_Hz.value+maxCircuitFrequency));
samplesPerPeriod = ceil(1./(sampleTimeRequired.*frequencyVector_Hz.value));
rampPeriod = ceil(0.1*numberPeriod);
settlingPeriods = ceil(0.7*numberPeriod);

% Maximum frequency
maxFreq = max([frequencyVector_Hz(end).value,switchingFrequency_Hz.value,LLCDesign.resonantFreq]);
% Sampling time
Ts = 1/(10*maxFreq);

% Define sinestream disturbance
input = frest.Sinestream('Frequency',2*pi*frequencyVector_Hz.value,...
    "RampPeriods",rampPeriod,"SamplesPerPeriod",...
    samplesPerPeriod,"SettlingPeriods",settlingPeriods,...
    "NumPeriods",numberPeriod,"Amplitude",...
    sinestreamMagnitude,"SimulationOrder","OneAtATime");


% Frequency response estimation
[systemFreqRes, simout] = frestimate(freqRespModelName,op,io,input);

% Bode plot
[mag,phase,wout] = bode(systemFreqRes);
bodeMagnitude = reshape(mag,[1,length(mag)]);
bodePhase = reshape(phase,[1,length(phase)]);

% Plotting time domain waveform
figure('Name','LLCResonantConverterFullBridgeControllerTimeResponse');

llcFreqRespTime = simout{1,1}.Time;
llcFreqOutputVoltage = simout{1,1}.Data;

plot(llcFreqRespTime,llcFreqOutputVoltage,'LineWidth',2);
xlabel('time (s)','FontSize',12);
ylabel('V_{out} (V)','FontSize',12);
title('LLC Converter Output Voltage','FontSize',13);
grid on
box on
xlim([0,max(llcFreqRespTime)]);
set(gcf, 'Position',  [400, 300, 800, 700]);

% Plotting bode plot
figure('Name','LLCResonantConverterFullBridgeControllerFrequencyResponse');

subplot(2,1,1);
semilogx(wout/(2*pi),20*log10(bodeMagnitude),'LineWidth',2);
hold on
xlabel('Frequency (Hz)','FontSize',12);
ylabel('Magnitude (dB)','FontSize',12);
title('Magnitude Bode Plot','FontSize',13);
grid on
box on

subplot(2,1,2);
semilogx(wout/(2*pi),bodePhase,'LineWidth',2);
hold on
xlabel('Frequency (Hz)','FontSize',12);
ylabel('Phase (deg)','FontSize',12);
title('Phase Bode Plot','FontSize',13);
grid on
box on
sgtitle("LLC Converter Frequency to Output Voltage Response" ,'FontSize',13);
set(gcf, 'Position',  [400, 300, 800, 700]);







