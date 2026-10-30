function simIn = setupCLLCConverterModel(ModelName, options)
%SETUPCLLCCONVERTERMODEL Configure the CLLC converter model for a simulation run.
%   simIn = SETUPCLLCCONVERTERMODEL(ModelName) returns a Simulink.SimulationInput
%   that sets the CLLC converter model's operating point, its control mode and its
%   plant fidelity, without modifying the saved model.
%
%   The plant is the masked ConverterLibrary "CLLC Converter Power Circuit" block, so
%   fidelity is selected through its mask popups:
%     modelOption            : 'Simplified' | 'Detailed'
%     PrimaryDeviceOption    : 'Ideal Switch' | 'MOSFET (Ideal, Switching) with Thermal'
%     SecondaryDeviceOption  : 'Ideal Switch' | 'MOSFET (Ideal, Switching) with Thermal'
%   The device popups apply to the Detailed model option only; the Simplified choice
%   is an averaged power stage with no switching devices.
%
%   The operating point is applied to the harness blocks:
%     Vin        DC voltage source - primary-side input voltage
%     Reference  Constant feeding the controller's Ref port
%     Constant1  Constant feeding the controller's CCCV port (1 = CC, 0 = CV)
%     Constant   Constant feeding the controller's mode port (1 = forward power flow)
%     Rload      load resistor, sized as Vref^2 / Pload
%
%   This function puts the
%   controller in constant-voltage mode (CCCV = 0) and selects forward power flow
%   (mode = 1). The saved model is in CC mode, which reads Vref as a
%   current setpoint. For current control, reverse power flow, or loss analysis, use
%   the converter-agnostic utilities in PowerConverterUtilities:
%     getConverterWaveforms(ModelName, Converter="CLLC", ...)
%     getConverterPowerLoss(ModelName, Converter="CLLC", ...)
%
%   Inputs (name-value):
%     PrimaryMOSFETModel    primary bridge device option (see strings above)
%     SecondaryMOSFETModel  secondary bridge device option (see strings above)
%     ModelOption           plant model fidelity, 'Simplified' or 'Detailed'
%     Vref                  output voltage reference (simscape.Value)
%     Vin                   input DC voltage (simscape.Value)
%     Pload                 output load power (simscape.Value)
%     SimTime               simulation stop time (simscape.Value)
%
%   Output:
%     simIn                 Simulink.SimulationInput configured for the run.
%
%   See also getConverterPowerLoss, getConverterWaveforms, openCLLCDeviceModel.

% Copyright 2025-2026 The MathWorks, Inc.

arguments
    ModelName char
    options.PrimaryMOSFETModel (1,:) char ...
        {mustBeMember(options.PrimaryMOSFETModel, ...
        {'Ideal Switch','MOSFET (Ideal, Switching) with Thermal'})} = 'Ideal Switch';
    options.SecondaryMOSFETModel (1,:) char ...
        {mustBeMember(options.SecondaryMOSFETModel, ...
        {'Ideal Switch','MOSFET (Ideal, Switching) with Thermal'})} = 'Ideal Switch';
    options.ModelOption (1,:) char ...
        {mustBeMember(options.ModelOption, {'Simplified','Detailed'})} = 'Detailed';
    options.Vref (1,1)  = simscape.Value(320,"V");    % Output voltage reference
    options.Vin (1,1)  = simscape.Value(380,"V");     % Input DC voltage
    options.Pload (1,1)  = simscape.Value(5000,"W");  % Output power
    options.SimTime (1,1) = simscape.Value(0.01,"s"); % Simulation time
end
load_system(ModelName);

% Locate the plant by name.
topLevelBlocks = find_system(ModelName, 'SearchDepth', 1, 'Type', 'block');
cllcPowerCircuit = topLevelBlocks(contains(topLevelBlocks, "CLLC Converter Power Circuit"));
if isempty(cllcPowerCircuit)
    error("setupCLLCConverterModel:plantNotFound", ...
        "Block 'CLLC Converter Power Circuit' does not exist in model '%s'.", ModelName);
end
cllcPowerCircuit = cllcPowerCircuit{1};

% Convert the operating point to base SI units for the calculations below.
referenceVoltage_V = convert(options.Vref, "V");
inputVoltage_V     = convert(options.Vin, "V");
loadPower_W        = convert(options.Pload, "W");
simulationTime_s   = convert(options.SimTime, "s");

% Everything is applied through the SimulationInput, so the saved model is untouched.
simIn = Simulink.SimulationInput(ModelName);
simIn = setModelParameter(simIn, "StopTime", string(simulationTime_s.value));

% Operating point on the harness blocks.
simIn = setBlockParameter(simIn, strcat(ModelName, "/Vin"), ...
    "dc_voltage", num2str(inputVoltage_V.value));
simIn = setBlockParameter(simIn, strcat(ModelName, "/Reference"), ...
    "Value", num2str(referenceVoltage_V.value));

% Output load resistance for the requested power at the regulated output voltage.
loadResistance_Ohm = referenceVoltage_V.value^2 / loadPower_W.value;
simIn = setBlockParameter(simIn, strcat(ModelName, "/Rload"), ...
    "R", num2str(loadResistance_Ohm));

% Control mode: constant voltage, forward power flow. The reference supplied here is
% a voltage, and the saved model is in
% constant-current mode.
simIn = setBlockParameter(simIn, strcat(ModelName, "/Constant1"), "Value", "0");
simIn = setBlockParameter(simIn, strcat(ModelName, "/Constant"),  "Value", "1");

% Plant fidelity, through the library block's mask popups.
simIn = setBlockParameter(simIn, cllcPowerCircuit, "modelOption", options.ModelOption);
simIn = setBlockParameter(simIn, cllcPowerCircuit, ...
    "PrimaryDeviceOption", options.PrimaryMOSFETModel);
simIn = setBlockParameter(simIn, cllcPowerCircuit, ...
    "SecondaryDeviceOption", options.SecondaryMOSFETModel);
end
