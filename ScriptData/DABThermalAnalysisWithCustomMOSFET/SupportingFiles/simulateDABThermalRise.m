function thermalResult = simulateDABThermalRise(modelName, options)
%SIMULATEDABTHERMALRISE Simulate a dual active bridge converter and log its temperatures.
%
%   thermalResult = simulateDABThermalRise(modelName) applies the default operating point
%   to the converter model and simulates it with Simscape and signal logging on. The
%   result holds both logs and the load resistance the operating point implies.
%
%   thermalResult = simulateDABThermalRise(modelName, Name=Value) sets the operating point
%   and the simulated time span.
%
%   Inputs:
%     modelName  Converter model name.
%
%   Name-value options:
%     Vin                 DC input voltage, simscape.Value or numeric volts.
%     Vref                Output-voltage setpoint, simscape.Value or numeric volts.
%     Pload               Delivered output power, simscape.Value or numeric watts.
%     AmbientTemperature  Ambient temperature, simscape.Value or numeric degC.
%     SimTime             Simulated time span, simscape.Value or numeric seconds.
%     HeatsinkTemperature Starting temperature of the primary and the secondary heatsink,
%                         a 1-by-2 simscape.Value. The devices on each bridge start at
%                         their heatsink's temperature. Default: the initial
%                         temperatures in the input parameters.
%
%   Outputs:
%     thermalResult  Struct of Model, SimulationLog, SignalLog, ElapsedSeconds,
%                    SolverSteps, LoadResistance and OutputVoltage.
%
%   Example:
%     DABThermalAnalysisWithCustomMOSFETInputParameters;
%     thermalResult = simulateDABThermalRise("DABThermalAnalysisWithCustomMOSFET", ...
%         Vin = simscape.Value(750, "V"), Pload = simscape.Value(10000, "W"));
%
%   See also estimateDABDeviceLoss, displayDABPowerFlow,
%   plotDABDeviceTemperature.

% Copyright 2026 The MathWorks, Inc.

arguments
    modelName (1,1) string
    options.Vin = simscape.Value(750, "V")
    options.Vref = simscape.Value(525, "V")
    options.Pload = simscape.Value(10000, "W")
    options.AmbientTemperature = simscape.Value(25, "degC")
    options.SimTime = simscape.Value(15e-3, "s")
    options.HeatsinkTemperature = []
end

if ~bdIsLoaded(modelName)
    load_system(modelName);
end

inputVoltageVolt = numericValueIn(options.Vin, "V");
outputVoltageVolt = numericValueIn(options.Vref, "V");
loadPowerWatt = numericValueIn(options.Pload, "W");
ambientTemperatureKelvin = numericValueIn(options.AmbientTemperature, "K");
stopTimeSecond = numericValueIn(options.SimTime, "s");
if ~isempty(options.HeatsinkTemperature)
    heatsinkKelvin = numericValueIn(options.HeatsinkTemperature, "K");
    assert(numel(heatsinkKelvin) == 2, "simulateDABThermalRise:HeatsinkTemperature", ...
        "HeatsinkTemperature holds the primary and the secondary heatsink temperature.");
end

% The load is specified as delivered power, so the resistance that draws it at the
% requested output voltage is what the model needs.
loadResistanceOhm = outputVoltageVolt^2 / loadPowerWatt;

% Every operating point value is applied to the simulation rather than to the saved
% model, so the saved model is unchanged.
simulationInput = Simulink.SimulationInput(modelName);
simulationInput = setBlockParameter(simulationInput, modelName + "/Vin", ...
    "dc_voltage", num2str(inputVoltageVolt, "%.12g"));
simulationInput = setBlockParameter(simulationInput, modelName + "/Vref", ...
    "Value", num2str(outputVoltageVolt, "%.12g"));
simulationInput = setBlockParameter(simulationInput, modelName + "/Rload", ...
    "R", num2str(loadResistanceOhm, "%.12g"));
simulationInput = setBlockParameter(simulationInput, modelName + "/Temperature Source", ...
    "temperature", num2str(ambientTemperatureKelvin, "%.12g"));

% Each heatsink starts at its requested temperature, and the devices on its bridge start
% at the same temperature through a copy of the device data used for this run only. With no
% request, the model's own initial temperatures from the input parameters apply.
if ~isempty(options.HeatsinkTemperature)
    simulationInput = setBlockParameter(simulationInput, modelName + "/Heatsink", ...
        "T_hs", num2str(heatsinkKelvin(1), "%.12g"), modelName + "/Heatsink", "T_hs_unit", "K");
    simulationInput = setBlockParameter(simulationInput, modelName + "/Heatsink1", ...
        "T_hs", num2str(heatsinkKelvin(2), "%.12g"), modelName + "/Heatsink1", "T_hs_unit", "K");
    deviceData = evalin("base", "DAB");
    deviceData.simTempPri = heatsinkKelvin(1) - 273.15;
    deviceData.simTempSec = heatsinkKelvin(2) - 273.15;
    simulationInput = setVariable(simulationInput, "DAB", deviceData);
end

% Starting the output capacitor at the requested output voltage keeps the run clear of
% a charging transient that has nothing to do with device heating.
simulationInput = setBlockParameter(simulationInput, modelName + "/DAB Converter/Co", ...
    "vc", num2str(outputVoltageVolt, "%.12g"));

simulationInput = setModelParameter(simulationInput, "StopTime", ...
    num2str(stopTimeSecond, "%.12g"));

% One output sample per solver step, so numel(tout) is the solver step count.
simulationInput = setModelParameter(simulationInput, "SaveTime", "on");
simulationInput = setModelParameter(simulationInput, "OutputOption", "RefineOutputTimes");
simulationInput = setModelParameter(simulationInput, "Refine", "1");

simulationInput = setModelParameter(simulationInput, "SimscapeLogType", "all");
simulationInput = setModelParameter(simulationInput, "SimscapeLogName", "simlogDABThermal");
simulationInput = setModelParameter(simulationInput, "SimscapeLogLimitData", "off");

% The MOSFET Model blocks log their cumulative conduction and switching energy as signals.
simulationInput = setModelParameter(simulationInput, "SignalLogging", "on", ...
    "SignalLoggingName", "logsout");

startTime = tic;
simulationOutput = sim(simulationInput);
elapsedSeconds = toc(startTime);

outputVoltageTrace = simulationOutput.simlogDABThermal.Rload.v.series.values("V");

thermalResult.Model = modelName;
thermalResult.SimulationLog = simulationOutput.simlogDABThermal;
thermalResult.SignalLog = simulationOutput.logsout;
thermalResult.ElapsedSeconds = elapsedSeconds;
thermalResult.SolverSteps = numel(simulationOutput.tout);
thermalResult.LoadResistance = simscape.Value(loadResistanceOhm, "Ohm");
thermalResult.OutputVoltage = simscape.Value(outputVoltageTrace(end), "V");
end

function numericValue = numericValueIn(quantity, unitText)
% Accept either a simscape.Value or a plain number already in the expected unit.
if isa(quantity, "simscape.Value")
    numericValue = value(quantity, unitText);
else
    numericValue = quantity;
end
end
