function [magnitude, freqVec] = plotLLCResonantTankImpedanceCurve(LLCDesign,options)
%   This function plots the impedance magnitude and phase curves of an LLC resonant tank
%   using the GainCurveLLCConverter Simulink model at specified load conditions.
%   The function linearizes the model at each frequency point and load resistance,
%   and computes the frequency response of the tank network.
%
%   Inputs:
%     LLCDesign   Structure containing LLC converter component values and parameters.
%
%     options     Structure with optional fields:
%                   - RloadVec:       Vector of load resistances (simscape.Value or numeric, Ohm)
%                                     Default: simscape.Value(100,"Ohm")
%                   - FrequencyVec:   Vector of frequencies (simscape.Value or numeric, Hz)
%                                     Default: linspace(0.1*fr, 2*fr, 100), where fr is resonant frequency
%
%   Outputs:
%     magnitude   Matrix of impedance magnitude (Ohms) for each load and frequency.
%     freqVec     Frequency vector (Hz) used for the plot.
%
%   Method:
%     - For each specified load resistance, sets up the GainCurveLLCConverter model
%       with the corresponding effective load.
%     - Linearizes the model at each frequency point using Simulink linear analysis tools.
%     - Computes impedance as the inverse of the input admittance (Vin/Iin).
%     - Plots magnitude (log-log) and phase (semilog-x) versus frequency for each load.
%
%   Example:
%     LLCDesign = ... % (structure from designLLCFullBridgeConverter)
%     options.RloadVec = simscape.Value([50 100 200],"Ohm");
%     options.FrequencyVec = simscape.Value(linspace(60e3, 200e3, 200),"Hz");
%     [magnitude, freqVec] = plotLLCResonantTankImpedanceCurve(LLCDesign, options);
%
% Copyright 2025-2026 The MathWorks, Inc.

arguments
    LLCDesign struct
    options.RloadVec  = simscape.Value(100,"Ohm"); % Load resistance
    options.FrequencyVec  = simscape.Value((linspace(0.1*...
        LLCDesign.resonantFreq,2*LLCDesign.resonantFreq,100)),"Hz"); % Frequency Hz
end

% Initialize the output parameter size
numPlots = length(options.RloadVec.value);
magnitude = zeros(numPlots,length(options.FrequencyVec.value));
phaseAngle = zeros(numPlots,length(options.FrequencyVec.value));
Rload = zeros(1,numPlots);
legendInfo = cell(1,numPlots);
% Model workspace
mdlWks = get_param(GainCurveLLCConverter,'ModelWorkspace');
freqVec = options.FrequencyVec.value;
% Port assignment
inputBlock = "GainCurveLLCConverter/Vin";
inputPort = 1;
inputType = 'input';

outputBlock = "GainCurveLLCConverter/Iin";
outputPort = 1;
outputType = 'output';

% Creating linearization points
io(1) = linio(inputBlock,inputPort,inputType);
io(2) = linio(outputBlock,outputPort,outputType);

% Setting the linearization points into the model
setlinio('GainCurveLLCConverter',io);
count = 0;
Parameters = struct("Name","","Value",0);

h = figure('Name','LLCResonantConverterFullBridgeGain');
% Plot the gain range
for i = 1:length(options.RloadVec.value)

    count = count+1;
    Reffective = 8*options.RloadVec(i).value/(pi^2);
    set_param("GainCurveLLCConverter/Rload", "R", num2str(Reffective));
    assignin(mdlWks,'LLCDesign',LLCDesign);

    Parameters(1).Name = 'LLCDesign.L';
    Parameters(1).Value = LLCDesign.L;
    Parameters(2).Name = 'LLCDesign.Llk1';
    Parameters(2).Value = LLCDesign.Llk1;
    Parameters(3).Name = 'LLCDesign.Llk2';
    Parameters(3).Value = LLCDesign.Llk2;
    Parameters(4).Name = 'LLCDesign.Lm';
    Parameters(4).Value = LLCDesign.Lm;
    Parameters(5).Name = 'LLCDesign.C';
    Parameters(5).Value = LLCDesign.C;

    Rload(count) = options.RloadVec(i).value;


    % Linearizing the model
    %linearizeOptions('AreParamsTunable',false);
    systemModel = linearize('GainCurveLLCConverter',io,Parameters); % Finding open loop system statespace model

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
end

