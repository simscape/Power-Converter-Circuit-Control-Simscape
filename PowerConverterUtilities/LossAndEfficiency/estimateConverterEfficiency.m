function lossData = estimateConverterEfficiency(source, loadBlocks, options)
%ESTIMATECONVERTEREFFICIENCY Loss and efficiency of any Simscape model.
%   lossData = ESTIMATECONVERTEREFFICIENCY(source, loadBlocks)
%   lossData = ESTIMATECONVERTEREFFICIENCY(source, loadBlocks, Name=Value)
%
%   Inputs:
%     source      Simscape log (simscape.logging.Node), or a model name to run.
%     loadBlocks  Load block path, or cell array of paths, that set the output power.
%
%   Name-value options:
%     TimeWindow          Fraction of the log span, or [tStart tEnd] in s. Default [0.8 1].
%     SwitchingLossDetail "lumped" (default) or "separated".
%     ShowPlots           Draw the loss figures. Default true.
%     Fidelity            Struct with BlockPath and Popups, set before the run and restored after.
%     SimlogVariable      Name of the Simscape log in simOut. Default: detected.
%
%   Outputs:
%     lossData  Result struct from powerLossFromSimscapeLog.

% Copyright 2026 The MathWorks, Inc.

arguments
    source
    loadBlocks
    options.TimeWindow (1,2) double = [0.8 1]
    options.SwitchingLossDetail (1,:) char {mustBeMember(options.SwitchingLossDetail,{'lumped','separated'})} = 'lumped'
    options.ShowPlots (1,1) logical = true
    options.Fidelity = []
    options.SimlogVariable (1,:) char = ''
end

% Convert the load block paths to leaf names.
loadIds = loadIdentifiersFromPaths(loadBlocks);

% Use the given log, or run the model to get one.
if isa(source, 'simscape.logging.Node')
    simlog = source;
    modelName = '';
else
    modelName = char(source);
    simlog = runAndGetSimlog(modelName, options.Fidelity, options.SimlogVariable);
end

lossData = powerLossFromSimscapeLog(simlog, ...
    AveragingWindow=options.TimeWindow, ...
    SwitchingLossDetail=options.SwitchingLossDetail, ...
    LoadIdentifier=loadIds, ...
    ShowPlots=options.ShowPlots, ...
    ModelName=modelName);
end

% ======================================================================
function loadIds = loadIdentifiersFromPaths(loadBlocks)
% Return the unique leaf block names of the load block paths.
if ischar(loadBlocks) || isstring(loadBlocks)
    paths = cellstr(loadBlocks);
elseif iscell(loadBlocks)
    paths = cellfun(@char, loadBlocks, 'UniformOutput', false);
else
    error('estimateConverterEfficiency:badLoad', ...
        'loadBlocks must be a block path (char/string) or a cell array of paths.');
end
loadIds = strings(1, numel(paths));
for i = 1:numel(paths)
    parts = split(string(paths{i}), '/');
    loadIds(i) = parts(end);
end
loadIds = unique(loadIds, 'stable');
end

% ======================================================================
function simlog = runAndGetSimlog(modelName, fidelity, simlogVar)
% Run the model and return its Simscape log.
load_system(modelName);

% Set the fidelity popups and restore them on exit.
restorer = [];
if ~isempty(fidelity)
    blk = char(fidelity.BlockPath);
    popups = fidelity.Popups;
    orig = struct();
    for f = fieldnames(popups)'
        try orig.(f{1}) = get_param(blk, f{1}); catch, end
    end
    restorer = onCleanup(@() restorePopups(blk, orig)); %#ok<NASGU>
    for f = fieldnames(popups)'
        set_param(blk, f{1}, popups.(f{1}));
    end
end

% Turn on Simscape logging if it is off.
simscapeLogWasOff = false;
try
    if strcmp(get_param(modelName,'SimscapeLogType'),'none')
        set_param(modelName,'SimscapeLogType','all');
        simscapeLogWasOff = true; %#ok<NASGU>
    end
catch
end

% Simulate and return a Simulink.SimulationOutput.
simIn = Simulink.SimulationInput(modelName);
simIn = setModelParameter(simIn, 'ReturnWorkspaceOutputs', 'on');
simOut = sim(simIn);

% Find the Simscape log variable.
if ~isempty(simlogVar)
    simlog = simOut.(simlogVar);
    return;
end
vars = simOut.who;
logVars = vars(cellfun(@(v) isa(simOut.(v),'simscape.logging.Node'), vars));
if isempty(logVars)
    error('estimateConverterEfficiency:noSimlog', ...
        ['No Simscape log found in the simulation output of "%s". Enable Simscape ' ...
         'logging (set_param(model,''SimscapeLogType'',''all'')) or pass SimlogVariable.'], modelName);
end
simlog = simOut.(logVars{1});
end

% ======================================================================
function restorePopups(blk, orig)
% Restore the saved mask popup values.
for f = fieldnames(orig)'
    try set_param(blk, f{1}, orig.(f{1})); catch, end
end
end
