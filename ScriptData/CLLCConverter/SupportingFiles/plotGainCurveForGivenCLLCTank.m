function [magnitude, freqVec, frequencyRange] = plotGainCurveForGivenCLLCTank(CLLCDesign,options)
%   This function plots the forward and reverse gain curves of a CLLC resonant converter
%   for a tank that has already been designed, using the GainCurveCLLCConverterForward
%   and GainCurveCLLCConverterReverse Simulink models. Unlike
%   plotGainCurveCLLCConverter, it does not sweep the quality factor or the inductance
%   ratio: the tank is fixed, and only the load and the frequency sweep vary.
%
%   Inputs:
%     CLLCDesign   Struct of designed tank values, as returned by
%                 designCLLCFullBridgeConverter.
%
%     options     Structure with the following optional fields:
%       .RloadVec          Load resistance(s) seen at the FORWARD output, that is, on the
%                          secondary side (default: simscape.Value(100,"Ohm")). The
%                          reverse-direction load is derived from these.
%       .FrequencyVec      Frequency vector(s) in Hz (default: linspace(0.1*CLLCDesign.resonantFreq, 2*CLLCDesign.resonantFreq, 150))
%
%   Outputs:
%     magnitude       Matrix of forward gain magnitude (Vout/Vin) for each load.
%     freqVec         Frequency vector (Hz) used for the gain curve.
%     frequencyRange  Struct with fields:
%                       .minFreqFwd / .maxFreqFwd - Forward operating region (Hz).
%                       .minFreqRev / .maxFreqRev - Reverse operating region (Hz).
%
%   Example:
%     CLLCConverterDefaultInputParameters;
%     plotGainCurveForGivenCLLCTank(CLLCDesign, ...
%         RloadVec=[simscape.Value(100,"Ohm") simscape.Value(200,"Ohm")]);

% Copyright 2025-2026 The MathWorks, Inc.
arguments
    CLLCDesign struct
    options.RloadVec  = simscape.Value(100,"Ohm"); % Load resistance
    % Sweep relative to the resonant frequency, matching plotGainCurveCLLCConverter. A
    % fixed absolute range cannot be right for every design: the minimum-gain crossing
    % that sets the maximum operating frequency often sits well above 1.5 times the
    % resonant frequency, and a sweep that stops short of it reports fmax as NaN.
    options.FrequencyVec  = simscape.Value((linspace(0.1*CLLCDesign.resonantFreq,...
        2*CLLCDesign.resonantFreq,150)),"Hz"); % Frequency Hz
end
turnsRatio = CLLCDesign.N1/CLLCDesign.N2;
RloadVec_Ohm = convert(options.RloadVec, "Ohm");

% Initialize the output parameter size
numPlots = length(RloadVec_Ohm.value);
minFrequencyFwd = zeros(1,numPlots);
maxFrequencyFwd = zeros(1,numPlots);
minFrequencyRev = zeros(1,numPlots);
maxFrequencyRev = zeros(1,numPlots);
magnitude = zeros(numPlots,length(options.FrequencyVec.value));
magnitudeRev = zeros(numPlots,length(options.FrequencyVec.value));
RloadFwd = zeros(1,numPlots);
RloadRev = zeros(1,numPlots);

% Forward gain characteristics model initialization
% Model workspace
mdlWks = get_param(GainCurveCLLCConverterForward,'ModelWorkspace');
freqVec = options.FrequencyVec.value;
% Port assignment
inputBlock = "GainCurveCLLCConverterForward/Vin";
inputPort = 1;
inputType = 'input';

outputBlock = "GainCurveCLLCConverterForward/Vo";
outputPort = 1;
outputType = 'output';

% Creating linearization points
io(1) = linio(inputBlock,inputPort,inputType);
io(2) = linio(outputBlock,outputPort,outputType);

% Setting the linearization points into the model
setlinio('GainCurveCLLCConverterForward',io);


% Reverse gain characteristics model initialization
% Model workspace
mdlWksRev = get_param(GainCurveCLLCConverterReverse,'ModelWorkspace');
freqVec = options.FrequencyVec.value;
% Port assignment
inputBlock = "GainCurveCLLCConverterReverse/Vin";
inputPort = 1;
inputType = 'input';

outputBlock = "GainCurveCLLCConverterReverse/Vo";
outputPort = 1;
outputType = 'output';

% Creating linearization points
ioRev(1) = linio(inputBlock,inputPort,inputType);
ioRev(2) = linio(outputBlock,outputPort,outputType);

% Setting the linearization points into the model
setlinio('GainCurveCLLCConverterReverse',ioRev);

