function comparison = compareBuckDeviceModels(deviceKind, testFolder)
%COMPAREBUCKDEVICEMODELS Simulate a device's two buck test models and compare their loss.
%
%   comparison = test.compareBuckDeviceModels(deviceKind, testFolder) simulates
%   <Device>BuckSimulinkDevice (the ConverterLibrary device block) and
%   <Device>BuckSimscapeDevice (the Simscape device with a thermal port) from testFolder,
%   and averages every loss term over the last 40 % of the run.
%
%   Inputs:
%     deviceKind  "MOSFET", "IGBT" or "Diode".
%     testFolder  Folder holding the two models.
%
%   Outputs:
%     comparison  Struct of DeviceKind, Window in s, Terms (table of Term, Simulink and
%                 Simscape loss in W), TotalSimulink and TotalSimscape in W, RiseSimulink and
%                 RiseSimscape (junction temperature rise at the end of the run, K),
%                 ComputedEnergy and InjectedEnergy (J, the Simulink device's computed loss
%                 energy and the heat its junction received), and SimulationTime (s, Simulink
%                 then Simscape).
%
%   See also test.assertBuckTotalLoss, test.assertBuckLossTerms,
%   test.assertBuckJunctionRise, test.assertBuckEnergyBalance.

% Copyright 2026 The MathWorks, Inc.

arguments
    deviceKind (1,1) string {mustBeMember(deviceKind, ["MOSFET", "IGBT", "Diode"])}
    testFolder (1,1) string {mustBeFolder}
end

models = deviceKind + "Buck" + ["Simulink", "Simscape"] + "Device";
outputs = cell(1, 2);
simulationTime = zeros(1, 2);
for modelIndex = 1:2
    load_system(fullfile(testFolder, models(modelIndex) + ".slx"));
    simulationInput = Simulink.SimulationInput(models(modelIndex));
    simulationInput = setModelParameter(simulationInput, "SimscapeLogType", "all", ...
        "SimscapeLogLimitData", "off", "SignalLogging", "on", "SignalLoggingName", "logsout");
    startTime = tic;
    outputs{modelIndex} = sim(simulationInput);
    simulationTime(modelIndex) = toc(startTime);
end

% Simscape logs a block name with its spaces replaced by underscores.
deviceNode = replace(deviceKind + " Under Test", " ", "_");
simulinkLog = outputs{1}.simlog.(deviceNode);
simscapeLog = outputs{2}.simlog.(deviceNode);
temperatureSeries = simulinkLog.Thermal_model.Junction_Thermal_Mass.T.series;
temperatureTime = temperatureSeries.time;
stopTime = temperatureTime(end);
window = stopTime * [0.6 1];

% Simulink device: every term from its logged cumulative energy.
signals = outputs{1}.logsout;
rate = @(name) energyChange(signals.get(name).Values.Time, ...
    squeeze(signals.get(name).Values.Data), window) / diff(window);
if deviceKind == "Diode"
    termNames = ["Conduction"; "Recovery"];
    simulinkTerms = [rate("conductionEnergy"); rate("erecEnergyTotal")];
else
    termNames = ["Conduction"; "TurnOn"; "TurnOff"];
    simulinkTerms = [rate("conductionEnergy"); rate("eonEnergyTotal"); rate("eoffEnergyTotal")];
end
simulinkTotal = rate("totalEnergy");

