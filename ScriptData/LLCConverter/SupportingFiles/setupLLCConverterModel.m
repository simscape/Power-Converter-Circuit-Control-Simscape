function simIn = setupLLCConverterModel(ModelName,options)
% This script initializes the simulation environment for the LLC converter design.
% It configures the MOSFET and diode components, sets the simulation time,
% specifies the output voltage reference, and defines the load condition.
%
% To use this script, provide:
%   - modelName:    Simulink model name to update.
%   - MOSFETModel:  Desired MOSFET component model.
%   - DiodeModel:   Desired diode component model.
%   - Vref:         Reference voltage
%   - Vin:          Input voltage
%   - Pload:        Output voltage
%   - SimTime:      Simulation time
%
% The script ensures all required parameters are set before running simulations or analyses.

% Copyright 2025-2026 The MathWorks, Inc.
arguments
    ModelName char
    options.MOSFETModel (1,:) char {mustBeMember(options.MOSFETModel,{'Ideal Semiconductor Switch', 'MOSFET (Ideal, Switching) without Thermal','MOSFET (Ideal, Switching) with Thermal'})} = 'MOSFET (Ideal, Switching) without Thermal';
    options.DiodeModel (1,:) char {mustBeMember(options.DiodeModel,{'Ideal Diode','Tabulated Diode'})} = 'Ideal Diode';
    options.Vref (1,1)  = simscape.Value(320,"V"); % Reference voltage
    options.Vin (1,1)  = simscape.Value(380,"V"); % Input voltage
    options.Pload (1,1)  = simscape.Value(5000,"W"); % Output power
    options.SimTime (1,1) = simscape.Value(0.01,"s"); % Simulation time
end
load_system(ModelName);

% This code works for both masked LLC power circuit library block and the
% unmasked subsystem in the "LLCResonantConverterFullBridge" model

topLevelBlocks = find_system(ModelName, 'SearchDepth', 1, 'Type', 'block');
llcPowerCircuit = topLevelBlocks(contains(topLevelBlocks,"LLC Converter Power Circuit"));
if isempty(llcPowerCircuit)
    error("Subsystem LLC Converter Power Circuit does not exist in the model");
end
maskObj = Simulink.Mask.get(llcPowerCircuit{1});
numMaskParam = length(maskObj.Parameters);

% Convert to base units for calculations
Vref_V = convert(options.Vref, "V");
Vin_V  = convert(options.Vin, "V");
Pload_W = convert(options.Pload, "W");
simTime_s = convert(options.SimTime, "s");

% Create simulation input object
simIn = Simulink.SimulationInput(ModelName);
simIn = setBlockParameter(simIn,strcat(ModelName, "/Vref"),...
    "Value",num2str(Vref_V.value));
simIn = setBlockParameter(simIn,strcat(ModelName, "/Vin"),...
    "dc_voltage",num2str(Vin_V.value));

% Estimate the output load resistance
Rload = Vref_V.value^2/Pload_W.value;
simIn = setBlockParameter(simIn,strcat(ModelName, "/Rload"),...
    "R",num2str(Rload));

simIn = setModelParameter(simIn,"StopTime",string(simTime_s.value)); % Simulation time [s]

% Set the proper fidelity
if numMaskParam==0
    if strcmp(options.MOSFETModel,'Ideal Semiconductor Switch')
        error("Ideal semiconductor switch model option available only in LLC Power Circuit Masked Libary Block");
    end
setPrimaryMOSFET(llcPowerCircuit{1},DeviceOption=options.MOSFETModel);
setSecondaryDiode(llcPowerCircuit{1},DeviceOption=options.DiodeModel);
else
    set_param(llcPowerCircuit{1},"primaryDeviceOption",options.MOSFETModel);
    set_param(llcPowerCircuit{1},"secondaryDeviceOption",options.DiodeModel);
end
end
