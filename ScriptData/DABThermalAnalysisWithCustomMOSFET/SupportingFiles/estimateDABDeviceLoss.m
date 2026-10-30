function lossData = estimateDABDeviceLoss(thermalResult, options)
%ESTIMATEDABDEVICELOSS Device loss and efficiency of a DAB run with MOSFET Model devices.
%
%   lossData = estimateDABDeviceLoss(thermalResult) reads the conduction, turn-on and
%   turn-off energy each of the eight MOSFET Model blocks logs, and averages each over the
%   last 25 % of the run. The passive loss comes from the Simscape log of every other
%   dissipating element except the load, and the efficiency is the output power over the
%   output power plus all the loss.
%
%   lossData = estimateDABDeviceLoss(thermalResult, Name=Value) sets the averaging window
%   and the loss columns.
%
%   Inputs:
%     thermalResult  Result of simulateDABThermalRise.
%
%   Name-value options:
%     AveragingWindow      Fraction of the run, default [0.75 1], or [tStart tEnd] in s.
%     SwitchingLossDetail  "lumped" for one Switching column, or "separated" for TurnOn
%                          and TurnOff columns. Default "lumped".
%
%   Outputs:
%     lossData  Struct of deviceTable (Device, Bridge, Conduction, Switching or TurnOn and
%               TurnOff, and Total, in W), deviceLoss, passiveLoss, totalLoss and
%               outputPower in W, efficiency in percent, and averagingWindow in s.
%
%   Example:
%     lossData = estimateDABDeviceLoss(thermalResult);
%     plotDABDeviceLoss(lossData);
%
%   See also plotDABDeviceLoss, simulateDABThermalRise.

% Copyright 2026 The MathWorks, Inc.

arguments
    thermalResult (1,1) struct
    options.AveragingWindow (1,2) double = [0.75 1]
    options.SwitchingLossDetail (1,1) string {mustBeMember(options.SwitchingLossDetail, ...
        ["lumped", "separated"])} = "lumped"
end

simulationLog = thermalResult.SimulationLog;
signalLog = thermalResult.SignalLog;
loadSeries = simulationLog.Rload.v.series;
logTime = loadSeries.time;
if all(options.AveragingWindow <= 1)
    window = logTime(1) + options.AveragingWindow * (logTime(end) - logTime(1));
else
    window = options.AveragingWindow;
end
span = diff(window);

deviceNames = ["MOSFETPriA1"; "MOSFETPriA2"; "MOSFETPriB1"; "MOSFETPriB2"; ...
    "MOSFETSecA1"; "MOSFETSecA2"; "MOSFETSecB1"; "MOSFETSecB2"];
bridgeNames = [repmat("Primary bridge", 4, 1); repmat("Secondary bridge", 4, 1)];
energyNames = ["conductionEnergy", "eonEnergyTotal", "eoffEnergyTotal"];
lossValues = zeros(numel(deviceNames), numel(energyNames));
for deviceIndex = 1:numel(deviceNames)
    signals = deviceSignals(signalLog, deviceNames(deviceIndex), energyNames);
    for energyIndex = 1:numel(energyNames)
        lossValues(deviceIndex, energyIndex) = ...
            energyChange(signals.(energyNames(energyIndex)), window) / span;
    end
end

if options.SwitchingLossDetail == "separated"
    deviceTable = table(deviceNames, bridgeNames, lossValues(:, 1), lossValues(:, 2), ...
        lossValues(:, 3), sum(lossValues, 2), VariableNames = ["Device", "Bridge", ...
        "Conduction", "TurnOn", "TurnOff", "Total"]);
else
    deviceTable = table(deviceNames, bridgeNames, lossValues(:, 1), ...
        lossValues(:, 2) + lossValues(:, 3), sum(lossValues, 2), VariableNames = ...
        ["Device", "Bridge", "Conduction", "Switching", "Total"]);
end

% Passive loss: every dissipating Simscape element except the load and the electrical
% blocks inside the MOSFET Model devices, whose loss is the logged device energy above.
powerSummary = ee_getPowerLossSummary(simulationLog, window(1), window(2));
nodeNames = string(powerSummary.LoggingNode);
isLoad = contains(nodeNames, ".Rload");
isDevice = contains(nodeNames, deviceNames');
outputPower = sum(powerSummary.Power(isLoad));
passiveLoss = sum(powerSummary.Power(~isLoad & ~isDevice));

lossData.deviceTable = deviceTable;
lossData.deviceLoss = sum(deviceTable.Total);
lossData.passiveLoss = passiveLoss;
lossData.totalLoss = lossData.deviceLoss + passiveLoss;
lossData.outputPower = outputPower;
lossData.efficiency = 100 * outputPower / (outputPower + lossData.totalLoss);
lossData.averagingWindow = window;
end

function signals = deviceSignals(signalLog, deviceName, energyNames)
% The logged cumulative energies of one device, by logging name.
signals = struct();
for elementIndex = 1:signalLog.numElements
    element = signalLog.getElement(elementIndex);
    if ~any(element.Name == energyNames), continue, end
    blockPath = element.BlockPath;
    pathText = strjoin(string(arrayfun(@(level) blockPath.getBlock(level), ...
        1:blockPath.getLength, UniformOutput = false)), "|");
    if contains(pathText, "/" + deviceName + "/")
        signals.(element.Name) = element.Values;
    end
end
missing = energyNames(~isfield(signals, energyNames));
assert(isempty(missing), "estimateDABDeviceLoss:MissingEnergy", ...
    "Device %s logs no %s. The device needs the MOSFET Model block with energy logging.", ...
    deviceName, strjoin(missing, ", "));
end

function energy = energyChange(energySeries, window)
% Change of a cumulative energy over the window, on de-duplicated time stamps.
[timeVector, uniqueIndex] = unique(energySeries.Time(:), "last");
values = squeeze(energySeries.Data);
values = values(uniqueIndex);
window = [max(window(1), timeVector(1)), min(window(2), timeVector(end))];
energy = interp1(timeVector, values, window(2)) - interp1(timeVector, values, window(1));
end
