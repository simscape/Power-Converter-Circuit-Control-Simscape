function lossData = powerLossFromSimscapeLog(simlog, options)
%POWERLOSSFROMSIMSCAPELOG Semiconductor loss and efficiency from a Simscape log.
%   lossData = POWERLOSSFROMSIMSCAPELOG(simlog)
%   lossData = POWERLOSSFROMSIMSCAPELOG(simlog, Name=Value)
%
%   Inputs:
%     simlog  Simscape log node (simscape.logging.Node) of a simulated converter.
%
%   Name-value options:
%     AveragingWindow      [tStart tEnd] as a simscape.Value time, for example
%                          simscape.Value([20 40],"ms"), or a fraction of the log span.
%                          Default [0.9 1].
%     FrequencyHz          Switching frequency, in Hz. Default [].
%     MinCycles            Whole periods of FrequencyHz averaged at the end of the log.
%                          Default 10.
%     SwitchingLossDetail  "lumped" (default) or "separated".
%     LoadIdentifier       Load block name substrings. Default "Rload".
%     GroupLabelMap        Dictionary that renames group labels. Default empty.
%     ShowPlots            Draw the loss figures. Default true.
%     Interactions         Keep the default axes interactions and toolbar. Default false.
%     Plots                Figures to draw. Default ["deviceBar","groupPie"].
%     ModelName            Model name for the plot titles. Default "".
%
%   Outputs:
%     lossData  Struct with fields:
%       .deviceTable        Loss per device, in W.
%       .groupTable         Loss per group, in W.
%       .deviceTypeTable    Loss per device class, in W.
%       .passiveLoss        Passive component loss, in W.
%       .outputPower        Load power, in W.
%       .totalLoss          Device plus passive loss, in W.
%       .efficiency         Efficiency, in percent.
%       .averagingWindow    Averaging window [tStart tEnd], in s.
%       .percentageByGroup  Loss share per group, in percent.

% Copyright 2026 The MathWorks, Inc.

arguments
    simlog {mustBeA(simlog,'simscape.logging.Node')}
    options.AveragingWindow {mustBeAveragingWindow} = [0.9 1]
    options.FrequencyHz double = []
    options.MinCycles (1,1) double = 10
    options.SwitchingLossDetail (1,:) char {mustBeMember(options.SwitchingLossDetail,{'lumped','separated'})} = 'lumped'
    options.LoadIdentifier (1,:) string = "Rload"
    options.GroupLabelMap = dictionary
    options.ShowPlots (1,1) logical = true
    options.Plots (1,:) string = ["deviceBar","groupPie"]
    options.ModelName (1,:) char = ''
    options.Interactions (1,1) logical = false
end

% ------------------------------------------------------------------
% 1. Averaging window in seconds.
% ------------------------------------------------------------------
% A fraction window is widened to span at least MinCycles switching periods.
tSpan = localTimeSpan(simlog);
win = options.AveragingWindow;
if isa(win, 'simscape.Value')
    % A window in time units is kept to the simulated data and, with FrequencyHz, to the
    % whole periods that fit in it, ending at its latest sample. An average over part of
    % a period is biased, for example part of a PFC line cycle.
    requestedWindow = value(convert(win, "s"));
    tStart = max(requestedWindow(1), tSpan(1));
    tEnd   = min(requestedWindow(2), tSpan(2));
    if tEnd <= tStart
        % No overlap with the data: use the data there is
        tStart = tSpan(1); tEnd = tSpan(2);
    end
    if ~isempty(options.FrequencyHz) && options.FrequencyHz > 0
        period = 1 / options.FrequencyHz;
        wholePeriods = floor((tEnd - tStart) / period + 1e-3);
        if wholePeriods >= 1
            tStart = tEnd - wholePeriods * period;
        else
            warning('powerLossFromSimscapeLog:insufficientData', ...
                ['The averaging window holds %.3g periods of %g Hz, less than one, so the loss ' ...
                 'is averaged over part of a period. Lengthen SimTime or the window.'], ...
                (tEnd - tStart) / period, options.FrequencyHz);
        end
        tolerance = 1e-3 * period;
    else
        tolerance = 1e-6 * max(tSpan(2), eps);
    end
    if abs(tStart - requestedWindow(1)) > tolerance || abs(tEnd - requestedWindow(2)) > tolerance
        warning('powerLossFromSimscapeLog:windowAdjusted', ...
            ['The loss is averaged over %.4g-%.4g ms, the part of the requested %.4g-%.4g ms ' ...
             'window that the simulation covers in whole periods.'], ...
            1e3 * tStart, 1e3 * tEnd, 1e3 * requestedWindow(1), 1e3 * requestedWindow(2));
    end
