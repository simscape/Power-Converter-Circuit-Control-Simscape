function [magnitude, freqVec, frequencyRange] = plotGainCurveCLLCConverter(CLLCSpec,options)
%   This function plots the gain curve of a CLLC resonant converter using the
%   GainCurveCLLCConverterForward and GainCurveCLLCConverterReverse Simulink models. It
%   allows you to specify the CLLC converter parameters, quality factor, inductance
%   ratio, load resistance, and frequency vector to plot the gain for.
%
%   Inputs:
%     CLLCSpec     Struct. CLLC converter specification, must include
%                 at least the field: resonantFrequency (with .value).
%
%     options     Structure with the following optional fields:
%       .QualityFactorVec   Quality factor(s) (default: 0.4)
%       .LmLrRatioVec      Lm/Lr ratio(s) (default: 3)
%       .RloadVec          Load resistance(s) seen at the FORWARD output, that is, on the
%                          secondary side (default: simscape.Value(100,"Ohm")). The
%                          reverse-direction load is derived from these, see below.
%       .FrequencyVec      Frequency vector(s) in Hz (default: linspace(0.1*CLLCSpec.resonantFrequency, 2*CLLCSpec.resonantFrequency, 150))
%       .N2                Secondary winding turns (default: 10). Given straight to
%                          designCLLCFullBridgeConverter, so the swept tank is the one
%                          the design call produces. Set the same value in both, or the
%                          sweep describes a different transformer from the design.
%       .TurnsRatioVec     Turns ratio(s) N1/N2 to use directly, instead of deriving one
%                          from turnratioVoltageLevel (default: [], which derives it).
%                          Each entry is a sweep axis of its own, so a
%                          vector produces one curve per ratio, and each is given to
%                          designCLLCFullBridgeConverter as the designed ratio. See
%                          computeCLLCTurnsRatio. The required gain band does not move with
%                          the ratio, because it comes from the voltage specification, so a
%                          ratio sweep shows the curve moving against a fixed band.
%       .PlotFlag          Logical. If true, plots the gain curves and displays the
%                          summary table (default: true). Set it false to sweep designs
%                          silently.
%
%   Outputs:
%     magnitude       Matrix of forward gain magnitude (Vout/Vin) for each parameter set.
%     freqVec         Frequency vector (Hz) used for the gain curve.
%     frequencyRange  Struct with fields:
%                       .minFreqFwd / .maxFreqFwd - Forward operating region (Hz).
%                       .minFreqRev / .maxFreqRev - Reverse operating region (Hz).
%
%   Reverse-direction load:
%     In reverse operation the roles of the ports swap, so the load sits on the PRIMARY
%     side and its output voltage is the converter's input voltage. To represent the
%     same rated power in both directions, the reverse load resistance is the forward
%     load scaled by the square of the average voltage conversion ratio
%     (avgInputVoltage/avgOutputVoltage), because Vin_avg^2/P = ratio^2 * Vout_avg^2/P.
%
%   Magnetizing current column:
%     The summary table reports Im/Im_limit for each design point, per direction. The
%     peak magnetizing current is slightly higher in reverse, because the secondary
%     bridge drives the tank through the realized (integer-winding) turns ratio. A value
%     above 1 means the design circulates more magnetizing current than
%     magCurrentPercentofInputCurrent allows.
%
%   Example:
%     CLLCSpec.resonantFrequency = simscape.Value(100e3, "Hz");
%     plotGainCurveCLLCConverter(CLLCSpec, ...
%         QualityFactorVec=[0.4 0.8], ...
%         LmLrRatioVec=[3 5], ...
%         RloadVec=[simscape.Value(100,"Ohm") simscape.Value(200,"Ohm")]);
%
%     % One curve per turns ratio, at one tank and one load
%     plotGainCurveCLLCConverter(CLLCSpec, N2=29, TurnsRatioVec=[0.93 0.96 0.99]);

