function boundaryTable = plotDABZVSRegion(DABDesign, options)
%PLOTDABZVSREGION Plot the DAB soft-switching region under SPS modulation.
%
%   boundaryTable = plotDABZVSRegion(DABDesign, Name=Value) draws the soft-switching region
%   in the (duty ratio, conversion ratio) plane for one power direction. At each conversion
%   ratio M = n*V2/V1 it traces the smallest duty ratio D = phi/pi at which each bridge
%   reaches the commutation current it needs. Both bridges have to commutate, so the shaded
%   region beyond the outer of the two curves soft switches.
%
%   Assumption: the series inductance is a T network, split by primarySideFraction across
%   the magnetizing branch. Each bridge commutates against the inductance on its own side
%   and receives the share of magnetizing current set by the inductance on the other side.
%   Every condition scales with the voltage level, so the curves hold at any V1.
%
%   Inputs:
%     DABDesign  Design structure from designDABConverter.
%
%   Name-value options:
%     PowerDirection      "forward" for power to the secondary, "reverse" for power back to
%                         the primary. Default "forward".
%     ConversionRatioVec  Conversion ratios to sweep. Default: the design's own envelope
%                         with 10% margin each side.
%     Interactions        Keep the default axes interactions and toolbar. Default false.
%
%   Outputs:
%     boundaryTable  Table of the swept conversion ratio, each bridge's boundary duty ratio
%                    and the region edge.
%
%   Example:
%     [designTable, DABDesign] = designDABConverter(DABSpec);
%     plotDABZVSRegion(DABDesign);
%     plotDABZVSRegion(DABDesign, PowerDirection = "reverse");
%
%   See also designDABConverter, DABSPSPhysics, computeDABSoftSwitchingLimit.

% Copyright 2026 The MathWorks, Inc.

arguments
    DABDesign struct
    options.PowerDirection (1,1) string ...
        {mustBeMember(options.PowerDirection, ["forward", "reverse"])} = "forward"
    options.ConversionRatioVec (1,:) double = []
    options.Interactions (1,1) logical = false
end

% Physical fields are sealed simscape.Value in SI base units, so .value is the magnitude;
% the dimensionless turns ratio is a plain double.
n = DABDesign.turnsRatio;
Prated = DABDesign.ratedPower.value;
Pmin   = DABDesign.minSoftSwitchPower.value;

secondaryCapacitance = DABDesign.mosfetOutputCapacitance.value;
if isfield(DABDesign, 'mosfetOutputCapacitanceSecondary')
    secondaryCapacitance = DABDesign.mosfetOutputCapacitanceSecondary.value;
end
% The same physics object the design function uses, so the plot and the sized floors come
% from one implementation.
sps = DABSPSPhysics(n, DABDesign.switchingFrequency.value, ...
    DABDesign.seriesInductance.value, DABDesign.mosfetOutputCapacitance.value, ...
    SecondaryOutputCapacitance = secondaryCapacitance, ...
    PrimarySideFraction = DABDesign.primarySideFraction, ...
    MagnetizingInductance = DABDesign.Lm.value, ...
    DeadTime = DABDesign.deadTime.value);

V1minVal = DABDesign.V1min.value;  V1maxVal = DABDesign.V1max.value;  V1nomVal = DABDesign.V1nom.value;
V2minVal = DABDesign.V2min.value;  V2maxVal = DABDesign.V2max.value;  V2nomVal = DABDesign.V2nom.value;

% Conversion-ratio extremes across the envelope, swept with margin.
Mmax = n * V2maxVal / V1minVal;
Mmin = n * V2minVal / V1maxVal;
if isempty(options.ConversionRatioVec)
    conversionRatioVec = linspace(0.9 * Mmin, 1.1 * Mmax, 160);
else
    conversionRatioVec = options.ConversionRatioVec;
end

isForward = options.PowerDirection == "forward";
if isForward
    directionSign = 1;
    directionText = 'power to the secondary';
    directionTitle = 'Forward Power Transfer';
else
    directionSign = -1;
    directionText = 'power back to the primary';
    directionTitle = 'Reverse Power Transfer';
end

% One voltage level traces the whole family, because every commutation condition and the
% available current all scale with V1.
dutyLimit = 0.5;                      % phase shift pi/2
V1 = V1nomVal;
numberOfRatios = numel(conversionRatioVec);
primaryBoundary = nan(numberOfRatios, 1);
secondaryBoundary = nan(numberOfRatios, 1);
for ratioIndex = 1:numberOfRatios
    V2 = conversionRatioVec(ratioIndex) * V1 / n;
    primaryBoundary(ratioIndex) = sps.bridgeZvsDutyBoundary("primary", V1, V2, directionSign);
    secondaryBoundary(ratioIndex) = sps.bridgeZvsDutyBoundary("secondary", V1, V2, directionSign);
