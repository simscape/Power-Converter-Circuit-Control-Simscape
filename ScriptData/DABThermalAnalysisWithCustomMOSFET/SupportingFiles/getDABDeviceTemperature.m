function temperatureData = getDABDeviceTemperature(simulationLog, bridgeSide)
%GETDABDEVICETEMPERATURE Junction temperature history of the four devices on one bridge.
%
%   temperatureData = getDABDeviceTemperature(simulationLog, bridgeSide) reads the
%   junction temperature of each device on the requested bridge, from either the MOSFET
%   Model block or the Simscape MOSFET (Ideal, Switching) block. The result
%   holds the time vector and one temperature trace per device.
%
%   Inputs:
%     simulationLog  Simscape simulation log of the converter model.
%     bridgeSide     "primary" or "secondary".
%
%   Outputs:
%     temperatureData  Struct of BridgeSide, DeviceNames, Time in s and Temperature in
%                      degC, one column per device.
%
%   Example:
%     temperatureData = getDABDeviceTemperature(thermalResult.SimulationLog, "primary");
%
%   See also simulateDABThermalRise, plotDABDeviceTemperature.

% Copyright 2026 The MathWorks, Inc.

arguments
    simulationLog (1,1) simscape.logging.Node
    bridgeSide (1,1) string {mustBeMember(bridgeSide, ["primary", "secondary"])}
end

if bridgeSide == "primary"
    bridgeNode = simulationLog.DAB_Converter.PrimaryBridge;
    deviceNames = ["MOSFETPriA1", "MOSFETPriA2", "MOSFETPriB1", "MOSFETPriB2"];
else
    bridgeNode = simulationLog.DAB_Converter.SecondaryBridge;
    deviceNames = ["MOSFETSecA1", "MOSFETSecA2", "MOSFETSecB1", "MOSFETSecB2"];
end

temperatureData.BridgeSide = bridgeSide;
temperatureData.DeviceNames = deviceNames;

firstSeries = getJunctionSeries(bridgeNode, deviceNames(1));
temperatureData.Time = firstSeries.time;

temperatureTraces = zeros(numel(temperatureData.Time), numel(deviceNames));
for deviceIndex = 1:numel(deviceNames)
    temperatureSeries = getJunctionSeries(bridgeNode, deviceNames(deviceIndex));
    % Every Simscape series carries its own time vector, so a shared time vector is
    % checked rather than assumed.
    assert(numel(temperatureSeries.time) == numel(temperatureData.Time), ...
        "getDABDeviceTemperature:TimeVectorMismatch", ...
        "Device %s is logged on a different time vector.", deviceNames(deviceIndex));
    temperatureTraces(:, deviceIndex) = temperatureSeries.values("degC");
end

temperatureData.Temperature = temperatureTraces;
end

function junctionSeries = getJunctionSeries(bridgeNode, deviceName)
% Junction temperature series of one device on a bridge, from either device model.
deviceNode = bridgeNode.(deviceName);
if any(string(deviceNode.childIds) == "MOSFET_Model")
    % The MOSFET Model block imposes its junction temperature on the thermal network
    % through a controlled temperature source.
    junctionSeries = deviceNode.MOSFET_Model.Thermal_model ...
        .Junction_Heat_Flow.B.T.series;
else
    % The Simscape MOSFET (Ideal, Switching) block logs its junction temperature directly.
    junctionSeries = deviceNode.MOSFET.mosfet_junction_temperature.series;
end
end
