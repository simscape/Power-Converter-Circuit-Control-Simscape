function marginTable = PlotBodeForController(controllerName,plotFlag)
% Copyright 2023 The MathWorks, Inc.

switch controllerName
    case 'VdController'
        marginTable = vdControllerBode(plotFlag);
    case 'VqController'
        marginTable = vqControllerBode(plotFlag);
    case 'IdController'
        marginTable = IdControllerBode(plotFlag);
    case 'IqController'
        marginTable = IqControllerBode(plotFlag);
    otherwise
        error('Choose the proper controller name')
end
disp('Grid Forming Converter controller Gain and Phase margin');
disp(marginTable);
end


function marginTable = vdControllerBode(plotFlag)
% Linearizing the Vd controller open loop system

inputBlock = ['GridFormingConverter' '/Grid-Forming Converter/Grid-Forming Converter Control/VoltageCurrentControl/Controller/Vderror'];
inputPort = 1;
inputType = 'openinput';

outputBlock = ['GridFormingConverter' '/Grid-Forming Converter/Grid-Forming Converter Control/VoltageCurrentControl/Controller/Vd LPF'];
outputPort = 1;
outputType = 'openoutput';

loopBreakBlock = ['GridFormingConverter' '/Grid-Forming Converter/Grid-Forming Converter Control/VoltageCurrentControl/Controller/ForVdBodePlot'];
loopBreakPort = 1;
loopBreakType = 'loopbreak';

% Creating linearization points
io(1) = linio(inputBlock,inputPort,inputType);
io(2) = linio(outputBlock,outputPort,outputType);
io(3) = linio(loopBreakBlock,loopBreakPort,loopBreakType);

% Setting the linearization points into the model
setlinio('GridFormingConverter',io);

% Linearizing the model
systemModel = linearize('GridFormingConverter',io,2.5); % Finding open loop system statespace model
titleInput = 'Vd Controller Open Loop Bode Plot';

% Plotting gain and phase margin
marginTable = plottingGainAndPhaseCurve(systemModel,titleInput,plotFlag);
marginTable.Controller = 'Vd Controller';
marginTable = movevars(marginTable,"Controller",'Before',"GainCrossOverFreqInHz");

end

function marginTable = vqControllerBode(plotFlag)
% Linearizing the Vq controller open loop system

inputBlock = ['GridFormingConverter' '/Grid-Forming Converter/Grid-Forming Converter Control/VoltageCurrentControl/Controller/Vqerror'];
inputPort = 1;
inputType = 'openinput';

outputBlock = ['GridFormingConverter' '/Grid-Forming Converter/Grid-Forming Converter Control/VoltageCurrentControl/Controller/Vq LPF'];
outputPort = 1;
outputType = 'openoutput';

loopBreakBlock = ['GridFormingConverter' '/Grid-Forming Converter/Grid-Forming Converter Control/VoltageCurrentControl/Controller/ForVqBodePlot'];
loopBreakPort = 1;
loopBreakType = 'loopbreak';

% Creating linearization points
io(1) = linio(inputBlock,inputPort,inputType);
io(2) = linio(outputBlock,outputPort,outputType);
io(3) = linio(loopBreakBlock,loopBreakPort,loopBreakType);

% Setting the linearization points into the model
setlinio('GridFormingConverter',io);

% Linearizing the model
systemModel = linearize('GridFormingConverter',io,1.6); % Finding open loop system statespace model
% Model parameters taken from base workspace
titleInput = 'Vq Controller Open Loop Bode Plot';

% Plotting gain and phase margin
marginTable = plottingGainAndPhaseCurve(systemModel,titleInput,plotFlag);
marginTable.Controller = 'Vq Controller';
marginTable = movevars(marginTable,"Controller",'Before',"GainCrossOverFreqInHz");
end

function marginTable = IdControllerBode(plotFlag)
% Linearizing the Id controller open loop system
inputBlock = ['GridFormingConverter' '/Grid-Forming Converter/Grid-Forming Converter Control/VoltageCurrentControl/Controller/Iderror'];
inputPort = 1;
inputType = 'openinput';

outputBlock = ['GridFormingConverter' '/Grid-Forming Converter/Grid-Forming Converter Control/VoltageCurrentControl/Controller/Id'];
outputPort = 1;
outputType = 'openoutput';

loopBreakBlock = ['GridFormingConverter' '/Grid-Forming Converter/Grid-Forming Converter Control/VoltageCurrentControl/Controller/ForIdBodePlot'];
loopBreakPort = 1;
loopBreakType = 'loopbreak';

% Creating linearization points
io(1) = linio(inputBlock,inputPort,inputType);
io(2) = linio(outputBlock,outputPort,outputType);
io(3) = linio(loopBreakBlock,loopBreakPort,loopBreakType);

% Setting the linearization points into the model
setlinio('GridFormingConverter',io);

