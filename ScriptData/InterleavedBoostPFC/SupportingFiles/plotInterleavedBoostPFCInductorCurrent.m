function rippleData = plotInterleavedBoostPFCInductorCurrent(interleavedDesign, options)
%PLOTINTERLEAVEDBOOSTPFCINDUCTORCURRENT Verify the sized per-leg inductor over the line cycle.
%
%   rippleData = plotInterleavedBoostPFCInductorCurrent(interleavedDesign, Name=Value) draws
%   one tile per requirement, over a line half cycle. The first is the per-leg ripple at every
%   AC input voltage against the input ripple that survives interleaving. The second is the
%   per-leg current envelope each core must not saturate at. Conduction mode is a load-range
%   result rather than a line-phase one, so it has its own figure.
%
%   Inputs:
%     interleavedDesign  Design structure from designInterleavedBoostPFCConverter.
%
%   Name-value options:
%     InputVoltageIndex  Index into interleavedDesign.operatingPoints, selecting the AC input voltage whose
%                  envelope is drawn in the second tile. Default 0, which chooses the
%                  highest-current one at the lowest line voltage.
%
%   Outputs:
%     rippleData  Structure of the plotted vectors and the marked points.
%
%   See also designInterleavedBoostPFCConverter, plotInterleavedBoostPFCCCMBoundary.

% Copyright 2026 The MathWorks, Inc.

arguments
    interleavedDesign struct
    % Zero means "choose automatically" (the highest-current AC input).
    options.InputVoltageIndex (1,1) double {mustBeNonnegative, mustBeInteger} = 0
end

% Naming the expected unit makes a wrong unit error instead of silently scaling.
boostInductance = value(interleavedDesign.boostInductance, "H");
switchingFrequency = value(interleavedDesign.switchingFrequency, "Hz");
outputVoltage = value(interleavedDesign.outputVoltage, "V");
numberOfLegs = interleavedDesign.numberOfLegs;
% Both tiles are drawn at rated load, so the title states the load rather than the name of
% the operating point it came from.
ratedPower = value(interleavedDesign.ratedPower, "W");
corners = interleavedDesign.operatingPoints;
cornerCount = numel(corners);

if options.InputVoltageIndex == 0
    [~, envelopeInputVoltageIndex] = max([corners.lineCurrentPeak]);
else
    envelopeInputVoltageIndex = min(options.InputVoltageIndex, cornerCount);
end

% A line half cycle is enough: the negative half is the mirror image through the bridge.
linePhase = linspace(0, pi, 4001);
linePhaseDegrees = linePhase * 180/pi;
rippleData.linePhase = linePhase;

cornerColors = lines(cornerCount);
figure('Name', 'InterleavedBoostPFCInductorCurrent', 'Position', [100 100 980 640]);
tiledlayout(2, 1, 'TileSpacing', 'compact');

% ---- Tile 1: per-leg ripple against the surviving input ripple ---------------
% N triangles shifted by Tsw/N cancel wherever N*duty is a whole number - including near
% |vac| = Vout/2, where the per-leg ripple is WORST. Interleaving is best exactly there.
nexttile;
hold on;
for cornerIndex = 1:cornerCount
    acVoltageInstantaneous = corners(cornerIndex).acPeakVoltage * sin(linePhase);
    instantaneousDuty = max(1 - acVoltageInstantaneous/outputVoltage, 0);
    legRipple = acVoltageInstantaneous .* instantaneousDuty / (boostInductance*switchingFrequency);
    dutyFraction = mod(numberOfLegs*instantaneousDuty, 1);
    inputRipple = outputVoltage * dutyFraction .* (1 - dutyFraction) / ...
        (numberOfLegs*boostInductance*switchingFrequency);

    plot(linePhaseDegrees, legRipple, '-', 'LineWidth', 1.8, 'Color', cornerColors(cornerIndex,:), ...
        'DisplayName', sprintf('V_{in,ac} = %.0f V rms, per leg', ...
            corners(cornerIndex).acVoltageRms));
    if cornerIndex == 1
        dashedName = 'Input ripple after interleaving (dashed)';
        dashedVisibility = 'on';
    else
        dashedName = '';
        dashedVisibility = 'off';
    end
    plot(linePhaseDegrees, inputRipple, '--', 'LineWidth', 1.4, ...
        'Color', cornerColors(cornerIndex,:), 'DisplayName', dashedName, ...
        'HandleVisibility', dashedVisibility);

    rippleData.operatingPoints(cornerIndex).name = corners(cornerIndex).name;
    rippleData.operatingPoints(cornerIndex).legRipple = legRipple;
    rippleData.operatingPoints(cornerIndex).inputRipple = inputRipple;
    rippleData.operatingPoints(cornerIndex).legRippleMax = corners(cornerIndex).inductorCurrentRipple;
    rippleData.operatingPoints(cornerIndex).inputRippleMax = corners(cornerIndex).inputCurrentRipple;
