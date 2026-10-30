function impedance = plotCLLCResonantTankImpedanceCurve(CLLCDesign,options)
%   This function plots the impedance magnitude and phase curves of a CLLC resonant tank
%   using the GainCurveCLLCConverter Simulink model at specified load conditions.
%   The function linearizes the model at each frequency point and load resistance,
%   and computes the frequency response of the tank network.
%
%   Inputs:
%     CLLCDesign   Structure containing CLLC converter component values and parameters.
%
%     options     Structure with optional fields:
%                   - RloadVec:       Vector of load resistances seen at the FORWARD
%                                     output, that is, on the secondary side (simscape.Value
%                                     or numeric, Ohm). The reverse-direction load is
%                                     derived from these, see below.
%                                     Default: simscape.Value(100,"Ohm")
%                   - FrequencyVec:   Vector of frequencies (simscape.Value or numeric, Hz)
%                                     Default: linspace(0.1*fr, 2*fr, 100), where fr is resonant frequency
%
%   Outputs:
%     impedance   Struct with fields:
%                   - magnitudeFwd / phaseAngleFwd: forward tank impedance (Ohm) and
%                     phase (deg), one row per load resistance.
%                   - magnitudeRev / phaseAngleRev: the same for reverse operation.
%                   - freqVec: frequency vector (Hz) used for the plot.
%
%   Reverse-direction load:
%     In reverse operation the roles of the ports swap, so the load sits on the PRIMARY
%     side and its output voltage is the converter's input voltage. To represent the
%     same rated power in both directions, the reverse load resistance is the forward
%     load scaled by the square of the average voltage conversion ratio
%     (avgInputVoltage/avgOutputVoltage), because Vin_avg^2/P = ratio^2 * Vout_avg^2/P.
%
%   Method:
%     - For each specified load resistance, sets up the GainCurveCLLCConverter model
%       with the corresponding effective load.
%     - Linearizes the model at each frequency point using Simulink linear analysis tools.
%     - Computes impedance as the inverse of the input admittance (Vin/Iin).
%     - Plots magnitude (log-log) and phase (semilog-x) versus frequency for each load.
%
%   Example:
%     CLLCDesign = ... % (structure from designCLLCFullBridgeConverter)
%     impedance = plotCLLCResonantTankImpedanceCurve(CLLCDesign, ...
%         RloadVec = simscape.Value([50 100 200],"Ohm"), ...
%         FrequencyVec = simscape.Value(linspace(60e3, 200e3, 200),"Hz"));
%
% Copyright 2025-2026 The MathWorks, Inc.

arguments
    CLLCDesign struct
    options.RloadVec  = simscape.Value(100,"Ohm"); % Load resistance
    options.FrequencyVec  = simscape.Value((linspace(0.1*...
        CLLCDesign.resonantFreq,2*CLLCDesign.resonantFreq,100)),"Hz"); % Frequency Hz
end

% Initialize the output parameter size
numPlots = length(options.RloadVec.value);
magnitude = zeros(numPlots,length(options.FrequencyVec.value));
phaseAngle = zeros(numPlots,length(options.FrequencyVec.value));
Rload = zeros(1,numPlots);

magnitudeRev = zeros(numPlots,length(options.FrequencyVec.value));
phaseAngleRev = zeros(numPlots,length(options.FrequencyVec.value));
RloadRev = zeros(1,numPlots);
legendInfo = cell(1,numPlots);

% Forward impedance characteristics
% Model workspace
mdlWks = get_param(GainCurveCLLCConverterForward,'ModelWorkspace');
freqVec = options.FrequencyVec.value;
% Port assignment
inputBlock = "GainCurveCLLCConverterForward/Vin";
inputPort = 1;
inputType = 'input';

outputBlock = "GainCurveCLLCConverterForward/Iin";
outputPort = 1;
outputType = 'output';

% Creating linearization points
io(1) = linio(inputBlock,inputPort,inputType);
io(2) = linio(outputBlock,outputPort,outputType);

% Setting the linearization points into the model
setlinio('GainCurveCLLCConverterForward',io);


% Reverse impedance characteristics
% Model workspace
mdlWksRev = get_param(GainCurveCLLCConverterReverse,'ModelWorkspace');
freqVec = options.FrequencyVec.value;
% Port assignment
inputBlock = "GainCurveCLLCConverterReverse/Vin";
inputPort = 1;
inputType = 'input';

