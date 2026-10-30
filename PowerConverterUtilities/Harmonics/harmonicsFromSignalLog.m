function harmonicData = harmonicsFromSignalLog(logsout, signalSpecs, options)
%HARMONICSFROMSIGNALLOG Harmonic spectrum and THD of logged AC signals.
%   harmonicData = HARMONICSFROMSIGNALLOG(logsout, signalSpecs, Name=Value)
%
%   Inputs:
%     logsout      Signal-logging Dataset or bus.
%     signalSpecs  Struct array with fields .signal, .label and .quantity
%                  ('current' or 'voltage'), or a string array or cellstr of names.
%
%   Name-value options:
%     FundamentalHz       Line frequency (Hz). Required.
%     SwitchingHz         Switching frequency (Hz). Needed for the ripple spectrum.
%     MaxHarmonic         Highest harmonic plotted and tabulated. Default 10.
%     THDMaxHarmonic      Highest harmonic summed for THD. Default 10.
%     RippleSpectrum      Plot the ripple spectrum. Default true.
%     RippleSpanMultiple  Ripple span as a multiple of SwitchingHz. Default 10.
%     ShowHarmonicTable   Print the harmonic table. Default false.
%     ShowStandardTable   Print the THD-by-standard table. Default true.
%     TimeWindow          [tStart tEnd] to analyze (s). Overrides WindowFraction.
%     WindowFraction      [f0 f1] fraction of the run to analyze. Default [0.6 1.0].
%     MinCycles           Warn below this many whole cycles. Default 3.
%     CyclesToAnalyze     Exact number of whole cycles to analyze.
%     ShowPlots           Plot the spectra. Default true.
%     FigureName          Figure name. Default 'Converter Harmonics'.
%     Interactions        Keep the default axes interactions and toolbar. Default false.
%
%   Outputs:
%     harmonicData  Struct with fields:
%       .signals(k)        Per-signal results:
%          .label .quantity .fundamentalHz
%          .harmonicOrder      Harmonic orders, 1 to MaxHarmonic.
%          .magnitude          Peak magnitude per order (A or V).
%          .percentOfFund      Magnitude as a percentage of the fundamental.
%          .fundamental        Fundamental magnitude (A or V).
%          .THD                THD (%) summed to .THDMaxOrder.
%          .THDMaxOrder        Highest harmonic summed for .THD.
%          .harmonicTable      Table of magnitude per harmonic.
%          .standardTable      Table of THD per standard.
%          .rippleFrequencyHz  Ripple spectrum frequencies (Hz).
%          .rippleMagnitude    Ripple spectrum magnitudes (A or V).
%          .rippleSpanHz       Highest ripple frequency (Hz).
%          .harmonicCapture    Fraction of energy on harmonic bins, or NaN.
%          .sampleTime         Resampling time step (s).
%          .analysisWindow     [tStart tEnd] analyzed (s).
%          .cyclesAnalyzed     Whole cycles analyzed.
%       .sampleTime        Time step of the first signal (s).
%       .reliableHarmonic  Highest harmonic below Nyquist.
%       .fundamentalHz     Line frequency (Hz).
%       .switchingHz       Switching frequency (Hz), or [].
%       .analysisWindow    [tStart tEnd] of the first signal (s).
%       .cyclesAnalyzed    Whole cycles of the first signal.
%       .skippedReason     Always "".

% Copyright 2026 The MathWorks, Inc.

arguments
    logsout
    signalSpecs
    options.FundamentalHz (1,1) double
    options.SwitchingHz double = []
    options.MaxHarmonic (1,1) double {mustBeInteger,mustBePositive} = 10
    options.THDMaxHarmonic (1,1) double {mustBeInteger,mustBePositive} = 10
    options.RippleSpectrum (1,1) logical = true
    options.RippleSpanMultiple (1,1) double {mustBePositive} = 10
    options.ShowHarmonicTable (1,1) logical = false
    options.ShowStandardTable (1,1) logical = true
    options.CyclesToAnalyze double = []
    options.TimeWindow double = []
    options.WindowFraction (1,2) double = [0.6 1.0]
    options.MinCycles (1,1) double = 3
    options.ShowPlots (1,1) logical = true
    options.FigureName (1,:) char = 'Converter Harmonics'
    options.Interactions (1,1) logical = false