elseif all(win <= 1) && win(2) <= 1
    % A fraction of the log, ending at its end. With FrequencyHz it becomes a whole number
    % of periods, at least MinCycles of them, so the default is the last MinCycles periods
    % of the run.
    logSpan = tSpan(2) - tSpan(1);
    tEnd    = tSpan(1) + win(2)*logSpan;
    windowDuration = (win(2)-win(1))*logSpan;
    if ~isempty(options.FrequencyHz) && options.FrequencyHz > 0
        period = 1 / options.FrequencyHz;
        wholePeriods = max(options.MinCycles, floor(windowDuration / period + 1e-3));
        availablePeriods = floor((tEnd - tSpan(1)) / period + 1e-3);
        if availablePeriods < wholePeriods
            % Too little data: use the whole periods there are, or all of it
            if availablePeriods >= 1
                warning('powerLossFromSimscapeLog:insufficientData', ...
                    ['The simulation holds only %d whole period(s) of %g Hz, fewer than the %d ' ...
                     'asked for, so the loss is averaged over %d. Lengthen SimTime for more.'], ...
                    availablePeriods, options.FrequencyHz, wholePeriods, availablePeriods);
            else
                warning('powerLossFromSimscapeLog:insufficientData', ...
                    ['The simulation holds %.3g periods of %g Hz, less than one, so the loss is ' ...
                     'averaged over part of a period. Lengthen SimTime.'], ...
                    (tEnd - tSpan(1)) / period, options.FrequencyHz);
            end
            wholePeriods = availablePeriods;
        end
        if wholePeriods >= 1
            windowDuration = wholePeriods * period;
        else
            windowDuration = tEnd - tSpan(1);
        end
    end
    tStart = max(tSpan(1), tEnd - windowDuration);
else
    tStart = win(1); tEnd = win(2);
end
lossData.averagingWindow = [tStart tEnd];

% ------------------------------------------------------------------
% 2. Find and classify devices.
% ------------------------------------------------------------------
loadIds = string(options.LoadIdentifier);
devices = discoverDevices(simlog, loadIds);
semis = devices([devices.isSemiconductor]);
% Warn about and drop devices that log no loss data.
lossless = semis(~[semis.hasLossVariables]);
if ~isempty(lossless)
    warning('powerLossFromSimscapeLog:deviceWithoutLossData', ...
        ['%d semiconductor device(s) log no loss data and are excluded from the ' ...
         'totals, the first being %s. Select a loss-capable device variant ' ...
         '(thermal MOSFET/IGBT, tabulated diode) if their loss matters.'], ...
        numel(lossless), lossless(1).path);
end
semis = semis(logical([semis.hasLossVariables]));
if isempty(semis)
    error('powerLossFromSimscapeLog:noLossData', ...
        ['No semiconductor loss data found in the simulation log. Re-run with ' ...
         'loss-capable fidelity (thermal MOSFET/IGBT and tabulated diode) so the ' ...
         'power_dissipated and switching-loss variables are logged.']);
end

% ------------------------------------------------------------------
% 3. Loss per device.
% ------------------------------------------------------------------
sep = strcmp(options.SwitchingLossDetail,'separated');
names = strings(numel(semis),1);
classes = strings(numel(semis),1);
groups = strings(numel(semis),1);
cond = zeros(numel(semis),1);
if sep
    turnOn = zeros(numel(semis),1); turnOff = zeros(numel(semis),1); recov = zeros(numel(semis),1);
else
    switching = zeros(numel(semis),1);
end
paths = strings(numel(semis),1);
for i = 1:numel(semis)
    d = semis(i);
    names(i)   = string(d.name);
    classes(i) = string(d.class);
    groups(i)  = string(d.parentGroup);
    paths(i)   = string(d.path);

    % Conduction loss is power_dissipated summed over the device subtree.
    cond(i) = subtreeAverage(d.lossNodes, 'power_dissipated', tStart, tEnd, 'W');
    if sep
        [turnOn(i), turnOff(i), recov(i)] = ...
            subtreeSwitchingSeparated(d.lossNodes, d.class, tStart, tEnd);
    else
        switching(i) = subtreeSwitchingLumped(d.lossNodes, tStart, tEnd);
    end
end

groups = applyGroupLabelMap(groups, options.GroupLabelMap);

% Build the device table.
if sep
    total = cond + turnOn + turnOff + recov;
    lossData.deviceTable = table(names, classes, groups, cond, turnOn, turnOff, recov, total, ...
        'VariableNames', {'Name','Class','Group','Conduction','TurnOn','TurnOff','Recovery','Total'});
