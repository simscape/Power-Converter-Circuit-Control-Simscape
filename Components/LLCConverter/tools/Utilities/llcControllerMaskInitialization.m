function llcControllerMaskInitialization(blockPath)
%   llcControllerMaskInitialization(blockPath) initializes the mask parameters and
%   variant subsystems of LLC controller Simulink block based on user
%   selections for the compensator and VCO (Voltage-Controlled Oscillator) types.
%
%   Input Arguments:
%   ----------------
%   blockPath : char
%       Character vector specifying the path to the LLC controller Simulink block.
%
%   Description:
%   ------------
%   This function configures the variant subsystems for both the compensator and VCO
%   blocks within the specified LLC controller block, according to the values of the
%   'cntrlSelect' and 'vcoSelect' mask parameters:
%       - For the compensator ('cntrlSelect'), selects between continuous/discrete
%         2P2Z compensators and PI controllers.
%       - For the VCO ('vcoSelect'), selects between 'Constant rate' and 'Two rate'
%         variants.
%   If an invalid selection is detected, a message is displayed prompting the user
%   to choose an appropriate model.
%
%   Example:
%   --------
%       llcControllerMaskInitialization('myModel/LLCController');

% Copyright 2025-2026 The MathWorks, Inc.

cntrlChoice = get_param(blockPath,'cntrlSelect');
vcoChoice = get_param(blockPath,'vcoSelect');
contrlLoc = [blockPath, '/2P2Z Compensator'];
vocLoc = [blockPath, '/VCO'];
switch cntrlChoice
    case 'Compensator (Continuous S domain)'
      set_param(contrlLoc, 'LabelModeActiveChoice', 'SCompensator');
    case 'Compensator (Discrete Z domain)'
      set_param(contrlLoc, 'LabelModeActiveChoice', 'ZCompensator');
    case 'PI controller (Continuous)'
      set_param(contrlLoc, 'LabelModeActiveChoice', 'PIContinuous');
    case 'PI controller (Discrete)'
      set_param(contrlLoc, 'LabelModeActiveChoice', 'PIDiscrete');
    otherwise
        disp("Choose the proper compensator");
end
switch vcoChoice
    case 'Constant rate'
      set_param(vocLoc, 'LabelModeActiveChoice', 'Constant');
    case 'Two rate'
      set_param(vocLoc, 'LabelModeActiveChoice', 'TwoRate');
    otherwise
        disp("Choose the proper VCO model");
end
end