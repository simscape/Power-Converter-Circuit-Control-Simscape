function [ivData, simulationLog] = getConverterWaveforms(modelName, options)
%GETCONVERTERWAVEFORMS Simulate a converter and plot its voltage and current waveforms.
%   [ivData, simulationLog] = GETCONVERTERWAVEFORMS(modelName, Converter=key)
%
%   Inputs:
%     modelName  Converter model name.
%
%   Name-value options:
%     Converter    Registry key, for example "LLC". Required.
%     Vin, Vout, Vref, Iref, Iin, Iout, Pload, ControlMode, PowerFlowDirection
%                  Operating point.
%     SimTime      Stop time (simscape.Value). Default 0.015 s.
%     FocusCycles  Number of cycles to display. Default 5.
%     FrequencyHz  Frequency of one displayed cycle (Hz).
%     MaxStep      Solver maximum step (s). Default keeps the model setting.
%     Interactions Keep the default axes interactions and toolbar. Default false.
%
%   Outputs:
%     ivData         Result struct from plotLoggedSignals.
%     simulationLog  Signal-logging dataset of the run.

% Copyright 2026 The MathWorks, Inc.

arguments
    modelName (1,:) char
    options.Converter (1,:) char
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
    % Simulation and plot options
    options.SimTime (1,1) = simscape.Value(0.015,"s")
    options.FocusCycles (1,1) double = 5
    options.FrequencyHz double = []
    options.MaxStep double = []
    options.Interactions (1,1) logical = false
end
if ~isfield(options,'Converter') || isempty(options.Converter)
    error('getConverterWaveforms:noConverter', ...
        'Specify the Converter registry key, e.g. getConverterWaveforms(model, Converter="LLC", ...).');
end

reg = converterRegistry(options.Converter);
load_system(modelName);

% Locate the plant subsystem.
topBlocks = find_system(modelName,'SearchDepth',1,'Type','block');
plant = topBlocks(contains(topBlocks, reg.plantSubsystem));
if isempty(plant)
    error('getConverterWaveforms:plantNotFound', ...
        'Plant subsystem containing "%s" not found in model "%s".', reg.plantSubsystem, modelName);
end
plant = plant{1};

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

% Set the solver maximum step when given.
if ~isempty(options.MaxStep)
    simIn = setModelParameter(simIn, 'MaxStep', num2str(options.MaxStep, '%.10g'));
end

% Simulate and plot.
simOut = sim(simIn);
logsout = simOut.(reg.logsoutVar);
simulationLog = logsout;

% Axes titles from the registry.
panelTitles = string.empty;
if isfield(reg, 'ivPanelTitles')
    panelTitles = reg.ivPanelTitles;
end

% Derived signals from the registry, such as Pout = Vout .* Iout.
derived = struct('name',{},'inputs',{},'fcn',{});
if isfield(reg, 'ivDerived') && ~isempty(reg.ivDerived)
    derived = reg.ivDerived;
end

% Use the registry axes list if defined, otherwise the signal pairs and singles.
if isfield(reg, 'ivPanels') && ~isempty(reg.ivPanels)
    ivData = plotLoggedSignals(logsout, ...
        Panels=reg.ivPanels, ...
        PanelTitles=panelTitles, ...
        Derived=derived, ...
        FrequencyHz=options.FrequencyHz, ...
        FocusCycles=options.FocusCycles, ...
        Interactions=options.Interactions, ...
        FigureName=sprintf('%s IV Curves', options.Converter));
else
    ivData = plotLoggedSignals(logsout, ...
        SignalPairs=reg.ivSignalPairs, ...
        SignalSingles=reg.ivSignalSingles, ...
        PanelTitles=panelTitles, ...
        Derived=derived, ...
        FrequencyHz=options.FrequencyHz, ...
        FocusCycles=options.FocusCycles, ...
        Interactions=options.Interactions, ...
        FigureName=sprintf('%s IV Curves', options.Converter));
end
end

% ======================================================================
function restoreFidelity(plant, originalFidelity)
% Restore the saved plant fidelity settings.
for f = fieldnames(originalFidelity)'
    try set_param(plant, f{1}, originalFidelity.(f{1})); catch, end
end
end