else
    total = cond + switching;
    lossData.deviceTable = table(names, classes, groups, cond, switching, total, ...
        'VariableNames', {'Name','Class','Group','Conduction','Switching','Total'});
end
lossData.deviceTable = sortrows(lossData.deviceTable, 'Name');

% ------------------------------------------------------------------
% 4. Passive, group and device-class totals.
% ------------------------------------------------------------------
passiveLoss = 0;
passives = devices(~[devices.isSemiconductor] & ~[devices.isLoad]);
for i = 1:numel(passives)
    passiveLoss = passiveLoss + averageSeries(passives(i).node, 'power_dissipated', tStart, tEnd, 'W');
end
lossData.passiveLoss = passiveLoss;

deviceTotal = sum(total);
lossData.totalLoss = deviceTotal + passiveLoss;

% Group totals, plus one "Passive" group.
[gNames,gFirst,gIdx] = unique(groups,'stable');
gTot = accumarray(gIdx, total);
gDisplay = strings(numel(gNames),1);
for k = 1:numel(gNames)
    gDisplay(k) = friendlyGroupLabel(paths(gFirst(k)), classes(gFirst(k)));
end
gDisplay = nameSecondarySideFromRectifier(gDisplay);
gDisplay = uniquifyGroupLabels(gDisplay, gNames);
gNames   = [gNames; "Passive"];
gDisplay = [gDisplay; "Passive Components"];
gTot     = [gTot; passiveLoss];
lossData.groupTable = table(gNames, gDisplay, gTot, 'VariableNames', {'Group','Label','Loss'});

% Device-class totals.
[cNames,~,cIdx] = unique(classes,'stable');
cTot = accumarray(cIdx, total);
lossData.deviceTypeTable = table(cNames, cTot, 'VariableNames', {'DeviceClass','Loss'});

% ------------------------------------------------------------------
% 5. Efficiency.
% ------------------------------------------------------------------
% Output power is the summed load power.
loadDev = devices([devices.isLoad]);
lossData.outputPower = 0;
for i = 1:numel(loadDev)
    lossData.outputPower = lossData.outputPower + averageSeries(loadDev(i).node,'power_dissipated',tStart,tEnd,'W');
end
% Efficiency = Pout / (Pout + total loss).
if lossData.outputPower > 0
    lossData.efficiency = 100*lossData.outputPower/(lossData.outputPower + lossData.totalLoss);
else
    lossData.efficiency = NaN;
    warning('powerLossFromSimscapeLog:noOutputPower', ...
        ['No output power found - check the LoadIdentifier (given: %s) matches a ' ...
         'dissipative load block in the model.'], strjoin(cellstr(loadIds), ', '));
end

% Loss share per group for the pie chart.
pct = 100*lossData.groupTable.Loss/sum(lossData.groupTable.Loss);
lossData.percentageByGroup = table(lossData.groupTable.Label, pct, ...
    'VariableNames', {'Group','Percentage'});

% ------------------------------------------------------------------
% 6. Plots.
% ------------------------------------------------------------------
if options.ShowPlots
    if any(options.Plots=="deviceBar"), plotDeviceBar(lossData, sep, options.ModelName, options.Interactions); end
    if any(options.Plots=="groupPie"),  plotGroupPie(lossData, options.Interactions); end
end
end

% ======================================================================
function mustBeAveragingWindow(window)
% A 1x2 increasing window: a simscape.Value with a time unit, or a double.
if isa(window, 'simscape.Value')
    window = value(convert(window, "s"));
end
if ~isnumeric(window) || numel(window) ~= 2 || ~(window(2) > window(1))
    error('powerLossFromSimscapeLog:badAveragingWindow', ...
        'AveragingWindow must be [tStart tEnd] with tEnd after tStart.');
end
end

% ======================================================================
function devices = discoverDevices(simlog, loadId)
% Return every semiconductor, dissipating component and load in the log.
devices = struct('name',{},'path',{},'node',{},'class',{}, ...
    'parentGroup',{},'isSemiconductor',{},'isLoad',{},'lossNodes',{}, ...
    'hasLossVariables',{});
devices = walk(simlog, string(simlog.id), string(simlog.id), devices, string(loadId));
end

function devices = walk(node, path, parentPath, devices, loadIds)
% Recursively add the devices under one log node.
ids = string(node.childIds);
[cls, isSemi] = classifyDevice(ids);
if isSemi
    % A semiconductor owns its whole subtree, so do not recurse further.
    e = newDeviceEntry(node, path, parentPath, cls, true, false);
    e.lossNodes = collectSubtree(node, {});
    e.hasLossVariables = subtreeHasLossVariables(e.lossNodes);
    devices(end+1) = e;
    return;