end

% Both bridges have to commutate, so the region starts at the larger duty magnitude of the
% two. A ratio where a bridge never reaches its current sits at the pi/2 limit.
regionEdge = directionSign * max(abs(primaryBoundary), abs(secondaryBoundary));
regionEdge(isnan(regionEdge)) = directionSign * dutyLimit;

figure('Name', 'DABZVSRegion');
hold on;

% Shade from the edge out to the pi/2 limit, so the shaded area is where both bridges soft
% switch and the clear wedge next to D = 0 is where at least one hard switches.
ratioColumn = conversionRatioVec(:);
softPatch = fill([regionEdge; repmat(directionSign * dutyLimit, numberOfRatios, 1)], ...
    [ratioColumn; flipud(ratioColumn)], [0.20 0.60 0.30], ...
    'DisplayName', 'Both bridges soft switch');
softPatch.FaceAlpha = 0.12;
softPatch.EdgeColor = 'none';

plot(primaryBoundary, conversionRatioVec, '-', 'Color', [0.85 0.33 0.10], 'LineWidth', 2, ...
    'DisplayName', 'Primary bridge boundary');
plot(secondaryBoundary, conversionRatioVec, '-', 'Color', [0.00 0.45 0.74], 'LineWidth', 2, ...
    'DisplayName', 'Secondary bridge boundary');

% The V1 and V2 combinations, at the duty ratio each needs for rated and for minimum power.
cornerVoltages = [V1minVal V2maxVal; V1maxVal V2minVal; V1nomVal V2nomVal];
cornerRatio = n * cornerVoltages(:, 2) ./ cornerVoltages(:, 1);
ratedDuty = zeros(size(cornerRatio));
minPowerDuty = zeros(size(cornerRatio));
for cornerIndex = 1:numel(cornerRatio)
    ratedDuty(cornerIndex) = sps.phaseShiftForPower(Prated, ...
        cornerVoltages(cornerIndex, 1), cornerVoltages(cornerIndex, 2)) / pi;
    minPowerDuty(cornerIndex) = sps.phaseShiftForPower(Pmin, ...
        cornerVoltages(cornerIndex, 1), cornerVoltages(cornerIndex, 2)) / pi;
end
plot(directionSign * ratedDuty, cornerRatio, 'ks', 'MarkerSize', 8, 'LineWidth', 1.5, ...
    'MarkerFaceColor', [0.95 0.95 0.95], 'DisplayName', 'V_1 / V_2 pairs at rated power');
plot(directionSign * minPowerDuty, cornerRatio, 'kx', 'MarkerSize', 10, 'LineWidth', 1.8, ...
    'DisplayName', 'V_1 / V_2 pairs at minimum power');

% Both curves crowd the D = 0 edge, so the label goes to the far edge of each plane.
if isForward
    labelAlignment = 'right';
else
    labelAlignment = 'left';
end
yline(1, 'Color', [0.5 0.5 0.5], 'LineStyle', '-.', 'LineWidth', 1.2, ...
    'Label', 'M = 1 (matched)', 'LabelHorizontalAlignment', labelAlignment, ...
    'HandleVisibility', 'off');

if isForward
    xlim([0, dutyLimit]);
    xticks(0:0.05:dutyLimit);
    legend('Location', 'southeast', 'FontSize', 9);
else
    xlim([-dutyLimit, 0]);
    xticks(-dutyLimit:0.05:0);
    legend('Location', 'southwest', 'FontSize', 9);
end
ylim([min(conversionRatioVec), max(conversionRatioVec)]);

xlabel(sprintf('Duty ratio D = \\phi/\\pi   (%s)', directionText), 'FontSize', 12);
ylabel('Voltage conversion ratio M = n V_2 / V_1', 'FontSize', 12);
title(sprintf('DAB Soft-Switching Region, %s', directionTitle), 'FontSize', 13);
grid on;
box on;
set(gcf, 'Position', [400, 300, 570, 390]);

% A live figure keeps its default interactions active, and without graphics hardware
% they slow the Live Editor, so they are off unless asked for
if ~options.Interactions
    plotAxes = gca;
    disableDefaultInteractivity(plotAxes);
    plotAxes.Toolbar.Visible = 'off';
end

boundaryTable = table(conversionRatioVec(:), primaryBoundary, secondaryBoundary, regionEdge, ...
    'VariableNames', {'ConversionRatio', 'PrimaryBoundary', 'SecondaryBoundary', 'RegionEdge'});

end
