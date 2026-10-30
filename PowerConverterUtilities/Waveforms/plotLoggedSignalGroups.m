function waveformData = plotLoggedSignalGroups(logsout, panelSpec, options)
%PLOTLOGGEDSIGNALGROUPS Plot converter analysis waveforms from a logged dataset.
%   waveformData = PLOTLOGGEDSIGNALGROUPS(logsout, panelSpec, Name=Value)
%
%   Inputs:
%     logsout    Signal-logging dataset.
%     panelSpec  Struct array, one element per axes, with fields:
%                  .title    Axes title.
%                  .signals  Signal names to plot.
%                  .legend   Legend labels. Optional, default .signals.
%                  .ylabel   Y-axis label. Optional.
%
%   Name-value options:
%     FocusCycles     Number of cycles to display. Default 5.
%     FrequencyHz     Frequency of one displayed cycle (Hz).
%     FocusFraction   Fraction of the run to display when FrequencyHz is empty. Default 0.05.
%     FigureName      Figure name. Default 'Converter Waveforms'.
%     FigurePosition  Figure position. Default [400 300 800 700].
%     LineWidth       Line width. Default 2.
%
%   Outputs:
%     waveformData  Struct with the .Data and .Time of each signal.

% Copyright 2026 The MathWorks, Inc.

arguments
    logsout
    panelSpec (1,:) struct
    options.FocusCycles (1,1) double = 5
    options.FrequencyHz double = []
    options.FocusFraction (1,1) double = 0.05
    options.FigureName (1,:) char = 'Converter Waveforms'
    options.FigurePosition (1,4) double = [400 300 800 700]
    options.LineWidth (1,1) double = 2
end

% Get each signal from logsout.
waveformData = struct();
allSignals = unique([panelSpec.signals]);
tEnd = 0;
for s = allSignals
    el = getSignal(logsout, char(s));
    if isempty(el)
        warning('plotLoggedSignalGroups:missingSignal', ...
            'Signal "%s" not found in the logged dataset; skipping.', s);
        continue;
    end
    waveformData.(matlab.lang.makeValidName(char(s))).Data = el.Values.Data;
    waveformData.(matlab.lang.makeValidName(char(s))).Time = el.Values.Time;
    tEnd = max(tEnd, el.Values.Time(end));
end

% Display window [t0 tEnd].
if ~isempty(options.FrequencyHz) && options.FrequencyHz > 0
    span = options.FocusCycles / options.FrequencyHz;
else
    span = options.FocusFraction * tEnd;
end
t0 = max(0, tEnd - span);

% Plot one axes per panelSpec element.
fig = figure('Name', options.FigureName);
set(fig, 'Position', options.FigurePosition);
nPanel = numel(panelSpec);
for p = 1:nPanel
    ax = subplot(nPanel, 1, p);
    hold(ax, 'on');
    spec = panelSpec(p);
    leg = spec.signals;
    if isfield(spec,'legend') && ~isempty(spec.legend)
        leg = spec.legend;
    end
    plottedAny = false;
    for k = 1:numel(spec.signals)
        fld = matlab.lang.makeValidName(char(spec.signals(k)));
        if ~isfield(waveformData, fld), continue; end
        t = waveformData.(fld).Time; y = waveformData.(fld).Data;
        idx = t >= t0;
        plot(ax, t(idx), y(idx), 'LineWidth', options.LineWidth);
        plottedAny = true;
    end
    grid(ax,'on'); box(ax,'on');
    xlabel(ax,'time (s)');
    if isfield(spec,'ylabel') && ~isempty(spec.ylabel), ylabel(ax, spec.ylabel); end
    if plottedAny
        xlim(ax, [t0 tEnd]);
        legend(ax, cellstr(leg), 'Location','best');
    end
    title(ax, spec.title, 'FontSize', 12);
end
end

% ======================================================================
function el = getSignal(logsout, name)
% Return the dataset element with this name, or [].
el = [];
try
    el = logsout.get(name);
catch
    el = [];
end
end