hold on;
figure(h)
hold on;
subplot(2,1,1);
legend(legendInfo);
xlabel('Frequency (Hz)','FontSize',12);
ylabel('Magnitude (Ohm)','FontSize',12);
title("Magnitude",'FontSize',13);
grid on
box on

if isscalar(Rload)
    [~,idx] = max(Rload);
    xZeroCrossing = find(phaseAngle(idx,:)>=0,1);
    if xZeroCrossing < length(phaseAngle(idx,:)) && xZeroCrossing > 1
        positiveAngle = phaseAngle(idx,xZeroCrossing+1:end)>0;
        if positiveAngle
            slope =(phaseAngle(idx,xZeroCrossing)-phaseAngle(idx,xZeroCrossing-1))/(freqVec(idx,xZeroCrossing)-freqVec(idx,xZeroCrossing-1));
            delFreq = -phaseAngle(idx,xZeroCrossing-1)/slope;
            freqZeroCrossing = freqVec(idx,xZeroCrossing-1)+delFreq;
        end
    end
    if exist('freqZeroCrossing','var')
        yaxisImp = [min(min(magnitude))*0.8,max(max(magnitude))*1.2,...
            max(max(magnitude))*1.2,min(min(magnitude))*0.8];
        xaxisImp = [freqZeroCrossing,freqZeroCrossing,freqVec(end),...
            freqVec(end)];
        fhandle = fill(xaxisImp,yaxisImp,'g', 'HandleVisibility','off');
        fhandle.FaceAlpha = 0.1;
    end
    if exist('freqZeroCrossing','var')
        yaxisImp = [min(min(magnitude))*0.8,max(max(magnitude))*1.2,...
            max(max(magnitude))*1.2,min(min(magnitude))*0.8];
        xaxisImp = [freqZeroCrossing,freqZeroCrossing,freqVec(1),...
            freqVec(1)];
        fhandle = fill(xaxisImp,yaxisImp,'y', 'HandleVisibility','off');
        fhandle.FaceAlpha = 0.1;
    end
    ylim([min(min(magnitude))*0.8,max(max(magnitude))*1.2]);
    grid on
end

subplot(2,1,2);
legend(legendInfo);
legend(legendInfo,"Location","southeast");
xlabel('Frequency (Hz)','FontSize',12);
ylabel('Phase (deg)','FontSize',12);
title("Phase",'FontSize',13);
grid on
box on
set(gcf, 'Position',  [400, 300, 600, 600]);

if isscalar(Rload)
    if exist('freqZeroCrossing','var')
        yaxisImp = [min(min(phaseAngle))*1.2,max(max(phaseAngle))*1.2,...
            max(max(phaseAngle))*1.2,min(min(phaseAngle))*1.2];
        xaxisImp = [freqZeroCrossing,freqZeroCrossing,freqVec(end),...
            freqVec(end)];
        fhandle = fill(xaxisImp,yaxisImp,'g','HandleVisibility','off');
        fhandle.FaceAlpha = 0.1;
    end
    if exist('freqZeroCrossing','var')
        yaxisImp = [min(min(phaseAngle))*1.2,max(max(phaseAngle))*1.2,...
            max(max(phaseAngle))*1.2,min(min(phaseAngle))*1.2];
        xaxisImp = [freqZeroCrossing,freqZeroCrossing,freqVec(1),...
            freqVec(1)];
        fhandle = fill(xaxisImp,yaxisImp,'y','HandleVisibility','off');
        fhandle.FaceAlpha = 0.1;
    end
    ylim([min(min(phaseAngle))*1.2,max(max(phaseAngle))*1.2]);
    grid on
    sgtitle("Impedance Curve (Yellow=Capacitive Region, Green=Inductive Region)",'FontSize',13);
else
    sgtitle("Impedance Curve",'FontSize',13);
end
end
