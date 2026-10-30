function harmonicData = estimateConverterHarmonics(simulationLog, options)
%ESTIMATECONVERTERHARMONICS Harmonics and THD of a converter from an existing log.
%   harmonicData = ESTIMATECONVERTERHARMONICS(simulationLog, Converter=key, FundamentalHz=f)
%
%   Inputs:
%     simulationLog  Signal-logging dataset, or a Simulink.SimulationOutput.
%
%   Name-value options:
%     Converter           Registry key, for example "BoostPFC".
%     FundamentalHz       Line frequency (Hz). Required.
%     SwitchingHz         Switching frequency (Hz). Needed for the ripple spectrum.
%     Signal              Logged signal to analyze instead of the registry signals.
%     Quantity            'current' or 'voltage' for Signal.
%     MaxHarmonic         Highest harmonic plotted and tabulated. Default 10.
%     THDMaxHarmonic      Highest harmonic summed for THD. Default 10.
%     RippleSpectrum      Plot the ripple spectrum. Default true.
%     RippleSpanMultiple  Ripple span as a multiple of SwitchingHz. Default 10.
%     ShowHarmonicTable   Print the harmonic table. Default false.
%     ShowStandardTable   Print the THD-by-standard table. Default true.
%     CyclesToAnalyze     Exact number of whole cycles to analyze.
%     TimeWindow          [tStart tEnd] to analyze (s). Overrides WindowFraction.
%     WindowFraction      [f0 f1] fraction of the log to analyze. Default [0.6 1].
%     MinCycles           Warn below this many whole cycles. Default 3.
%     ShowPlots           Plot the spectra. Default true.
%     FigureName          Figure name. Default names the converter.
%     Interactions        Keep the default axes interactions and toolbar. Default false.
%
%   Outputs:
%     harmonicData  Result struct from harmonicsFromSignalLog. skippedReason names
%                   the missing license when the analysis is skipped.

% Copyright 2026 The MathWorks, Inc.

arguments
    simulationLog
    options.Converter (1,:) char = ''
    options.FundamentalHz (1,1) double
    options.SwitchingHz double = []
    options.Signal (1,:) string = string.empty
    options.Quantity (1,:) char = ''
    % Analysis options
    options.MaxHarmonic (1,1) double = 10
    options.THDMaxHarmonic (1,1) double = 10
    options.RippleSpectrum (1,1) logical = true
    options.RippleSpanMultiple (1,1) double {mustBePositive} = 10
    options.ShowHarmonicTable (1,1) logical = false
    options.ShowStandardTable (1,1) logical = true
    % Time-window options
    options.CyclesToAnalyze double = []
    options.TimeWindow double = []
    options.WindowFraction (1,2) double = [0.6 1.0]
    options.MinCycles (1,1) double = 3
    options.ShowPlots (1,1) logical = true
    options.FigureName (1,:) char = ''
    options.Interactions (1,1) logical = false
end
if ~isfield(options,'FundamentalHz') || isempty(options.FundamentalHz) || options.FundamentalHz <= 0
    error('estimateConverterHarmonics:noFundamental', ...
        'Specify FundamentalHz (the line frequency), e.g. FundamentalHz=50.');
end

isConverterSpecified = ~isempty(options.Converter);
if isConverterSpecified
    reg = converterRegistry(options.Converter);
end

% Take the logged dataset from a simulation output.
if isa(simulationLog, 'Simulink.SimulationOutput')
    if ~isConverterSpecified
        error('estimateConverterHarmonics:noConverter', ...
            ['Specify the Converter registry key to take the logged dataset from a ' ...
             'Simulink.SimulationOutput, or give the dataset itself.']);
    end
    simulationLog = simulationLog.(reg.logsoutVar);
end

