function freqRange = estimateCLLCFrequencyRange(gainData, FreqData, gainRange, wr)
%   This function estimates the minimum and maximum operating frequencies of a
%   CLLC converter that achieve a required gain range. The algorithm identifies the
%   descending branch on which the converter operates, then searches along
%   it for:
%     - Minimum frequency: where the gain curve crosses maxGain
%     - Maximum frequency: where the gain curve crosses minGain
%
%   Choosing the operating branch:
%     A CLLC tank has two resonances, the primary C1-L1-Lm loop and the secondary
%     L2-C2 arm, so its gain curve is not always a single hump. When the product of
%     the quality factor and the inductance ratio is large, the curve splits into a
%     lobe near the lower resonance fr2 and a second lobe near the main resonance
%     f1, separated by a valley, and the lower lobe can be the taller of the two.
%     Anchoring on the global maximum would then land on the lower lobe and report a
%     maximum frequency inside the valley, which the converter can never use: the
%     gain rises again on the far side of the valley, so frequency control loses its
%     monotonic sign there.
%
%     The converter therefore operates on the highest-frequency descending branch,
%     that is, the branch above the LAST gain peak in the swept range. This branch
%     surrounds the main resonance, it is the inductive and soft-switching side of
%     the tank, and the gain falls monotonically along it. For a single-hump curve
%     the last peak is also the global peak, so the usual case is unaffected.
%
%   The function is direction agnostic: call it once with the forward gain sweep and
%   once with the reverse gain sweep.
%
%   Inputs:
%     gainData   Vector of gain values (linear) over frequency.
%     FreqData   Vector of frequency values (rad/s), corresponding to gainData.
%     gainRange  1x2 vector [minGain, maxGain] specifying the required gain range.
%     wr         Resonant frequency (rad/s), unused but kept for interface compatibility.
%
%   Output:
%     freqRange  Struct with fields:
%                  - fminHz: Minimum frequency (Hz) achieving maxGain.
%                  - fmaxHz: Maximum frequency (Hz) achieving minGain.
%                NaN in either field means the operating branch never reaches that
%                gain, so the requested gain range is not achievable at the given
%                quality factor, Lm/L1 ratio and load. A NaN minimum frequency means
%                the branch peaks below maxGain, and a NaN maximum frequency means
%                the branch never falls to minGain within the swept range.
%
%   Example:
%     gainData = [ ... ];     % vector of measured or simulated gains
%     FreqData = [ ... ];     % corresponding frequency vector (rad/s)
%     gainRange = [0.8, 1.2]; % desired gain limits
%     wr = 2*pi*100e3;        % resonant frequency (rad/s)
%     freqRange = estimateCLLCFrequencyRange(gainData, FreqData, gainRange, wr)

% Copyright 2025-2026 The MathWorks, Inc.

minGain = gainRange(1);
maxGain = gainRange(2);

% Default to NaN (infeasible)
freqRange.fminHz = NaN;
freqRange.fmaxHz = NaN;

% Locate the top of the operating branch, that is, the last gain peak. Every local
% maximum counts, however shallow, because the test that matters is monotonicity: even
% a slight rise in gain with frequency reverses the sign of the frequency control loop,
% so the usable branch cannot extend past it. The gain curve comes from the frequency
% response of a linear model, so it is smooth and carries no numerical ripple that
% would need filtering out.
lobeIdx = find(islocalmax(gainData));

if isempty(lobeIdx)
    if gainData(1) >= gainData(end)
        % No interior peak and the curve descends across the whole sweep, so the
        % sweep starts part way down the operating branch.
        peakIdx = 1;
    else
        % The curve rises across the whole sweep, so no descending branch was
        % captured and no operating point can be reported.
        return;
    end
else
    peakIdx = lobeIdx(end);
end

peakGain = gainData(peakIdx);

if peakGain < minGain
    return;
end

% Search right of the peak, where the gain decreases monotonically
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
