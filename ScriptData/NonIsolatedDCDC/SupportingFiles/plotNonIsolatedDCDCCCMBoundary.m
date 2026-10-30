function [ccmPowerBoundary, inputVoltageVec] = plotNonIsolatedDCDCCCMBoundary( ...
    nonIsolatedDCDCDesign, options)
%PLOTNONISOLATEDDCDCCCMBOUNDARY Plot the CCM/DCM boundary of a non-isolated DC-DC.
%
%   [ccmPowerBoundary, inputVoltageVec] = plotNonIsolatedDCDCCCMBoundary(
%   nonIsolatedDCDCDesign, Name=Value) draws the continuous-conduction-mode boundary in
%   the (input voltage, output power) plane, for any of the six topologies
%   designNonIsolatedDCDCConverter supports.
%
%   Inputs:
%     nonIsolatedDCDCDesign  Design structure from designNonIsolatedDCDCConverter.
%
%   Name-value options:
%     InputVoltageVec  Input voltages to sweep (V). Default: the specified range with
%                      10% margin each side.
%
%   Outputs:
%     ccmPowerBoundary  Boundary output power at each swept input voltage (W).
%     inputVoltageVec   The input voltages swept (V).
%
%   Example:
%     [designTable, nonIsolatedDCDCDesign] = designNonIsolatedDCDCConverter(spec);
%     plotNonIsolatedDCDCCCMBoundary(nonIsolatedDCDCDesign);
%
%   See also designNonIsolatedDCDCConverter,
%   plotNonIsolatedDCDCInductorCurrentRipple.

% Copyright 2026 The MathWorks, Inc.

arguments
    nonIsolatedDCDCDesign struct
    options.InputVoltageVec (1,:) double = []
end

% Plain doubles for the arithmetic and the labelling. The topology and switching frequency
% are not read here - they reach the sweep through
% nonIsolatedDCDCOperatingPoint, which takes the whole design structure.
outputVoltage = value(nonIsolatedDCDCDesign.outputVoltage, "V");
ratedPower    = value(nonIsolatedDCDCDesign.ratedPower, "W");
corners = nonIsolatedDCDCDesign.operatingPoints;
cornerCount = numel(corners);

% Margin so the operating points sit inside the plot rather than on its edges.
if isempty(options.InputVoltageVec)
    inputVoltageMin = min([corners.inputVoltage]);
    inputVoltageMax = max([corners.inputVoltage]);
    inputVoltageVec = linspace(0.9*inputVoltageMin, 1.1*inputVoltageMax, 400);
else
    inputVoltageVec = options.InputVoltageVec;
end

% The boundary, from the same CCM laws designNonIsolatedDCDCConverter uses. Raising the
% switching frequency does not move it: holding the ripple fraction shrinks the
% inductance in exact proportion, so only a smaller ripple fraction reaches further down.
% Light-load DCM is inherent - staying continuous to zero load needs infinite inductance.
sweptOperatingPoint = nonIsolatedDCDCOperatingPoint(nonIsolatedDCDCDesign, ...
    inputVoltageVec, ratedPower);
ccmPowerBoundary = sweptOperatingPoint.ccmPowerThreshold;

% The swept curve must pass through every stored threshold, which is the guard
% against the sweep and the design table drifting apart.
cornerInputVoltages = [corners.inputVoltage];
cornerOperatingPoint = nonIsolatedDCDCOperatingPoint(nonIsolatedDCDCDesign, ...
    cornerInputVoltages, ratedPower);
assert(all(abs(cornerOperatingPoint.ccmPowerThreshold - ...
    [corners.ccmPowerThreshold]) < 1e-9*ratedPower), ...
    'plotNonIsolatedDCDCCCMBoundary:OperatingPointMismatch', ...
    ['The swept CCM boundary does not reproduce the design''s own ' ...
    'per-input-voltage thresholds, so the two have drifted apart.']);

figure('Name', 'NonIsolatedDCDCCCMBoundary', 'Position', [100 100 1150 800]);
hold on;

% A LOGARITHMIC power axis: the boundary sits at a small fraction of rated power, and what
% is wanted off the plot is a ratio - how far down the load range conduction stays
% continuous - which a log axis shows at constant size.
% Room above the rated-power line for its markers and below the boundary for the input
% voltage labels; on a log axis a factor is the right kind of margin.
powerCeiling = max(2*ratedPower, 1.3*max(ccmPowerBoundary));
powerFloor = min(ccmPowerBoundary)/5;
set(gca, 'YScale', 'log');

