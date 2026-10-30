function [minFreq, maxFreq] = getCLLCOperatingFrequencyRange(frequencyRange)
%   This function reduces a CLLC converter frequency range to the single lowest and
%   highest operating frequency the converter has to support.
%
%   A CLLC converter transfers power in both directions, so the gain curve functions
%   report a separate operating region for each direction, with one entry per swept
%   operating point. One controller and one set of devices serve both directions, so the
%   frequency span they must cover is the span that contains every reported region: the
%   lowest minimum frequency of the two directions and the highest maximum frequency.
%
%   Inputs:
%     frequencyRange  Struct with fields:
%                       .minFreqFwd / .maxFreqFwd - Forward operating region (Hz).
%                       .minFreqRev / .maxFreqRev - Reverse operating region (Hz).
%                     Each field is a vector with one entry per swept operating point.
%
%   Outputs:
%     minFreq  Lowest operating frequency over both directions (Hz).
%     maxFreq  Highest operating frequency over both directions (Hz).
%
%   A NaN entry means the gain curve never reaches the gain that bound requires, so that
%   operating point cannot be served. The reduction skips NaN entries and warns, naming
%   how many it skipped, because a span taken over the points that remain is narrower
%   than the design needs and the number on its own does not show that. When every entry
%   of a bound is NaN there is no span to report and the function errors, so a NaN cannot
%   reach a controller parameter or a device rating.
%
%   Example:
%     [~, ~, frequencyRange] = plotGainCurveCLLCConverter(CLLCSpec);
%     [minFreq, maxFreq] = getCLLCOperatingFrequencyRange(frequencyRange)

% Copyright 2026 The MathWorks, Inc.

arguments
    frequencyRange (1,1) struct
end

% A range taken from an earlier release of the workflow carries the single-direction
% fields, which name no power-flow direction. Say so, rather than letting the field
% reference fail with a name the caller never wrote.
requiredFields = ["minFreqFwd" "maxFreqFwd" "minFreqRev" "maxFreqRev"];
missingFields = requiredFields(~isfield(frequencyRange, requiredFields));
if ~isempty(missingFields)
    if all(isfield(frequencyRange, ["minFreq" "maxFreq"]))
        error("getCLLCOperatingFrequencyRange:singleDirectionRange", ...
            "frequencyRange holds the single-direction fields minFreq and maxFreq. " + ...
            "Run CLLCConverterDefaultInputParameters to refresh it, or take it from " + ...
            "plotGainCurveCLLCConverter, which reports both power-flow directions.");
    end
    error("getCLLCOperatingFrequencyRange:missingFields", ...
        "frequencyRange is missing the field %s.", strjoin(missingFields, ", "));
end

% Both directions are pooled before reducing, so neither bound can come from a direction
% the other cannot follow.
minEntries = [frequencyRange.minFreqFwd(:); frequencyRange.minFreqRev(:)];
maxEntries = [frequencyRange.maxFreqFwd(:); frequencyRange.maxFreqRev(:)];

minFreq = reduceBound(minEntries, @min, "minimum");
maxFreq = reduceBound(maxEntries, @max, "maximum");

end

function boundValue = reduceBound(entries, reduceFunction, boundName)
% Reduces one bound over both directions, skipping the operating points the gain curve
% cannot serve and reporting how many were skipped.

usableEntries = entries(~isnan(entries));

if isempty(usableEntries)
    error("getCLLCOperatingFrequencyRange:noFeasibleOperatingPoint", ...
        "Every %s operating frequency is NaN, so the resonant tank meets the required " + ...
        "gain at none of the swept operating points. Narrow the required gain range, or " + ...
        "change the quality factor and the inductance ratio.", boundName);
end

% A skipped operating point narrows the span, and the number that comes back does not show
% that on its own, so say how many were skipped.
skippedCount = numel(entries) - numel(usableEntries);
if skippedCount > 0
    warning("getCLLCOperatingFrequencyRange:infeasibleOperatingPoint", ...
        "%d of %d %s operating frequencies are NaN, so the gain curve does not reach the " + ...
        "gain those operating points require. The reported span covers the remaining " + ...
        "points and is narrower than the design needs.", skippedCount, numel(entries), boundName);
end

boundValue = reduceFunction(usableEntries);

end