% Simscape device: conduction from its dissipated power, switching from its event energies.
switch deviceKind
    case "MOSFET"
        conduction = averagePower(simscapeLog.power_dissipated.series, window) + ...
            averagePower(simscapeLog.diode.Diode.power_dissipated.series, window);
        simscapeTerms = [conduction; eventPower(simscapeLog.lastTurnOnLoss.series, window); ...
            eventPower(simscapeLog.lastTurnOffLoss.series, window)];
        simscapeTemperature = simscapeLog.mosfet_junction_temperature.series;
    case "IGBT"
        simscapeTerms = [averagePower(simscapeLog.power_dissipated.series, window); ...
            eventPower(simscapeLog.lastTurnOnLoss.series, window); ...
            eventPower(simscapeLog.lastTurnOffLoss.series, window)];
        simscapeTemperature = simscapeLog.IGBT_junction_temperature.series;
    case "Diode"
        % From R2026b the diode logs no conduction power, so it is the product of the inner
        % diode's current and voltage, and the recovery energy is under reverseRecoveryLoss.
        if any(string(simscapeLog.childIds) == "reverseRecoveryLoss")
            recovery = simscapeLog.reverseRecoveryLoss.accumulatedReverseRecoveryLoss.series;
            conduction = averageProductPower(simscapeLog.diode.i.series, ...
                simscapeLog.diode.v.series, window);
        else
            recovery = simscapeLog.accumulatedReverseRecoveryLoss.series;
            conduction = averagePower(simscapeLog.Diode.power_dissipated.series, window);
        end
        simscapeTerms = [conduction; ...
            energyChange(recovery.time, recovery.values("J"), window) / diff(window)];
        simscapeTemperature = simscapeLog.junction_temperature.series;
end

comparison.DeviceKind = deviceKind;
comparison.Window = window;
comparison.Terms = table(termNames, simulinkTerms, simscapeTerms, ...
    VariableNames = ["Term", "Simulink", "Simscape"]);
comparison.TotalSimulink = simulinkTotal;
comparison.TotalSimscape = sum(simscapeTerms);
simulinkTemperature = temperatureSeries.values("degC");
simscapeTemperatureValues = simscapeTemperature.values("degC");
comparison.RiseSimulink = simulinkTemperature(end) - simulinkTemperature(1);
comparison.RiseSimscape = simscapeTemperatureValues(end) - simscapeTemperatureValues(1);

% Energy balance of the Simulink device: the heat its junction received against the
% energy it computed. The heat is injected one thermal sample late, so the computed energy
% is read one sample before the end, interpolated linearly because the energy log is
% decimated.
heatSeries = simulinkLog.Thermal_model.Junction_Heat_Flow.Q.series;
heatTime = heatSeries.time;
heatValues = heatSeries.values("W");
% The heat flow is piecewise constant per thermal sample, and the variable-step solver lands
% on every sample time, where the log already holds the new value. Each interval therefore
% takes the value at its start.
comparison.InjectedEnergy = sum(heatValues(1:end-1) .* diff(heatTime));
totalSignal = signals.get("totalEnergy").Values;
thermalSampleTime = 1e-5;
comparison.ComputedEnergy = interp1(totalSignal.Time, squeeze(totalSignal.Data), ...
    floor(heatTime(end) / thermalSampleTime) * thermalSampleTime - thermalSampleTime, "linear");
comparison.SimulationTime = simulationTime;
end

function power = averagePower(series, window)
% Time-weighted average over the window.
timeVector = series.time;
values = series.values("W");
inWindow = timeVector >= window(1) & timeVector <= window(2);
power = trapz(timeVector(inWindow), values(inWindow)) / diff(window);
end

function power = averageProductPower(currentSeries, voltageSeries, window)
% Time-weighted average of current times voltage over the window. Both come from one log
% node, so they share their time vector.
timeVector = currentSeries.time;
values = currentSeries.values("A") .* voltageSeries.values("V");
inWindow = timeVector >= window(1) & timeVector <= window(2);
power = trapz(timeVector(inWindow), values(inWindow)) / diff(window);
end
function power = eventPower(series, window)
% A Simscape last-event energy steps up from zero at each event; sum those steps.
timeVector = series.time;
values = series.values("J");
isEvent = [false; values(2:end) > 0 & values(2:end) ~= values(1:end-1)];
inWindow = timeVector > window(1) & timeVector <= window(2);
power = sum(values(isEvent & inWindow)) / diff(window);
end

function energy = energyChange(timeVector, values, window)
% Change of a cumulative energy over the window, on de-duplicated time stamps.
[timeVector, uniqueIndex] = unique(timeVector(:), "last");
values = values(:);
values = values(uniqueIndex);
window = [max(window(1), timeVector(1)), min(window(2), timeVector(end))];
energy = interp1(timeVector, values, window(2)) - interp1(timeVector, values, window(1));
end