outputBlock = "GainCurveCLLCConverterReverse/Iin";
outputPort = 1;
outputType = 'output';

% Creating linearization points
ioRev(1) = linio(inputBlock,inputPort,inputType);
ioRev(2) = linio(outputBlock,outputPort,outputType);

% Setting the linearization points into the model
setlinio('GainCurveCLLCConverterReverse',ioRev);

count = 0;
Parameters = struct("Name","","Value",0);

h = figure('Name','CLLCResonantConverterFullBridgeImpedanceFwd');
hRev = figure('Name','CLLCResonantConverterFullBridgeImpedanceRev');

% Plot the gain range
for i = 1:length(options.RloadVec.value)

    count = count+1;

    % Forward: the load sits on the secondary port, which is where the Rload block is,
    % so only the FHA rectifier factor 8/pi^2 is needed. Reverse: the load sits on the
    % primary port and its output voltage is the converter's input voltage, so the same
    % rated power corresponds to Vin_avg^2/P instead of Vout_avg^2/P. CLLCDesign.avgGainRev
    % is exactly that voltage conversion ratio (avgInputVoltage/avgOutputVoltage).
    reverseLoadReferralFactor = CLLCDesign.avgGainRev.value^2;
    reverseLoadResistance = options.RloadVec(i).value*reverseLoadReferralFactor;
    Reffective = 8*options.RloadVec(i).value/(pi^2);
    ReffectiveRev = 8*reverseLoadResistance/(pi^2);


    set_param("GainCurveCLLCConverterForward/Rload", "R", num2str(Reffective));
    set_param("GainCurveCLLCConverterReverse/Rload", "R", num2str(ReffectiveRev));

    assignin(mdlWks,'CLLCDesign',CLLCDesign);
    assignin(mdlWksRev,'CLLCDesign',CLLCDesign);

    Parameters(1).Name = 'CLLCDesign.L1';
    Parameters(1).Value = CLLCDesign.L1;
    Parameters(2).Name = 'CLLCDesign.Llk1';
    Parameters(2).Value = CLLCDesign.Llk1;
    Parameters(3).Name = 'CLLCDesign.Llk2';
    Parameters(3).Value = CLLCDesign.Llk2;
    Parameters(4).Name = 'CLLCDesign.Lm';
    Parameters(4).Value = CLLCDesign.Lm;
    Parameters(5).Name = 'CLLCDesign.C1';
    Parameters(5).Value = CLLCDesign.C1;
    Parameters(6).Name = 'CLLCDesign.C2';
    Parameters(6).Value = CLLCDesign.C2;

    % Report the load actually applied in each direction.
    Rload(count) = options.RloadVec(i).value;
    RloadRev(count) = reverseLoadResistance;

    % Linearizing the model
    %linearizeOptions('AreParamsTunable',false);
    systemModel = linearize('GainCurveCLLCConverterForward',io,Parameters); % Finding open loop system statespace model
    systemModelRev = linearize('GainCurveCLLCConverterReverse',ioRev,Parameters); % Finding open loop system statespace model

    [mag,phase] = bode(systemModel,2*pi*freqVec);
    magnitude(count,:) = 1./reshape(mag,[1,length(mag)]);
    phaseAngle(count,:) = -1*reshape(phase,[1,length(phase)]);
    figure(h);
    subplot(2,1,1);
    loglog(freqVec,magnitude(count,:),'LineWidth',2);
    hold on;
    subplot(2,1,2);
    semilogx(freqVec,phaseAngle(count,:),'LineWidth',2);
    hold on
    legendInfo{i}=sprintf("R_L = %3.2f Ohm ",Rload(i));


    [magRev,phaseRev] = bode(systemModelRev,2*pi*freqVec);
    magnitudeRev(count,:) = 1./reshape(magRev,[1,length(magRev)]);
    phaseAngleRev(count,:) = -1*reshape(phaseRev,[1,length(phaseRev)]);
    figure(hRev);
    subplot(2,1,1);
    loglog(freqVec,magnitudeRev(count,:),'LineWidth',2);
    hold on;
    subplot(2,1,2);
    semilogx(freqVec,phaseAngleRev(count,:),'LineWidth',2);
    hold on
    legendInfo{i}=sprintf("R_L = %3.2f Ohm ",Rload(i));
end
% legendInfo{end+1} = sprintf(" ");
% legendInfo{end+2} = sprintf(" ");

