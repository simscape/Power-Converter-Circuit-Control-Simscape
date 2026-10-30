function temperatureData = plotDABDeviceTemperature(simulationLog, options)
%PLOTDABDEVICETEMPERATURE Plot the junction temperature of all eight bridge devices.
%
%   plotDABDeviceTemperature(simulationLog) plots the junction temperature of every
%   MOSFET Model block against time in one figure of four rows and two columns: the four
%   primary bridge devices in the left column and the four secondary bridge devices in the
%   right column.
%
%   plotDABDeviceTemperature(simulationLog, Name=Value) adds the ambient temperature as a
%   reference line.
%
%   temperatureData = plotDABDeviceTemperature(...) also returns the plotted traces.
%
%   Inputs:
%     simulationLog  Simscape simulation log of the converter model.
%
%   Name-value options:
%     AmbientTemperature  Ambient temperature drawn as a reference line, simscape.Value.
%                         Default is no reference line.
%     Interactions        Keep the default axes interactions and toolbar. Default false.
%
%   Outputs:
%     temperatureData  1-by-2 struct array returned by getDABDeviceTemperature, primary
%                      bridge first.
%
%   Example:
%     plotDABDeviceTemperature(thermalResult.SimulationLog);
%
%   See also getDABDeviceTemperature, simulateDABThermalRise.

% Copyright 2026 The MathWorks, Inc.

arguments
    simulationLog (1,1) simscape.logging.Node
    options.AmbientTemperature = []
    options.Interactions (1,1) logical = false
end

bridgeSides = ["primary", "secondary"];
temperatureData = [getDABDeviceTemperature(simulationLog, bridgeSides(1)), ...
    getDABDeviceTemperature(simulationLog, bridgeSides(2))];

figure('Name', 'DAB device junction temperature', 'Position', [100 100 640 560]);
layout = tiledlayout(4, 2, TileSpacing = "compact", Padding = "compact");
title(layout, "Device junction temperature")

axesHandles = gobjects(4, 2);
for columnIndex = 1:2
    bridgeData = temperatureData(columnIndex);
    timeMillisecond = bridgeData.Time * 1e3;

    % One column shares one temperature range, so the four devices of a bridge compare
    % directly.
    columnTemperature = [bridgeData.Temperature(:); ambientTemperatureDegC(options)];
    temperatureMargin = 0.05 * max(max(columnTemperature) - min(columnTemperature), 1);
    columnLimits = [min(columnTemperature) - temperatureMargin, ...
        max(columnTemperature) + temperatureMargin];

    for rowIndex = 1:4
        % Tiles fill row by row, so tile 2*row-1 is the left column and 2*row the right.
        axesHandles(rowIndex, columnIndex) = nexttile(layout, 2 * (rowIndex - 1) + columnIndex);
        plot(timeMillisecond, bridgeData.Temperature(:, rowIndex), LineWidth = 1.2)
        if ~isempty(options.AmbientTemperature)
            yline(ambientTemperatureDegC(options), "k--", "Ambient")
        end
        grid on
        ylim(columnLimits)
        xlim([timeMillisecond(1), timeMillisecond(end)])
        title(bridgeData.DeviceNames(rowIndex))
        if columnIndex == 1
            ylabel("Temp (degC)")
        end
        if rowIndex == 4
            xlabel("Time (ms)")
        else
            xticklabels([])
        end
    end
end
linkaxes(axesHandles(:), "x")
% A live figure keeps its default interactions active, and without graphics hardware
% they slow the Live Editor, so they are off unless asked for
if ~options.Interactions
    for interactionAxes = axesHandles(:).'
        disableDefaultInteractivity(interactionAxes);
        interactionAxes.Toolbar.Visible = 'off';
    end
end
end

function temperatureDegC = ambientTemperatureDegC(options)
% Ambient temperature in degC when a reference line was asked for, empty otherwise.
if isempty(options.AmbientTemperature)
    temperatureDegC = [];
else
    temperatureDegC = value(options.AmbientTemperature, "degC");
end
end
