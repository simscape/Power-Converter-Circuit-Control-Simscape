function simIn = setupLLCLibraryConverterModel(ModelName, options)
%SETUPLLCLIBRARYCONVERTERMODEL Configure the library-plant LLC model for simulation.
%   Companion to setupLLCConverterModel, but targets the
%   "LLCResonantConverterFullBridge" model whose plant is the masked
%   ConverterLibrary "LLC Converter" block (with the full mask/variant interface),
%   rather than the original unmasked reference-subsystem plant (which is kept as
%   "LLCResonantConverterFullBridgeOld").
%
%   The device-fidelity option STRINGS differ from the original plant:
%     - primaryDeviceOption   : 'Ideal Semiconductor Switch' | 'MOSFET (Ideal, Switching) with Thermal'
%     - secondaryDeviceOption : 'Ideal Diode' | 'Tabulated Diode'
%   (The original model additionally offered 'MOSFET (Ideal, Switching) without
%   Thermal'; the library block does not expose that choice, so it is not accepted.)
%
%   Inputs (name-value):
%     MOSFETModel  primary switch device option (see valid strings above)
%     DiodeModel   secondary rectifier diode option
%     Vref         reference output voltage (simscape.Value)
%     Vin          input DC voltage (simscape.Value)
%     Pload        output load power (simscape.Value)
%     SimTime      simulation stop time (simscape.Value)
%
%   Output:
%     simIn        Simulink.SimulationInput configured for the run.

% Copyright 2026 The MathWorks, Inc.

arguments
    ModelName char
    options.MOSFETModel (1,:) char ...
        {mustBeMember(options.MOSFETModel, ...
        {'Ideal Semiconductor Switch','MOSFET (Ideal, Switching) with Thermal'})} = 'Ideal Semiconductor Switch';
    options.DiodeModel (1,:) char ...
        {mustBeMember(options.DiodeModel, {'Ideal Diode','Tabulated Diode'})} = 'Ideal Diode';
    options.Vref (1,1)    = simscape.Value(360,"V");
    options.Vin  (1,1)    = simscape.Value(380,"V");
    options.Pload (1,1)   = simscape.Value(7000,"W");
    options.SimTime (1,1) = simscape.Value(0.015,"s");
end
load_system(ModelName);

% Locate the plant subsystem (the masked library block).
topLevelBlocks = find_system(ModelName,'SearchDepth',1,'Type','block');
plant = topLevelBlocks(contains(topLevelBlocks,"LLC Converter Power Circuit"));
if isempty(plant)
    error("Subsystem 'LLC Converter Power Circuit' does not exist in the model.");
end
plant = plant{1};

% Convert operating point to base SI.
Vref_V  = convert(options.Vref, "V");
Vin_V   = convert(options.Vin, "V");
Pload_W = convert(options.Pload, "W");
simTime_s = convert(options.SimTime, "s");

% Build the simulation input: operating point on the harness blocks + device fidelity on the mask.
simIn = Simulink.SimulationInput(ModelName);
simIn = setBlockParameter(simIn, ModelName + "/Vref",  "Value",      num2str(Vref_V.value));
simIn = setBlockParameter(simIn, ModelName + "/Vin",   "dc_voltage", num2str(Vin_V.value));
Rload = Vref_V.value^2 / Pload_W.value;                       % output load resistance
simIn = setBlockParameter(simIn, ModelName + "/Rload", "R",          num2str(Rload));
simIn = setModelParameter(simIn, "StopTime", string(simTime_s.value));

% Device fidelity via the library block's mask popups.
simIn = setBlockParameter(simIn, plant, "primaryDeviceOption",   options.MOSFETModel);
simIn = setBlockParameter(simIn, plant, "secondaryDeviceOption", options.DiodeModel);
end