[~,idx] = max(Rload);
xZeroCrossingFwd = find(phaseAngle(idx,:)>=0,1);
if xZeroCrossingFwd < length(phaseAngle(idx,:)) && xZeroCrossingFwd > 1
    positiveAngleFwd = phaseAngle(idx,xZeroCrossingFwd+1:end)>0;
    if positiveAngleFwd
        slopeFwd =(phaseAngle(idx,xZeroCrossingFwd)-phaseAngle(idx,xZeroCrossingFwd-1))/(freqVec(idx,xZeroCrossingFwd)-freqVec(idx,xZeroCrossingFwd-1));
        delFreqFwd = -phaseAngle(idx,xZeroCrossingFwd-1)/slopeFwd;
        freqZeroCrossingFwd = freqVec(idx,xZeroCrossingFwd-1)+delFreqFwd;
    end
end

xZeroCrossingRev = find(phaseAngleRev(idx,:)>=0,1);
if xZeroCrossingRev < length(phaseAngleRev(idx,:)) && xZeroCrossingRev > 1
    positiveAngleRev = phaseAngleRev(idx,xZeroCrossingRev+1:end)>0;
    if positiveAngleRev
        slopeRev =(phaseAngleRev(idx,xZeroCrossingRev)-phaseAngleRev(idx,xZeroCrossingRev-1))/(freqVec(idx,xZeroCrossingRev)-freqVec(idx,xZeroCrossingRev-1));
        delFreqRev = -phaseAngleRev(idx,xZeroCrossingRev-1)/slopeRev;
        freqZeroCrossingRev = freqVec(idx,xZeroCrossingRev-1)+delFreqRev;
    end
end

impedance.magnitudeRev = magnitudeRev;
impedance.phaseAngleRev = phaseAngleRev;
impedance.magnitudeFwd = magnitude;
impedance.phaseAngleFwd = phaseAngle;
impedance.freqVec = freqVec;
hold on;
figure(h)
hold on;
subplot(2,1,1);
legend(legendInfo);
xlabel('Frequency (Hz)','FontSize',12);
ylabel('Magnitude (Ohm)','FontSize',12);
title("Forward Impedance Magnitude",'FontSize',13);
grid on
box on
if exist('freqZeroCrossingFwd','var')
    yaxisFwd = [min(min(impedance.magnitudeFwd))*0.8,max(max(impedance.magnitudeFwd))*1.2,...
        max(max(impedance.magnitudeFwd))*1.2,min(min(impedance.magnitudeFwd))*0.8];
    xaxisFwd = [freqZeroCrossingFwd,freqZeroCrossingFwd,freqVec(end),...
        freqVec(end)];
    fhandle = fill(xaxisFwd,yaxisFwd,'g', 'HandleVisibility','off');
    fhandle.FaceAlpha = 0.1;
end
if exist('freqZeroCrossingFwd','var')
    yaxisFwd = [min(min(impedance.magnitudeFwd))*0.8,max(max(impedance.magnitudeFwd))*1.2,...
        max(max(impedance.magnitudeFwd))*1.2,min(min(impedance.magnitudeFwd))*0.8];
    xaxisFwd = [freqZeroCrossingFwd,freqZeroCrossingFwd,freqVec(1),...
        freqVec(1)];
    fhandle = fill(xaxisFwd,yaxisFwd,'y', 'HandleVisibility','off');
    fhandle.FaceAlpha = 0.1;
end
ylim([min(min(impedance.magnitudeFwd))*0.8,max(max(impedance.magnitudeFwd))*1.2]);
grid on

subplot(2,1,2);
legend(legendInfo);
legend(legendInfo,"Location","southeast");
xlabel('Frequency (Hz)','FontSize',12);
ylabel('Phase (deg)','FontSize',12);
title("Forward Impedance Phase",'FontSize',13);
grid on
box on
sgtitle("Impedance Curve (Yellow=Capacitive Region, Green=Inductive Region)",'FontSize',13);
set(gcf, 'Position',  [400, 300, 600, 600]);
hold on
if exist('freqZeroCrossingFwd','var')
    yaxisFwd = [min(min(impedance.phaseAngleFwd))*1.2,max(max(impedance.phaseAngleFwd))*1.2,...
        max(max(impedance.phaseAngleFwd))*1.2,min(min(impedance.phaseAngleFwd))*1.2];
    xaxisFwd = [freqZeroCrossingFwd,freqZeroCrossingFwd,freqVec(end),...
        freqVec(end)];
    fhandle = fill(xaxisFwd,yaxisFwd,'g','HandleVisibility','off');
    fhandle.FaceAlpha = 0.1;
