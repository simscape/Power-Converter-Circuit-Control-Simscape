function [gridInverter, sampleTime] = setGFMConverterModelFidelity(options)
% This function sets the model fidelity variant for the GridFormingConverter model.
% You can input the fidelity option for the GFM converter.
% It also set the suitable model sample time.

% Copyright 2026 The MathWorks, Inc.
arguments
    options.Converter {mustBeMember(options.Converter,["Average","Switching"])} ...
        = "Average"; % Converter model variant option
     options.SampleTime {simscape.mustBeCommensurateUnit(options.SampleTime,"s") } ...
        = simscape.Value(1e-4,"s"); % Sample time for average converter and simplified generator fidelity
end
modelName = "GridFormingConverter"; % GFM model
load_system(modelName); % Load the model

% Generator subsystem path
gfmConverterBlockLoc = strcat(modelName,"/Grid-Forming Converter/Grid-Forming Converter Power Circuit");

% Run the input parameters
GridFormingConverterInputParameters;

switch options.Converter
    case "Average"
        set_param(gfmConverterBlockLoc, 'LabelModeActiveChoice', 'Average'); % Average GFM converter        
        sampleTime = options.SampleTime.value;
    case "Switching"
        set_param(gfmConverterBlockLoc, 'LabelModeActiveChoice', 'Switching'); % Average GFM converter
        % Set the gfm converter variant
        sampleTime=min(1/(10*gridInverter.switchingFrequency),1e-5); %#ok<*NODEF>
        gridInverter.vsm.samplingTime = sampleTime;
        gridInverter.measurementSampleTime =sampleTime;
        gridInverter.droopControl.sampleTime =sampleTime;
        gridInverter.controller.VoltageControlSampleTime=sampleTime;
        gridInverter.controller.CurrentControlSampleTime=sampleTime;
    otherwise
        error("Invalid value for Converter name-value argument. " + ...
            "Specify the argument value as Average or Switching");
end
end
