function powerFlowTable = displayDABPowerFlow(thermalResult, options)
%DISPLAYDABPOWERFLOW Power flow summary of a DAB run with MOSFET Model devices.
%
%   powerFlowTable = displayDABPowerFlow(thermalResult) returns the output voltage, the
%   input and the output power, the device loss of each bridge, the passive component loss
%   and the efficiency of the run, averaged over the last 25 % of the run.
%
%   powerFlowTable = displayDABPowerFlow(thermalResult, DisplayTableFlag=true) also
%   displays the table.
%
%   Inputs:
%     thermalResult  Result of simulateDABThermalRise.
%
%   Name-value options:
%     DisplayTableFlag  Display the table. Default false.
%
%   Outputs:
%     powerFlowTable  Table of Parameter, Value and Unit.
%
%   Example:
%     powerFlowTable = displayDABPowerFlow(thermalResult, DisplayTableFlag = true);
%
%   See also simulateDABThermalRise, estimateDABDeviceLoss.

% Copyright 2026 The MathWorks, Inc.

arguments
    thermalResult (1,1) struct
    options.DisplayTableFlag (1,1) logical = false
end

lossData = estimateDABDeviceLoss(thermalResult);
deviceTable = lossData.deviceTable;
primaryBridgeLoss = sum(deviceTable.Total(deviceTable.Bridge == "Primary bridge"));
secondaryBridgeLoss = sum(deviceTable.Total(deviceTable.Bridge == "Secondary bridge"));

parameterName = { ...
    'Output voltage'; ...
    'Input power'; ...
    'Output power'; ...
    'Primary bridge device loss'; ...
    'Secondary bridge device loss'; ...
    'Passive component loss'; ...
    'Efficiency'};
tableValue = [ ...
    value(thermalResult.OutputVoltage, "V"); ...
    lossData.outputPower + lossData.totalLoss; ...
    lossData.outputPower; ...
    primaryBridgeLoss; ...
    secondaryBridgeLoss; ...
    lossData.passiveLoss; ...
    lossData.efficiency];
tableUnit = {'V'; 'W'; 'W'; 'W'; 'W'; 'W'; '%'};

powerFlowTable = table(char(parameterName), round(tableValue, 4, "significant"), ...
    char(tableUnit), 'VariableNames', {'Parameter', 'Value', 'Unit'});

if options.DisplayTableFlag
    disp(table(powerFlowTable, 'VariableNames', "DAB Power Flow"));
end
end
