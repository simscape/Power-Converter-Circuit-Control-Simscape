function marginTable = plotBodeForController(controllerName,plotFlag)
% Copyright 2023 The MathWorks, Inc.

% Controller loops. Each row: loop name, error Sum (open-loop input), measured signal
% (open-loop output), loop-break gain and whether the loop is a current loop.
loopList = {
    'VdController', 'Vderror', 'Vd LPF', 'ForVdBodePlot', false;
    'VqController', 'Vqerror', 'Vq LPF', 'ForVqBodePlot', false;
    'IdController', 'Iderror', 'Id',     'ForIdBodePlot', true;
    'IqController', 'Iqerror', 'Iq',     'ForIqBodePlot', true};

% Select the loop by name
selectedLoop = find(strcmp(loopList(:,1),controllerName));
if isempty(selectedLoop)
    error('Choose the proper controller name')
end

modelName = 'GridFormingConverter';
steadyStateTime = 2.5; % s, Time at which the operating point is taken

% Simulating the model once to steady state, then linearizing the loop at this operating point
operatingPointOptions = findopOptions('DisplayReport','off');
operatingPoint = findop(modelName,steadyStateTime,operatingPointOptions);
marginTable = controllerBode(modelName,operatingPoint,loopList(selectedLoop,:),plotFlag);
disp('Grid Forming Converter controller Gain and Phase margin');
disp(marginTable);
end


function marginTable = controllerBode(modelName,operatingPoint,loopData,plotFlag)
% Linearizing one controller open loop system at the operating point

[controllerName, errorBlock, measuredBlock, loopBreakBlock, isCurrentLoop] = loopData{:};
controllerPath = [modelName '/Grid-Forming Converter/Grid-Forming Converter Control/VoltageCurrentControl/Controller/'];
powerMeasurementPath = [modelName '/Grid-Forming Converter/Grid-Forming Converter Control/Measurement/Power Measurement (Three-Phase)'];

% Creating linearization points: the loop is opened at its error Sum and its measured signal
io(1) = linio([controllerPath errorBlock],1,'openinput');
io(2) = linio([controllerPath measuredBlock],1,'openoutput');
io(3) = linio([controllerPath loopBreakBlock],1,'loopbreak');

% Opening the outer loops, so that the Bode plot shows this loop alone. The active and
% reactive power measurement outputs open the power control loops.
io(end+1) = linio(powerMeasurementPath,1,'loopbreak');
io(end+1) = linio(powerMeasurementPath,2,'loopbreak');
if isCurrentLoop
    % The voltage loops are the outer loops of the current loops
    io(end+1) = linio([controllerPath 'ForVdBodePlot'],1,'loopbreak');
    io(end+1) = linio([controllerPath 'ForVqBodePlot'],1,'loopbreak');
end

% Linearizing the model at the operating point
systemModel = linearize(modelName,operatingPoint,io); % Finding open loop system statespace model
loopLabel = strrep(controllerName,'Controller',' Controller');
titleInput = [loopLabel ' Open Loop Bode Plot'];

% Plotting gain and phase margin
marginTable = plottingGainAndPhaseCurve(systemModel,titleInput,plotFlag);
marginTable.Controller = string(loopLabel);
marginTable = movevars(marginTable,"Controller",'Before',"GainCrossOverFreqInHz");
end

% Function to plot the bode plot, estimating gain and phase margin
function marginTable = plottingGainAndPhaseCurve(systemModel, titleInput,plotFlag)

% Every gain and phase crossover of the loop transfer, with the phase wrapped
stabilityMargins = allmargin(systemModel);

% Phase margin at the loop's own gain crossover, which is its highest-frequency one
if isempty(stabilityMargins.PMFrequency)
    gainCrossOverFreq = NaN;
    phaseMargin = Inf;
else
    [gainCrossOverFreq, crossOverIdx] = max(stabilityMargins.PMFrequency);
    phaseMargin = stabilityMargins.PhaseMargin(crossOverIdx);
end

% Gain margin at the first phase crossover above the gain crossover, Inf when there is none
aboveCrossOver = stabilityMargins.GMFrequency > gainCrossOverFreq;
if any(aboveCrossOver)
    gainMarginsAbove = stabilityMargins.GainMargin(aboveCrossOver);
    [~, firstIdx] = min(stabilityMargins.GMFrequency(aboveCrossOver));
    gainMargin = gainMarginsAbove(firstIdx);
else
    gainMargin = Inf;
end

% Storing the data in a table
GainMarginIndB = 20*log10(gainMargin);
PhaseMarginInDeg = phaseMargin;
GainCrossOverFreqInHz = gainCrossOverFreq/(2*pi);

% Bode data in Hz. The phase is shifted by whole turns so that it lies in (-360, 0] deg at the
% gain crossover, where the margin is read.
[mag,phase,wout] = bode(systemModel);
bodeMagnitude = reshape(mag,[1,length(mag)]);
bodePhase = reshape(phase,[1,length(phase)]);
frequencyHz = wout/(2*pi);
if isfinite(gainCrossOverFreq)
    phaseAtCrossOver = interp1(wout, bodePhase, gainCrossOverFreq);
    bodePhase = bodePhase - 360*ceil(phaseAtCrossOver/360);
end

annotGainMargin = sprintf('Gain Margin = %0.2f dB',GainMarginIndB);
annotPhaseMargin = sprintf('Phase Margin = %0.2f degrees',PhaseMarginInDeg);
marginTable=table(GainCrossOverFreqInHz,GainMarginIndB,PhaseMarginInDeg);

% Plotting gain and phase margin
if plotFlag>0
    figure('Name','GridFormingConverterControllerBodePlot');

    hsubplot = subplot(2,1,1);
    semilogx(frequencyHz,20*log10(bodeMagnitude),'LineWidth',2);
    hold on
    if isfinite(GainCrossOverFreqInHz)
        xline(GainCrossOverFreqInHz,'k--','Gain crossover');
    end
    xlabel('Frequency (Hz)','FontSize',12);
    ylabel('Magnitude (dB)','FontSize',12);
    title('Magnitude Bode Plot','FontSize',13);
    grid on
    box on
    pos = get(hsubplot, 'position');
    dim = pos.*[1 1 0.5 0.5]+[0.4 0 0 0];
    annotation('textbox',dim,'String',annotGainMargin,'FitBoxToText','on');

    hsubplot = subplot(2,1,2);
    semilogx(frequencyHz,bodePhase,'LineWidth',2);
    hold on
    if isfinite(GainCrossOverFreqInHz)
        xline(GainCrossOverFreqInHz,'k--');
        yline(-180,'k:');
    end
    xlabel('Frequency (Hz)','FontSize',12);
    ylabel('Phase (deg)','FontSize',12);
    title('Phase Bode Plot','FontSize',13);
    grid on
    box on
    pos = get(hsubplot, 'position');
    dim = pos.*[1 1 0.5 0.5]-[0 0.08 0 0];
    annotation('textbox',dim,'String',annotPhaseMargin,'FitBoxToText','on');

    sgtitle(titleInput,'FontSize',13);
end
end
