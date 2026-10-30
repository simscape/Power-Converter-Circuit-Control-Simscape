function ivData = plotLoggedSignals(logsout, options)
%PLOTLOGGEDSIGNALS Plot a converter's voltage and current waveforms from logsout.
%   ivData = PLOTLOGGEDSIGNALS(logsout, Name=Value)
%
%   Inputs:
%     logsout  Signal-logging dataset.
%
%   Name-value options:
%     Panels         Cell array of string arrays, the signals of each axes in order.
%     SignalPairs    Cell array of signal pairs, each plotted on one axes. Default {}.
%     SignalSingles  Signals plotted on their own axes. Default every unpaired signal.
%     PanelTitles    Axes titles, in axes order.
%     Derived        Struct array of computed signals with fields name, inputs and fcn.
%     FrequencyHz    Frequency of one displayed cycle (Hz).
%     FocusCycles    Number of cycles to display. Default 5.
%     FocusFraction  Fraction of the run to display when FrequencyHz is empty. Default 0.05.
%     PerFigure      Axes per figure. Default 4.
%     FigureName     Figure name. Default 'Converter Waveforms'.
%     LineWidth      Line width. Default 2.
%     Interactions   Keep the default axes interactions and toolbar. Default false.
%
%   Outputs:
%     ivData  Struct with the .Data and .Time of each plotted signal.

% Copyright 2026 The MathWorks, Inc.

arguments
    logsout
    options.Panels cell = {}
    options.SignalPairs cell = {}
    options.SignalSingles (1,:) string = string.empty
    options.PanelTitles (1,:) string = string.empty
    options.Derived struct = struct('name',{},'inputs',{},'fcn',{})
    options.FrequencyHz double = []
    options.FocusCycles (1,1) double = 5
    options.FocusFraction (1,1) double = 0.05
    options.PerFigure (1,1) double = 4
    options.FigureName (1,:) char = 'Converter Waveforms'
    options.LineWidth (1,1) double = 2
    options.Interactions (1,1) logical = false
end

% Map signal names to timeseries and add the derived signals.
sigMap = buildSignalMap(logsout);
sigMap = addDerivedSignals(sigMap, options.Derived);

available = string(keys(sigMap));

% List the axes from Panels, or from SignalPairs then SignalSingles.
panels = struct('signals',{},'title',{});
if ~isempty(options.Panels)
    for k = 1:numel(options.Panels)
        p = string(options.Panels{k});
        p = p(ismember(p, available));
        if isempty(p), continue; end
        e.signals = p;
        e.title = strjoin(cellstr(p), ' & ');
        panels(end+1) = e; %#ok<AGROW>
    end
else
    % By default every unpaired signal is a single.
    paired = strings(0);
    for k = 1:numel(options.SignalPairs)
        paired = [paired, string(options.SignalPairs{k})]; %#ok<AGROW>
    end
    if isempty(options.SignalSingles)
        options.SignalSingles = setdiff(available, paired, 'stable');
    end
    for k = 1:numel(options.SignalPairs)
        p = string(options.SignalPairs{k});
        p = p(ismember(p, available));
        if isempty(p), continue; end
        e.signals = p;
        e.title = strjoin(cellstr(p), ' & ');
        panels(end+1) = e; %#ok<AGROW>
    end
    for s = options.SignalSingles(:)'
        if ~ismember(s, available), continue; end
        e.signals = s;
        e.title = char(s);
        panels(end+1) = e; %#ok<AGROW>
    end
end

% Apply the given axes titles.
for k = 1:min(numel(options.PanelTitles), numel(panels))
    if strlength(options.PanelTitles(k)) > 0
        panels(k).title = char(options.PanelTitles(k));
    end
end
if isempty(panels)
    warning('plotLoggedSignals:noSignals','No matching signals found in logsout.');
    ivData = struct(); return;
end

% Store the signal data and find the display window.
ivData = struct(); tEnd = 0;
for p = panels
    for s = p.signals
        fld = matlab.lang.makeValidName(char(s));
        if isfield(ivData, fld), continue; end
        ts = sigMap(char(s));
        ivData.(fld).Data = ts.Data;
        ivData.(fld).Time = ts.Time;
        tEnd = max(tEnd, ts.Time(end));
    end
end
if ~isempty(options.FrequencyHz) && options.FrequencyHz > 0
    span = options.FocusCycles / options.FrequencyHz;
else
    span = options.FocusFraction * tEnd;
end
t0 = max(0, tEnd - span);