end
if ~isfield(options,'FundamentalHz') || isempty(options.FundamentalHz) || options.FundamentalHz <= 0
    error('harmonicsFromSignalLog:noFundamental', ...
        'Specify FundamentalHz (the line frequency), e.g. FundamentalHz=50.');
end
f1 = options.FundamentalHz;

specs = normalizeSpecs(signalSpecs);
sigMap = buildSignalMap(logsout);

% Analyze each signal. Field order matches the order r is built in below.
results = struct('label',{},'quantity',{},'fundamentalHz',{}, ...
    'harmonicOrder',{},'magnitude',{},'percentOfFund',{},'fundamental',{}, ...
    'THD',{},'THDMaxOrder',{},'harmonicTable',{},'standardTable',{}, ...
    'rippleFrequencyHz',{},'rippleMagnitude',{},'rippleSpanHz',{}, ...
    'harmonicCapture',{},'sampleTime',{},'analysisWindow',{},'cyclesAnalyzed',{});
reliableHarmonic = NaN;
dtUsed = NaN;
windowUsed = [NaN NaN];
cyclesUsed = NaN;
windowReported = false;
rippleSpanReported = false;

for i = 1:numel(specs)
    sp = specs(i);
    ts = resolveSignal(sigMap, sp.signal);
    if isempty(ts)
        warning('harmonicsFromSignalLog:signalNotFound', ...
            'Signal "%s" not found in logsout - skipped.', sp.signal);
        continue;
    end

    % Compute every harmonic up to Nyquist.
    spectrum = harmonicsOf(ts.Time, ts.Data, f1, options.TimeWindow, ...
        options.WindowFraction, options.CyclesToAnalyze, options.MinCycles);
    fullOrder = spectrum.harmonicOrder;
    fullMag   = spectrum.harmonicMagnitude;
    fund      = spectrum.fundamental;
    dt        = spectrum.dt;
    hReliable = spectrum.reliableHarmonic;
    win       = spectrum.window;
    nCyc      = spectrum.cycles;
    % Print and store the window of the first signal.
    if ~windowReported
        dtUsed = dt; reliableHarmonic = hReliable; windowUsed = win; cyclesUsed = nCyc;
        fprintf(['Harmonic analysis window: %.4g to %.4g s (%.4g s, %d whole ' ...
            'cycles of %g Hz), sample dt = %.3g s.\n'], win(1), win(2), ...
            win(2)-win(1), nCyc, f1, dt);
        if nCyc < options.MinCycles
            warning('harmonicsFromSignalLog:fewCycles', ...
                ['Only %d whole fundamental cycle(s) in the analysis window ' ...
                 '(recommend >= %d). Increase SimTime or widen the window for a ' ...
                 'cleaner spectrum.'], nCyc, options.MinCycles);
        end
        windowReported = true;
    end

    % Keep harmonics 1 to MaxHarmonic for the plot and table.
    keep = fullOrder <= options.MaxHarmonic;
    order = fullOrder(keep); mag = fullMag(keep);
    thd = thdToOrder(fullOrder, fullMag, fund, options.THDMaxHarmonic);

    pct = 100 * mag / fund;
    r.label = sp.label; r.quantity = sp.quantity; r.fundamentalHz = f1;
    r.harmonicOrder = order; r.magnitude = mag; r.percentOfFund = pct;
    r.fundamental = fund; r.THD = thd;
    % Highest harmonic summed for THD.
    r.THDMaxOrder = min(options.THDMaxHarmonic, hReliable);

    % Harmonic table.
    unit = quantityUnit(sp.quantity);
    orderName = cell(numel(order),1);
    for h = 1:numel(order)
        if order(h) == 1, orderName{h} = 'Fundamental (1st)';
        else, orderName{h} = sprintf('%s harmonic', ordinal(order(h))); end
    end
    r.harmonicTable = table(char(orderName), mag(:), pct(:), ...
        'VariableNames', {'Harmonic','Magnitude','PercentOfFundamental'});
    r.harmonicTable.Properties.VariableUnits = {'', unit, '%'};

    % THD-by-standard table from the full spectrum.
    r.standardTable = buildStandardTable(fullOrder, fullMag, fund, options.MaxHarmonic);

    % Ripple spectrum from DC to RippleSpanMultiple x SwitchingHz, clipped to Nyquist.
    r.rippleFrequencyHz = [];
    r.rippleMagnitude   = [];
    r.rippleSpanHz      = NaN;
    if ~isempty(options.SwitchingHz) && options.SwitchingHz > 0
        requestedSpanHz = options.RippleSpanMultiple * options.SwitchingHz;
        nyquistHz       = 0.5 / dt;
        actualSpanHz    = min(requestedSpanHz, nyquistHz);
        withinSpan      = spectrum.binFrequencyHz <= actualSpanHz;
        r.rippleFrequencyHz = spectrum.binFrequencyHz(withinSpan);
        r.rippleMagnitude   = spectrum.binMagnitude(withinSpan);
        r.rippleSpanHz      = actualSpanHz;
        if requestedSpanHz > nyquistHz && ~rippleSpanReported
            warning('harmonicsFromSignalLog:rippleSpanClipped', ...
                ['Ripple spectrum requested to %g x f_sw = %.4g Hz, but this log ' ...
                 'resolves only to %.4g Hz (Nyquist at dt = %.3g s). Plotted to ' ...
                 '%.4g Hz = %.2f x f_sw. Log at a finer sample time for the full ' ...
                 'span.'], options.RippleSpanMultiple, requestedSpanHz, nyquistHz, ...
                 dt, actualSpanHz, actualSpanHz/options.SwitchingHz);
            rippleSpanReported = true;
        end
    end

    % Per-signal analysis settings.
    r.harmonicCapture = spectrum.harmonicCapture;
    r.sampleTime      = dt;
    r.analysisWindow  = win;
    r.cyclesAnalyzed  = nCyc;

    results(end+1) = r; %#ok<AGROW>