count = 0;
Parameters = struct("Name","","Value",0);

h = figure('Name','CLLCResonantConverterFullBridgeGain');
set(gcf, 'Position',  [400, 300, 930, 500]);

% Plot the gain range

for i = 1:length(RloadVec_Ohm.value)
    count = count+1;

    % Forward: the load sits on the secondary port, which is where the Rload block is,
    % so only the FHA rectifier factor 8/pi^2 is needed. Reverse: the load sits on the
    % primary port and its output voltage is the converter's input voltage, so the same
    % rated power corresponds to Vin_avg^2/P instead of Vout_avg^2/P. CLLCDesign.avgGainRev
    % is exactly that voltage conversion ratio (avgInputVoltage/avgOutputVoltage).
    reverseLoadReferralFactor = CLLCDesign.avgGainRev.value^2;
    reverseLoadResistance = RloadVec_Ohm(i).value*reverseLoadReferralFactor;
    Reffective = 8*RloadVec_Ohm(i).value/(pi^2);
    ReffectiveRev = 8*reverseLoadResistance/(pi^2);
    set_param("GainCurveCLLCConverterForward/Rload", "R", num2str(Reffective));
    set_param("GainCurveCLLCConverterReverse/Rload", "R", num2str(ReffectiveRev));

    assignin(mdlWks,'CLLCDesign',CLLCDesign);
    assignin(mdlWksRev,'CLLCDesign',CLLCDesign);

 
    Parameters(1).Name = 'CLLCDesign.Llk1';
    Parameters(1).Value = CLLCDesign.Llk1;
    Parameters(2).Name = 'CLLCDesign.Llk2';
    Parameters(2).Value = CLLCDesign.Llk2;
    Parameters(3).Name = 'CLLCDesign.Lm';
    Parameters(3).Value = CLLCDesign.Lm;
    Parameters(4).Name = 'CLLCDesign.C1';
    Parameters(4).Value = CLLCDesign.C1;
    Parameters(5).Name = 'CLLCDesign.C2';    
    Parameters(5).Value = CLLCDesign.C2;
    % Parameters(6).Name = 'CLLCDesign.N2';
    % Parameters(6).Value = CLLCDesign.N2;
    % Parameters(7).Name = 'CLLCDesign.N1';   
    % Parameters(7).Value = CLLCDesign.N1;

    % Report the load actually applied in each direction.
    RloadFwd(count) = RloadVec_Ohm(i).value;
    RloadRev(count) = round(reverseLoadResistance,3);


    % Linearizing the model
    %linearizeOptions('AreParamsTunable',false);
    systemModel = linearize('GainCurveCLLCConverterForward',io,Parameters); % Finding open loop system statespace model
    systemModelRev = linearize('GainCurveCLLCConverterReverse',ioRev,Parameters); % Finding open loop system statespace model

    [mag,~] = bode(systemModel,2*pi*freqVec);
    magnitude(count,:) = reshape(mag,[1,length(mag)]);
    gainRange = [CLLCDesign.minGainFwd,CLLCDesign.maxGainFwd];

    [magRev,~] = bode(systemModelRev,2*pi*freqVec);
    magnitudeRev(count,:) = reshape(magRev,[1,length(magRev)]);
    gainRangeRev = [CLLCDesign.minGainRev,CLLCDesign.maxGainRev];

    % Estimate fmin and fmax
    freqRangeFwd = estimateCLLCFrequencyRange(abs(magnitude(count,:)), 2*pi*freqVec, gainRange, 2*pi*CLLCDesign.resonantFreq);
    freqRangeRev = estimateCLLCFrequencyRange(abs(magnitudeRev(count,:)), 2*pi*freqVec, gainRangeRev, 2*pi*CLLCDesign.resonantFreq);

    minFrequencyFwd(count) = freqRangeFwd.fminHz;
    maxFrequencyFwd(count) = freqRangeFwd.fmaxHz;

    minFrequencyRev(count) = freqRangeRev.fminHz;
    maxFrequencyRev(count) = freqRangeRev.fmaxHz;

    figure(h);
    subplot(1,2,1)
    semilogx(freqVec*1e-3,magnitude(count,:),'LineWidth',2);
    hold on
    subplot(1,2,2)
    semilogx(freqVec*1e-3,magnitudeRev(count,:),'LineWidth',2);
    hold on;
end

