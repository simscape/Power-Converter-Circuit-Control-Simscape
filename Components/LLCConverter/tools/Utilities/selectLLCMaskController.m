function selectLLCMaskController(blockPath)
%   selectLLCMaskController(blockPath) sets the visibility of mask parameters and
%   selects the appropriate variant for the 2P2Z Compensator block within the specified
%   LLC controller Simulink block, based on the selected controller type.
%
%   Input Arguments:
%   ----------------
%   blockPath : char
%       Character vector specifying the path to the LLC controller Simulink block.
%
%   Description:
%   ------------
%   This function adjusts the mask parameter visibility and the active variant for the
%   '2P2Z Compensator' block inside the LLC controller block according to the
%   'cntrlSelect' mask parameter:
%       - For 'Compensator (Continuous S domain)', shows S-domain parameters and Kc.
%       - For 'Compensator (Discrete Z domain)', shows Z-domain parameters and Kc.
%       - For 'PI controller (Continuous)', shows Kp and Ki.
%       - For 'PI controller (Discrete)', shows Kp, Ki, and TsController.
%   All other unrelated parameters are hidden for each selection.
%   If an unsupported option is selected, a message is displayed prompting the user
%   to choose the proper compensator.
%
%   Example:
%   --------
%       selectLLCMaskController('myModel/LLCController');
%
%   See also: setVisibilityMaskParameter, set_param, get_param

% Copyright 2025-2026 The MathWorks, Inc.

cntrlChoice=get_param(blockPath,'cntrlSelect');
contrlLoc = [blockPath, '/2P2Z Compensator'];

switch cntrlChoice
    case 'Compensator (Continuous S domain)'
      set_param(contrlLoc, 'LabelModeActiveChoice', 'SCompensator');
      setVisibilityForMaskParameter(BlockPath=blockPath,ParameterVec={'numSdomain','denSdomain','Kc'},...
            Visibility='on');
      setVisibilityForMaskParameter(BlockPath=blockPath,ParameterVec={'numZdomain','denZdomain','Kp',...
          'Ki','TsController'},Visibility='off');  
    case 'Compensator (Discrete Z domain)'
      set_param(contrlLoc, 'LabelModeActiveChoice', 'ZCompensator');
      setVisibilityForMaskParameter(BlockPath=blockPath,ParameterVec={'numZdomain','denZdomain','Kc'},...
            Visibility='on');
      setVisibilityForMaskParameter(BlockPath=blockPath,ParameterVec={'numSdomain','denSdomain','Kp',...
          'Ki','TsController'},Visibility='off');  
    case 'PI controller (Continuous)'
      set_param(contrlLoc, 'LabelModeActiveChoice', 'PIContinuous');
      setVisibilityForMaskParameter(BlockPath=blockPath,ParameterVec={'numZdomain','denZdomain',...
          'numSdomain','denSdomain','Kc','TsController'},Visibility='off');
      setVisibilityForMaskParameter(BlockPath=blockPath,ParameterVec={'Ki','Kp'},...
          Visibility='on');  
    case 'PI controller (Discrete)'
      set_param(contrlLoc, 'LabelModeActiveChoice', 'PIDiscrete');
      setVisibilityForMaskParameter(BlockPath=blockPath,ParameterVec={'numZdomain','denZdomain',...
          'numSdomain','denSdomain','Kc'},Visibility='off');
      setVisibilityForMaskParameter(BlockPath=blockPath,ParameterVec={'Ki','Kp','TsController'},...
          Visibility='on');  
    otherwise
        disp("Choose the proper compensator");
end
end