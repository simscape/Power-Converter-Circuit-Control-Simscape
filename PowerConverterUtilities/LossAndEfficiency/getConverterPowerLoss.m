function [lossData, simlog] = getConverterPowerLoss(modelName, options)
%GETCONVERTERPOWERLOSS Converter loss and efficiency at an operating point.
%   lossData = GETCONVERTERPOWERLOSS(modelName, Converter=key)
%   lossData = GETCONVERTERPOWERLOSS(modelName, Converter=key, Name=Value)
%   [lossData, simlog] = GETCONVERTERPOWERLOSS(___)
%
%   Inputs:
%     modelName  Name of the converter model.
%
%   Name-value options:
%     Converter              Registry key, for example "LLC", "CLLC" or "DAB". Required.
%     Vin, Vout, Vref        Operating-point voltages, simscape.Value or numeric in V.
%     Iref, Iin, Iout        Operating-point currents, simscape.Value or numeric in A.
%     Pload                  Output power, simscape.Value or numeric in W.
%     ControlMode            "voltage" or "current".
%     PowerFlowDirection     "forward" or "reverse".
%     SimTime                Simulation stop time, simscape.Value. Default 0.01 s.
%     SwitchingLossDetail    "lumped" (default) or "separated".
%     SimulationTemperature  Device junction temperature, simscape.Value or numeric in degC. Default [].
%     AveragingWindow        [tStart tEnd] as a simscape.Value time, for example
%                            simscape.Value([20 40],"ms"), or a fraction of the log span.
%                            Default [0.9 1].
%     FrequencyHz            Switching frequency, in Hz. Default [].
%     MinCycles              Whole periods of FrequencyHz averaged at the end of the run.
%                            Default 10.
%     LogDataHistory         Simscape log length, in steps. Default [] sizes the log to hold
%                            the averaging window when FrequencyHz is set.
%     LogDecimation          Simscape log decimation. Default [].
%     Solver                 Solver name, for example "daessc". Default [].
%     MaxStep                Maximum solver step, in s. Default [].
%     ShowPlots              Draw the loss figures. Default true.
%     Interactions           Keep the default axes interactions and toolbar. Default false.
%
%   Outputs:
%     lossData  Result struct from powerLossFromSimscapeLog.
%     simlog    Simscape log node of the loss run.

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
    % Analysis settings
    options.SimTime (1,1) = simscape.Value(0.01,"s")
    options.SwitchingLossDetail (1,:) char {mustBeMember(options.SwitchingLossDetail,{'lumped','separated'})} = 'lumped'
    options.SimulationTemperature = []
    options.AveragingWindow = [0.9 1]
    options.FrequencyHz double = []
    options.MinCycles (1,1) double = 10
    options.LogDataHistory double = []
    options.LogDecimation double = []
    options.Solver (1,:) char = ''
    options.MaxStep double = []
    options.ShowPlots (1,1) logical = true
    options.Interactions (1,1) logical = false
end
if ~isfield(options,'Converter') || isempty(options.Converter)
    error('getConverterPowerLoss:noConverter', ...
        'Specify the Converter registry key, e.g. getConverterPowerLoss(model, Converter="LLC", ...).');
end

reg = converterRegistry(options.Converter);
load_system(modelName);

% Find the plant subsystem.
topBlocks = find_system(modelName,'SearchDepth',1,'Type','block');
plant = topBlocks(contains(topBlocks, reg.plantSubsystem));
if isempty(plant)
    error('getConverterPowerLoss:plantNotFound', ...
        'Plant subsystem containing "%s" not found in model "%s".', reg.plantSubsystem, modelName);
end
plant = plant{1};

% Save the device fidelity popups and restore them on exit.
fidFields = fieldnames(reg.lossFidelity);
originalFidelity = struct();
for i = 1:numel(fidFields)
    try originalFidelity.(fidFields{i}) = get_param(plant, fidFields{i}); catch, end
end
restorer = onCleanup(@() restoreFidelity(plant, originalFidelity)); %#ok<NASGU>

% Set the operating point and the loss fidelity.
opValues  = operatingPointValues(options);
simTime_s = convert(options.SimTime, "s");

simIn = Simulink.SimulationInput(modelName);
simIn = setModelParameter(simIn, 'StopTime', num2str(simTime_s.value));
simIn = applyOperatingPointToSimulationInput(simIn, modelName, reg, opValues);
for i = 1:numel(fidFields)
    simIn = setBlockParameter(simIn, plant, fidFields{i}, reg.lossFidelity.(fidFields{i}));
end

% Set the device junction temperature.
simIn = applySimulationTemperature(simIn, plant, reg, options.SimulationTemperature);

% Set the Simscape log length and decimation (numeric values). Without LogDataHistory,
% the log is lengthened to hold the averaging window of MinCycles periods.
if ~isempty(options.LogDataHistory)
    simIn = setModelParameter(simIn, 'SimscapeLogLimitData', 'on');
    simIn = setModelParameter(simIn, 'SimscapeLogDataHistory', options.LogDataHistory);
elseif isa(options.AveragingWindow, 'simscape.Value') || ...
        (~isempty(options.FrequencyHz) && options.FrequencyHz > 0)
    requiredHistory = requiredLogHistory(modelName, options);
    if ~isempty(requiredHistory)
        simIn = setModelParameter(simIn, 'SimscapeLogDataHistory', requiredHistory);
    end