end

harmonicData.signals          = results;
harmonicData.sampleTime       = dtUsed;
harmonicData.reliableHarmonic = reliableHarmonic;
harmonicData.fundamentalHz    = f1;
harmonicData.switchingHz      = options.SwitchingHz;
harmonicData.analysisWindow   = windowUsed;
harmonicData.cyclesAnalyzed   = cyclesUsed;
harmonicData.skippedReason    = "";

% Plot the spectra, then print the results.
if options.ShowPlots && ~isempty(results)
    plotSpectra(results, options);
end

for i = 1:numel(results)
    r = results(i);
    thdLabel = thdSymbol(r.quantity);
    fprintf('\n%s - %s = %.2f %% (to %d%s harmonic), fundamental = %.4g %s @ %g Hz\n', ...
        r.label, thdLabel, r.THD, r.THDMaxOrder, superscriptOrdinal(r.THDMaxOrder), ...
        r.fundamental, quantityUnit(r.quantity), f1);
    if options.ShowHarmonicTable
        disp(table(r.harmonicTable, 'VariableNames', string(r.label) + " Harmonics"));
    end
    if options.ShowStandardTable
        disp(table(r.standardTable, 'VariableNames', string(r.label) + " THD by Standard"));
    end
end
end

% ======================================================================
function spectrum = harmonicsOf(t, y, f1, timeWindow, windowFraction, cyclesReq, minCycles) %#ok<INUSD>
% FFT of a whole-cycle window, returning the magnitude of every harmonic and bin.
t = t(:); y = y(:);
% Remove repeated time stamps, keeping the last sample at each.
[t, keepIdx] = unique(t, 'last');
y = y(keepIdx);
if numel(t) < 2
    error('harmonicsFromSignalLog:badTime','Fewer than two distinct time stamps.');