end
if exist('freqZeroCrossingFwd','var')
    yaxisFwd = [min(min(impedance.phaseAngleFwd))*1.2,max(max(impedance.phaseAngleFwd))*1.2,...
        max(max(impedance.phaseAngleFwd))*1.2,min(min(impedance.phaseAngleFwd))*1.2];
    xaxisFwd = [freqZeroCrossingFwd,freqZeroCrossingFwd,freqVec(1),...
        freqVec(1)];
    fhandle = fill(xaxisFwd,yaxisFwd,'y','HandleVisibility','off');
    fhandle.FaceAlpha = 0.1;
end
ylim([min(min(impedance.phaseAngleFwd))*1.2,max(max(impedance.phaseAngleFwd))*1.2]);
grid on

figure(hRev)
hold on;
subplot(2,1,1);
legend(legendInfo);
xlabel('Frequency (Hz)','FontSize',12);
ylabel('Magnitude (Ohm)','FontSize',12);
title("Reverse Impedance Magnitude",'FontSize',13);
grid on
box on
hold on
if exist('freqZeroCrossingRev','var')
    yaxisRev = [min(min(impedance.magnitudeRev))*0.8,max(max(impedance.magnitudeRev))*1.2,...
        max(max(impedance.magnitudeRev))*1.2,min(min(impedance.magnitudeRev))*0.8];
    xaxisRev = [freqZeroCrossingRev,freqZeroCrossingRev,freqVec(end),...
        freqVec(end)];
    fhandle = fill(xaxisRev,yaxisRev,'g','HandleVisibility','off');
    fhandle.FaceAlpha = 0.1;
end
if exist('freqZeroCrossingRev','var')
    yaxisRev = [min(min(impedance.magnitudeRev))*0.8,max(max(impedance.magnitudeRev))*1.2,...
        max(max(impedance.magnitudeRev))*1.2,min(min(impedance.magnitudeRev))*0.8];
    xaxisRev = [freqZeroCrossingRev,freqZeroCrossingRev,freqVec(1),...
        freqVec(1)];
    fhandle = fill(xaxisRev,yaxisRev,'y','HandleVisibility','off');
    fhandle.FaceAlpha = 0.1;
end
ylim([min(min(impedance.magnitudeRev))*0.8,max(max(impedance.magnitudeRev))*1.2]);
grid on

subplot(2,1,2);
legend(legendInfo);
legend(legendInfo,"Location","southeast");
xlabel('Frequency (Hz)','FontSize',12);
ylabel('Phase (deg)','FontSize',12);
title("Reverse Impedance Phase",'FontSize',13);
grid on
box on
sgtitle("Impedance Curve (Yellow=Capacitive Region, Green=Inductive Region)",'FontSize',13);
set(gcf, 'Position',  [400, 300, 600, 600]);
hold on

if exist('freqZeroCrossingRev','var')
    yaxisRev = [min(min(impedance.phaseAngleRev))*1.2,max(max(impedance.phaseAngleRev))*1.2,...
        max(max(impedance.phaseAngleRev))*1.2,min(min(impedance.phaseAngleRev))*1.2];
    xaxisRev = [freqZeroCrossingRev,freqZeroCrossingRev,freqVec(end),...
        freqVec(end)];
    fhandle = fill(xaxisRev,yaxisRev,'g','HandleVisibility','off');
    fhandle.FaceAlpha = 0.1;
end

if exist('freqZeroCrossingRev','var')
    yaxisRev = [min(min(impedance.phaseAngleRev))*1.2,max(max(impedance.phaseAngleRev))*1.2,...
        max(max(impedance.phaseAngleRev))*1.2,min(min(impedance.phaseAngleRev))*1.2];
    xaxisRev = [freqZeroCrossingRev,freqZeroCrossingRev,freqVec(1),...
        freqVec(1)];
    fhandle = fill(xaxisRev,yaxisRev,'y','HandleVisibility','off');
    fhandle.FaceAlpha = 0.1;
end
grid on
ylim([min(min(impedance.phaseAngleRev))*1.2,max(max(impedance.phaseAngleRev))*1.2]);
end