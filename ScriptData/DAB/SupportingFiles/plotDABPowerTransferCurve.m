function [powerMatrix, phaseShiftVec] = plotDABPowerTransferCurve(DABDesign, options)
%PLOTDABPOWERTRANSFERCURVE Plot the SPS power-transfer curves over the voltage range.
%
%   [powerMatrix, phaseShiftVec] = plotDABPowerTransferCurve(DABDesign, Name=Value)
%   sweeps the single-phase-shift control variable phi over its full bidirectional range
%   [-pi/2, +pi/2] at each V1 and V2 combination. It plots the transferred power, positive
%   for primary to secondary and negative for reverse flow. Both bridges run a fixed 50%
%   duty throughout. The phase shift that meets rated power is marked on each curve, against
%   overlaid rated and minimum-power levels.
%
%   Inputs:
%     DABDesign  Design structure from designDABConverter.
%
%   Name-value options:
%     PhaseShiftVec  Phase shifts to sweep (rad). Default linspace(-pi/2, pi/2, 401).
%     VoltagePairs   N-by-2 [V1 V2] combinations to plot. Default: the minimum, nominal
%                    and maximum of the design's own voltage envelope.
%     Interactions   Keep the default axes interactions and toolbar. Default false.
%
%   Outputs:
%     powerMatrix    Transferred power, one row per V1 and V2 pair and one column per
%                    phase shift.
%     phaseShiftVec  The phase shifts swept (rad).
%
%   Example:
%     [designTable, DABDesign] = designDABConverter(DABSpec);
%     plotDABPowerTransferCurve(DABDesign);
%
%   See also designDABConverter, DABSPSPhysics, plotDABZVSRegion.

% Copyright 2026 The MathWorks, Inc.

arguments
    DABDesign struct
    options.PhaseShiftVec (1,:) double = linspace(-pi/2, pi/2, 401)
    options.VoltagePairs double = []
    options.Interactions (1,1) logical = false
end

% Physical fields are sealed simscape.Value in SI base units, so .value is the magnitude;
% the dimensionless turns ratio is a plain double.
n   = DABDesign.turnsRatio;
L   = DABDesign.seriesInductance.value;
fsw = DABDesign.switchingFrequency.value;
Prated = DABDesign.ratedPower.value;
Pmin   = DABDesign.minSoftSwitchPower.value;

% The same physics object the design function uses, so the power law and its inverse have
% one source. Coss does not enter the power law and is left at its default.
sps = DABSPSPhysics(n, fsw, L);

% For fixed n, fsw and L the SPS power depends only on the product V1*V2, so the four
% voltage extremes collapse to three power-capability levels: lowest product (the weakest
% case, needing the most phase shift for rated power), nominal, and highest.
if isempty(options.VoltagePairs)
    voltagePairs = [ ...
        DABDesign.V1min.value, DABDesign.V2min.value; ...   % lowest V1*V2  -> lowest power capability
        DABDesign.V1nom.value, DABDesign.V2nom.value; ...    % nominal
        DABDesign.V1max.value, DABDesign.V2max.value];       % highest V1*V2 -> highest power capability
    voltagePairLabels = {'V_{1min} / V_{2min}', 'V_{1nom} / V_{2nom}', 'V_{1max} / V_{2max}'};
else
    voltagePairs = options.VoltagePairs;
    voltagePairLabels = arrayfun(@(k) sprintf('%g V / %g V', ...
        voltagePairs(k,1), voltagePairs(k,2)), 1:size(voltagePairs,1), ...
        'UniformOutput', false);
end

phaseShiftVec = options.PhaseShiftVec;
dutyVec = phaseShiftVec / pi;               % D = phi/pi (50% duty is fixed; phi is the DOF)
numberOfVoltagePairs = size(voltagePairs, 1);
powerMatrix = zeros(numberOfVoltagePairs, numel(phaseShiftVec));

% Per-unit base = rated power, so rated power plots at 1 pu.
basePower = Prated;

figure('Name', 'DABPowerTransferCurve');
hold on;
colors = lines(numberOfVoltagePairs);
for k = 1:numberOfVoltagePairs
    V1 = voltagePairs(k, 1);
    V2 = voltagePairs(k, 2);
    % Bidirectional SPS power law (antisymmetric in phi): D*(1-|D|).
    powerMatrix(k, :) = sps.bidirectionalPowerForDuty(dutyVec, V1, V2);
    plot(phaseShiftVec, powerMatrix(k, :) / basePower, 'LineWidth', 2, 'Color', colors(k, :));

    % phaseShiftForPower returns NaN if this pair cannot reach rated power at all.
    phiRated = sps.phaseShiftForPower(Prated, V1, V2);
    if ~isnan(phiRated)
        plot(phiRated, Prated / basePower, 'o', 'MarkerSize', 8, 'LineWidth', 2, ...
            'Color', colors(k, :), 'HandleVisibility', 'off');
    end
end

% Rated and minimum power reference lines (per unit), forward and reverse.
yline( Prated / basePower, 'k--', 'LineWidth', 1.5, 'Label', 'Rated power', ...
    'LabelHorizontalAlignment', 'left');
yline(-Prated / basePower, 'k--', 'LineWidth', 1.5, 'HandleVisibility', 'off');
yline( Pmin / basePower, 'k:', 'LineWidth', 1.5, 'Label', 'Min soft-switch power', ...
    'LabelHorizontalAlignment', 'left');
yline(-Pmin / basePower, 'k:', 'LineWidth', 1.5, 'HandleVisibility', 'off');
xline(0, 'Color', [0.5 0.5 0.5], 'HandleVisibility', 'off');

% Tick the x-axis in fractions of pi over the bidirectional range.
xticks([-pi/2, -pi/4, 0, pi/4, pi/2]);
xticklabels({'-\pi/2', '-\pi/4', '0', '\pi/4', '\pi/2'});
xlim([-pi/2, pi/2]);

xlabel('Phase shift \phi (rad)', 'FontSize', 12);
ylabel('Transferred power (pu)', 'FontSize', 12);
title('DAB SPS Power Transfer Across the Voltage Range', 'FontSize', 13);
% Box on: MATLAB then auto-sizes it to the text, so no label is clipped.
legendHandle = legend(voltagePairLabels, 'Location', 'northwest');
legendHandle.Box = 'on';
grid on;
box on;
set(gcf, 'Position', [400, 300, 544, 408]);

% A live figure keeps its default interactions active, and without graphics hardware
% they slow the Live Editor, so they are off unless asked for
if ~options.Interactions
    plotAxes = gca;
    disableDefaultInteractivity(plotAxes);
    plotAxes.Toolbar.Visible = 'off';
end

end
