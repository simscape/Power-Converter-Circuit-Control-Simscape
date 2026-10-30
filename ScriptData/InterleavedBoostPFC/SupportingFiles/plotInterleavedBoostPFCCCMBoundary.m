function [ccmPowerBoundary, fullCycleDCMPowerBoundary, acVoltageVec] = ...
    plotInterleavedBoostPFCCCMBoundary(interleavedDesign, options)
%PLOTINTERLEAVEDBOOSTPFCCCMBOUNDARY Plot the CCM/DCM boundaries of an interleaved boost PFC.
%
%   [ccmPowerBoundary, fullCycleDCMPowerBoundary, acVoltageVec] = ...
%       plotInterleavedBoostPFCCCMBoundary(interleavedDesign, Name=Value) draws the two
%   continuous-conduction-mode boundaries against AC input voltage in volts rms, with output
%   power per unit of rated power. The upper one is the load below which conduction goes
%   discontinuous around the line zero crossings, and the lower one is the load below which
%   even the line peak is discontinuous. Both are total loads, so each carries the leg count.
%   Each AC input voltage is marked at rated power and again on the upper boundary, so the gap
%   between the pair is the part of its load range that stays continuous over the whole line
%   cycle.
%
%   Inputs:
%     interleavedDesign  Design structure from designInterleavedBoostPFCConverter.
%
%   Name-value options:
%     ACVoltageVec  AC input voltages to sweep (V rms). Default: the specified input range
%                   with 10% margin each side.
%
%   Outputs:
%     ccmPowerBoundary           Output power below which conduction goes discontinuous near
%                                the zero crossings, at each swept line voltage (W).
%     fullCycleDCMPowerBoundary  Output power below which conduction is discontinuous over the
%                                whole line cycle, at each swept line voltage (W).
%     acVoltageVec               The line voltages swept (V rms).
%
%   Example:
%     [designTable, interleavedDesign] = designInterleavedBoostPFCConverter(interleavedSpec);
%     plotInterleavedBoostPFCCCMBoundary(interleavedDesign);
%
%   See also designInterleavedBoostPFCConverter, plotInterleavedBoostPFCInductorCurrent.

% Copyright 2026 The MathWorks, Inc.

arguments
    interleavedDesign struct
    options.ACVoltageVec (1,:) double = []
end

% Naming the expected unit makes a wrong unit error instead of silently scaling.
boostInductance    = value(interleavedDesign.boostInductance, "H");
switchingFrequency = value(interleavedDesign.switchingFrequency, "Hz");
outputVoltage      = value(interleavedDesign.outputVoltage, "V");
ratedPower         = value(interleavedDesign.ratedPower, "W");
numberOfLegs = interleavedDesign.numberOfLegs;
corners = interleavedDesign.operatingPoints;
cornerCount = numel(corners);

% Margin on each side, so the operating points sit inside the plot, not on its edges.
if isempty(options.ACVoltageVec)
    acVoltageVec = linspace(0.9 * min([corners.acVoltageRms]), ...
        1.1 * max([corners.acVoltageRms]), 400);
else
    acVoltageVec = options.ACVoltageVec;
end

% Requiring iL > dIL/2 in a leg, with iL = (Ipk/N)*sin(theta) and dIL = Vpk*sin(theta)*
% (1 - m*sin(theta))/(L*fsw), cancels the sin(theta) exactly and leaves
% Ipk/N > Vpk*(1 - m*sin(theta))/(2*L*fsw). The surviving factor (1 - m*sin(theta)) is the
% duty, so it is LARGEST at the line ZERO CROSSING and smallest at the line PEAK. The two ends
% of the line cycle therefore give two different loads, which are the two boundaries drawn
% here:
%   theta = 0   the load DCM first appears at, around the zero crossings
%   theta = 90  the load below which even the line peak is discontinuous, 1-m times the first
% Both are TOTAL loads, N times the per-leg threshold, because the legs share the line
% current. Light-load DCM near the zero crossings is inherent to a PFC rather than a fault -
% staying continuous down to zero load needs infinite inductance.

modulationIndexVec = sqrt(2) * acVoltageVec / outputVoltage;
ccmPowerBoundary = numberOfLegs * acVoltageVec.^2 / (2 * switchingFrequency * boostInductance);
% Clamped at zero: past Vpk = Vout the converter cannot boost at all, so the lower boundary
% closing on zero there is the feasibility limit rather than a conduction result.
fullCycleDCMPowerBoundary = max(ccmPowerBoundary .* (1 - modulationIndexVec), 0);

% The load axis is per unit of rated power, so the boundary reads as a fraction of what the
% converter was sized for. The input axis stays in volts rms, the number the reader specified.
ccmPowerBoundaryPu = ccmPowerBoundary / ratedPower;
fullCycleDCMPowerBoundaryPu = fullCycleDCMPowerBoundary / ratedPower;

figure('Name', 'InterleavedBoostPFCCCMBoundary', 'Position', [100 100 832 496]);
hold on;

% A ceiling above rated power, so the rated-power line sits inside the shading.
powerCeilingPu = max(1.2, 1.1 * max(ccmPowerBoundaryPu));

% All three regions are filled, so the mode is read from the color rather than from a ratio.
fill([acVoltageVec, fliplr(acVoltageVec)], ...
    [ccmPowerBoundaryPu, powerCeilingPu * ones(size(acVoltageVec))], ...
    [0.80 0.95 0.80], 'EdgeColor', 'none', 'HandleVisibility', 'off');
