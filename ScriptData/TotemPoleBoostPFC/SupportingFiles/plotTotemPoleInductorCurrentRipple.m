function rippleData = plotTotemPoleInductorCurrentRipple(totemPoleDesign, options)
%PLOTTOTEMPOLEINDUCTORCURRENTRIPPLE Verify the boost inductor ripple and peak current.
%
%   rippleData = plotTotemPoleInductorCurrentRipple(totemPoleDesign, Name=Value) draws the
%   two facts that drive the inductor sizing, over a line half cycle. The upper tile is the
%   ripple at every AC input voltage against the limit. It peaks part way up the line
%   cycle, not at the AC peak. The lower tile is the current envelope at one input. Its
%   upper branch sets the core saturation rating, and its lower branch reaching zero is the
%   CCM boundary.
%
%   Inputs:
%     totemPoleDesign  Design structure from designTotemPoleBoostPFCConverter.
%
%   Name-value options:
%     InputVoltageIndex  AC input whose envelope is drawn in the lower tile. Default 0,
%                  which chooses the highest-current input, the lowest line voltage.
%
%   Outputs:
%     rippleData  Structure of the plotted vectors and the marked points.
%
%   Example:
%     [designTable, totemPoleDesign] = designTotemPoleBoostPFCConverter(totemPoleSpec);
%     plotTotemPoleInductorCurrentRipple(totemPoleDesign);
%
%   See also designTotemPoleBoostPFCConverter, plotTotemPoleCCMBoundary.

% Copyright 2026 The MathWorks, Inc.

arguments
    totemPoleDesign struct
    % Zero means "choose automatically" (the highest-current AC input).
    options.InputVoltageIndex (1,1) double {mustBeNonnegative, mustBeInteger} = 0
end

% Naming the expected unit makes a wrong unit error instead of silently scaling.
boostInductance    = value(totemPoleDesign.boostInductance, "H");
switchingFrequency = value(totemPoleDesign.switchingFrequency, "Hz");
outputVoltage      = value(totemPoleDesign.outputVoltage, "V");
requestedRippleFraction = totemPoleDesign.requestedRippleFraction;
corners = totemPoleDesign.operatingPoints;
cornerCount = numel(corners);

if options.InputVoltageIndex == 0
    [~, envelopeInputVoltageIndex] = max([corners.lineCurrentPeak]);
else
    envelopeInputVoltageIndex = min(options.InputVoltageIndex, cornerCount);
end

% A line half cycle is enough: the negative half is the mirror image, with the two
% fast-leg devices' roles swapped.
linePhase = linspace(0, pi, 4001);
linePhaseDegrees = linePhase * 180 / pi;
rippleData.linePhase = linePhase;

cornerColors = lines(cornerCount);

% Both legends sit outside the axes on the same side, so the plot boxes stay the same
% width and no legend can cover a marked point.
figure('Name', 'TotemPoleInductorCurrentRipple', 'Position', [100 100 1000 720]);
tiledlayout(2, 1, 'TileSpacing', 'compact');

% ---- Upper tile: ripple over the line cycle, every AC input -----------------
nexttile;
hold on;

% dIL = |v_ac|*(1 - |v_ac|/Vout)/(L*fsw), which is QUADRATIC in the AC voltage: it peaks at
% |v_ac| = Vout/2, and that maximum Vout/(4*L*fsw) carries no AC voltage term at all, so
% every AC input voltage reaches the same level.
for cornerIndex = 1:cornerCount
    acPeakVoltage = corners(cornerIndex).acPeakVoltage;
    acVoltageInstantaneous = acPeakVoltage * sin(linePhase);
    mainSwitchDuty = max(1 - acVoltageInstantaneous / outputVoltage, 0);
    inductorCurrentRipple = acVoltageInstantaneous .* mainSwitchDuty / ...
        (boostInductance * switchingFrequency);

    plot(linePhaseDegrees, inductorCurrentRipple, '-', 'LineWidth', 1.8, ...
        'Color', cornerColors(cornerIndex, :), ...
        'DisplayName', sprintf('%s (%.0f V rms)', ...
            corners(cornerIndex).name, corners(cornerIndex).acVoltageRms));

    rippleData.operatingPoints(cornerIndex).name = corners(cornerIndex).name;
    rippleData.operatingPoints(cornerIndex).ripple = inductorCurrentRipple;
    rippleData.operatingPoints(cornerIndex).rippleMax = corners(cornerIndex).inductorCurrentRipple;
    rippleData.operatingPoints(cornerIndex).rippleAtACPeak = ...
        corners(cornerIndex).inductorCurrentRippleAtACPeak;
end