end
rippleCeiling = outputVoltage/(4*boostInductance*switchingFrequency);
yline(rippleCeiling, '--k', sprintf('Vout/(4 L Fsw) = %.3f A per leg', rippleCeiling), ...
    'LineWidth', 1.2, 'HandleVisibility', 'off');
% Large text, so the labels stay readable when the figure is shown at half width.
set(gca, 'FontSize', 12);
xlabel('Line phase (deg)', 'FontSize', 14); ylabel('Ripple, peak-to-peak (A)', 'FontSize', 14);
title(sprintf('Leg and input current ripple at %.0f W', ratedPower), 'FontSize', 14);
legend('Location', 'eastoutside', 'FontSize', 11); grid on; xlim([0 180]);

% ---- Tile 2: per-leg current envelope at the highest-current AC input --------
% The envelope peak sits slightly past the line peak, because the ripple is still growing
% there - so the core peak is not the line peak over N.
nexttile;
envelopeInputVoltage = corners(envelopeInputVoltageIndex);
acVoltageInstantaneous = envelopeInputVoltage.acPeakVoltage * sin(linePhase);
envelopeRipple = acVoltageInstantaneous .* ...
    max(1 - acVoltageInstantaneous/outputVoltage, 0) / (boostInductance*switchingFrequency);
meanCurrent = envelopeInputVoltage.legCurrentPeak * sin(linePhase);
hold on;
% The band between the two edges IS the switching ripple, so it is filled and named once
% instead of drawn as two curves the reader has to pair up.
upperEnvelope = meanCurrent + envelopeRipple/2;
lowerEnvelope = max(meanCurrent - envelopeRipple/2, 0);
fill([linePhaseDegrees, fliplr(linePhaseDegrees)], [upperEnvelope, fliplr(lowerEnvelope)], ...
    [0.99 0.88 0.80], 'EdgeColor', 'none', 'DisplayName', 'Switching ripple envelope');
plot(linePhaseDegrees, upperEnvelope, '-', 'LineWidth', 1.4, ...
    'Color', [0.85 0.33 0.10], 'HandleVisibility', 'off');
plot(linePhaseDegrees, lowerEnvelope, '-', 'LineWidth', 1.4, ...
    'Color', [0.85 0.33 0.10], 'HandleVisibility', 'off');
plot(linePhaseDegrees, meanCurrent, '-', 'LineWidth', 1.8, 'Color', [0 0.45 0.74], ...
    'DisplayName', 'Inductor average current');
plot(envelopeInputVoltage.peakInductorCurrentPhase, envelopeInputVoltage.peakInductorCurrent, 'kd', ...
    'MarkerSize', 9, 'LineWidth', 1.6, 'MarkerFaceColor', 'y', 'DisplayName', ...
    sprintf('Peak %.2f A at %.0f deg', envelopeInputVoltage.peakInductorCurrent, ...
        envelopeInputVoltage.peakInductorCurrentPhase));
set(gca, 'FontSize', 12);
xlabel('Line phase (deg)', 'FontSize', 14); ylabel('Leg inductor current (A)', 'FontSize', 14);
title(sprintf('Leg inductor current at %.0f W, V_{in,ac} = %.0f V rms, %d legs', ...
    ratedPower, envelopeInputVoltage.acVoltageRms, numberOfLegs), 'FontSize', 14);
% Grid on top, or the filled band hides it.
legend('Location', 'eastoutside', 'FontSize', 11); grid on; xlim([0 180]); set(gca, 'Layer', 'top');
rippleData.envelopeInputVoltage = envelopeInputVoltage.name;
rippleData.envelopePeak = envelopeInputVoltage.peakInductorCurrent;
end
