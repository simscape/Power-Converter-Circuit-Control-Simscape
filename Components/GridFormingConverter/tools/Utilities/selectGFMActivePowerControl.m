function selectGFMActivePowerControl(blockPath)
%   selectGFMActivePowerControl(blockPath) sets the visibility of mask parameters
%   in the specified Grid-Forming (GFM) controller Simulink block based on the
%   selected active power control method.
%
%   Input Arguments:
%   ----------------
%   blockPath : char
%       Character vector specifying the path to the GFM controller Simulink block.
%
%   Description:
%   ------------
%   This function adjusts the visibility of relevant mask parameters in the GFM
%   controller block according to the value of the 'powerControl' mask parameter:
%       - If 'Virtual Synchronous Machine' is selected, shows VSM-related parameters
%         and hides droop control parameters.
%       - If 'Droop Control' is selected, shows droop control parameters and hides
%         VSM-related parameters.
%   If an unsupported option is selected, a message is displayed prompting the user
%   to choose a proper active power control method.
%
%   Example:
%   --------
%       selectGFMActivePowerControl('myModel/GFMController');

% Copyright 2025-2026 The MathWorks, Inc.

slectedActivePowerControl=get_param(blockPath,'powerControl');
switch slectedActivePowerControl 
    case 'Virtual Synchronous Machine'

        setVisibilityForMaskParameter(BlockPath=blockPath,ParameterVec={'droopSlope',...
            'droopTC','droopT1','droopT2'},Visibility='off');
        setVisibilityForMaskParameter(BlockPath=blockPath,ParameterVec={'vsmPmeasFilterTC',...
            'vsmFreqDroop','vsmInertiaTC','vsmDampingConst','dampingPowerMaxLimit',...
            'dampingPowerMinLimit','freqOption','freqMeasTimeConst'},Visibility='on');

      case 'Droop Control'
          
        setVisibilityForMaskParameter(BlockPath=blockPath,ParameterVec={'droopSlope',...
            'droopTC','droopT1','droopT2','freqMeasTimeConst'},Visibility='on');
        setVisibilityForMaskParameter(BlockPath=blockPath,ParameterVec={'vsmPmeasFilterTC',...
            'vsmFreqDroop','vsmInertiaTC','vsmDampingConst','dampingPowerMaxLimit',...
            'dampingPowerMinLimit','freqOption'},Visibility='off');
    otherwise
        disp('Choose proper active power control method')
end
end