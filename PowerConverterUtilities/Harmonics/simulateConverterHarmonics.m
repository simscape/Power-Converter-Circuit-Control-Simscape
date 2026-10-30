function harmonicData = simulateConverterHarmonics(modelName, options)
%SIMULATECONVERTERHARMONICS Simulate a converter and analyze its AC harmonics and THD.
%   harmonicData = SIMULATECONVERTERHARMONICS(modelName, Converter=key, FundamentalHz=f)
%
%   Inputs:
%     modelName  Converter model name.
%
%   Name-value options:
%     Converter           Registry key, for example "BoostPFC". Required.
%     FundamentalHz       Line frequency (Hz). Required.
%     SwitchingHz         Switching frequency (Hz). Needed for the ripple spectrum.
%     Signal              Logged signal to analyze instead of the registry signals.
%     Quantity            'current' or 'voltage' for Signal.
%     Vin, Vout, Vref, Iref, Iin, Iout, Pload, ControlMode, PowerFlowDirection
%                         Operating point.
%     SimTime             Stop time (simscape.Value). Default 0.06 s.
%     MaxHarmonic         Highest harmonic plotted and tabulated. Default 10.
%     THDMaxHarmonic      Highest harmonic summed for THD. Default 10.
%     RippleSpectrum      Plot the ripple spectrum. Default true.
%     RippleSpanMultiple  Ripple span as a multiple of SwitchingHz. Default 10.
%     MaxStep             Solver maximum step (s). Default 1/(2*RippleSpanMultiple*SwitchingHz).
%     ShowHarmonicTable   Print the harmonic table. Default false.
%     ShowStandardTable   Print the THD-by-standard table. Default true.
%     TimeWindow          [tStart tEnd] to analyze (s). Overrides WindowFraction.
%     WindowFraction      [f0 f1] fraction of the run to analyze. Default [0.6 1].
%     MinCycles           Warn below this many whole cycles. Default 3.
%     ShowPlots           Plot the spectra. Default true.
%     Interactions        Keep the default axes interactions and toolbar. Default false.
%
%   Outputs:
%     harmonicData  Result struct from harmonicsFromSignalLog. skippedReason names
%                   the missing license when the analysis is skipped.

% Copyright 2026 The MathWorks, Inc.

arguments
    modelName (1,:) char
    options.Converter (1,:) char
    options.FundamentalHz (1,1) double
    options.SwitchingHz double = []
    options.Signal (1,:) string = string.empty
    options.Quantity (1,:) char = ''
    % Operating point
    options.Vin  = []
    options.Vout = []
    options.Vref = []
    options.Iref = []
    options.Iin  = []
    options.Iout = []
    options.Pload = []
    options.ControlMode (1,:) char = ''
    options.PowerFlowDirection (1,:) char = ''
    % Simulation and analysis options
    options.SimTime (1,1) = simscape.Value(0.06,"s")
    options.MaxHarmonic (1,1) double = 10
    options.THDMaxHarmonic (1,1) double = 10
    options.RippleSpectrum (1,1) logical = true
    options.RippleSpanMultiple (1,1) double {mustBePositive} = 10
    options.MaxStep double = []
    options.ShowHarmonicTable (1,1) logical = false
    options.ShowStandardTable (1,1) logical = true
    % Time-window options
    options.TimeWindow double = []
    options.WindowFraction (1,2) double = [0.6 1.0]
    options.MinCycles (1,1) double = 3
    options.ShowPlots (1,1) logical = true
    options.Interactions (1,1) logical = false
end
if ~isfield(options,'Converter') || isempty(options.Converter)
    error('simulateConverterHarmonics:noConverter', ...
        'Specify the Converter registry key, e.g. simulateConverterHarmonics(model, Converter="BoostPFC", ...).');
end
if ~isfield(options,'FundamentalHz') || isempty(options.FundamentalHz) || options.FundamentalHz <= 0
    error('simulateConverterHarmonics:noFundamental', ...
        'Specify FundamentalHz (the line frequency), e.g. FundamentalHz=50.');
end

reg = converterRegistry(options.Converter);
load_system(modelName);

% Locate the plant subsystem.
topBlocks = find_system(modelName,'SearchDepth',1,'Type','block');
plant = topBlocks(contains(topBlocks, reg.plantSubsystem));
if isempty(plant)
    error('simulateConverterHarmonics:plantNotFound', ...
        'Plant subsystem containing "%s" not found in model "%s".', reg.plantSubsystem, modelName);
end
plant = plant{1};

% Error before simulating when there is no signal to analyze.
if isempty(options.Signal) && (~isfield(reg,'harmonicSignals') || isempty(reg.harmonicSignals))
    error('simulateConverterHarmonics:noSignals', ...
        ['Converter "%s" has no registry harmonicSignals. Set Signal="<name>" to ' ...
         'analyze a specific logged signal.'], options.Converter);
end

% Save the plant fidelity settings and restore them on exit.
fidFields = fieldnames(reg.idealFidelity);
originalFidelity = struct();
for i = 1:numel(fidFields)
    try originalFidelity.(fidFields{i}) = get_param(plant, fidFields{i}); catch, end
end
restorer = onCleanup(@() restoreFidelity(plant, originalFidelity)); %#ok<NASGU>

% Build the simulation input with the operating point and ideal fidelity.
opValues  = operatingPointValues(options);
simTime_s = convert(options.SimTime, "s");

simIn = Simulink.SimulationInput(modelName);
simIn = setModelParameter(simIn, 'StopTime', num2str(simTime_s.value));
simIn = applyOperatingPointToSimulationInput(simIn, modelName, reg, opValues);
for i = 1:numel(fidFields)
    simIn = setBlockParameter(simIn, plant, fidFields{i}, reg.idealFidelity.(fidFields{i}));
end

% Limit the solver step so the log resolves the ripple span.
solverMaxStep_s = options.MaxStep;
if isempty(solverMaxStep_s) && options.RippleSpectrum && ...
        ~isempty(options.SwitchingHz) && options.SwitchingHz > 0
    solverMaxStep_s = 1 / (2 * options.RippleSpanMultiple * options.SwitchingHz);
end
if ~isempty(solverMaxStep_s)
    simIn = setModelParameter(simIn, 'MaxStep', num2str(solverMaxStep_s, '%.10g'));
end

% Simulate, then analyze the log.
simOut = sim(simIn);

harmonicData = estimateConverterHarmonics(simOut.(reg.logsoutVar), ...
    Converter=options.Converter, ...
    FundamentalHz=options.FundamentalHz, ...
    SwitchingHz=options.SwitchingHz, ...
    Signal=options.Signal, ...
    Quantity=options.Quantity, ...
    MaxHarmonic=options.MaxHarmonic, ...
    THDMaxHarmonic=options.THDMaxHarmonic, ...
    RippleSpectrum=options.RippleSpectrum, ...
    RippleSpanMultiple=options.RippleSpanMultiple, ...
    ShowHarmonicTable=options.ShowHarmonicTable, ...
    ShowStandardTable=options.ShowStandardTable, ...
    TimeWindow=options.TimeWindow, ...
    WindowFraction=options.WindowFraction, ...
    MinCycles=options.MinCycles, ...
    ShowPlots=options.ShowPlots, ...
    Interactions=options.Interactions);
end

% ======================================================================
function restoreFidelity(plant, originalFidelity)
% Restore the saved plant fidelity settings.
for f = fieldnames(originalFidelity)'
    try set_param(plant, f{1}, originalFidelity.(f{1})); catch, end
end
end
