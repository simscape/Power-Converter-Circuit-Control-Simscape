function selectCLLCMaskController(blockPath)
%   selectCLLCMaskController(blockPath) sets the visibility of mask parameters and
%   selects the appropriate variant for the 2P2Z Compensator block within the specified
%   CLLC controller Simulink block, based on the selected controller type.
%
%   Input Arguments:
%   ----------------
%   blockPath : char
%       Character vector specifying the path to the CLLC controller Simulink block.
%
%   Description:
%   ------------
%   This function adjusts the mask parameter visibility and the active variant for the
%   '2P2Z Compensator' block inside the CLLC controller block from two mask parameters,
%   'cntrlSelect' and 'controllerDomain'. The compensator form comes from 'cntrlSelect'
%   and the time domain from 'controllerDomain':
%       - '2P2Z compensator' with 'Continuous' shows Kc and the S-domain coefficients.
%       - '2P2Z compensator' with 'Discrete' shows Kc and the Z-domain coefficients.
%       - 'PI controller' with either domain shows Kp and Ki.
%   All other parameters are hidden. 'TsCurrent' is the rate of
%   whichever form is selected, so it belongs to the time domain rather than to the form, and
%   selectCLLCControllerDomain owns its visibility.
%
%   Example:
%   --------
%       selectCLLCMaskController('myModel/CLLCController');
%
%   See also: selectCLLCControllerDomain, setControllerVariantActiveChoice,
%   setVisibilityForMaskParameter

% Copyright 2025-2026 The MathWorks, Inc.

currentControllerChoice = get_param(blockPath, 'cntrlSelect');
domainChoice = get_param(blockPath, 'controllerDomain');
isDiscrete = strcmp(domainChoice, 'Discrete');
compensatorLoc = [blockPath, '/2P2Z Compensator'];

switch currentControllerChoice
    case '2P2Z compensator'
        if isDiscrete
            setControllerVariantActiveChoice(compensatorLoc, 'ZCompensator');
            visibleParameters = {'Kc', 'numZdomain', 'denZdomain'};
            hiddenParameters = {'numSdomain', 'denSdomain', 'Kp', 'Ki'};
        else
            setControllerVariantActiveChoice(compensatorLoc, 'SCompensator');
            visibleParameters = {'Kc', 'numSdomain', 'denSdomain'};
            hiddenParameters = {'numZdomain', 'denZdomain', 'Kp', 'Ki'};
        end
    case 'PI controller'
        if isDiscrete
            setControllerVariantActiveChoice(compensatorLoc, 'PIDiscrete');
        else
            setControllerVariantActiveChoice(compensatorLoc, 'PIContinuous');
        end
        visibleParameters = {'Kp', 'Ki'};
        hiddenParameters = {'Kc', 'numSdomain', 'denSdomain', 'numZdomain', 'denZdomain'};
    otherwise
        error('converterController:unknownCLLCCurrentController', ...
            'Current controller "%s" is not one of 2P2Z compensator or PI controller.', ...
            currentControllerChoice);
end

setVisibilityForMaskParameter(BlockPath=blockPath, ParameterVec=visibleParameters, ...
    Visibility='on');
setVisibilityForMaskParameter(BlockPath=blockPath, ParameterVec=hiddenParameters, ...
    Visibility='off');
end