end
% Resample onto a uniform grid at the median time step.
dt = median(diff(t));
if ~isfinite(dt) || dt <= 0
    error('harmonicsFromSignalLog:badTime','Non-monotonic or degenerate time vector.');
end
tUniform = (t(1):dt:t(end)).';
yUniform = interp1(t, y, tUniform, 'linear');
tEndAll = tUniform(end);
samplesPerCycle = (1/f1) / dt;

% Requested analysis window [wStart wEnd].
if ~isempty(timeWindow)
    wStart = max(tUniform(1), timeWindow(1));
    wEnd   = min(tEndAll,     timeWindow(2));
else
    wStart = tUniform(1) + windowFraction(1) * (tEndAll - tUniform(1));
    wEnd   = tUniform(1) + windowFraction(2) * (tEndAll - tUniform(1));
end
if wEnd <= wStart
    wStart = tUniform(1); wEnd = tEndAll;
end

% Whole cycles in the window and in the run, to within one sample.
cycleTolerance   = dt * f1;
availCyclesInWin = floor((wEnd - wStart) / (1/f1) + cycleTolerance);
totalCycles      = floor((tEndAll - tUniform(1)) / (1/f1) + cycleTolerance);
if totalCycles < 1
    error('harmonicsFromSignalLog:tooShort', ...
        'Simulation shorter than one fundamental cycle (need >= 1/%.4g s).', f1);
end

% Number of whole cycles to analyze.
if ~isempty(cyclesReq)
    nCycles = round(cyclesReq);
elseif availCyclesInWin >= 1
    nCycles = availCyclesInWin;
else
    nCycles = 0;
end
% If the window holds no whole cycle, use the last whole cycles of the run.
windowReplaced = false;
if nCycles < 1
    nCycles = min(totalCycles, max(1, floor(0.4 * totalCycles)));
    wEnd = tEndAll;
    windowReplaced = true;
end
nCycles = min(nCycles, totalCycles);

% Whole-cycle window ending at wEnd.
nWin  = round(nCycles * samplesPerCycle);
endIdx = min(numel(yUniform), round((wEnd - tUniform(1))/dt) + 1);
% Drop a cycle if the window needs more samples than the grid holds.
while nCycles > 1 && nWin > endIdx
    nCycles = nCycles - 1;
    nWin = round(nCycles * samplesPerCycle);
end
startIdx = endIdx - nWin + 1;
if startIdx < 1, startIdx = 1; endIdx = min(numel(yUniform), nWin); end
yWin = yUniform(startIdx:endIdx);
win  = [tUniform(startIdx), tUniform(endIdx)];
if windowReplaced
    warning('harmonicsFromSignalLog:windowReplaced', ...
        ['The requested analysis window holds no whole %.4g Hz cycle, so the last %d ' ...
        'whole cycles of the run (%.4g to %.4g s) were analyzed instead.'], ...
        f1, nCycles, win(1), win(2));
end

% Single-sided FFT peak magnitude per bin.
N = numel(yWin);
Y = fft(yWin);
mag2 = abs(Y) / N;
half = floor(N/2) + 1;
magSingle = mag2(1:half);
% Double every bin except DC and, for even N, the Nyquist bin.
if mod(N,2) == 0
    magSingle(2:end-1) = 2 * magSingle(2:end-1);
else
    magSingle(2:end)   = 2 * magSingle(2:end);
end

% Highest harmonic below Nyquist.
fs = 1/dt;
hReliable = max(1, floor((fs/2) / f1));

