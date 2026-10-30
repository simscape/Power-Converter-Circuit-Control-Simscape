function rippleData = plotBoostPFCInductorCurrent(boostPFCDesign, options)
%PLOTBOOSTPFCINDUCTORCURRENT Verify the sized boost inductor over the line cycle.
%
%   rippleData = plotBoostPFCInductorCurrent(boostPFCDesign, Name=Value) draws one tile per
%   requirement, over a line half cycle. The first is the ripple magnitude at every AC input
%   voltage against the specified limit. The second is the current envelope the core must not
%   saturate at. Conduction mode is a load-range result rather than a line-phase one, so it
%   has its own figure.
%
%   Inputs:
%     boostPFCDesign  Design structure from designBoostPFCConverter.
%
%   Name-value options:
%     InputVoltageIndex  Index into boostPFCDesign.operatingPoints, selecting the AC input voltage whose
%                  envelope is drawn in the second tile. Default 0, which chooses the
%                  highest-current one at the lowest line voltage.
%
%   Outputs:
%     rippleData  Structure of the plotted vectors and the marked points.
%
%   See also designBoostPFCConverter, plotBoostPFCCCMBoundary.

% Copyright 2026 The MathWorks, Inc.

arguments
    boostPFCDesign struct
    % Zero means "choose automatically" (the highest-current AC input).
    options.InputVoltageIndex (1,1) double {mustBeNonnegative, mustBeInteger} = 0
end

% Naming the expected unit makes a wrong unit error instead of silently scaling.
boostInductance = value(boostPFCDesign.boostInductance, "H");
switchingFrequency = value(boostPFCDesign.switchingFrequency, "Hz");
outputVoltage = value(boostPFCDesign.outputVoltage, "V");
% Both tiles are drawn at rated load, so the title states the load rather than the name of
% the operating point it came from.
ratedPower = value(boostPFCDesign.ratedPower, "W");
corners = boostPFCDesign.operatingPoints;
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
figure('Name', 'BoostPFCInductorCurrent', 'Position', [100 100 980 640]);
tiledlayout(2, 1, 'TileSpacing', 'compact');

% ---- Tile 1: ripple over the line cycle, every AC input ---------------------
% Ripple peaks at |vac| = Vout/2, so its ceiling is the same at every AC input voltage.
% Only the current under it changes, so the fraction is worst at high line.
nexttile;
hold on;
for cornerIndex = 1:cornerCount
    acVoltageInstantaneous = corners(cornerIndex).acPeakVoltage * sin(linePhase);
    inductorCurrentRipple = acVoltageInstantaneous .* ...
        max(1 - acVoltageInstantaneous/outputVoltage, 0) / (boostInductance*switchingFrequency);
    plot(linePhaseDegrees, inductorCurrentRipple, '-', 'LineWidth', 1.8, ...
        'Color', cornerColors(cornerIndex,:), 'DisplayName', ...
        sprintf('V_{in,ac} = %.0f V rms', corners(cornerIndex).acVoltageRms));
    rippleData.operatingPoints(cornerIndex).name = corners(cornerIndex).name;
    rippleData.operatingPoints(cornerIndex).ripple = inductorCurrentRipple;
    rippleData.operatingPoints(cornerIndex).rippleMax = corners(cornerIndex).inductorCurrentRipple;
    rippleData.operatingPoints(cornerIndex).rippleAtACPeak = ...
        corners(cornerIndex).inductorCurrentRippleAtACPeak;
end
rippleCeiling = outputVoltage/(4*boostInductance*switchingFrequency);
yline(rippleCeiling, '--k', sprintf('Vout/(4 L Fsw) = %.3f A', rippleCeiling), ...
    'LineWidth', 1.2, 'HandleVisibility', 'off');
xlabel('Line phase (deg)'); ylabel('Ripple, peak-to-peak (A)');
title(sprintf('Inductor current ripple at %.0f W', ratedPower));
legend('Location', 'eastoutside'); grid on; xlim([0 180]);

% ---- Tile 2: current envelope at the highest-current AC input ---------------
% The envelope peak sits slightly past the line peak, because the ripple is still growing
% there - so the core peak is not the line peak.
nexttile;
envelopeInputVoltage = corners(envelopeInputVoltageIndex);
acVoltageInstantaneous = envelopeInputVoltage.acPeakVoltage * sin(linePhase);
envelopeRipple = acVoltageInstantaneous .* ...
    max(1 - acVoltageInstantaneous/outputVoltage, 0) / (boostInductance*switchingFrequency);
meanCurrent = envelopeInputVoltage.lineCurrentPeak * sin(linePhase);
hold on;
% The band between the two edges is the switching ripple, so it is filled and named once
% instead of drawn as two curves.
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
xlabel('Line phase (deg)'); ylabel('Inductor current (A)');
title(sprintf('Inductor current at %.0f W, V_{in,ac} = %.0f V rms', ratedPower, ...
    envelopeInputVoltage.acVoltageRms));
% Grid on top, or the filled band hides it.
legend('Location', 'eastoutside'); grid on; xlim([0 180]); set(gca, 'Layer', 'top');
rippleData.envelopeInputVoltage = envelopeInputVoltage.name;
rippleData.envelopePeak = envelopeInputVoltage.peakInductorCurrent;
end