end
if any(ids=="power_dissipated")
    % Passive component, or the load if its name matches.
    isLoad = any(contains(lower(string(node.id)), lower(loadIds)));
    e = newDeviceEntry(node, path, parentPath, cls, false, isLoad);
    e.lossNodes = {node};
    e.hasLossVariables = true;
    devices(end+1) = e;
end
% Recurse into child nodes.
for k = 1:numel(ids)
    id = ids(k);
    child = node.(id);
    if isa(child,'simscape.logging.Node') && ~isempty(child.childIds)
        devices = walk(child, path+"."+id, path, devices, loadIds);
    end
end
end

% ======================================================================
function e = newDeviceEntry(node, path, parentPath, deviceClass, isSemiconductor, isLoad)
% Create one device entry.
e.name = char(node.id);
e.path = char(path);
e.node = node;
e.class = deviceClass;
% Group by the full path of the containing subsystem.
e.parentGroup = char(parentPath);
e.isSemiconductor = isSemiconductor;
e.isLoad = isLoad;
e.lossNodes = {};
e.hasLossVariables = false;
end

% ======================================================================
function nodes = collectSubtree(node, nodes)
% Return a node and all its descendant nodes.
nodes{end+1} = node;
ids = string(node.childIds);
for k = 1:numel(ids)
    child = node.(ids(k));
    if isa(child,'simscape.logging.Node') && ~isempty(child.childIds)
        nodes = collectSubtree(child, nodes);
    end
end
end

% ======================================================================
function tf = subtreeHasLossVariables(lossNodes)
% True if any node in the subtree logs a loss variable.
tf = false;
lossVariables = ["power_dissipated" "accumulatedSwitchingLosses" ...
    "accumulatedTurnOnLosses" "accumulatedTurnOffLosses" ...
    "accumulatedReverseRecoveryLosses" "accumulatedReverseRecoveryLoss"];
for k = 1:numel(lossNodes)
    if any(ismember(lossVariables, string(lossNodes{k}.childIds)))
        tf = true;
        return;
    end
end
end

% ======================================================================
function p = subtreeAverage(lossNodes, varName, tStart, tEnd, unitName)
% Time average of one variable, summed over the subtree nodes.
p = 0;
for k = 1:numel(lossNodes)
    p = p + averageSeries(lossNodes{k}, varName, tStart, tEnd, unitName);
end
end

% ======================================================================
function p = subtreeSwitchingLumped(lossNodes, tStart, tEnd)
% Total switching power, summed over the subtree nodes.
p = 0;
for k = 1:numel(lossNodes)
    c = nodeSwitchingComponents(lossNodes{k}, tStart, tEnd);
    if c.hasLumped
        % Use the lumped total when the node logs one.
        p = p + c.lumped;
    else
        p = p + c.turnOn + c.turnOff + c.recovery;
    end
end
end

% ======================================================================
function [turnOn, turnOff, recovery] = subtreeSwitchingSeparated(lossNodes, deviceClass, ...
    tStart, tEnd)
% Turn-on, turn-off and recovery power, summed over the subtree nodes.
% A lumped-only node counts as recovery for a diode, turn-off otherwise.
turnOn = 0; turnOff = 0; recovery = 0;
for k = 1:numel(lossNodes)
    c = nodeSwitchingComponents(lossNodes{k}, tStart, tEnd);
    if c.hasSeparated
        turnOn   = turnOn   + c.turnOn;
        turnOff  = turnOff  + c.turnOff;
        recovery = recovery + c.recovery;
    elseif c.hasLumped
        if strcmpi(deviceClass,'Diode')
            recovery = recovery + c.lumped;
        else
            turnOff = turnOff + c.lumped;
        end
    end
end
end

% ======================================================================
function components = nodeSwitchingComponents(node, tStart, tEnd)
% Average switching power of each energy accumulator on one node.
% Reads both spellings of the reverse-recovery accumulator.
ids = string(node.childIds);
components.turnOn   = ratePerWindow(node, 'accumulatedTurnOnLosses',  tStart, tEnd);
components.turnOff  = ratePerWindow(node, 'accumulatedTurnOffLosses', tStart, tEnd);
components.recovery = ratePerWindow(node, 'accumulatedReverseRecoveryLosses', tStart, tEnd) ...
                    + ratePerWindow(node, 'accumulatedReverseRecoveryLoss',   tStart, tEnd);