% Choose the signals to analyze.
if ~isempty(options.Signal)
    quantity = options.Quantity;
    if isempty(quantity)
        signalName = char(options.Signal(1));
        if ~isempty(signalName) && upper(signalName(1))=='V'
            quantity = 'voltage';
        else
            quantity = 'current';
        end
    end
    signalSpecs = struct('signal',char(options.Signal(1)),'label',char(options.Signal(1)), ...
        'quantity',quantity);
elseif isConverterSpecified && isfield(reg,'harmonicSignals') && ~isempty(reg.harmonicSignals)
    signalSpecs = reg.harmonicSignals;
elseif isConverterSpecified
    error('estimateConverterHarmonics:noSignals', ...
        ['Converter "%s" has no registry harmonicSignals. Set Signal="<name>" to ' ...
         'analyze a specific logged signal.'], options.Converter);
else
    error('estimateConverterHarmonics:noSignals', ...
        ['Specify the Converter registry key, e.g. Converter="BoostPFC", or ' ...
         'Signal="<name>" to analyze a specific logged signal.']);
end

% Default figure name.
figureName = options.FigureName;
if isempty(figureName)
    if isConverterSpecified
        figureName = sprintf('%s Harmonics', options.Converter);
    else
        figureName = 'Converter Harmonics';
    end
end

% Analyze. Skip on a license error and rethrow any other error.
try
    harmonicData = harmonicsFromSignalLog(simulationLog, signalSpecs, ...
        FundamentalHz=options.FundamentalHz, ...
        SwitchingHz=options.SwitchingHz, ...
        MaxHarmonic=options.MaxHarmonic, ...
        THDMaxHarmonic=options.THDMaxHarmonic, ...
        RippleSpectrum=options.RippleSpectrum, ...
        RippleSpanMultiple=options.RippleSpanMultiple, ...
        ShowHarmonicTable=options.ShowHarmonicTable, ...
        ShowStandardTable=options.ShowStandardTable, ...
        CyclesToAnalyze=options.CyclesToAnalyze, ...
        TimeWindow=options.TimeWindow, ...
        WindowFraction=options.WindowFraction, ...
        MinCycles=options.MinCycles, ...
        ShowPlots=options.ShowPlots, ...
        Interactions=options.Interactions, ...
        FigureName=figureName);
catch thisError
    if ~isProductAvailabilityError(thisError)
        rethrow(thisError);
    end
    harmonicData = reportSkip(options, thisError.message);
end
end

% ======================================================================
function tf = isProductAvailabilityError(thisError)
% True when the error reports a missing product or license.
identifier = lower(string(thisError.identifier));
message = lower(string(thisError.message));
tf = contains(identifier, "licen") || contains(message, "license") || ...
    identifier == "matlab:undefinedfunction" || ...
    contains(message, "unrecognized function or variable");
end

% ======================================================================
function featureName = licenseFeatureFromMessage(detail)
% Return the license name after "Feature:" in an error message, or "".
featureName = "";
token = regexp(string(detail), 'Feature:\s*([A-Za-z0-9_\-]+)', 'tokens', 'once');
if ~isempty(token)
    featureName = string(token{1});
end
end

% ======================================================================
function harmonicData = reportSkip(options, detail)
% Print the missing license and return an empty result.
featureName = licenseFeatureFromMessage(detail);
if strlength(featureName) > 0
    reason = "You need the " + featureName + " license to analyze harmonics.";
else
    reason = "The harmonic analysis could not run, because a license it needs is " + ...
        "unavailable on this machine.";
end
if ~isempty(detail)
    reason = reason + newline + "Reported as: " + string(detail);
end
fprintf('%s\nSkipping the harmonic analysis. Every later section of this script still runs.\n', ...
    reason);

% Get the empty result struct by analyzing no signals.
harmonicData = harmonicsFromSignalLog(struct(), struct('signal',{}), ...
    FundamentalHz=options.FundamentalHz, SwitchingHz=options.SwitchingHz, ...
    ShowPlots=false, ShowStandardTable=false);
harmonicData.skippedReason = reason;
end