% Plot PerFigure axes per figure.
nPanel = numel(panels);
nFig = ceil(nPanel / options.PerFigure);
for f = 1:nFig
    figure('Name', sprintf('%s (%d/%d)', options.FigureName, f, nFig));
    set(gcf,'Position',[400 200 700 560]);
    first = (f-1)*options.PerFigure + 1;
    last  = min(f*options.PerFigure, nPanel);
    nSub = last - first + 1;
    figureAxes = gobjects(nSub, 1);
    for j = 1:nSub
        pn = panels(first + j - 1);
        ax = subplot(nSub, 1, j); hold(ax,'on');
        figureAxes(j) = ax;
        % Quantity from the name prefix: I is current, P is power, otherwise voltage.
        isCurrent = all(startsWith(pn.signals, "I"));
        isPower   = all(startsWith(pn.signals, "P"));
        % Plot each signal and track its range in the display window.
        yLo = +Inf; yHi = -Inf;
        for s = pn.signals
            fld = matlab.lang.makeValidName(char(s));
            t = ivData.(fld).Time; y = ivData.(fld).Data; idx = t >= t0;
            plot(ax, 1e3 * t(idx), y(idx), 'LineWidth', options.LineWidth);
            if any(idx)
                yLo = min(yLo, min(y(idx))); yHi = max(yHi, max(y(idx)));
            end
        end
        grid(ax,'on'); box(ax,'on'); xlim(ax, 1e3 * [t0 tEnd]);
        % Y-limits: 5% margin for data that crosses zero, otherwise a 20% margin.
        if isfinite(yLo) && isfinite(yHi)
            if yLo < 0 && yHi > 0
                pad = 0.05 * max(yHi - yLo, eps);
                yBottom = yLo - pad;
                yTop    = yHi + pad;
            else
                span    = yHi - yLo;
                yBottom = yLo - max(0.2 * span, 0.2 * abs(yLo));
                yTop    = yHi + max(0.2 * span, 0.2 * abs(yHi));
                % Do not let the limits cross zero.
                if yLo >= 0, yBottom = max(yBottom, 0); end
                if yHi <= 0, yTop    = min(yTop, 0);    end
            end
            if yTop > yBottom, ylim(ax, [yBottom yTop]); end
        end
        % The axes share one time range, so only the bottom one carries the time labels
        if j == nSub
            xlabel(ax,'Time (ms)');
        else
            xticklabels(ax, {});
        end
        if isCurrent
            ylabel(ax,'Current (A)');
        elseif isPower
            ylabel(ax,'Power (W)');
        else
            ylabel(ax,'Voltage (V)');
        end
        if numel(pn.signals) > 1
            legend(ax, cellstr(pn.signals), 'Location','eastoutside');
        end
        title(ax, pn.title, 'Interpreter','none', 'FontSize',11);
        % A live figure keeps its default interactions active, and without graphics
        % hardware they slow the Live Editor, so they are off unless asked for
        if ~options.Interactions
            disableDefaultInteractivity(ax);
            ax.Toolbar.Visible = 'off';
        end
    end
    % A legend outside an axes narrows it, so every axes takes the narrowest width and
    % the time axes stay aligned
    drawnow;
    axesWidth = min(arrayfun(@(axesHandle) axesHandle.Position(3), figureAxes));
    for j = 1:nSub
        figureAxes(j).Position(3) = axesWidth;
    end
end
end

% ======================================================================
function sigMap = buildSignalMap(logsout)
% Map each logged signal and bus member name, and its aliases, to its timeseries.
sigMap = containers.Map('KeyType','char','ValueType','any');
for i = 1:logsout.numElements
    el = logsout{i};
    name = char(el.Name);
    if isempty(name)
        name = sourceBlockName(el);   % use the source block name
    end
    addValue(sigMap, name, el.Values);
end
end

function name = sourceBlockName(el)
% Return the name of the block that feeds a logged element, or ''.
name = '';
try
    fullPath = el.BlockPath.getBlock(el.BlockPath.getLength);
    parts = strsplit(fullPath, '/');
    name = parts{end};
catch
    try
        fullPath = el.BlockPath.getBlock(1);
        parts = strsplit(fullPath, '/');
        name = parts{end};
    catch
    end
end
end

function addValue(sigMap, name, vals)
% Add a timeseries, or each field of a bus, to the map.
if isa(vals, 'timeseries')
    registerAlias(sigMap, char(name), vals);
elseif isstruct(vals) || (isobject(vals) && ~isa(vals,'timeseries'))
    try
        fn = fieldnames(vals);
    catch
        return;
    end
    for k = 1:numel(fn)
        addValue(sigMap, fn{k}, vals.(fn{k}));
    end
end
end

function registerAlias(sigMap, name, ts)
% Add a timeseries under its name and under any alias not already in the map.
if ~isKey(sigMap, name), sigMap(name) = ts; end
for alias = aliasCandidates(name)
    a = alias{1};
    if ~isempty(a) && ~strcmp(a, name) && ~isKey(sigMap, a)
        sigMap(a) = ts;
    end
end
end

function aliases = aliasCandidates(name)
% Return the name without its unit suffix, and also without a trailing "Sens".
aliases = {};
base = regexprep(name, '(__|\s*\[).*$', '');
aliases{end+1} = base;
sensStripped = regexprep(base, 'Sens$', '');
aliases{end+1} = sensStripped;
end

% ======================================================================
function sigMap = addDerivedSignals(sigMap, derived)
% Add each derived signal, fcn applied to its inputs, to the map.
for i = 1:numel(derived)
    d = derived(i);
    inputs = string(d.inputs);
    if any(~arrayfun(@(s) isKey(sigMap, char(s)), inputs))
        continue;   % skip when an input is missing
    end
    series = arrayfun(@(s) sigMap(char(s)), inputs, 'UniformOutput', false);
    tRef = series{1}.Time;
    for k = 2:numel(series)
        if ~isequal(series{k}.Time, tRef)
            series{k} = resample(series{k}, tRef);   % resample onto the first input's time
        end
    end
    try
        data = d.fcn(series);
    catch err
        warning('plotLoggedSignals:derivedFailed', ...
            'Could not compute derived signal "%s": %s', d.name, err.message);
        continue;
    end
    sigMap(char(d.name)) = timeseries(data, tRef, 'Name', char(d.name));
end
end
