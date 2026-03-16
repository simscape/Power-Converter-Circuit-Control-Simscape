function selectLLCControllerMaskVCO(blockPath)
%   selectLLCControllerMaskVCO(blockPath) configures the VCO (Voltage-Controlled
%   Oscillator) mask parameters and block variant for the LLC Controller Simulink block
%   based on the selected VCO type.
%
%   Input Arguments:
%   ----------------
%   blockPath : char
%       Character vector specifying the path to the Simulink block.
%
%   Description:
%   ------------
%   This function reads the current VCO selection (the 'vcoSelect' parameter)
%   from the specified block and updates the block's variant choice and mask
%   parameter visibility accordingly:
%       - If 'Constant rate' is selected, sets the block variant to 'Constant'
%         and makes the 'vcoGain' parameter visible while hiding 'vcoGainVec'.
%       - If 'Two rate' is selected, sets the block variant to 'TwoRate' and
%         makes the 'vcoGainVec' parameter visible while hiding 'vcoGain'.
%       - Otherwise, displays a message prompting the user to choose a proper
%         VCO model.
%
%   Example:
%   --------
%       selectLLCControllerMaskVCO('myModel/LLCController');
%
%   See also: setVisibilityMaskParameter, Simulink.Mask, set_param, get_param

% Copyright 2025-2026 The MathWorks, Inc.

vcoChoice = get_param(blockPath,'vcoSelect');
vocLoc = [blockPath, '/VCO'];
switch vcoChoice
    case 'Constant rate'
      set_param(vocLoc, 'LabelModeActiveChoice', 'Constant');
      setVisibilityForMaskParameter(BlockPath=blockPath,ParameterVec={'vcoGain'},...
            Visibility='on');
      setVisibilityForMaskParameter(BlockPath=blockPath,ParameterVec={'vcoGainVec'},...
            Visibility='off');
    case 'Two rate'
      set_param(vocLoc, 'LabelModeActiveChoice', 'TwoRate');
      setVisibilityForMaskParameter(BlockPath=blockPath,ParameterVec={'vcoGain'},...
            Visibility='off');
      setVisibilityForMaskParameter(BlockPath=blockPath,ParameterVec={'vcoGainVec'},...
            Visibility='on');
    otherwise
        disp("Choose the proper VCO model");
end
end