function lossShareTable = plotDABLossPieChart(lossData, options)
%PLOTDABLOSSPIECHART Pie chart of the DAB converter loss by subsystem, titled with the efficiency.
%
%   plotDABLossPieChart(lossData) plots the share of the primary bridge device loss, the secondary
%   bridge device loss and the passive component loss in the total loss, and shows the converter
%   efficiency in the title.
%
%   lossShareTable = plotDABLossPieChart(lossData) also returns the shares.
%
%   Inputs:
%     lossData  Result of estimateDABDeviceLoss.
%
%   Name-value options:
%     Interactions  Keep the default axes interactions and toolbar. Default false.
%
%   Outputs:
%     lossShareTable  Table of Subsystem and LossShare in percent.
%
%   Example:
%     lossData = estimateDABDeviceLoss(lossResult);
%     plotDABLossPieChart(lossData);
%
%   See also estimateDABDeviceLoss, plotDABDeviceLoss.

% Copyright 2026 The MathWorks, Inc.

arguments
    lossData (1,1) struct
    options.Interactions (1,1) logical = false
end

deviceTable = lossData.deviceTable;
subsystemLoss = [sum(deviceTable.Total(deviceTable.Bridge == "Primary bridge")); ...
    sum(deviceTable.Total(deviceTable.Bridge == "Secondary bridge")); ...
    lossData.passiveLoss];
Subsystem = ["Primary Bridge"; "Secondary Bridge"; "Passive Device"];
LossShare = 100 * subsystemLoss / sum(subsystemLoss);
lossShareTable = table(Subsystem, LossShare);

% The axes-based pie is used rather than piechart, whose interactions cannot be turned
% off; the style matches the loss pie of the converter Main scripts.
figure('Name', 'Percentage Subsystem Loss', 'Position', [400 525 610 347]);
pieAxes = axes;
pieObjects = pie(pieAxes, LossShare, compose("%.1f%%", LossShare));
set(pieObjects(1:2:end), 'EdgeColor', 'w', 'LineWidth', 1.5);    % slice outlines
set(pieObjects(2:2:end), 'FontSize', 11, 'FontWeight', 'bold');  % slice labels
% Slice colors from the blue-to-green part of parula, leaving out its yellow end
pieColormap = parula(256);
colormap(pieAxes, pieColormap(1:170, :));
% The share labels sit just outside the circle, so the limits leave room for them, and the
% legend is placed to the right of the pie so it cannot cover a label
axis(pieAxes, 1.35 * [-1 1 -1 1]);
pieAxes.Position = [0.02 0.06 0.58 0.84];
legendHandle = legend(pieAxes, Subsystem, 'FontSize', 10);
legendHandle.Position(1:2) = [0.62, 0.5 - legendHandle.Position(4)/2];
title(pieAxes, sprintf('Loss Distribution, Efficiency = %.2f%%', lossData.efficiency), 'FontSize', 11);
% A live figure keeps its default interactions active, and without graphics hardware
% they slow the Live Editor, so they are off unless asked for
if ~options.Interactions
    for interactionAxes = pieAxes
        disableDefaultInteractivity(interactionAxes);
        interactionAxes.Toolbar.Visible = 'off';
    end
end
end