components.lumped   = ratePerWindow(node, 'accumulatedSwitchingLosses', tStart, tEnd);
components.hasSeparated = any(ismember(["accumulatedTurnOnLosses" "accumulatedTurnOffLosses" ...
    "accumulatedReverseRecoveryLosses" "accumulatedReverseRecoveryLoss"], ids));
components.hasLumped = any(ids == "accumulatedSwitchingLosses");
end

% ======================================================================
function label = friendlyGroupLabel(devicePath, deviceClass)
% Group label from the device path and class, for example "Primary MOSFETs".
p = lower(replace(string(devicePath), "_", " "));

% Side from the path.
if contains(p,"primary")
    side = "Primary ";
elseif contains(p,"secondary")
    side = "Secondary ";
else
    side = "";
end
% Leg from the path.
if contains(p,"fastleg") || contains(p,"fast leg")
    leg = "Fast Leg ";
elseif contains(p,"slowleg") || contains(p,"slow leg")
    leg = "Slow Leg ";
else
    leg = "";
end
% Stage from the path; "boost" is read below the fidelity variant only.
if contains(p,"rectifier")
    stage = "Rectifier ";
elseif contains(p,"inverter")
    stage = "Inverter ";
elseif contains(p,"bridge")
    stage = "Bridge ";
elseif contains(pathBelowFidelityVariant(devicePath),"boost")
    stage = "Boost ";
else
    stage = "";
end
% Use side and leg if present, otherwise the stage.
if strlength(side) > 0 || strlength(leg) > 0
    role = side + leg;
else
    role = stage;
end

% Device class, plural.
switch upper(string(deviceClass))
    case "MOSFET",    dev = "MOSFETs";
    case "IGBT",      dev = "IGBTs";
    case "DIODE",     dev = "Diodes";
    case "THYRISTOR", dev = "Thyristors";
    otherwise,        dev = string(deviceClass) + "s";
end

% Default role from the device class.
if strlength(role) == 0
    switch upper(string(deviceClass))
        case {"DIODE","THYRISTOR"}, role = "Rectifier ";
        case {"MOSFET","IGBT"},     role = "Converter ";
    end
end

label = strtrim(role + dev);
if strlength(label) == 0
    label = strtrim(dev);
end
end

% ======================================================================
function labels = nameSecondarySideFromRectifier(labels)
% Rename "Rectifier" groups to "Secondary" when a "Primary" group exists.
labels = string(labels);
if ~any(startsWith(labels, "Primary "))
    return
end
isRectifierGroup = startsWith(labels, "Rectifier ");
labels(isRectifierGroup) = replace(labels(isRectifierGroup), "Rectifier ", "Secondary ");
end

% ======================================================================
function roleOnlyPath = pathBelowFidelityVariant(devicePath)
% Part of the log path below the fidelity variant, or the whole path if none.
segments = split(lower(replace(string(devicePath), "_", "")), ".");
variantIndex = find(endsWith(segments,"variant") | ...
    ismember(segments, ["detailedmodel" "simplifiedmodel"]), 1, 'last');
if isempty(variantIndex) || variantIndex == numel(segments)
    roleOnlyPath = join(segments, ".");
else
    roleOnlyPath = join(segments(variantIndex+1:end), ".");
end
end

% ======================================================================
function labels = uniquifyGroupLabels(labels, groupPaths)
% Append the first differing path segment to duplicate labels.
labels = string(labels);
groupPaths = string(groupPaths);
for whichLabel = reshape(unique(labels), 1, [])
    tied = find(labels == whichLabel);
    if numel(tied) < 2
        continue
    end
    segments = arrayfun(@(k) split(groupPaths(k), "."), tied, 'UniformOutput', false);
    sharedDepth = min(cellfun(@numel, segments));
    for whichSegment = 1:sharedDepth
        segmentNames = cellfun(@(s) s(whichSegment), segments);
        if numel(unique(segmentNames)) > 1
            labels(tied) = whichLabel + " (" + ...
                disambiguatingSuffix(whichLabel, segmentNames) + ")";
            break
        end
    end
end
end

% ======================================================================
function suffix = disambiguatingSuffix(baseLabel, segmentNames)
% Suffix text that tells duplicate labels apart.
segmentNames = string(segmentNames);
% Numbered segments with a common stem become "Leg N".
indexTokens = regexp(segmentNames, '^(.*?)(\d+)$', 'tokens', 'once');
if all(~cellfun(@isempty, indexTokens))
    stems   = strings(size(segmentNames));
    indices = strings(size(segmentNames));
    for whichName = 1:numel(indexTokens)
        tokenPair = string(indexTokens{whichName});
        stems(whichName)   = tokenPair(1);
        indices(whichName) = tokenPair(2);
    end
    if isscalar(unique(lower(stems)))
        suffix = "Leg " + indices;
        return
    end
