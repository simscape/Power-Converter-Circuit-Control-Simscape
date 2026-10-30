function [inductorCurrentEnvelope, inputVoltageVec] = ...
    plotNonIsolatedDCDCInductorCurrentRipple(nonIsolatedDCDCDesign, options)
%PLOTNONISOLATEDDCDCINDUCTORCURRENTRIPPLE Inductor current across the input range.
%
%   [inductorCurrentEnvelope, inputVoltageVec] =
%   plotNonIsolatedDCDCInductorCurrentRipple(nonIsolatedDCDCDesign, Name=Value) plots the
%   inductor current envelope and the realized ripple fraction across the specified input
%   voltage range at rated power.
%
%   Inputs:
%     nonIsolatedDCDCDesign  Design structure from designNonIsolatedDCDCConverter.
%
%   Name-value options:
%     InputVoltageVec  Input voltages to sweep (V). Default: the specified range.
%     LoadFraction     Output power as a fraction of rated. Default 1.
%
%   Outputs:
%     inductorCurrentEnvelope  Operating point over the sweep.
%     inputVoltageVec          The input voltages swept (V).
%
%   Example:
%     [designTable, nonIsolatedDCDCDesign] = designNonIsolatedDCDCConverter(spec);
%     plotNonIsolatedDCDCInductorCurrentRipple(nonIsolatedDCDCDesign);
%
%   See also designNonIsolatedDCDCConverter, nonIsolatedDCDCOperatingPoint,
%   plotNonIsolatedDCDCCCMBoundary.

% Copyright 2026 The MathWorks, Inc.

arguments
    nonIsolatedDCDCDesign struct
    options.InputVoltageVec (1,:) double = []
    options.LoadFraction (1,1) double {mustBePositive} = 1
end

inductance    = value(nonIsolatedDCDCDesign.inductance, "H");
outputVoltage = value(nonIsolatedDCDCDesign.outputVoltage, "V");
ratedPower    = value(nonIsolatedDCDCDesign.ratedPower, "W");
requestedRippleFraction = nonIsolatedDCDCDesign.requestedRippleFraction;
corners = nonIsolatedDCDCDesign.operatingPoints;
cornerCount = numel(corners);

cornerInputVoltages = [corners.inputVoltage];
if isempty(options.InputVoltageVec)
    inputVoltageVec = linspace(min(cornerInputVoltages), max(cornerInputVoltages), 400);
else
    inputVoltageVec = options.InputVoltageVec;
end

% Both plots share this x range: the swept range with a narrow gutter, so the markers
% and labels at the two ends sit clear of the axes box. The sweep itself is not
% widened: behavior outside the specified input range is not part of the design.
plotVoltageLimits = [min(inputVoltageVec) max(inputVoltageVec)] + ...
    0.02*(max(inputVoltageVec) - min(inputVoltageVec))*[-1 1];

outputPower = options.LoadFraction*ratedPower;
inductorCurrentEnvelope = nonIsolatedDCDCOperatingPoint(nonIsolatedDCDCDesign, ...
    inputVoltageVec, outputPower);

% Evaluated at the plotted power, not scaled from the design's stored values: only the
% average current scales with load, so the peak and the ripple fraction do not.
cornerOperatingPoint = nonIsolatedDCDCOperatingPoint(nonIsolatedDCDCDesign, ...
    cornerInputVoltages, outputPower);

% Guard against the sweep and the design table drifting apart. Only meaningful at rated
% power, which is where the design evaluated its input voltages.
if options.LoadFraction == 1
    currentTolerance = 1e-9*max([corners.peakInductorCurrent]);
    assert(all(abs(cornerOperatingPoint.peakInductorCurrent - ...
        [corners.peakInductorCurrent]) < currentTolerance) && ...
        all(abs(cornerOperatingPoint.inductorCurrentRipple - ...
        [corners.inductorCurrentRipple]) < currentTolerance), ...
        'plotNonIsolatedDCDCInductorCurrentRipple:OperatingPointMismatch', ...
        ['The swept inductor current does not reproduce the design''s own ' ...
        'per-input-voltage values, so the two have drifted apart.']);
end

figure('Name', 'NonIsolatedDCDCInductorCurrentRipple', 'Position', [100 100 900 700]);
tiledLayout = tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

%% ------------------------------------------------ plot 1: the current envelope
nexttile;
hold on;

% The band between valley and peak IS the ripple; against its height it is the ripple
% fraction the plot below shows.
fill([inputVoltageVec, fliplr(inputVoltageVec)], ...
    [inductorCurrentEnvelope.peakInductorCurrent, ...
    fliplr(inductorCurrentEnvelope.valleyInductorCurrent)], ...
    [0.85 0.90 0.98], 'EdgeColor', 'none', 'DisplayName', ...
    'Ripple band i_{L,avg} \pm \DeltaI_L/2');

plot(inputVoltageVec, inductorCurrentEnvelope.peakInductorCurrent, '-', ...
    'Color', [0.85 0.33 0.10], 'LineWidth', 1.8, ...
    'DisplayName', 'Peak (sizes the core and the devices)');