% Harmonic h sits at bin h*nCycles + 1.
maxH = hReliable;
order = (1:maxH).';
mag = zeros(maxH,1);
for h = 1:maxH
    bin = h * nCycles + 1;
    if bin <= numel(magSingle)
        mag(h) = magSingle(bin);
    else
        mag(h) = NaN;
    end
end

% Fraction of the energy up to harmonic 40, excluding DC, that sits on harmonic bins.
captureMaxOrder = min(40, hReliable);
captureLastBin  = min(numel(magSingle), captureMaxOrder * nCycles + 1);
captureBins     = (1:captureMaxOrder).' * nCycles + 1;
captureBins     = captureBins(captureBins <= numel(magSingle));
bandEnergy      = sum(magSingle(2:captureLastBin).^2);
if nCycles >= 2 && bandEnergy > 0
    harmonicCapture = sum(magSingle(captureBins).^2) / bandEnergy;
else
    harmonicCapture = NaN;
end
% Warn when FundamentalHz does not match the signal.
if ~isnan(harmonicCapture) && harmonicCapture < 0.9
    warning('harmonicsFromSignalLog:fundamentalMismatch', ...
        ['Only %.0f %% of the energy up to harmonic %d lands on multiples of the ' ...
        'declared %.4g Hz, so FundamentalHz does not describe this signal. Check it ' ...
        'against the source, and note the harmonic magnitudes and THD below are ' ...
        'referred to %.4g Hz whatever the signal contains.'], ...
        100*harmonicCapture, captureMaxOrder, f1, f1);
end

spectrum.harmonicOrder     = order;
spectrum.harmonicMagnitude = mag;
spectrum.harmonicCapture   = harmonicCapture;
spectrum.fundamental       = mag(1);
spectrum.binFrequencyHz    = (0:numel(magSingle)-1).' * (fs / N);
spectrum.binMagnitude      = magSingle(:);
spectrum.dt                = dt;
spectrum.reliableHarmonic  = hReliable;
spectrum.window            = win;
spectrum.cycles            = nCycles;
end

% ======================================================================
function thd = thdToOrder(order, mag, fund, kMax)
% THD (%) over harmonics 2 to kMax.
sel = order >= 2 & order <= kMax & isfinite(mag);
if fund <= 0 || ~any(sel)
    thd = NaN; return;
end
thd = 100 * sqrt(sum(mag(sel).^2)) / fund;
end

% ======================================================================
function tbl = buildStandardTable(order, mag, fund, plottedMax)
% Table of THD to the 40th, the 50th and the plotted harmonic.
hReliable = max(order);
defs = { ...
    'IEEE 519 (to 40th)',                   40 ; ...
    'IEC 61000 (to 50th)',                  50 ; ...
    sprintf('Plotted (to %s)', ordinal(plottedMax)), plottedMax };
nStd = size(defs,1);
Standard = cell(nStd,1); Considered = zeros(nStd,1); Reliable = zeros(nStd,1); THD = zeros(nStd,1);
for i = 1:nStd
    Standard{i}   = defs{i,1};
    Considered(i) = defs{i,2};
    Reliable(i)   = min(hReliable, defs{i,2});
    kUse = min(defs{i,2}, hReliable);
    THD(i) = thdToOrder(order, mag, fund, kUse);
end
tbl = table(char(Standard), Considered, Reliable, THD, ...
    'VariableNames', {'Standard','HarmonicsConsidered','HarmonicsReliable','THD_percent'});
tbl.Properties.VariableUnits = {'', '', '', '%'};
end

% ======================================================================
function plotSpectra(results, options)
% Plot the ripple spectrum and the harmonic stem of each signal.
n = numel(results);
drawRipple = options.RippleSpectrum && ...
    any(arrayfun(@(r) ~isempty(r.rippleFrequencyHz), results));