hold on;
xaxis = [min(freqVec*1e-3),max(freqVec*1e-3),max(freqVec*1e-3),min(freqVec*1e-3)];
yaxisFwd = [CLLCDesign.minGainFwd,CLLCDesign.minGainFwd,CLLCDesign.maxGainFwd,CLLCDesign.maxGainFwd];
yaxisRev = [CLLCDesign.minGainRev,CLLCDesign.minGainRev,CLLCDesign.maxGainRev,CLLCDesign.maxGainRev];

figure(h)
subplot(1,2,1);
fhandle = fill(xaxis,yaxisFwd,'g');
fhandle.FaceAlpha = 0.2;
hold on;
plot(freqVec*1e-3,ones(1,length(freqVec*1e-3))*CLLCDesign.avgGainFwd.value,"r--",...
    "LineWidth",1);
hold on
[legendInfoFwd,figureTitleFwd] = getLegendData(RloadFwd);
legendInfoFwd{length(legendInfoFwd)+1} = 'Gain range';
legendInfoFwd{length(legendInfoFwd)+1} = 'Avg gain ';
if numPlots == 1
    xaxisFwd = [minFrequencyFwd*1e-3,maxFrequencyFwd*1e-3,maxFrequencyFwd*1e-3,minFrequencyFwd*1e-3];
    yaxisFwd = [CLLCDesign.minGainFwd,CLLCDesign.minGainFwd,CLLCDesign.maxGainFwd,CLLCDesign.maxGainFwd];
    fhandle = fill(xaxisFwd,yaxisFwd,'c');
    fhandle.FaceAlpha = 0.2;
    legendInfoFwd{length(legendInfoFwd)+1} = 'Operating region';
end
legend(legendInfoFwd,"Location","southwest");
xlabel('Frequency (kHz)','FontSize',12);
ylabel('Gain (Vout/Vin)','FontSize',12);
title("Forward Gain Curve",'FontSize',13);
grid on
box on


subplot(1,2,2);
fhandle = fill(xaxis,yaxisRev,'g');
fhandle.FaceAlpha = 0.2;
hold on;
plot(freqVec*1e-3,ones(1,length(freqVec*1e-3))*CLLCDesign.avgGainRev.value,"r--",...
    "LineWidth",1);
hold on
[legendInfoRev,~] = getLegendData(RloadRev);
legendInfoRev{length(legendInfoRev)+1} = 'Gain range';
legendInfoRev{length(legendInfoRev)+1} = 'Avg gain ';
if numPlots == 1
    xaxisRev = [minFrequencyRev*1e-3,maxFrequencyRev*1e-3,maxFrequencyRev*1e-3,minFrequencyRev*1e-3];
    yaxisRev = [CLLCDesign.minGainRev,CLLCDesign.minGainRev,CLLCDesign.maxGainRev,CLLCDesign.maxGainRev];
    fhandle = fill(xaxisRev,yaxisRev,'c');
    fhandle.FaceAlpha = 0.2;
    legendInfoRev{length(legendInfoRev)+1} = 'Operating region';
end
legend(legendInfoRev,"Location","southwest");
xlabel('Frequency (kHz)','FontSize',12);
ylabel('Gain (Vout/Vin)','FontSize',12);
title("Reverse Gain Curve",'FontSize',13);
grid on
box on

sgtitle(figureTitleFwd,"FontSize",13);
RloadTable = [RloadFwd RloadRev];
minFrequencyTable = [minFrequencyFwd minFrequencyRev];
maxFrequencyTable = [maxFrequencyFwd maxFrequencyRev];
modeTable(1:numPlots) = {'Forward'};
modeTable(numPlots+1:2*numPlots) = {'Reverse'};


% Frequency operating range table
tableHeaderNames = {'Mode','Rload (Ohm)',...
    'Minimum Frequency (kHz)','Maximum Frequency (kHz)'};
freqTable =  table(char(modeTable'), RloadTable',...
    1e-3*minFrequencyTable',1e-3*maxFrequencyTable','VariableNames',tableHeaderNames);
disp(table(freqTable,'VariableNames',{'Operating Frequency Range'}));

frequencyRange.maxFreqFwd = maxFrequencyFwd;
frequencyRange.minFreqFwd = minFrequencyFwd;
frequencyRange.maxFreqRev = maxFrequencyRev;
frequencyRange.minFreqRev = minFrequencyRev;
end


% Get legend info
function [legendInfoFwd, figureTitle] = getLegendData(Rload)

legendInfoFwd = cell(1,length(Rload));

for i = 1:length(Rload)
    legendInfoFwd{i}=strcat("R_L = ",num2str(Rload(i)));
end
figureTitle = {"Gain Curve at the Given Tank Parameters"};
end