% Everything above the boundary, up to the ceiling so the rated-power line sits inside.
fill([inputVoltageVec, fliplr(inputVoltageVec)], ...
    [ccmPowerBoundary, powerCeiling*ones(size(inputVoltageVec))], ...
    [0.80 0.95 0.80], 'EdgeColor', 'none', 'HandleVisibility', 'off');

plot(inputVoltageVec, ccmPowerBoundary, 'r-', 'LineWidth', 2, ...
    'DisplayName', 'CCM boundary P_{CCM} = \DeltaI_L / (2 i_{L,avg}/P)');

yline(ratedPower, 'k--', 'LineWidth', 1.4, ...
    'DisplayName', sprintf('Rated power = %.0f W', ratedPower));

% The specified input range, which is the part of the sweep that matters.
xline(min(cornerInputVoltages), 'b:', 'LineWidth', 1.2, 'HandleVisibility', 'off');
xline(max(cornerInputVoltages), 'b:', 'LineWidth', 1.2, 'HandleVisibility', 'off');

% Each input voltage twice: at rated power where it operates, and on the boundary where
% its CCM threshold lies. The vertical gap between the pair IS the continuous part of
% the load range at that input voltage.
for cornerIndex = 1:cornerCount
    cornerVoltage = corners(cornerIndex).inputVoltage;
    cornerThreshold = corners(cornerIndex).ccmPowerThreshold;
    plot(cornerVoltage, ratedPower, 's', 'MarkerSize', 10, 'LineWidth', 1.8, ...
        'MarkerFaceColor', 'w', 'Color', 'b', 'HandleVisibility', 'off');
    plot(cornerVoltage, cornerThreshold, 'o', 'MarkerSize', 8, 'LineWidth', 1.6, ...
        'MarkerFaceColor', 'w', 'Color', 'r', 'HandleVisibility', 'off');
    % The power, and the fraction of rated it is.
    text(cornerVoltage, cornerThreshold/1.15, ...
        sprintf('%.0f W (%.1f%%)', cornerThreshold, 100*cornerThreshold/ratedPower), ...
        'VerticalAlignment', 'top', 'HorizontalAlignment', 'center', ...
        'FontSize', 11, 'FontWeight', 'bold');
end
% One legend entry per marker kind rather than one per input voltage.
plot(NaN, NaN, 's', 'MarkerSize', 10, 'LineWidth', 1.8, 'MarkerFaceColor', 'w', ...
    'Color', 'b', 'DisplayName', 'Specified input voltages at rated power');
plot(NaN, NaN, 'o', 'MarkerSize', 8, 'LineWidth', 1.6, 'MarkerFaceColor', 'w', ...
    'Color', 'r', 'DisplayName', 'CCM threshold at each input voltage');

% Name the two regions, so the plot reads without the legend.
regionVoltage = min(inputVoltageVec) + ...
    0.06*(max(inputVoltageVec) - min(inputVoltageVec));
text(regionVoltage, sqrt(max(ccmPowerBoundary)*powerCeiling), ...
    'CCM over the whole cycle', 'FontSize', 13, 'FontWeight', 'bold', ...
    'Color', [0.15 0.45 0.15], 'HorizontalAlignment', 'left');
text(regionVoltage, sqrt(min(ccmPowerBoundary)*powerFloor), ...
    'DCM near the current valley', 'FontSize', 13, 'FontWeight', 'bold', ...
    'Color', [0.55 0.30 0.10], 'HorizontalAlignment', 'left');

xlim([min(inputVoltageVec) max(inputVoltageVec)]);
ylim([powerFloor powerCeiling]);
% Large text, so the labels stay readable when the figure is shown at half width.
set(gca, 'FontSize', 13);
xlabel('Input voltage (V)', 'FontSize', 15);
ylabel('Output power (W)', 'FontSize', 15);
title(sprintf('%s conduction mode, V_{out} = %.0f V', nonIsolatedDCDCDesign.topology, ...
    outputVoltage), 'FontSize', 15);
% Below the axes, so the legend covers neither the regions nor the markers.
legend('Location', 'southoutside', 'NumColumns', 2, 'FontSize', 12);
grid on;
end