rowsPerSignal = 1 + double(drawRipple);
figure('Name', options.FigureName, ...
    'Position', [380 120 700 230*rowsPerSignal*n]);
for i = 1:n
    if drawRipple
        plotRippleSpectrum(subplot(rowsPerSignal*n, 1, rowsPerSignal*(i-1)+1), ...
            results(i), options);
        harmonicAxes = subplot(rowsPerSignal*n, 1, rowsPerSignal*(i-1)+2);
    else
        harmonicAxes = subplot(n, 1, i);
    end
    plotHarmonicStem(harmonicAxes, results(i), options);
end
% A live figure keeps its default interactions active, and without graphics hardware
% they slow the Live Editor, so they are off unless asked for
if ~options.Interactions
    for axesHandle = findobj(gcf, 'Type', 'axes').'
        disableDefaultInteractivity(axesHandle);
        axesHandle.Toolbar.Visible = 'off';
    end
end
end

function plotRippleSpectrum(ax, r, options)
% Plot the ripple spectrum in dB against log frequency, from the first non-zero bin.
frequencyHz = r.rippleFrequencyHz;
firstBin    = find(frequencyHz > 0, 1);

% Magnitude in dB relative to 1 A or 1 V.
rippleAmplitude = r.rippleMagnitude;
magnitudeDb = 20*log10(max(rippleAmplitude, realmin));
semilogx(ax, frequencyHz(firstBin:end), magnitudeDb(firstBin:end), 'LineWidth', 1);
set(ax, 'XScale', 'log');
hold(ax,'on');
grid(ax,'on'); box(ax,'on');
xlim(ax, [frequencyHz(firstBin), max(frequencyHz)]);
% Show 80 dB below the peak.
peakDb = max(magnitudeDb(firstBin:end));
if isfinite(peakDb)
    ylim(ax, [peakDb - 80, peakDb + 6]);
end
% Mark 1, 2, 5, 10, ... times the switching frequency.
combCount = floor(max(frequencyHz) / options.SwitchingHz);
markedMultiples = [1 2 5 10 20 50 100];
markedMultiples = markedMultiples(markedMultiples <= combCount);
for k = markedMultiples
    if k == 1, combLabel = 'f_{sw}'; else, combLabel = sprintf('%df_{sw}', k); end
    xline(ax, k*options.SwitchingHz, '--', combLabel, 'Interpreter','tex', ...
        'LabelVerticalAlignment','bottom', 'LabelHorizontalAlignment','left', ...
        'Alpha', 0.35, 'FontSize', 8);
end
xlabel(ax, 'Frequency (Hz), log scale');
ylabel(ax, 'Ripple amplitude (dB)');
title(ax, sprintf('%s ripple spectrum (dB, log frequency)  -  %s to %s = %g x f_{sw}', ...
    r.label, formatFrequency(frequencyHz(firstBin)), formatFrequency(r.rippleSpanHz), ...
    r.rippleSpanHz/options.SwitchingHz), 'Interpreter','tex', 'FontSize', 10);
end

function text = formatFrequency(frequencyHz)
% Format a frequency in Hz, kHz or MHz.
if frequencyHz >= 1e6
    text = sprintf('%.3g MHz', frequencyHz/1e6);
elseif frequencyHz >= 1e3
    text = sprintf('%.3g kHz', frequencyHz/1e3);
else
    text = sprintf('%.3g Hz', frequencyHz);
end
end

function plotHarmonicStem(ax, r, options)
% Stem plot of harmonic magnitudes with THD in the title.
hold(ax,'on');
ord = r.harmonicOrder; mag = r.magnitude;
valid = isfinite(mag);
stem(ax, ord(valid), mag(valid), 'filled', 'LineWidth', 1.5, 'BaseValue', 0);
grid(ax,'on'); box(ax,'on');
xlim(ax,[0.5, max(ord)+0.5]); xticks(ax, ord);
xlabel(ax, 'Harmonic order (1 = fundamental)');
ylabel(ax, sprintf('Magnitude (%s)', quantityUnit(r.quantity)));
ttl = sprintf('%s line harmonics  -  %s = %.2f%%', r.label, thdSymbol(r.quantity), r.THD);
if ~isempty(options.SwitchingHz)
    ttl = sprintf('%s   (f_1=%g Hz, f_{sw}=%.4g Hz)', ttl, r.fundamentalHz, options.SwitchingHz);
