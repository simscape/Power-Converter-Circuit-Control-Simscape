function setConverterFidelity(modelName, tier)
%SETCONVERTERFIDELITY Set a harness model's device fidelity and solver step.
%   SETCONVERTERFIDELITY(modelName, tier)
%
%   Inputs:
%     modelName  Name of the harness model.
%     tier       Device option, case-insensitive:
%                  "Ideal Switch", "ideal", "fast" or "simplified" - ideal devices
%                  "MOSFET (Ideal, Switching) with Thermal Port", any "... with Thermal"
%                  option, "loss", "detailed" or "thermal" - thermal devices

% Copyright 2026 The MathWorks, Inc.

arguments
    modelName (1,:) char
    tier (1,:) char
end

load_system(modelName);

% Find the converter registry entry.
converterKey = localResolveConverterKey(modelName);
reg = converterRegistry(converterKey);

% Find the plant block, exact name first, then partial.
topBlocks = find_system(modelName,'SearchDepth',1,'Type','block');
topNames = cellfun(@(blockPath) get_param(blockPath,'Name'), topBlocks, ...
    'UniformOutput', false);
plant = topBlocks(strcmp(topNames, char(reg.plantSubsystem)));
if isempty(plant)
    plant = topBlocks(contains(topNames, char(reg.plantSubsystem)));
end
if isempty(plant)
    error('setConverterFidelity:plantNotFound', ...
        'Plant subsystem containing "%s" not found in "%s".', reg.plantSubsystem, modelName);
end
plant = plant{1};

% Normalize the tier text and pick the fidelity settings.
normalizedTier = lower(strtrim(regexprep(tier, '\s+', ' ')));
normalizedTier = regexprep(normalizedTier, ' port$', '');
if any(strcmp(normalizedTier, {'ideal switch','ideal diode','ideal','fast','simplified'}))
    fidelity = reg.idealFidelity;
    tierName = "Ideal Switch - fast, ideal devices";
elseif contains(normalizedTier, 'with thermal') || ...
        any(strcmp(normalizedTier, {'loss','detailed','thermal'}))
    fidelity = reg.lossFidelity;
    tierName = "MOSFET (Ideal, Switching) with Thermal Port - thermal / tabulated devices";
else
    error('setConverterFidelity:badTier', ...
        ['Unknown fidelity tier "%s". Use the device-model option string ' ...
        '"Ideal Switch" or "MOSFET (Ideal, Switching) with Thermal Port".'], tier);
end

% Set the device options on the plant mask.
fn = fieldnames(fidelity);
for i = 1:numel(fn)
    try
        set_param(plant, fn{i}, fidelity.(fn{i}));
    catch ME
        warning('setConverterFidelity:paramFailed', ...
            'Could not set %s on plant: %s', fn{i}, ME.message);
    end
end

% Choose the maximum step from the model option.
isAveraged = false;
if isfield(fidelity,'modelOption')
    isAveraged = strcmpi(fidelity.modelOption,'Simplified');
end
if isAveraged
    maxStep = '1e-5';   % averaged power stage
else
    maxStep = '1e-6';   % switching power stage
end

% Set the solver.
set_param(modelName, ...
    'SolverType', 'Variable-step', ...
    'Solver',     'ode23t', ...
    'MaxStep',    maxStep, ...
    'AbsTol',     '1e-3', ...
    'RelTol',     '1e-3');

fprintf('Fidelity set to %s. Solver: ode23t, MaxStep=%s.\n', tierName, maxStep);
end

% ======================================================================
function key = localResolveConverterKey(modelName)
% Return the converter key from the model workspace or the plant block name.
key = '';
try
    if hasVariable(get_param(modelName,'ModelWorkspace'), 'ConverterKey')
        key = char(getVariable(get_param(modelName,'ModelWorkspace'),'ConverterKey'));
    end
catch
end
if ~isempty(key), return; end

% Match the plant name: an exact match wins, else the longest partial match.
topBlocks = find_system(modelName,'SearchDepth',1,'Type','block');
topNames = cellfun(@(blockPath) get_param(blockPath,'Name'), topBlocks, ...
    'UniformOutput', false);
bestPartialKey = '';
bestPartialLength = 0;
for k = converterRegistry()
    r = converterRegistry(k);
    plantName = char(r.plantSubsystem);
    if any(strcmp(topNames, plantName))
        key = char(k);
        return;
    end
    if any(contains(topNames, plantName)) && numel(plantName) > bestPartialLength
        bestPartialKey = char(k);
        bestPartialLength = numel(plantName);
    end
end
if ~isempty(bestPartialKey)
    key = bestPartialKey;
    return;
end
error('setConverterFidelity:unknownConverter', ...
    'Could not identify the converter for model "%s".', modelName);
end
