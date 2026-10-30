function [magnitude, freqVec, frequencyRange] = plotGainCurveLLCConverter(LLCSpec, options)
%   This function plots the gain curve of an LLC resonant converter using the
%   GainCurveLLCConverter Simulink model. It allows you to specify the LLC
%   converter parameters, quality factor, inductance ratio, load resistance,
%   and frequency vector for which the gain should be plotted.
%
%   Inputs:
%     LLCSpec     Struct. LLC converter specification, must include
%                 at least the field: resonantFrequency (simscape.Value).
%
%     options     Structure with the following optional fields:
%       .QualityFactorVec   Quality factor(s) (default: 0.4)
%       .LmLrRatioVec       Lm/Lr ratio(s) (default: 3)
%       .RloadVec           Load resistance(s) (default: simscape.Value(100,"Ohm"))
%       .FrequencyVec       Frequency vector (simscape.Value, default: 0.1*fr to 2*fr, 100 points)
%       .N1                 Primary winding turns (default: 50). Given straight to
%                           designLLCFullBridgeConverter, so the swept tank is the one the
%                           design call produces. Set the same value in both, or the sweep
%                           describes a different transformer from the design.
%       .TurnsRatioVec      Turns ratio(s) N1/N2 to use directly, instead of deriving one
%                           from turnratioVoltageLevel (default: [], which derives it).
%                           Each entry is a sweep axis of its own, so a vector produces one
%                           curve per ratio, and each is given to
%                           designLLCFullBridgeConverter as the designed ratio. See
%                           computeLLCTurnsRatio. The required gain band does not move with
%                           the ratio, because it comes from the voltage specification, so
%                           a ratio sweep shows the curve moving against a fixed band.
%       .PlotFlag           Logical. If true, plots the gain curve and table (default: true)
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
%
%     % One curve per turns ratio, at a fixed quality factor, inductance ratio and load
%     plotGainCurveLLCConverter(LLCSpec, N1=50, TurnsRatioVec=[0.93 0.96 0.99]);

% Copyright 2025-2026 The MathWorks, Inc.

arguments
    LLCSpec struct
    options.QualityFactorVec {mustBeNonnegative} = 0.4
    options.LmLrRatioVec {mustBeNonnegative} = 3
    options.RloadVec = simscape.Value(100, "Ohm")
    options.FrequencyVec = simscape.Value(linspace( ...
        0.1*value(LLCSpec.resonantFrequency,"Hz"), ...
        2*value(LLCSpec.resonantFrequency,"Hz"), 150), "Hz")
    options.N1 (1,1) {mustBePositive, mustBeInteger} = 50 % Primary winding turns
    options.TurnsRatioVec {mustBePositive} = [] % Specified turns ratio N1/N2, one curve each
    options.PlotFlag (1,1) {mustBeNumericOrLogical} = true
end

modelName = "GainCurveLLCConverter";

% Load model if not already loaded
if ~bdIsLoaded(modelName)
    load_system(modelName);
end

% Convert inputs to consistent SI units
freqVec = value(options.FrequencyVec, "Hz");
RloadVec_Ohm = value(convert(options.RloadVec, "Ohm"), "Ohm");

% Turns ratio sweep axis. An empty request means one pass with the ratio left to the
% voltage specification, which is the default and the behavior every existing caller gets.
if isempty(options.TurnsRatioVec)
    turnsRatioRequestList = {[]};