% The line reaches |v_ac| = Vout/2 twice per half cycle; mark the rising crossing.
for cornerIndex = 1:cornerCount
    acPeakVoltage = corners(cornerIndex).acPeakVoltage;
    if acPeakVoltage >= outputVoltage / 2
        maxPhaseDegrees = asin((outputVoltage / 2) / acPeakVoltage) * 180 / pi;
    else
        maxPhaseDegrees = 90;      % ripple still rising at the AC peak
    end
    plot(maxPhaseDegrees, corners(cornerIndex).inductorCurrentRipple, 'o', ...
        'MarkerSize', 9, 'LineWidth', 1.8, 'Color', cornerColors(cornerIndex, :), ...
        'HandleVisibility', 'off');
end

% The common worst-case level, and the at-AC-peak values it is compared against.
yline(corners(1).inductorCurrentRipple, 'k--', 'LineWidth', 1.4, ...
    'DisplayName', sprintf('Worst case V_{out}/(4 L f_{sw}) = %.2f A', ...
        corners(1).inductorCurrentRipple));
for cornerIndex = 1:cornerCount
    plot(90, corners(cornerIndex).inductorCurrentRippleAtACPeak, 'x', ...
        'MarkerSize', 10, 'LineWidth', 1.8, 'Color', cornerColors(cornerIndex, :), ...
        'HandleVisibility', 'off');
end

xlim([0 180]);
xticks(0:30:180);
xlabel('Line phase \theta (deg)', 'FontSize', 12);
ylabel('Ripple \DeltaI_L (A)', 'FontSize', 12);
title('Boost inductor current ripple over the line cycle', 'FontSize', 13);
subtitle('o = worst case at |v_{ac}| = V_{out}/2      x = at the AC peak', 'FontSize', 10);
legend('Location', 'eastoutside', 'FontSize', 9);
grid on;

% ---- Lower tile: current envelope at the chosen AC input -------------------
nexttile;
hold on;

envelopeInputVoltage = corners(envelopeInputVoltageIndex);
acPeakVoltage   = envelopeInputVoltage.acPeakVoltage;
lineCurrentPeak = envelopeInputVoltage.lineCurrentPeak;

acVoltageInstantaneous = acPeakVoltage * sin(linePhase);
mainSwitchDuty = max(1 - acVoltageInstantaneous / outputVoltage, 0);
inductorCurrentRipple = acVoltageInstantaneous .* mainSwitchDuty / ...
    (boostInductance * switchingFrequency);
inductorCurrentAverage = lineCurrentPeak * sin(linePhase);
upperEnvelope = inductorCurrentAverage + inductorCurrentRipple / 2;
lowerEnvelope = inductorCurrentAverage - inductorCurrentRipple / 2;

% Shade the ripple band so the envelope is readable at a glance.
fill([linePhaseDegrees, fliplr(linePhaseDegrees)], ...
    [upperEnvelope, fliplr(lowerEnvelope)], [0.85 0.90 1.00], ...
    'EdgeColor', 'none', 'DisplayName', 'Ripple band');
plot(linePhaseDegrees, inductorCurrentAverage, 'b-', 'LineWidth', 2, ...
    'DisplayName', 'Average current i_L');
plot(linePhaseDegrees, upperEnvelope, 'r-', 'LineWidth', 1.4, ...
    'DisplayName', 'Envelope i_L \pm \DeltaI_L/2');
plot(linePhaseDegrees, lowerEnvelope, 'r-', 'LineWidth', 1.4, ...
    'HandleVisibility', 'off');

% The true peak, where the envelope maximizes - the core saturation rating.
plot(envelopeInputVoltage.peakInductorCurrentPhase * 180 / pi, ...
    envelopeInputVoltage.peakInductorCurrent, 'rv', 'MarkerSize', 10, ...
    'MarkerFaceColor', 'r', ...
    'DisplayName', sprintf('Peak = %.2f A at %.1f deg', ...
        envelopeInputVoltage.peakInductorCurrent, ...
        envelopeInputVoltage.peakInductorCurrentPhase * 180 / pi));

% Where the lower envelope touches zero, conduction becomes discontinuous.
yline(0, 'k-', 'LineWidth', 1, 'HandleVisibility', 'off');

xlim([0 180]);
xticks(0:30:180);
xlabel('Line phase \theta (deg)', 'FontSize', 12);
ylabel('Inductor current (A)', 'FontSize', 12);
title(sprintf('Inductor current envelope at %s (%.0f V rms)', ...
    envelopeInputVoltage.name, envelopeInputVoltage.acVoltageRms), 'FontSize', 13);
subtitle(sprintf('Realized ripple fraction %.3f of I_{pk}   (requested %.3f)', ...
    envelopeInputVoltage.realizedRippleFraction, requestedRippleFraction), 'FontSize', 10);
legend('Location', 'eastoutside', 'FontSize', 9);
grid on;

rippleData.envelopeInputVoltageIndex = envelopeInputVoltageIndex;
rippleData.upperEnvelope = upperEnvelope;
rippleData.lowerEnvelope = lowerEnvelope;
rippleData.peakInductorCurrent = envelopeInputVoltage.peakInductorCurrent;
end