% Linearizing the model
systemModel = linearize('GridFormingConverter',io,1.6); % Finding open loop system statespace model
titleInput = 'Id Controller Open Loop Bode Plot';

% Plotting gain and phase margin
marginTable = plottingGainAndPhaseCurve(systemModel,titleInput,plotFlag);
marginTable.Controller = 'Id Controller';
marginTable = movevars(marginTable,"Controller",'Before',"GainCrossOverFreqInHz");

end

function marginTable = IqControllerBode(plotFlag)
% Linearizing the Iq controller open loop system
inputBlock = ['GridFormingConverter' '/Grid-Forming Converter/Grid-Forming Converter Control/VoltageCurrentControl/Controller/Iqerror'];
inputPort = 1;
inputType = 'openinput';

outputBlock = ['GridFormingConverter' '/Grid-Forming Converter/Grid-Forming Converter Control/VoltageCurrentControl/Controller/Iq'];
outputPort = 1;
outputType = 'openoutput';

loopBreakBlock = ['GridFormingConverter' '/Grid-Forming Converter/Grid-Forming Converter Control/VoltageCurrentControl/Controller/ForIqBodePlot'];
loopBreakPort = 1;
loopBreakType = 'loopbreak';

% Creating linearization points
io(1) = linio(inputBlock,inputPort,inputType);
io(2) = linio(outputBlock,outputPort,outputType);
io(3) = linio(loopBreakBlock,loopBreakPort,loopBreakType);

% Setting the linearization points into the model
setlinio('GridFormingConverter',io);

% Linearizing the model
systemModel = linearize('GridFormingConverter',io,2); % Finding open loop system statespace model
titleInput = 'Iq Controller Open Loop Bode Plot';

% Plotting gain and phase margin
marginTable = plottingGainAndPhaseCurve(systemModel,titleInput,plotFlag);
marginTable.Controller = 'Iq Controller';
marginTable = movevars(marginTable,"Controller",'Before',"GainCrossOverFreqInHz");

end

% Function to plot the bode plot, estimating gain and phase margin
function marginTable = plottingGainAndPhaseCurve(systemModel, titleInput,plotFlag)

% Finding Bode plot
[mag,phase,wout] = bode(systemModel);
bodeMagnitude = reshape(mag,[1,length(mag)]);
bodePhase = reshape(phase,[1,length(phase)]);

% Estimating gain margin
gainIdx = find(bodeMagnitude<=1,1);
if gainIdx>1
    gainCrossOverFreq = interp1([bodeMagnitude(gainIdx-1) bodeMagnitude(gainIdx)],...
        [wout(gainIdx-1) wout(gainIdx)],1);
    phaseVal = interp1([wout(gainIdx-1) wout(gainIdx)],...
        [bodePhase(gainIdx-1) bodePhase(gainIdx)],gainCrossOverFreq);
    phaseMargin = phaseVal+180;
else
    gainCrossOverFreq = NaN;
    phaseMargin = bodePhase(1)+180;
end

% Estimating phase margin
phaseIdx = find(bodePhase<=-180,1);
if phaseIdx>1
    phaseCrossOverFreq = interp1([bodePhase(phaseIdx-1) bodePhase(phaseIdx)],...
        [wout(phaseIdx-1) wout(phaseIdx)],-180);
    gainMargin = interp1([wout(phaseIdx-1) wout(phaseIdx)],...
        [bodeMagnitude(phaseIdx-1) bodeMagnitude(phaseIdx)],phaseCrossOverFreq);
else
    gainMargin = 20*log10(bodeMagnitude(1)); % in dB
end

% Storing the data in a table
GainMarginIndB = 20*log10(gainMargin);
PhaseMarginInDeg = phaseMargin;
GainCrossOverFreqInHz = gainCrossOverFreq/(2*pi);

annotGainMargin = sprintf('Gain Margin = %0.2f dB',GainMarginIndB);
annotPhaseMargin = sprintf('Phase Margin = %0.2f degrees',PhaseMarginInDeg);
marginTable=table(GainCrossOverFreqInHz,GainMarginIndB,PhaseMarginInDeg);

% Plotting gain and phase margin
if plotFlag>0
    figure('Name','GridFormingConverterControllerBodePlot');

    hsubplot = subplot(2,1,1);
    semilogx(wout,20*log10(bodeMagnitude),'LineWidth',2);
    hold all
    xlabel('Frequency (rad/s)','FontSize',12);
    ylabel('Magnitude (dB)','FontSize',12);
    title('Magnitude Bode Plot','FontSize',13);
    grid on
    box on
    pos = get(hsubplot, 'position');
    dim = pos.*[1 1 0.5 0.5]+[0.4 0 0 0];
    annotation('textbox',dim,'String',annotGainMargin,'FitBoxToText','on');

    hsubplot = subplot(2,1,2);
    semilogx(wout,bodePhase,'LineWidth',2);
    hold all
    xlabel('Frequency (rad/s)','FontSize',12);
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

