function selectCLLCControllerDomain(blockPath)
%   selectCLLCControllerDomain(blockPath) selects the voltage controller variant of the
%   CLLC controller Simulink block and sets the visibility of the two loop sample times,
%   from the time domain chosen on the mask.
%
%   Input Arguments:
%   ----------------
%   blockPath : char
%       Character vector specifying the path to the CLLC controller Simulink block.
%
%   Description:
%   ------------
%   This function reads the 'controllerDomain' mask parameter and points the 'Voltage PI'
%   variant subsystem inside the voltage controller at the matching choice:
%       - 'Continuous' selects the 'PIContinuous' choice and hides 'TsVoltage' and
%         'TsCurrent'.
%       - 'Discrete' selects the 'PIDiscrete' choice and shows 'TsVoltage' and 'TsCurrent'.
%   Each loop has its own rate: 'TsVoltage' runs the outer voltage controller and the block
%   that gates it, and 'TsCurrent' runs the current controller, whether that is the
%   compensator or the PI form. Both rates belong to the time domain rather than to one
%   control loop's form, so this function owns both visibilities.
%
%   Example:
%   --------
%       selectCLLCControllerDomain('myModel/CLLCController');
%
%   See also: selectCLLCMaskController, setControllerVariantActiveChoice,
%   setVisibilityForMaskParameter

% Copyright 2026 The MathWorks, Inc.

domainChoice = get_param(blockPath, 'controllerDomain');

% The action subsystem holding the voltage loop carries a line break in its name, so the
% path is built with sprintf rather than written out.
voltageLoopPath = sprintf('%s/Voltage Controller/If Action\nSubsystem1/Voltage PI', blockPath);

% One rate per control loop, each shown in its own group on the dialog box.
loopSampleTimes = {'TsVoltage', 'TsCurrent'};

switch domainChoice
    case 'Continuous'
        setControllerVariantActiveChoice(voltageLoopPath, 'PIContinuous');
        setVisibilityForMaskParameter(BlockPath=blockPath, ParameterVec=loopSampleTimes, ...
            Visibility='off');
    case 'Discrete'
        setControllerVariantActiveChoice(voltageLoopPath, 'PIDiscrete');
        setVisibilityForMaskParameter(BlockPath=blockPath, ParameterVec=loopSampleTimes, ...
            Visibility='on');
    otherwise
        error('converterController:unknownControllerDomain', ...
            'Controller time domain "%s" is not one of Continuous or Discrete.', domainChoice);
end

end
