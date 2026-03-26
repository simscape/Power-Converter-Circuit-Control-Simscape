function [magnitude, freqVec, frequencyRange] = plotGainCurveLLCConverter(LLCSpec,options)
%   This function plots the gain curve of an LLC resonant converter using the
%   GainCurveLLCConverter Simulink model. It allows you to specify the LLC
%   converter parameters, quality factor, inductance ratio, turns ratio, load
%   resistance, and frequency vector for which the gain should be plotted.
%
%   Inputs:
%     LLCSpec     Struct. LLC converter specification, must include
%                 at least the field: resonantFrequency (with .value).
%
%     options     Structure with the following optional fields:
%       .QualityFactorVec   Quality factor(s) (default: 0.4)
%       .LmLrRatioVec      Lm/Lr ratio(s) (default: 3)
%       .TurnsRatio        Transformer turns ratio (default: 1)
%       .RloadVec          Load resistance(s) (default: simscape.Value(100,"Ohm"))
%       .FrequencyVec      Frequency vector(s) in Hz (default: linspace(0.1*LLCSpec.resonantFrequency, 2*LLCSpec.resonantFrequency, 100))
%
%   Outputs:
%     magnitude       Matrix of gain magnitude (Vout/Vin) for each parameter set.
%     freqVec         Frequency vector (Hz) used for the gain curve.
%     frequencyRange  Struct with fields:
%                       .minFreq - Minimum frequency (Hz) for operating region.
%                       .maxFreq - Maximum frequency (Hz) for operating region.
%
%   Example:
%     LLCSpec.resonantFrequency = simscape.Value(100e3, "Hz");
%     plotGainCurveLLCConverter(LLCSpec, ...
%         QualityFactorVec=[0.4 0.8], ...
%         LmLrRatioVec=[3 5], ...
%         RloadVec=[simscape.Value(100,"Ohm") simscape.Value(200,"Ohm")]);

% Copyright 2025-2026 The MathWorks, Inc.
    arguments
        LLCSpec struct
        options.QualityFactorVec {mustBeNonnegative} = 0.4; % Quality factor
        options.LmLrRatioVec {mustBeNonnegative} = 3; % Inductor ratio
        options.TurnsRatio {mustBeNonnegative} = 1; % Turns ratio
        options.RloadVec  = simscape.Value(100,"Ohm"); % Load resistance
        options.FrequencyVec  = simscape.Value((linspace(0.1*...
            LLCSpec.resonantFrequency.value,2*LLCSpec.resonantFrequency.value,100)),"Hz"); % Frequency Hz
    end
    
    RloadVec_Ohm = convert(options.RloadVec, "Ohm");

    % Initialize the output parameter size
    numPlots = length(options.QualityFactorVec)*length(options.LmLrRatioVec)*...
        length(RloadVec_Ohm.value);
    minFrequency = zeros(1,numPlots);
    maxFrequency = zeros(1,numPlots);
    magnitude = zeros(numPlots,length(options.FrequencyVec.value));
    qualityFactor = zeros(1,numPlots);
    LmLrRatio = zeros(1,numPlots);
    Rload = zeros(1,numPlots);
    
    % Model workspace
    mdlWks = get_param(GainCurveLLCConverter,'ModelWorkspace');
    freqVec = options.FrequencyVec.value;
    % Port assignment
    inputBlock = "GainCurveLLCConverter/Vin";
    inputPort = 1;
    inputType = 'input';
    
    outputBlock = "GainCurveLLCConverter/Vo";
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
    for i = 1:length(RloadVec_Ohm.value)
        for j = 1:length(options.QualityFactorVec)
            for k = 1:length(options.LmLrRatioVec)
                count = count+1;
                LLCSpec.qualityFactor = options.QualityFactorVec(j); % Quality factor
                LLCSpec.k = options.LmLrRatioVec(k); % (Lm+Lr)/Lr ratio
                [~, LLCDesign]  = designLLCFullBridgeConverter(LLCSpec,DisplayTableFlag=false); % Estimate LLC converter parameters
                Reffective = 8*RloadVec_Ohm(i).value/(pi^2);
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
    
                qualityFactor(count) = LLCSpec.qualityFactor;
                LmLrRatio(count) = LLCSpec.k;
                Rload(count) = RloadVec_Ohm(i).value;
    
    
                % Linearizing the model
                %linearizeOptions('AreParamsTunable',false);
                systemModel = linearize('GainCurveLLCConverter',io,Parameters); % Finding open loop system statespace model
    
                [mag,~] = bode(systemModel,2*pi*freqVec);
                magnitude(count,:) = reshape(mag,[1,length(mag)]);
                gainRange = [LLCDesign.minGain,LLCDesign.maxGain];

                % Estimate fmin and fmax
                freqRange = estimateFreqRange(abs(magnitude(count,:)), 2*pi*freqVec, gainRange, 2*pi*LLCDesign.resonantFreq);

                minFrequency(count) = freqRange.fminHz;
                maxFrequency(count) = freqRange.fmaxHz;
    
                figure(h);
                semilogx(freqVec*1e-3,magnitude(count,:),'LineWidth',2);
                hold on;
            end
        end
    end
    hold on;
    figure(h)
    xaxis = [min(freqVec*1e-3),max(freqVec*1e-3),max(freqVec*1e-3),min(freqVec*1e-3)];
    yaxis = [LLCDesign.minGain,LLCDesign.minGain,LLCDesign.maxGain,LLCDesign.maxGain];
    fhandle = fill(xaxis,yaxis,'g');
    fhandle.FaceAlpha = 0.2;
    hold on;
    plot(freqVec*1e-3,ones(1,length(freqVec*1e-3))*LLCDesign.avgGain.value,"r--",...
        "LineWidth",1);
    
    
    [legendInfo,figureTitle] = getLegendData(qualityFactor,LmLrRatio,Rload);
    legendInfo{length(legendInfo)+1} = 'Gain range';
    legendInfo{length(legendInfo)+1} = 'Avg gain ';
    if numPlots == 1
        xaxis = [minFrequency*1e-3,maxFrequency*1e-3,maxFrequency*1e-3,minFrequency*1e-3];
        yaxis = [LLCDesign.minGain,LLCDesign.minGain,LLCDesign.maxGain,LLCDesign.maxGain];
        fhandle = fill(xaxis,yaxis,'c');
        fhandle.FaceAlpha = 0.2;
        legendInfo{length(legendInfo)+1} = 'Operating region';
    end
    legend(legendInfo,"Location","southeast");
    xlabel('Frequency (kHz)','FontSize',12);
    ylabel('Gain (Vout/Vin)','FontSize',12);
    title(figureTitle,'FontSize',13);
    grid on
    box on
    
    % Frequency operating range table
    tableHeaderNames = {'Quality factor', 'Lm/Lr','Rload (Ohm)',...
        'Minimum Frequency (kHz)','Maximum Frequency (kHz)'};
    freqTable =  table(qualityFactor', LmLrRatio', Rload',...
        1e-3*minFrequency',1e-3*maxFrequency','VariableNames',tableHeaderNames);
    disp(table(freqTable,'VariableNames',{'Operating Frequency Range'}));

    frequencyRange.maxFreq = maxFrequency;
    frequencyRange.minFreq = minFrequency;