end
if ~isempty(options.LogDecimation)
    simIn = setModelParameter(simIn, 'SimscapeLogDecimation', options.LogDecimation);
end

% Set the solver and maximum step.
if ~isempty(options.Solver)
    simIn = setModelParameter(simIn, 'Solver', options.Solver);
end
if ~isempty(options.MaxStep)
    simIn = setModelParameter(simIn, 'MaxStep', num2str(options.MaxStep));
end

% Simulate and analyze.
simOut = sim(simIn);
simlog = simOut.(reg.simlogVar);

lossData = powerLossFromSimscapeLog(simlog, ...
    SwitchingLossDetail=options.SwitchingLossDetail, ...
    AveragingWindow=options.AveragingWindow, ...
    FrequencyHz=options.FrequencyHz, ...
    MinCycles=options.MinCycles, ...
    LoadIdentifier=char(reg.loadIdentifier), ...
    ShowPlots=options.ShowPlots, ...
    Interactions=options.Interactions, ...
    ModelName=modelName);
end

% ======================================================================
function simIn = applySimulationTemperature(simIn, plant, reg, requestedTemperature)
% Set the plant's device temperature mask parameters, if the registry lists them.
if isempty(requestedTemperature) || ~isfield(reg,'simTempParams') || isempty(reg.simTempParams)
    return;
end

% Convert the temperature to degC.
if isa(requestedTemperature,'simscape.Value')
    temperatureDegC = convert(requestedTemperature, "degC");
    temperatureDegC = temperatureDegC.value;
else
    temperatureDegC = double(requestedTemperature);
end

% Set each temperature parameter that exists on the mask, with its unit in degC.
existingMaskNames = get_param(plant, 'MaskNames');
for k = 1:numel(reg.simTempParams)
    thisParam = reg.simTempParams(k);
    if ~ismember(thisParam.valueParam, existingMaskNames)
        continue;
    end
    simIn = setBlockParameter(simIn, plant, thisParam.valueParam, num2str(temperatureDegC));
    if isfield(thisParam,'unitParam') && ~isempty(thisParam.unitParam) ...
            && ismember(thisParam.unitParam, existingMaskNames)
        simIn = setBlockParameter(simIn, plant, thisParam.unitParam, 'degC');
    end
end
end

% ======================================================================
function restoreFidelity(plant, originalFidelity)
% Restore the plant's original device fidelity popups.
for f = fieldnames(originalFidelity)'
    try set_param(plant, f{1}, originalFidelity.(f{1})); catch, end
end
end

% ======================================================================
function history = requiredLogHistory(modelName, options)
% Simscape log length, in samples, that holds the averaging window. The window is the
% AveragingWindow given in time, else MinCycles periods of FrequencyHz or the
% AveragingWindow fraction of the run, whichever is longer. The sample spacing is the Simscape local solver step, or the maximum
% step without a local solver, with a 50 % margin for extra steps. Empty when the log is
% not limited or the step cannot be read, in which case the model setting is kept and
% powerLossFromSimscapeLog reports a log that is too short.
history = [];
if strcmp(get_param(modelName, 'SimscapeLogLimitData'), 'off')
    return
end

stopTime = value(convert(options.SimTime, "s"));
averagingWindow = options.AveragingWindow;
if isa(averagingWindow, 'simscape.Value')
    % The log has to reach back from the stop time to the start of the window
    windowDuration = stopTime - value(convert(averagingWindow(1), "s"));
elseif all(averagingWindow <= 1)
    windowDuration = options.MinCycles / options.FrequencyHz;
    windowDuration = max(windowDuration, diff(averagingWindow) * stopTime);
else
    windowDuration = stopTime - averagingWindow(1);
end
% A window past the stop time leaves nothing to hold, so the whole run is kept
if ~(windowDuration > 0)
    windowDuration = stopTime;
end
windowDuration = min(windowDuration, stopTime);

% Sample spacing: the smallest local solver step, else the maximum step
sampleSpacing = [];
solverBlocks = find_system(modelName, 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
    'MatchFilter', @Simulink.match.activeVariants, 'ReferenceBlock', 'nesl_utility/Solver Configuration');
for blockIndex = 1:numel(solverBlocks)
    if strcmp(get_param(solverBlocks{blockIndex}, 'UseLocalSolver'), 'on')
        try
            localStep = slResolve(get_param(solverBlocks{blockIndex}, 'LocalSolverSampleTime'), solverBlocks{blockIndex});
            sampleSpacing = min([sampleSpacing, localStep]);
        catch
        end
    end
end
if isempty(sampleSpacing)
    if ~isempty(options.MaxStep)
        sampleSpacing = options.MaxStep;
    else
        sampleSpacing = str2double(get_param(modelName, 'MaxStep'));
    end
end
if isempty(sampleSpacing) || ~isfinite(sampleSpacing) || sampleSpacing <= 0
    return
end

if ~isempty(options.LogDecimation)
    decimation = options.LogDecimation;
else
    decimation = str2double(get_param(modelName, 'SimscapeLogDecimation'));
end
if ~isfinite(decimation) || decimation < 1
    decimation = 1;
end

% Never shorter than the model's own setting
history = ceil(1.5 * windowDuration / (sampleSpacing * decimation));
modelHistory = str2double(get_param(modelName, 'SimscapeLogDataHistory'));
if isfinite(modelHistory)
    history = max(history, modelHistory);
end
end