fill([acVoltageVec, fliplr(acVoltageVec)], ...
    [fullCycleDCMPowerBoundaryPu, fliplr(ccmPowerBoundaryPu)], ...
    [0.99 0.90 0.80], 'EdgeColor', 'none', 'HandleVisibility', 'off');
fill([acVoltageVec, fliplr(acVoltageVec)], ...
    [zeros(size(acVoltageVec)), fliplr(fullCycleDCMPowerBoundaryPu)], ...
    [0.97 0.80 0.78], 'EdgeColor', 'none', 'HandleVisibility', 'off');

plot(acVoltageVec, ccmPowerBoundaryPu, 'r-', 'LineWidth', 2, ...
    'DisplayName', 'DCM starts at the zero crossings');
plot(acVoltageVec, fullCycleDCMPowerBoundaryPu, '-', 'LineWidth', 2, ...
    'Color', [0.55 0.10 0.10], 'DisplayName', 'DCM reaches the line peak');

yline(1, 'k--', 'LineWidth', 1.4, 'DisplayName', 'Rated power = 1 pu');

% The specified input range, which is the part of the sweep that matters.
xline(min([corners.acVoltageRms]), 'b:', 'LineWidth', 1.2, 'HandleVisibility', 'off');
xline(max([corners.acVoltageRms]), 'b:', 'LineWidth', 1.2, 'HandleVisibility', 'off');

% Each AC input voltage twice: at rated power where it operates, and on the boundary where
% it leaves continuous conduction. The vertical gap between the pair IS the continuous part
% of the load range at that input voltage.
for cornerIndex = 1:cornerCount
    cornerVoltage = corners(cornerIndex).acVoltageRms;
    cornerThresholdPu = corners(cornerIndex).ccmPowerThreshold / ratedPower;
    plot(cornerVoltage, 1, 's', 'MarkerSize', 10, 'LineWidth', 1.8, ...
        'MarkerFaceColor', 'w', 'Color', 'b', 'HandleVisibility', 'off');
    plot(cornerVoltage, cornerThresholdPu, 'o', 'MarkerSize', 8, 'LineWidth', 1.6, ...
        'MarkerFaceColor', 'w', 'Color', 'r', 'HandleVisibility', 'off');
    % The load the converter goes discontinuous at, and the input voltage it happens at.
    text(cornerVoltage, cornerThresholdPu - 0.03 * powerCeilingPu, ...
        sprintf('%.2f pu at %.0f V rms', cornerThresholdPu, cornerVoltage), ...
        'VerticalAlignment', 'top', 'HorizontalAlignment', 'center', ...
        'FontSize', 9, 'FontWeight', 'bold');
end
% One legend entry per marker kind rather than one per AC input voltage.
plot(NaN, NaN, 's', 'MarkerSize', 10, 'LineWidth', 1.8, 'MarkerFaceColor', 'w', ...
    'Color', 'b', 'DisplayName', 'Operating points at rated power');
plot(NaN, NaN, 'o', 'MarkerSize', 8, 'LineWidth', 1.6, 'MarkerFaceColor', 'w', ...
    'Color', 'r', 'DisplayName', 'CCM threshold at each input voltage');

% Name all three regions, so the plot reads without the legend.
labelVoltage = min(acVoltageVec) + 0.04 * (max(acVoltageVec) - min(acVoltageVec));
text(labelVoltage, (max(ccmPowerBoundaryPu) + powerCeilingPu)/2, ...
    'CCM over the whole line cycle', 'FontSize', 11, 'FontWeight', 'bold', ...
    'Color', [0.15 0.45 0.15], 'HorizontalAlignment', 'left');
text(labelVoltage, (min(ccmPowerBoundaryPu) + max(fullCycleDCMPowerBoundaryPu))/2, ...
    'DCM around the zero crossings only', 'FontSize', 11, 'FontWeight', 'bold', ...
    'Color', [0.55 0.30 0.10], 'HorizontalAlignment', 'left');
% Bottom-aligned just above the axis floor, because this band is only a few percent of the
% power axis and a centered label would cross its own boundary line.
text(labelVoltage, 0.01 * powerCeilingPu, 'DCM over the whole line cycle', ...
    'FontSize', 9, 'FontWeight', 'bold', 'Color', [0.60 0.10 0.10], ...
    'HorizontalAlignment', 'left', 'VerticalAlignment', 'bottom');

xlim([min(acVoltageVec) max(acVoltageVec)]);
ylim([0 powerCeilingPu]);
% The power base is not stated on its axis - rated power is a specification input.
xlabel('AC input voltage, rms (V)', 'FontSize', 12);
ylabel('Output power (W, pu)', 'FontSize', 12);
% The regions are labeled inside the axes, so the title carries only the design values.
title(sprintf('Conduction mode, L = %.1f \\muH per leg, %d legs, V_{out} = %.0f V', ...
    boostInductance * 1e6, numberOfLegs, outputVoltage), 'FontSize', 13);
% Outside the axes: every region is filled and both boundaries run the full width, so an
% inside legend would cover a boundary line wherever it sat.
legend('Location', 'southoutside', 'NumColumns', 2, 'FontSize', 9);
% Grid on top, or the three filled regions hide it.
grid on;
set(gca, 'Layer', 'top');
end