plot(inputVoltageVec, inductorCurrentEnvelope.inductorCurrentAverage, '-', ...
    'Color', [0 0.45 0.74], 'LineWidth', 2, 'DisplayName', 'Average');
% In a synchronous topology the low-side device conducts in reverse below zero, so the
% current goes negative and conduction stays continuous.
plot(inputVoltageVec, inductorCurrentEnvelope.valleyInductorCurrent, '-', ...
    'Color', [0.47 0.67 0.19], 'LineWidth', 1.8, ...
    'DisplayName', 'Valley (CCM boundary at zero)');
yline(0, 'k-', 'LineWidth', 0.8, 'HandleVisibility', 'off');

markInputVoltages(cornerCount, cornerInputVoltages, ...
    cornerOperatingPoint.peakInductorCurrent, ...
    compose('%.2f A', cornerOperatingPoint.peakInductorCurrent));

xlim(plotVoltageLimits);
% Headroom for the input voltage labels, and zero kept in view so the valley's distance
% from DCM is visible.
ylim([0 1.18*max(inductorCurrentEnvelope.peakInductorCurrent)]);
ylabel('Inductor current (A)', 'FontSize', 12);
title(sprintf(['%s inductor current across the input range,  L = %.1f \\muH,  ' ...
    'V_{out} = %.0f V,  P = %.0f W'], nonIsolatedDCDCDesign.topology, ...
    inductance*1e6, outputVoltage, outputPower), 'FontSize', 12);
legend('Location', 'best', 'FontSize', 9);
grid on;

%% ------------------------------------------- plot 2: the realized ripple fraction
nexttile;
hold on;

plot(inputVoltageVec, 100*inductorCurrentEnvelope.realizedRippleFraction, '-', ...
    'Color', [0.49 0.18 0.56], 'LineWidth', 2, ...
    'DisplayName', 'Realized ripple fraction \DeltaI_L / i_{L,avg}');
yline(100*requestedRippleFraction, 'r--', 'LineWidth', 1.6, ...
    'DisplayName', sprintf('Specified limit = %.1f%%', 100*requestedRippleFraction));

markInputVoltages(cornerCount, cornerInputVoltages, ...
    100*cornerOperatingPoint.realizedRippleFraction, ...
    compose('%.1f%%', 100*cornerOperatingPoint.realizedRippleFraction));

xlim(plotVoltageLimits);
% Room above the limit for the worst input voltage's label, and below for the others'.
rippleFractionSpan = [100*min(inductorCurrentEnvelope.realizedRippleFraction), ...
    max(100*requestedRippleFraction, ...
    100*max(inductorCurrentEnvelope.realizedRippleFraction))];
% A single-point input range would give a zero span, which ylim rejects.
rippleFractionMargin = max(0.14*diff(rippleFractionSpan), 0.5);
ylim(rippleFractionSpan + rippleFractionMargin*[-1 1]);
xlabel('Input voltage (V)', 'FontSize', 12);
ylabel('Ripple fraction (%)', 'FontSize', 12);
% Name the input voltage that sets the inductance.
title(sprintf(['The inductance is set at %s, where the realized ripple fraction meets ' ...
    'its limit'], nonIsolatedDCDCDesign.inductanceSetByInputVoltage), 'FontSize', 12);
legend('Location', 'best', 'FontSize', 9);
grid on;

title(tiledLayout, 'Inductor current and ripple fraction', 'FontSize', 13, ...
    'FontWeight', 'bold');
end

%% ------------------------------------------------------------------ local function
function markInputVoltages(cornerCount, cornerInputVoltages, cornerValues, cornerLabels)
%markInputVoltages Put a marker and a value label at each specified input voltage.
%   One legend entry covers all the markers. The markers sit at the two ends of the swept
%   range, where a centered label runs off the axes, so each is aligned away from its own
%   edge instead.
minimumVoltage = min(cornerInputVoltages);
maximumVoltage = max(cornerInputVoltages);
for cornerIndex = 1:cornerCount
    cornerVoltage = cornerInputVoltages(cornerIndex);
    plot(cornerVoltage, cornerValues(cornerIndex), 's', ...
        'MarkerSize', 9, 'LineWidth', 1.6, 'MarkerFaceColor', 'w', 'Color', 'k', ...
        'HandleVisibility', 'off');
    if cornerVoltage == minimumVoltage
        labelAlignment = 'left';
        labelText = "  " + cornerLabels(cornerIndex);
    elseif cornerVoltage == maximumVoltage
        labelAlignment = 'right';
        labelText = cornerLabels(cornerIndex) + "  ";
    else
        labelAlignment = 'center';
        labelText = cornerLabels(cornerIndex);
    end
    text(cornerVoltage, cornerValues(cornerIndex), labelText, 'FontSize', 9, ...
        'FontWeight', 'bold', 'VerticalAlignment', 'bottom', ...
        'HorizontalAlignment', labelAlignment);
end
plot(NaN, NaN, 's', 'MarkerSize', 9, 'LineWidth', 1.6, 'MarkerFaceColor', 'w', ...
    'Color', 'k', 'DisplayName', 'Specified input voltages');
end
