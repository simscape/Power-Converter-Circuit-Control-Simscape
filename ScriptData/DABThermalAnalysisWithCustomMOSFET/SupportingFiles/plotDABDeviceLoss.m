function plotDABDeviceLoss(lossData, options)
%PLOTDABDEVICELOSS Plot the loss of every bridge device by loss component.
%
%   plotDABDeviceLoss(lossData) draws one bar per device, split by loss component, with
%   the primary and the secondary bridge devices on shaded bands that carry the bridge
%   name.
%
%   plotDABDeviceLoss(lossData, ModelName=name) adds the model name to the title.
%
%   Inputs:
%     lossData  Result of estimateDABDeviceLoss.
%
%   Name-value options:
%     ModelName     Model name added to the title. Default "".
%     Interactions  Keep the default axes interactions and toolbar. Default false.
%
%   Example:
%     plotDABDeviceLoss(estimateDABDeviceLoss(thermalResult));
%
%   See also estimateDABDeviceLoss.

% Copyright 2026 The MathWorks, Inc.

arguments
    lossData (1,1) struct
    options.ModelName (1,1) string = ""
    options.Interactions (1,1) logical = false
end

deviceTable = lossData.deviceTable;
if any(deviceTable.Properties.VariableNames == "TurnOn")
    lossMatrix = [deviceTable.Conduction, deviceTable.TurnOn, deviceTable.TurnOff];
    legendText = ["Conduction", "Turn-on", "Turn-off"];
else
    lossMatrix = [deviceTable.Conduction, deviceTable.Switching];
    legendText = ["Conduction", "Switching"];
end
deviceCount = height(deviceTable);

figure('Name', 'Semiconductor Power Loss', 'Position', [400 525 755 429]);
axesHandle = axes;
hold(axesHandle, 'on');
% Limits first, so the bridge bands can be drawn behind the bars.
xlim(axesHandle, [0.5 deviceCount + 0.5]);
yUpper = max([sum(lossMatrix, 2, 'omitnan'); eps]) * 1.22;
ylim(axesHandle, [0 yUpper]);
bridges = unique(deviceTable.Bridge, "stable");
bandColors = [0.94 0.96 1.00; 0.96 0.96 0.96];
for bridgeIndex = 1:numel(bridges)
    inBridge = find(deviceTable.Bridge == bridges(bridgeIndex));
    xStart = min(inBridge) - 0.5;
    xEnd = max(inBridge) + 0.5;
    patch(axesHandle, [xStart xEnd xEnd xStart], [0 0 yUpper yUpper], ...
        bandColors(mod(bridgeIndex - 1, 2) + 1, :), 'EdgeColor', 'none', 'HandleVisibility', 'off');
    text(axesHandle, (xStart + xEnd) / 2, yUpper * 0.96, bridges(bridgeIndex), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', 'FontWeight', 'bold');
end

barHandles = bar(axesHandle, 1:deviceCount, lossMatrix, 'stacked');
ylabel(axesHandle, 'Power (W)');
grid(axesHandle, 'on');
box(axesHandle, 'on');
set(axesHandle, 'XTick', 1:deviceCount, 'XTickLabel', cellstr(deviceTable.Device), ...
    'TickLabelInterpreter', 'none', 'Layer', 'top');
legend(barHandles, cellstr(legendText), 'Location', 'eastoutside');
titleText = "Semiconductor Power Loss by Device";
if strlength(options.ModelName) > 0
    titleText = titleText + " - " + options.ModelName;
end
title(axesHandle, titleText, 'Interpreter', 'none');
hold(axesHandle, 'off');
% A live figure keeps its default interactions active, and without graphics hardware
% they slow the Live Editor, so they are off unless asked for
if ~options.Interactions
    for interactionAxes = axesHandle
        disableDefaultInteractivity(interactionAxes);
        interactionAxes.Toolbar.Visible = 'off';
    end
end
end