% Copyright 2025-2026 The MathWorks, Inc.
    arguments
        CLLCSpec struct
        options.QualityFactorVec {mustBeNonnegative} = 0.4; % Quality factor
        options.LmLrRatioVec {mustBeNonnegative} = 3; % Inductor ratio
        options.RloadVec  = simscape.Value(100,"Ohm"); % Load resistance at the forward output
        options.FrequencyVec  = simscape.Value((linspace(0.1*...
            CLLCSpec.resonantFrequency.value,2*CLLCSpec.resonantFrequency.value,150)),"Hz"); % Frequency Hz
        options.N2 (1,1) {mustBePositive, mustBeInteger} = 10; % Secondary winding turns
        options.TurnsRatioVec {mustBePositive} = []; % Specified turns ratio N1/N2, one curve each
        options.PlotFlag (1,1) {mustBeNumericOrLogical} = true; % Plot the curves and show the table
    end

    RloadVec_Ohm = convert(options.RloadVec, "Ohm");

    % One sweep entry per requested turns ratio. An empty vector means the ratio is not
    % specified at all, so computeCLLCTurnsRatio derives it from the voltage specification -
    % that is one design point, and it is the behavior when the option is left out.
    if isempty(options.TurnsRatioVec)
        turnsRatioRequestList = {[]};
    else
        turnsRatioRequestList = num2cell(options.TurnsRatioVec(:)');
    end

    % Initialize the output parameter size
    numPlots = length(options.QualityFactorVec)*length(options.LmLrRatioVec)*...
        length(RloadVec_Ohm.value)*numel(turnsRatioRequestList);
    minFrequencyFwd = zeros(1,numPlots);
    maxFrequencyFwd = zeros(1,numPlots);
    minFrequencyRev = zeros(1,numPlots);
    maxFrequencyRev = zeros(1,numPlots);
    magnitude = zeros(numPlots,length(options.FrequencyVec.value));
    magnitudeRev = zeros(numPlots,length(options.FrequencyVec.value));

    qualityFactor = zeros(1,numPlots);
    LmLrRatio = zeros(1,numPlots);
    RloadFwd = zeros(1,numPlots);
    RloadRev = zeros(1,numPlots);
    ImRatioFwd = zeros(1,numPlots);
    ImRatioRev = zeros(1,numPlots);
    % The realized ratio N1/N2, not the requested one, because that is the transformer the
    % linearized models see once the winding counts have been rounded.
    turnsRatioRealized = zeros(1,numPlots);

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

    % Sweep the requested design points. Nothing is plotted inside the loop, so the whole
    % sweep can run with PlotFlag = false.
    for i = 1:length(RloadVec_Ohm.value)
        for j = 1:length(options.QualityFactorVec)
            for k = 1:length(options.LmLrRatioVec)
                for m = 1:numel(turnsRatioRequestList)
                    count = count+1;
                    CLLCSpec.qualityFactor = options.QualityFactorVec(j); % Quality factor
                    CLLCSpec.k = options.LmLrRatioVec(k); % (Lm+Lr)/Lr ratio
                    % An empty turns ratio leaves the ratio to the voltage specification,
                    % which is what the design call does when the option is left out.
                    [~, CLLCDesign]  = designCLLCFullBridgeConverter(CLLCSpec,...
                        N2=options.N2,TurnsRatio=turnsRatioRequestList{m},...
                        DisplayTableFlag=false); % Estimate CLLC converter parameters

                    % Forward: the load sits on the secondary port, which is where the
                    % Rload block is, so only the FHA rectifier factor 8/pi^2 is needed.
                    % Reverse: the load sits on the primary port and its output voltage is
                    % the converter's input voltage, so the same rated power corresponds to
                    % Vin_avg^2/P instead of Vout_avg^2/P. CLLCDesign.avgGainRev is exactly
                    % that voltage conversion ratio (avgInputVoltage/avgOutputVoltage).
                    reverseLoadReferralFactor = CLLCDesign.avgGainRev.value^2;
                    reverseLoadResistance = RloadVec_Ohm(i).value*reverseLoadReferralFactor;
                    Reffective = 8*RloadVec_Ohm(i).value/(pi^2);
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

                    qualityFactor(count) = CLLCSpec.qualityFactor;
                    LmLrRatio(count) = CLLCSpec.k;
                    % Report the load actually applied in each direction, so the table
                    % cannot disagree with what was written into the models above.
                    RloadFwd(count) = RloadVec_Ohm(i).value;
                    RloadRev(count) = round(reverseLoadResistance,3);
                    % Peak magnetizing current relative to its limit, per direction.
                    ImRatioFwd(count) = CLLCDesign.ImRatioFwd;
                    ImRatioRev(count) = CLLCDesign.ImRatioRev;
                    % The transformer this curve was linearized with, after the winding
                    % counts were rounded.
                    turnsRatioRealized(count) = CLLCDesign.turnsRatio;


                    % Linearizing the model
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
                end
            end
        end
    end

    % Plot the forward and reverse gain curves side by side. The gain bands and the
    % average gain lines come from the last design point of the sweep, which is the only
    % one available once the loop has finished; they are identical across the sweep
    % because they depend on the voltage specification, not on Q, k, the load or the turns
    % ratio. A turns ratio sweep therefore moves the curves against a band that stays put.
    if options.PlotFlag
        h = figure('Name','CLLCResonantConverterFullBridgeGain');
        set(gcf, 'Position',  [400, 300, 930, 500]);
        freqVec_kHz = freqVec*1e-3;

        for idx = 1:numPlots
            subplot(1,2,1)
            semilogx(freqVec_kHz,magnitude(idx,:),'LineWidth',2);
            hold on
            subplot(1,2,2)
            semilogx(freqVec_kHz,magnitudeRev(idx,:),'LineWidth',2);
            hold on;
        end

        xaxis = [min(freqVec_kHz),max(freqVec_kHz),max(freqVec_kHz),min(freqVec_kHz)];
        yaxisFwd = [CLLCDesign.minGainFwd,CLLCDesign.minGainFwd,CLLCDesign.maxGainFwd,CLLCDesign.maxGainFwd];
        yaxisRev = [CLLCDesign.minGainRev,CLLCDesign.minGainRev,CLLCDesign.maxGainRev,CLLCDesign.maxGainRev];

        figure(h)
        subplot(1,2,1);
        fhandle = fill(xaxis,yaxisFwd,'g');
        fhandle.FaceAlpha = 0.2;
        hold on;
        plot(freqVec_kHz,ones(1,length(freqVec_kHz))*CLLCDesign.avgGainFwd.value,"r--",...
            "LineWidth",1);
        hold on
        [legendInfoFwd,figureTitleFwd] = getLegendData(qualityFactor,LmLrRatio,RloadFwd,...
            turnsRatioRealized);
        legendInfoFwd{length(legendInfoFwd)+1} = 'Gain range';
        legendInfoFwd{length(legendInfoFwd)+1} = 'Avg gain ';
        % Shade the operating region only when it is unambiguous, that is, for one or two
        % curves, and only when both edges were found. Shading a NaN edge would silently
        % drop the patch and leave a legend entry with nothing behind it.
        if numPlots <= 2 && ~any(isnan([minFrequencyFwd, maxFrequencyFwd]))
            xaxisFwd = [min(minFrequencyFwd)*1e-3,max(maxFrequencyFwd)*1e-3,...
                max(maxFrequencyFwd)*1e-3,min(minFrequencyFwd)*1e-3];
            fhandle = fill(xaxisFwd,yaxisFwd,'c');
            fhandle.FaceAlpha = 0.2;
            legendInfoFwd{length(legendInfoFwd)+1} = 'Operating region';
        end
        legend(legendInfoFwd,"Location","northeast");
        xlabel('Frequency (kHz)','FontSize',12);
        ylabel('Gain (Vout/Vin)','FontSize',12);
        title("Forward Gain Curve",'FontSize',13);
        grid on
        box on


        subplot(1,2,2);
        fhandle = fill(xaxis,yaxisRev,'g');
        fhandle.FaceAlpha = 0.2;
        hold on;
        plot(freqVec_kHz,ones(1,length(freqVec_kHz))*CLLCDesign.avgGainRev.value,"r--",...
            "LineWidth",1);
        hold on
        [legendInfoRev,~] = getLegendData(qualityFactor,LmLrRatio,RloadRev,...
            turnsRatioRealized);
        legendInfoRev{length(legendInfoRev)+1} = 'Gain range';
        legendInfoRev{length(legendInfoRev)+1} = 'Avg gain ';
        if numPlots <= 2 && ~any(isnan([minFrequencyRev, maxFrequencyRev]))
            xaxisRev = [min(minFrequencyRev)*1e-3,max(maxFrequencyRev)*1e-3,...
                max(maxFrequencyRev)*1e-3,min(minFrequencyRev)*1e-3];
            fhandle = fill(xaxisRev,yaxisRev,'c');
            fhandle.FaceAlpha = 0.2;
            legendInfoRev{length(legendInfoRev)+1} = 'Operating region';
        end
        legend(legendInfoRev,"Location","northeast");
        xlabel('Frequency (kHz)','FontSize',12);
        ylabel('Gain (Vout/Vin)','FontSize',12);
        title("Reverse Gain Curve",'FontSize',13);
        grid on
        box on

        sgtitle(figureTitleFwd,"FontSize",13);
    end

    % Frequency operating range table, forward rows followed by reverse rows
    if options.PlotFlag
        qualityFactorTable = [qualityFactor qualityFactor];
        LmLrRatioTable = [LmLrRatio LmLrRatio];
        RloadTable = [RloadFwd RloadRev];
        minFrequencyTable = [minFrequencyFwd minFrequencyRev];
        maxFrequencyTable = [maxFrequencyFwd maxFrequencyRev];
        ImRatioTable = [ImRatioFwd ImRatioRev];
        modeTable(1:numPlots) = {'Forward'};
        modeTable(numPlots+1:2*numPlots) = {'Reverse'};

        ImStatus = strings(2*numPlots,1);
        for idx = 1:2*numPlots
            if ImRatioTable(idx) <= 1
                ImStatus(idx) = sprintf("%.2fx (within)", ImRatioTable(idx));
            else
                ImStatus(idx) = sprintf("%.2fx (exceeds)", ImRatioTable(idx));
            end
        end

        tableHeaderNames = {'Mode','Quality factor', 'Lm/Lr','Rload (Ohm)'};
        tableColumns = {char(modeTable'),qualityFactorTable', LmLrRatioTable', RloadTable'};

        % Name the transformer only when the sweep varies it. One ratio across the whole
        % sweep is one transformer, and the design table already reports it.
        turnsRatioTable = [turnsRatioRealized turnsRatioRealized];
        if numel(unique(turnsRatioTable)) > 1
            tableHeaderNames{end+1} = 'Turns ratio (N1/N2)';
            tableColumns{end+1} = turnsRatioTable';
        end

        tableHeaderNames = [tableHeaderNames, {'Minimum Frequency (kHz)',...
            'Maximum Frequency (kHz)','Im/Im_limit'}];
        tableColumns = [tableColumns, {1e-3*minFrequencyTable',1e-3*maxFrequencyTable',ImStatus}];
        freqTable =  table(tableColumns{:},'VariableNames',tableHeaderNames);
        disp(table(freqTable,'VariableNames',{'Operating Frequency Range'}));
    end

    frequencyRange.maxFreqFwd = maxFrequencyFwd;
    frequencyRange.minFreqFwd = minFrequencyFwd;
    frequencyRange.maxFreqRev = maxFrequencyRev;
    frequencyRange.minFreqRev = minFrequencyRev;
end


% Get legend info
function [legendInfoFwd, figureTitle] = getLegendData(qualityFactor,LmLrRatio,Rload,turnsRatio)
    legendInfoFwd = cell(1,length(qualityFactor));
    Qlength = length(unique(qualityFactor));
    LmLrLength = length(unique(LmLrRatio));
    RloadLength = length(unique(Rload));
    turnsRatioLength = length(unique(turnsRatio));

    % The turns ratio cases come first, so a sweep that holds it fixed - which is every
    % sweep that leaves the ratio to the voltage specification - reads exactly as before.
    if turnsRatioLength > 1 && Qlength == 1 && LmLrLength == 1 && RloadLength == 1
        for i = 1:length(turnsRatio)
            legendInfoFwd{i}=strcat("N1/N2 = ",num2str(turnsRatio(i)));
        end
        figureTitle = sprintf("Gain Curve at Q = %3.2f, k = %3.2f, and R_L = %3.2f Ohm",...
            qualityFactor(end), LmLrRatio(end), Rload(end));
    elseif turnsRatioLength > 1
        % More than one axis varies, so each entry has to name all four.
        for i = 1:length(qualityFactor)
            legendInfoFwd{i}=strcat("Q = ",num2str(qualityFactor(i)),...
                " k =",num2str(LmLrRatio(i)),...
                " RL = ", num2str(Rload(i)), " Ohm",...
                " N1/N2 = ", num2str(turnsRatio(i)));
        end
        figureTitle = {"Gain Curve"};
    elseif Qlength > 1 && LmLrLength == 1 && RloadLength == 1
        for i = 1:length(qualityFactor)
            legendInfoFwd{i}=strcat("Q = ",num2str(qualityFactor(i)));
        end
        figureTitle = sprintf("Gain Curve at k = %3.2f and R_L = %3.2f Ohm",...
            LmLrRatio(end), Rload(end));
    elseif Qlength == 1 && LmLrLength > 1 && RloadLength == 1
        for i = 1:length(LmLrRatio)
            legendInfoFwd{i}=strcat("k = ",num2str(LmLrRatio(i)));
        end
        figureTitle = sprintf("Gain Curve at Q = %3.2f and R_L = %3.2f Ohm",...
            qualityFactor(end), Rload(end));
    elseif Qlength == 1 && LmLrLength == 1 && RloadLength > 1
        for i = 1:length(Rload)
            legendInfoFwd{i}=strcat("R_L = ",num2str(Rload(i)));
        end
        figureTitle = sprintf("Gain Curve at Q = %3.2f and k = %3.2f",...
            qualityFactor(end), LmLrRatio(end));
    elseif Qlength == 1 && LmLrLength == 1 && RloadLength == 1
        legendInfoFwd = "Selected curve";
        figureTitle = sprintf("Gain Curve at Q = %3.2f, k = %3.2f, and R_L = %3.2f",...
            qualityFactor(end), LmLrRatio(end), Rload(end));

    else
        for i = 1:length(qualityFactor)
            legendInfoFwd{i}=strcat("Q = ",num2str(qualityFactor(i)),...
                " k =",num2str(LmLrRatio(i)),...
                " RL = ", num2str(Rload(i)), " Ohm");
        end
        figureTitle = {"Gain Curve"};
    end
end
