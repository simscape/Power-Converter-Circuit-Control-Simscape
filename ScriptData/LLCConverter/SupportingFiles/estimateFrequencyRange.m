function freqRange = estimateFrequencyRange(gainData, FreqData, gainRange, wr)
%   This function estimates the minimum and maximum operating frequencies of an
%   LLC converter that achieve a required gain range. The algorithm finds the
%   gain peak, then searches to the right (above peak frequency) for:
%     - Minimum frequency: where the gain curve crosses maxGain
%     - Maximum frequency: where the gain curve crosses minGain
%
%   This approach works whether the operating region is below, above, or
%   spanning the resonant frequency.
%
%   Inputs:
%     gainData   Vector of gain values (linear) vs. frequency.
%     FreqData   Vector of frequency values (rad/s), corresponding to gainData.
%     gainRange  1x2 vector [minGain, maxGain] specifying the required gain range.
%     wr         Resonant frequency (rad/s), unused but kept for interface compatibility.
%
%   Output:
%     freqRange  Struct with fields:
%                  - fminHz: Minimum frequency (Hz) achieving maxGain.
%                  - fmaxHz: Maximum frequency (Hz) achieving minGain.
%
%   Example:
%     gainData = [ ... ];     % vector of measured or simulated gains
%     FreqData = [ ... ];     % corresponding frequency vector (rad/s)
%     gainRange = [0.8, 1.2]; % desired gain limits
%     wr = 2*pi*100e3;        % resonant frequency (rad/s)
%     freqRange = estimateFrequencyRange(gainData, FreqData, gainRange, wr)

% Copyright 2025-2026 The MathWorks, Inc.

minGain = gainRange(1);
maxGain = gainRange(2);

% Find peak gain and its index
[peakGain, peakIdx] = max(gainData);

% Default to NaN (infeasible)
freqRange.fminHz = NaN;
freqRange.fmaxHz = NaN;

if peakGain < minGain
    return;
end

% Search right of peak (gain is monotonically decreasing)
rightData = gainData(peakIdx:end);

% fmin: where descending gain crosses maxGain (closest to peak)
if peakGain >= maxGain
    idx = find(rightData <= maxGain, 1);
    if ~isempty(idx)
        freqRange.fminHz = FreqData(peakIdx + idx - 1) / (2*pi);
    end
end

% fmax: where descending gain crosses minGain (further from peak)
idx = find(rightData <= minGain, 1);
if ~isempty(idx)
    freqRange.fmaxHz = FreqData(peakIdx + idx - 1) / (2*pi);
end

end