end


% Get legend info
function [legendInfo, figureTitle] = getLegendData(qualityFactor,LmLrRatio,Rload)
    legendInfo = cell(1,length(qualityFactor));
    Qlength = length(unique(qualityFactor));
    LmLrLength = length(unique(LmLrRatio));
    RloadLength = length(unique(Rload));
    
    if Qlength > 1 && LmLrLength == 1 && RloadLength == 1
        for i = 1:length(qualityFactor)
            legendInfo{i}=strcat("Q = ",num2str(qualityFactor(i)));
        end
        figureTitle = sprintf("Gain Curve at k = %3.2f and R_L = %3.2f Ohm",...
            LmLrRatio(end), Rload(end));
    elseif Qlength == 1 && LmLrLength > 1 && RloadLength == 1
        for i = 1:length(LmLrRatio)
            legendInfo{i}=strcat("k = ",num2str(LmLrRatio(i)));
        end
        figureTitle = sprintf("Gain Curve at Q = %3.2f and R_L = %3.2f Ohm",...
            qualityFactor(end), Rload(end));
    elseif Qlength == 1 && LmLrLength == 1 && RloadLength > 1
        for i = 1:length(Rload)
            legendInfo{i}=strcat("R_L = ",num2str(Rload(i)));
        end
        figureTitle = sprintf("Gain Curve at Q = %3.2f and k = %3.2f",...
            qualityFactor(end), LmLrRatio(end));
    elseif Qlength == 1 && LmLrLength == 1 && RloadLength == 1
        legendInfo = "Selected curve";
        figureTitle = sprintf("Gain Curve at Q = %3.2f, k = %3.2f, and R_L = %3.2f",...
            qualityFactor(end), LmLrRatio(end), Rload(end));
    
    else
        for i = 1:length(qualityFactor)
            legendInfo{i}=strcat("Q = ",num2str(qualityFactor(i)),...
                " k =",num2str(LmLrRatio(i)),...
                " RL = ", num2str(Rload(i)), " Ohm");
        end
        figureTitle = {"Gain Curve"};
    end
end