else
    turnsRatioRequestList = num2cell(options.TurnsRatioVec(:)');
end

% Determine sweep dimensions
numQ = length(options.QualityFactorVec);
numK = length(options.LmLrRatioVec);
numR = length(RloadVec_Ohm);
numRatio = numel(turnsRatioRequestList);
numPlots = numQ * numK * numR * numRatio;

% Preallocate outputs
magnitude = zeros(numPlots, length(freqVec));
minFrequency = zeros(1, numPlots);
maxFrequency = zeros(1, numPlots);
qualityFactor = zeros(1, numPlots);
LmLrRatio = zeros(1, numPlots);
Rload = zeros(1, numPlots);
ImRatio = zeros(1, numPlots);
turnsRatioRealized = zeros(1, numPlots);

% Model workspace and linearization I/O setup
mdlWks = get_param(modelName, 'ModelWorkspace');
io(1) = linio(modelName + "/Vin", 1, 'input');
io(2) = linio(modelName + "/Vo", 1, 'output');
setlinio(modelName, io);

% Sweep parameters and compute gain curves
count = 0;
Parameters = struct("Name", "", "Value", 0);

for i = 1:numR
    for j = 1:numQ
        for k = 1:numK
            for m = 1:numRatio
                count = count + 1;

                LLCSpec.qualityFactor = options.QualityFactorVec(j);
                LLCSpec.k = options.LmLrRatioVec(k);

                [~, LLCDesign] = designLLCFullBridgeConverter(LLCSpec, ...
                    N1=options.N1, TurnsRatio=turnsRatioRequestList{m}, ...
                    DisplayTableFlag=false);

                % Set AC-equivalent load resistance in model (FHA conversion)
                Reffective = 8 * RloadVec_Ohm(i) / pi^2;
                set_param(modelName + "/Rload", "R", num2str(Reffective));

                % Update model workspace parameters
                assignin(mdlWks, 'LLCDesign', LLCDesign);
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

                % Store sweep info
                qualityFactor(count) = options.QualityFactorVec(j);
                LmLrRatio(count) = options.LmLrRatioVec(k);
                Rload(count) = RloadVec_Ohm(i);
                ImRatio(count) = LLCDesign.ImRatio;
                turnsRatioRealized(count) = LLCDesign.turnsRatio;

                % Linearize and compute frequency response
                systemModel = linearize(modelName, io, Parameters);
                [mag, ~] = bode(systemModel, 2*pi*freqVec);
                magnitude(count, :) = reshape(mag, [1, length(mag)]);

                % Estimate operating frequency range
                gainRange = [LLCDesign.minGain, LLCDesign.maxGain];
                freqRange = estimateFrequencyRange(abs(magnitude(count,:)), ...
                    2*pi*freqVec, gainRange, 2*pi*LLCDesign.resonantFreq);
                minFrequency(count) = freqRange.fminHz;
                maxFrequency(count) = freqRange.fmaxHz;
            end
        end
    end
end

% Plot gain curves
if options.PlotFlag
    h = figure('Name', 'LLCResonantConverterFullBridgeGain');
    freqVec_kHz = freqVec * 1e-3;

    for idx = 1:numPlots
        semilogx(freqVec_kHz, magnitude(idx,:), 'LineWidth', 2);
        hold on;
    end

    % Gain range shading
    xaxis = [min(freqVec_kHz), max(freqVec_kHz), max(freqVec_kHz), min(freqVec_kHz)];
    yaxis = [LLCDesign.minGain, LLCDesign.minGain, LLCDesign.maxGain, LLCDesign.maxGain];
    fhandle = fill(xaxis, yaxis, 'g');
    fhandle.FaceAlpha = 0.2;

    % Average gain line
    plot(freqVec_kHz, ones(1, length(freqVec_kHz)) * LLCDesign.avgGain, ...
        "r--", "LineWidth", 1);

    % Legend
    [legendInfo, figureTitle] = getLegendData(qualityFactor, LmLrRatio, Rload, ...
        turnsRatioRealized);
    legendInfo{end+1} = 'Gain range';
    legendInfo{end+1} = 'Avg gain';

    % Operating region shading
    if numPlots == 1 && ~any(isnan([minFrequency, maxFrequency]))
        xaxis = [minFrequency*1e-3, maxFrequency*1e-3, maxFrequency*1e-3, minFrequency*1e-3];
        yaxis = [LLCDesign.minGain, LLCDesign.minGain, LLCDesign.maxGain, LLCDesign.maxGain];
        fhandle = fill(xaxis, yaxis, 'c');
        fhandle.FaceAlpha = 0.2;
        legendInfo{end+1} = 'Operating region';
    elseif numPlots == 2 && ~any(isnan([minFrequency, maxFrequency]))
        xaxis = [min(minFrequency)*1e-3, max(maxFrequency)*1e-3, max(maxFrequency)*1e-3, min(minFrequency)*1e-3];
        yaxis = [LLCDesign.minGain, LLCDesign.minGain, LLCDesign.maxGain, LLCDesign.maxGain];
        fhandle = fill(xaxis, yaxis, 'c');
        fhandle.FaceAlpha = 0.2;
        legendInfo{end+1} = 'Operating region';
    end

    legend(legendInfo, "Location", "northwest");
    xlabel('Frequency (kHz)', 'FontSize', 12);
    ylabel('Gain (Vout/Vin)', 'FontSize', 12);
    title(figureTitle, 'FontSize', 13);
    grid on
    box on
end

% Display frequency operating range table
if options.PlotFlag
    ImStatus = strings(numPlots, 1);
    for idx = 1:numPlots
        if ImRatio(idx) <= 1
            ImStatus(idx) = sprintf("%.2fx (within)", ImRatio(idx));
        else
            ImStatus(idx) = sprintf("%.2fx (exceeds)", ImRatio(idx));
        end
    end

    tableHeaderNames = {'Quality factor', 'Lm/Lr', 'Rload (Ohm)'};
    tableColumns = {qualityFactor', LmLrRatio', Rload'};

    % Name the transformer only when the sweep varies it. One ratio across the whole sweep
    % is one transformer, and the design table already reports it.
    if numel(unique(turnsRatioRealized)) > 1
        tableHeaderNames{end+1} = 'Turns ratio (N1/N2)';
        tableColumns{end+1} = turnsRatioRealized';
    end

    tableHeaderNames = [tableHeaderNames, ...
        {'Min Freq (kHz)', 'Max Freq (kHz)', 'Im/Im_limit'}];
    tableColumns = [tableColumns, ...
        {1e-3*minFrequency', 1e-3*maxFrequency', ImStatus}];
    freqTable = table(tableColumns{:}, 'VariableNames', tableHeaderNames);
    disp(table(freqTable, 'VariableNames', {'Operating Frequency Range'}));
end

% Build output struct
frequencyRange.maxFreq = maxFrequency;
frequencyRange.minFreq = minFrequency;

end


function [legendInfo, figureTitle] = getLegendData(qualityFactor, LmLrRatio, Rload, turnsRatio)

Qlength = length(unique(qualityFactor));
LmLrLength = length(unique(LmLrRatio));
RloadLength = length(unique(Rload));
turnsRatioLength = length(unique(turnsRatio));
numCurves = length(qualityFactor);
legendInfo = cell(1, numCurves);

% The turns ratio cases come first, so a sweep that holds it fixed - which is every sweep
% that leaves the ratio to the voltage specification - reads exactly as before.
if turnsRatioLength > 1 && Qlength == 1 && LmLrLength == 1 && RloadLength == 1
    for i = 1:numCurves
        legendInfo{i} = "N1/N2 = " + num2str(turnsRatio(i));
    end
    figureTitle = sprintf("Gain Curve at Q = %.2f, k = %.2f, and R_L = %.2f Ohm", ...
        qualityFactor(end), LmLrRatio(end), Rload(end));

elseif turnsRatioLength > 1
    % More than one axis varies, so each entry has to name all four.
    for i = 1:numCurves
        legendInfo{i} = "Q = " + num2str(qualityFactor(i)) + ...
            ", k = " + num2str(LmLrRatio(i)) + ...
            ", R_L = " + num2str(Rload(i)) + " Ohm" + ...
            ", N1/N2 = " + num2str(turnsRatio(i));
    end
    figureTitle = "Gain Curve";

elseif Qlength > 1 && LmLrLength == 1 && RloadLength == 1
    for i = 1:numCurves
        legendInfo{i} = "Q = " + num2str(qualityFactor(i));
    end
    figureTitle = sprintf("Gain Curve at k = %.2f and R_L = %.2f Ohm", ...
        LmLrRatio(end), Rload(end));

elseif Qlength == 1 && LmLrLength > 1 && RloadLength == 1
    for i = 1:numCurves
        legendInfo{i} = "k = " + num2str(LmLrRatio(i));
    end
    figureTitle = sprintf("Gain Curve at Q = %.2f and R_L = %.2f Ohm", ...
        qualityFactor(end), Rload(end));

elseif Qlength == 1 && LmLrLength == 1 && RloadLength > 1
    for i = 1:numCurves
        legendInfo{i} = "R_L = " + num2str(Rload(i)) + " Ohm";
    end
    figureTitle = sprintf("Gain Curve at Q = %.2f and k = %.2f", ...
        qualityFactor(end), LmLrRatio(end));

elseif Qlength == 1 && LmLrLength == 1 && RloadLength == 1
    legendInfo{1} = "Selected curve";
    figureTitle = sprintf("Gain Curve at Q = %.2f, k = %.2f, and R_L = %.2f Ohm", ...
        qualityFactor(end), LmLrRatio(end), Rload(end));

else
    for i = 1:numCurves
        legendInfo{i} = "Q = " + num2str(qualityFactor(i)) + ...
            ", k = " + num2str(LmLrRatio(i)) + ...
            ", R_L = " + num2str(Rload(i)) + " Ohm";
    end
    figureTitle = "Gain Curve";
end

end