end

% Otherwise use the segment name, without words already in the label.
suffix = humanizeLogName(segmentNames);
labelWords = regexprep(lower(split(string(baseLabel), " ")), 's$', '');
for whichSuffix = 1:numel(suffix)
    words = split(suffix(whichSuffix), " ");
    isNew = ~ismember(regexprep(lower(words), 's$', ''), labelWords);
    if any(isNew)
        suffix(whichSuffix) = join(words(isNew), " ");
    end
end
end

% ======================================================================
function readable = humanizeLogName(rawName)
% Split a log name into words, for example "FastLeg" -> "Fast Leg".
readable = replace(string(rawName), "_", " ");
readable = regexprep(readable, '([a-z0-9])([A-Z])', '$1 $2');
readable = regexprep(readable, '([A-Za-z])(\d+)$', '$1 $2');
readable = strtrim(readable);
end

% ======================================================================
function [cls, isSemi] = classifyDevice(ids)
% Classify a log node as MOSFET, IGBT, Thyristor, Diode or Passive from its variables.
hasTurnOn  = any(ids=="lastTurnOnLoss") || any(ids=="accumulatedTurnOnLosses");
hasTurnOff = any(ids=="lastTurnOffLoss")|| any(ids=="accumulatedTurnOffLosses");
hasRecov   = any(ids=="lastReverseRecoveryLoss") || ...
    any(ids=="accumulatedReverseRecoveryLosses") || any(ids=="accumulatedReverseRecoveryLoss");
hasGatedSwitching = hasTurnOn || hasTurnOff || any(ids=="accumulatedSwitchingLosses");
hasChannel = any(ids=="vds") || any(ids=="ids");
hasIGBTchannel = any(ids=="vce") || any(ids=="ic");
hasThyristorChannel = any(ids=="vak") || any(ids=="iak");
hasDiodeMarker = any(ids=="v_on") || hasRecov || ...
    (any(ids=="v_diode") && any(ids=="i_diode")) || hasInternalDiodeComponent(ids);

isSemi = false; cls = "Passive";
if hasGatedSwitching || hasChannel || hasIGBTchannel || hasThyristorChannel
    % Controlled device; MOSFET unless the channel says otherwise.
    isSemi = true;
    if hasIGBTchannel
        cls = "IGBT";
    elseif hasThyristorChannel
        cls = "Thyristor";
    else
        cls = "MOSFET";
    end
elseif hasDiodeMarker
    isSemi = true; cls = "Diode";
end
end

% ======================================================================
function tf = hasInternalDiodeComponent(ids)
% True if the node has its own terminals and a "diode" child or junction charge.
hasOwnTerminals = all(ismember(["i" "n" "p" "v"], ids));
namesDiodeComponent = any(strcmpi(ids, "diode"));
hasJunctionCharge = any(ids=="Qj") && any(ids=="i_capacitor");
tf = hasOwnTerminals && (namesDiodeComponent || hasJunctionCharge);
end

% ======================================================================
function v = averageSeries(node, varName, tStart, tEnd, unitName)
% Time-weighted average of a logged variable over the window, or 0 if absent.
v = 0;
if ~any(string(node.childIds)==varName), return; end
[t, y] = seriesInUnit(node, varName, unitName);
w = t>=tStart & t<=tEnd;
tw = t(w); yw = y(w);
if numel(tw) >= 2 && (tw(end)-tw(1)) > 0
    v = trapz(tw, yw) / (tw(end) - tw(1));
elseif ~isempty(yw)
    v = yw(1);
end
end

% ======================================================================
function p = ratePerWindow(node, accVarName, tStart, tEnd)
% Average power, in W, from an accumulated energy variable over the window.
p = 0;
if ~any(string(node.childIds)==accVarName), return; end
[t, y] = seriesInUnit(node, accVarName, 'J');
w = t>=tStart & t<=tEnd;
tw = t(w); yw = y(w);
if numel(tw) >= 2 && (tw(end)-tw(1))>0
    p = (yw(end)-yw(1))/(tw(end)-tw(1));
end
end

% ======================================================================
function [times, values] = seriesInUnit(node, varName, unitName)
% Time and values of one logged variable, converted to unitName.
thisSeries = node.(varName).series;
times = thisSeries.time();
try
    values = thisSeries.values(unitName);
catch conversionError
    % Warn and use the logged values if the unit does not convert.
    warning('powerLossFromSimscapeLog:unitConversionFailed', ...
        ['Cannot read %s (logged in %s) as %s, using the logged numbers as they ' ...
         'stand: %s'], varName, string(thisSeries.unit), unitName, conversionError.message);
    values = thisSeries.values();