end
title(ax, ttl, 'Interpreter','tex', 'FontSize', 10);
% Label the fundamental.
text(ax, 1, mag(1), sprintf('  %.4g %s', mag(1), quantityUnit(r.quantity)), ...
    'VerticalAlignment','bottom','FontSize',9);
end

% ======================================================================
% Signal helpers
% ======================================================================
function specs = normalizeSpecs(raw)
% Convert signalSpecs to a struct array with .signal, .label and .quantity.
if isstruct(raw)
    specs = raw;
    for i = 1:numel(specs)
        if ~isfield(specs,'label') || isempty(specs(i).label), specs(i).label = char(specs(i).signal); end
        if ~isfield(specs,'quantity') || isempty(specs(i).quantity)
            specs(i).quantity = guessQuantity(specs(i).signal);
        end
    end
    return;
end
names = string(raw);
specs = struct('signal',{},'label',{},'quantity',{});
for i = 1:numel(names)
    specs(i).signal = char(names(i));
    specs(i).label = char(names(i));
    specs(i).quantity = guessQuantity(names(i));
end
end

function q = guessQuantity(name)
% Return 'voltage' for a name starting with V, otherwise 'current'.
name = char(name);
if ~isempty(name) && (upper(name(1)) == 'V'), q = 'voltage'; else, q = 'current'; end
end

function ts = resolveSignal(sigMap, name)
% Return the timeseries for a name, or [] if absent.
ts = [];
name = char(name);
if isKey(sigMap, name), ts = sigMap(name); return; end
% Try a case-insensitive match.
ks = keys(sigMap);
hit = find(strcmpi(ks, name), 1);
if ~isempty(hit), ts = sigMap(ks{hit}); end
end

function sigMap = buildSignalMap(logsout)
% Map each logged signal name, with and without its unit suffix, to its timeseries.
sigMap = containers.Map('KeyType','char','ValueType','any');
try
    nEl = logsout.numElements;
    for i = 1:nEl
        el = logsout{i};
        addValue(sigMap, el.Name, el.Values);
    end
catch
    % Not a Dataset: treat it as a bus.
    addValue(sigMap, 'root', logsout);
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
% Add a timeseries under its name and its name without the unit suffix.
if ~isKey(sigMap, name), sigMap(name) = ts; end
base = regexprep(name, '(__|\s*\[).*$', '');
if ~isempty(base) && ~strcmp(base,name) && ~isKey(sigMap, base)
    sigMap(base) = ts;
end
end

% ======================================================================
% Formatting helpers
% ======================================================================
function u = quantityUnit(quantity)
% Return the unit of a quantity.
if strcmpi(quantity,'voltage'), u = 'V'; else, u = 'A'; end
end

function s = thdSymbol(quantity)
% Return the THD label of a quantity.
if strcmpi(quantity,'voltage'), s = 'THD-V'; else, s = 'THD-I'; end
end

function s = ordinal(n)
% Return an ordinal such as 1st, 2nd or 3rd.
n = round(n);
if mod(n,100) >= 11 && mod(n,100) <= 13
    suf = 'th';
else
    switch mod(n,10)
        case 1, suf = 'st';
        case 2, suf = 'nd';
        case 3, suf = 'rd';
        otherwise, suf = 'th';
    end
end
s = sprintf('%d%s', n, suf);
end

function s = superscriptOrdinal(n)
% Return the ordinal suffix only, such as th or st.
s = regexprep(ordinal(n), '^\d+', '');
end
