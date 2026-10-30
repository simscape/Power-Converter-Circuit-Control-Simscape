function [ccmPowerBoundary, acVoltageVec] = plotTotemPoleCCMBoundary(totemPoleDesign, options)
%PLOTTOTEMPOLECCMBOUNDARY Plot the CCM/DCM boundary of a totem-pole boost PFC.
%
%   [ccmPowerBoundary, acVoltageVec] = plotTotemPoleCCMBoundary(totemPoleDesign, Name=Value)
%   draws the continuous-conduction-mode boundary in the (AC input voltage, output power)
%   plane. The boundary is a curve in the line voltage alone and rises as the square of it,
%   putting the hardest case at high line. Each AC input voltage is marked at rated power
%   together with its own threshold as a fraction of rated.
%
%   Inputs:
%     totemPoleDesign  Design structure from designTotemPoleBoostPFCConverter.
%
%   Name-value options:
%     ACVoltageVec  AC input voltages to sweep (V rms). Default: the specified input range
%                   with 10% margin each side.
%
%   Outputs:
%     ccmPowerBoundary  Boundary output power at each swept line voltage (W).
%     acVoltageVec      The line voltages swept (V rms).
%
%   Example:
%     [designTable, totemPoleDesign] = designTotemPoleBoostPFCConverter(totemPoleSpec);
%     plotTotemPoleCCMBoundary(totemPoleDesign);
%
%   See also designTotemPoleBoostPFCConverter, plotTotemPoleInductorCurrentRipple.

% Copyright 2026 The MathWorks, Inc.

arguments
    totemPoleDesign struct
    options.ACVoltageVec (1,:) double = []
end

% Naming the expected unit makes a wrong unit error instead of silently scaling.
boostInductance    = value(totemPoleDesign.boostInductance, "H");
switchingFrequency = value(totemPoleDesign.switchingFrequency, "Hz");
ratedPower         = value(totemPoleDesign.ratedPower, "W");
corners = totemPoleDesign.operatingPoints;
cornerCount = numel(corners);

% Margin on each side, so the operating points sit inside the plot, not on its edges.
if isempty(options.ACVoltageVec)
    acVoltageMin = min([corners.acVoltageRms]);
    acVoltageMax = max([corners.acVoltageRms]);
    acVoltageVec = linspace(0.9 * acVoltageMin, 1.1 * acVoltageMax, 400);
else
    acVoltageVec = options.ACVoltageVec;
end

% The CCM boundary power at each line voltage. CCM needs i_L(theta) > dIL(theta)/2
% everywhere on the cycle, and with i_L = Ipk*sin(theta) and
% dIL = Vpk*sin(theta)*(1 - m*sin(theta))/(L*fsw) the sin(theta) cancels EXACTLY, leaving a
% condition in the line voltage alone. Light-load DCM is inherent to a PFC rather than a
% fault - staying continuous down to zero load needs infinite inductance.
ccmPowerBoundary = acVoltageVec.^2 / (2 * switchingFrequency * boostInductance);

figure('Name', 'TotemPoleCCMBoundary');
hold on;

% Shade the CCM region, up to a ceiling above rated power so the rated-power line is
% visible inside the shading.
powerCeiling = max(1.2 * ratedPower, 1.1 * max(ccmPowerBoundary));
fill([acVoltageVec, fliplr(acVoltageVec)], ...
    [ccmPowerBoundary, powerCeiling * ones(size(acVoltageVec))], ...
    [0.80 0.95 0.80], 'EdgeColor', 'none', 'HandleVisibility', 'off');

plot(acVoltageVec, ccmPowerBoundary, 'r-', 'LineWidth', 2, ...
    'DisplayName', 'CCM boundary P_{CCM} = V_{rms}^2 / (2 f_{sw} L)');

% Rated power, and the operating points evaluated there.
yline(ratedPower, 'k--', 'LineWidth', 1.4, ...
    'DisplayName', sprintf('Rated power = %.0f W', ratedPower));

for cornerIndex = 1:cornerCount
    plot(corners(cornerIndex).acVoltageRms, ratedPower, 's', ...
        'MarkerSize', 10, 'LineWidth', 1.8, 'MarkerFaceColor', 'w', ...
        'Color', 'b', 'HandleVisibility', 'off');
    % CCM threshold as a fraction of rated power, offset above the rated-power line so
    % the dashed line does not strike the text through.
    text(corners(cornerIndex).acVoltageRms, ratedPower + 0.03 * ratedPower, ...
        sprintf('%.0f%%', 100 * corners(cornerIndex).ccmPowerThreshold / ratedPower), ...
        'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center', ...
        'FontSize', 9, 'FontWeight', 'bold');
end
% One legend entry for the markers rather than one per AC input voltage.
plot(NaN, NaN, 's', 'MarkerSize', 10, 'LineWidth', 1.8, 'MarkerFaceColor', 'w', ...
    'Color', 'b', 'DisplayName', 'AC input voltages at rated power');

xlim([min(acVoltageVec) max(acVoltageVec)]);
ylim([0 powerCeiling]);
xlabel('AC input voltage (V rms)', 'FontSize', 12);
ylabel('Output power (W)', 'FontSize', 12);
title(sprintf(['Totem-Pole Boost PFC conduction mode (green = CCM over the full ' ...
    'line cycle),  L = %.1f \\muH'], boostInductance * 1e6), 'FontSize', 13);
subtitle(['Labels give the CCM power threshold as a percentage of rated power ' ...
    'at each AC input voltage'], 'FontSize', 10);
% Bottom right is empty DCM region, so the legend cannot cover the markers or
% their labels up on the rated-power line.
legend('Location', 'southeast', 'FontSize', 9);
grid on;
end