end
end

% ======================================================================
function groups = applyGroupLabelMap(groups, labelMap)
% Rename groups using the label map.
if isConfigured(labelMap)
    k = keys(labelMap);
    for i=1:numel(k)
        groups(groups==k(i)) = labelMap(k(i));
    end
end
end

% ======================================================================
function tSpan = localTimeSpan(simlog)
% Return [tMin tMax] of the log, or [0 1] if not found.
tSpan = [0 1];
try
    s = findSpan(simlog);
    if numel(s) == 2 && s(2) > s(1)
        tSpan = s;
    end
catch
end
end

function span = findSpan(node)
% Return the time span of the first leaf series found.
span = [];
ids = string(node.childIds);
for k=1:numel(ids)
    c = node.(ids(k));
    if isa(c,'simscape.logging.Node')
        if isempty(c.childIds)
            try s=c.series; tt=s.time(); span=[tt(1) tt(end)]; return; catch, end
        else
            span = findSpan(c);
            if ~isempty(span), return; end
        end
    end
end
end

% ======================================================================
function plotDeviceBar(lossData, sep, modelName, interactions)
% Bar chart of loss components per device, grouped into side bands.
T = lossData.deviceTable;
if isempty(T)
    return
end

% Sort devices by side, then by name.
[sideLabels, sideOrder] = deviceSideBands(T.Group);
[~, rowOrder] = sortrows(table(sideOrder, string(T.Name), ...
    'VariableNames', {'Side','Name'}), {'Side','Name'});
T = T(rowOrder,:);
sideLabels = sideLabels(rowOrder);

if sep
    M = [T.Conduction T.TurnOn T.TurnOff T.Recovery];
    leg = {'Conduction','Turn-on','Turn-off','Reverse recovery'};
else
    M = [T.Conduction T.Switching];
    leg = {'Conduction','Switching'};
end

figure('Name','Semiconductor Power Loss');
ax = axes;
hold(ax,'on');
deviceCount = height(T);
% Set limits first so the bands draw behind the bars.
xlim(ax, [0.5 deviceCount+0.5]);
% A bar draws its positive segments up from zero and its negative segments down, so
% the limits come from each sum separately; a negative loss stays visible, not clipped
stackTop    = max([sum(max(M,0),2,'omitnan'); eps]);
stackBottom = min([sum(min(M,0),2,'omitnan'); 0]);
ylim(ax, [stackBottom stackTop] * 1.22);
drawSideBands(ax, sideLabels);

barHandles = bar(ax, 1:deviceCount, M, 'stacked');

ylabel(ax,'Power (W)');
grid(ax,'on'); box(ax,'on');
% Tick labels: device name, with a path suffix where the band does not tell
% same-named bars apart.
deviceNames = string(T.Name);
tickLabels  = cellstr(deviceNames);
pathQualified = uniquifyGroupLabels(deviceNames, string(T.Group));
for barIndex = 1:deviceCount
    sharesName = deviceNames == deviceNames(barIndex);
    if nnz(sharesName) < 2
        continue
    end
    spansBands = numel(unique(sideLabels(sharesName))) > 1;
    if spansBands && strlength(sideLabels(barIndex)) > 0
        continue
    end
    tickLabels{barIndex} = char(pathQualified(barIndex));
end
set(ax, 'XTick', 1:deviceCount, 'XTickLabel', tickLabels, ...
    'TickLabelInterpreter','none');
legend(barHandles, leg, 'Location','eastoutside');
ttl = 'Semiconductor Power Loss by Device';
if ~isempty(modelName), ttl = [ttl ' - ' modelName]; end
title(ax, ttl, 'Interpreter','none');
set(gcf,'Position',[400 525 755 429]);
hold(ax,'off');
setAxesInteractions(ax, interactions);
end

