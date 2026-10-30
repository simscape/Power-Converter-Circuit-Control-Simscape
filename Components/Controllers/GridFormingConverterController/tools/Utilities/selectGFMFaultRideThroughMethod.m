function selectGFMFaultRideThroughMethod(blockPath)
%   selectGFMFaultRideThroughMethod(blockPath) sets the visibility of mask parameters
%   in the specified Grid-Forming (GFM) controller Simulink block based on the
%   selected current limiting method for fault ride-through operation.
%
%   Input Arguments:
%   ----------------
%   blockPath : char
%       Character vector specifying the path to the GFM controller Simulink block.
%
%   Description:
%   ------------
%   This function adjusts the visibility of relevant mask parameters in the GFM
%   controller block according to the value of the 'currentLimit' mask parameter:
%       - If 'Virtual Impedance' is selected, shows virtual impedance parameters and
%         hides current limiting parameters.
%       - If 'Current Limiting' is selected, shows current limiting parameters and
%         hides virtual impedance parameters.
%       - If 'Virtual Impedance and Current Limiting' is selected, shows all related
%         parameters except 'ctLimitDelayTime'.
%   If an unsupported option is selected, a message is displayed prompting the user
%   to choose a proper current limiting method.
%
%   Example:
%   --------
%       selectGFMFaultRideThroughMethod('myModel/GFMController');

% Copyright 2025-2026 The MathWorks, Inc.

currentLimitControl=get_param(blockPath,'currentLimit');
switch currentLimitControl
    case 'Virtual Impedance' 

       setVisibilityForMaskParameter(BlockPath=blockPath,ParameterVec={'maxVICurrentLimit',...
            'ctLimitVirtualImp','ctLimitXbyR','currentVITimeConst'},Visibility='on');

       setVisibilityForMaskParameter(BlockPath=blockPath,ParameterVec={'maxSatCurrentLimit',...
            'ctLimitDelayTime','currentSatTime','modeTransferTime'},Visibility='off');
          
    case 'Current Limiting'

       setVisibilityForMaskParameter(BlockPath=blockPath,ParameterVec={'maxVICurrentLimit',...
            'ctLimitVirtualImp','ctLimitXbyR','currentVITimeConst',...
            'currentSatTime','modeTransferTime'},Visibility='off');

       setVisibilityForMaskParameter(BlockPath=blockPath,ParameterVec={'maxSatCurrentLimit',...
            'ctLimitDelayTime'},Visibility='on');
  
    case 'Virtual Impedance and Current Limiting'

       setVisibilityForMaskParameter(BlockPath=blockPath,ParameterVec={'maxVICurrentLimit',...
            'ctLimitVirtualImp','ctLimitXbyR','currentVITimeConst',...
            'currentSatTime','modeTransferTime','maxSatCurrentLimit'},Visibility='on');

       setVisibilityForMaskParameter(BlockPath=blockPath,ParameterVec={'ctLimitDelayTime'},Visibility='off');

    otherwise
        disp('Choose proper current limiting method')
end
end