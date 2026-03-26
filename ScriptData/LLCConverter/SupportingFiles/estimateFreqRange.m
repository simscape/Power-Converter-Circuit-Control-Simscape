function freqRange = estimateFreqRange(gainData, FreqData, gainRange, wr)
%   This function estimates the minimum and maximum operating frequencies of an
%   LLC converter that achieve a required gain range. The function assumes that
%   maximum gain occurs at the minimum frequency and minimum gain occurs at the
%   maximum frequency (typical for LLC converters).
%
%   Inputs:
%     gainData   Vector of gain values (linear or dB) vs. frequency.
%     FreqData   Vector of frequency values (rad/s), corresponding to gainData.
%     gainRange  1x2 vector [minGain, maxGain] specifying the required gain range.
%     wr         Resonant frequency (rad/s) separating forward and boost modes.
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
%     freqRange = estimateFreqRange(gainData, FreqData, gainRange, wr)

% Copyright 2025-2026 The MathWorks, Inc.

wrIdx = find(FreqData>=wr,1);

% Forward Mode
if isempty(wrIdx) || max(gainData)<gainRange(1)
    freqRange.fminHz = NaN;
    freqRange.fmaxHz = NaN;
else
    if  max(gainData(wrIdx:-1:1))>gainRange(2)
        maxGainFminIdx = find(gainData(wrIdx:-1:1)>=gainRange(2),1);
        if max(gainData(wrIdx:-1:1))>=gainRange(2)
            maxGainFmin = wrIdx-maxGainFminIdx+1;
        else
            maxGainFmin = 1;
        end
        minFreqData = FreqData(maxGainFmin);
    else
        minFreqData = NaN;
    end
    if min(gainData(wrIdx:end))<gainRange(1)
        minGainFmaxIdx = find(gainData(wrIdx:end)<=gainRange(1),1);

        if ~isempty(minGainFmaxIdx)
            minGainFmax = wrIdx+minGainFmaxIdx-1;
        else
            if min(gainData(wrIdx:end)) > gainRange(1)
                minGainFmax = length(gainData(:));
            else
                minGainFmax = minGainFmaxIdx;
            end
        end
        maxFreqData = FreqData(minGainFmax);
    else
        maxFreqData = NaN;
    end
    freqRange.fmaxHz = maxFreqData/(2*pi);
    freqRange.fminHz = minFreqData/(2*pi);
end