% ======================================================================
function [labels, order] = deviceSideBands(groups)
% Band label and draw order for each device, from its log path.
groups = string(groups);
labels = strings(numel(groups), 1);
order  = zeros(numel(groups), 1);
for rowIndex = 1:numel(groups)
    logPath = lower(replace(groups(rowIndex), "_", " "));
    % Rectifier and boost are read below the fidelity variant only.
    rolePath  = pathBelowFidelityVariant(groups(rowIndex));
    boostLeg  = regexp(rolePath, 'boost[a-z]*?(\d+)', 'tokens', 'once');
    if contains(logPath, "primary")
        labels(rowIndex) = "Primary";     order(rowIndex) = 1;
    elseif contains(logPath, "secondary")
        labels(rowIndex) = "Secondary";   order(rowIndex) = 2;
    elseif contains(logPath, "fastleg") || contains(logPath, "fast leg")
        labels(rowIndex) = "Fast Leg";    order(rowIndex) = 1;
    elseif contains(logPath, "slowleg") || contains(logPath, "slow leg")
        labels(rowIndex) = "Slow Leg";    order(rowIndex) = 2;
    elseif contains(rolePath, "rectifier")
        labels(rowIndex) = "Rectifier";   order(rowIndex) = 10;
    elseif ~isempty(boostLeg)
        % Numbered boost stage.
        labels(rowIndex) = "Boost Leg " + string(boostLeg{1});
        order(rowIndex)  = 20 + str2double(boostLeg{1});
    elseif contains(rolePath, "boost")
        labels(rowIndex) = "Boost";       order(rowIndex) = 20;
    else
        labels(rowIndex) = "";            order(rowIndex) = 30;
    end
end

% Band a rectifier as "Secondary" when a primary side exists and no boost stage does.
isRectifierBand = labels == "Rectifier";
if any(isRectifierBand) && any(labels == "Primary") && ~any(startsWith(labels, "Boost"))
    labels(isRectifierBand) = "Secondary";
    order(isRectifierBand)  = 2;
end
end

% ======================================================================
function drawSideBands(ax, sideLabels)
% Draw a shaded, named background band per side, if there are at least two sides.
sideLabels = string(sideLabels);
namedSides = unique(sideLabels(strlength(sideLabels) > 0));
if numel(namedSides) < 2
    return
end

% Alternating light fill colors.
bandFillColors = [0.898 0.933 0.969
                  0.929 0.929 0.937];

% Each run of one label is one band.
runStart = [1; find(sideLabels(2:end) ~= sideLabels(1:end-1)) + 1];
runStop  = [runStart(2:end) - 1; numel(sideLabels)];

yRange = ylim(ax);
for bandIndex = 1:numel(runStart)
    xLeft  = runStart(bandIndex) - 0.5;
    xRight = runStop(bandIndex)  + 0.5;
    fillColor = bandFillColors(mod(bandIndex-1, size(bandFillColors,1)) + 1, :);
    patch(ax, [xLeft xRight xRight xLeft], yRange([1 1 2 2]), fillColor, ...
        'EdgeColor','none', 'HandleVisibility','off');
    bandName = sideLabels(runStart(bandIndex));
    if strlength(bandName) > 0
        % Band name near the top of the band.
        text(ax, (xLeft+xRight)/2, yRange(2) - 0.025*diff(yRange), bandName, ...
            'HorizontalAlignment','center', 'VerticalAlignment','top', ...
            'FontWeight','bold', 'FontSize', 11, 'Color', [0.3 0.3 0.3]);
    end
end
% Draw the grid above the bands.
set(ax, 'Layer', 'top');
end

% ======================================================================
function plotGroupPie(lossData, interactions)
% Pie chart of loss share per group, with efficiency in the title. The axes-based pie
% is used rather than piechart, whose interactions cannot be turned off.
groupShares = lossData.percentageByGroup;
figure('Name','Loss Distribution by Group', 'Position',[400 525 610 347]);
ax = axes;
pieObjects = pie(ax, groupShares.Percentage, compose("%.1f%%", groupShares.Percentage));
set(pieObjects(1:2:end), 'EdgeColor','w', 'LineWidth',1.5);    % slice outlines
set(pieObjects(2:2:end), 'FontSize',11, 'FontWeight','bold');  % slice labels
% Slice colors from the blue-to-green part of parula, leaving out its yellow end
pieColormap = parula(256);
colormap(ax, pieColormap(1:170, :));
% The share labels sit just outside the circle, so the limits leave room for them. The
% pie keeps the left of the figure and the legend is placed to its right, because an
% equal-aspect axes lets an 'eastoutside' legend cover a label.
axis(ax, 1.35 * [-1 1 -1 1]);
ax.Position = [0.02 0.06 0.58 0.84];
legendHandle = legend(ax, string(groupShares.Group), 'FontSize',10);
legendHandle.Position(1:2) = [0.62, 0.5 - legendHandle.Position(4)/2];
title(ax, sprintf('Loss Distribution, Efficiency = %.2f%%', lossData.efficiency), 'FontSize',11);
setAxesInteractions(ax, interactions);
end

% ======================================================================
function setAxesInteractions(ax, interactions)
% Turn off the default axes interactions and toolbar unless they are asked for. A live
% figure keeps them active, and without graphics hardware they slow the Live Editor.
if ~interactions
    disableDefaultInteractivity(ax);
    ax.Toolbar.Visible = 'off';
end
end
