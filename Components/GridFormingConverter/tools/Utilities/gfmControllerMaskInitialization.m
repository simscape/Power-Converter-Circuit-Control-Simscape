function gfmControllerMaskInitialization(blockPath)
%   gfmControllerMaskInitialization(blockPath) initializes the mask parameters and
%   variant subsystems for the specified Grid-Forming (GFM) controller Simulink block
%   based on user selections for power control and current limiting methods.
%
%   Input Arguments:
%   ----------------
%   blockPath : char
%       Character vector specifying the path to the GFM controller Simulink block.
%
%   Description:
%   ------------
%   This function configures the variant subsystems for the power control and current
%   limiting blocks within the specified GFM controller block, according to the values
%   of the 'powerControl' and 'currentLimit' mask parameters:
%       - For 'powerControl', selects between 'Virtual Synchronous Machine' and
%         'Droop Control'. If 'Virtual Synchronous Machine' is selected, the function
%         further configures the damping frequency method based on the 'freqOption'
%         parameter.
%       - For 'currentLimit', selects between 'Virtual Impedance', 'Current Limiting',
%         or both methods.
%   If an invalid selection is detected, a message is displayed prompting the user to
%   choose an appropriate method.
%
%   Example:
%   --------
%       gfmControllerMaskInitialization('myModel/GFMController');

% Copyright 2025-2026 The MathWorks, Inc.

powerChoice = get_param(blockPath,'powerControl');
currentChoice = get_param(blockPath,'currentLimit');

powerloc = [blockPath, '/Power Control/ActivePowerControl']; 
currentloc = [blockPath, '/Current Limiting/CurrentLimitingMethod'];
freqLoc = [blockPath,'/Power Control/ActivePowerControl/vsmControl/Damping Frequency'];

switch powerChoice
    case 'Virtual Synchronous Machine'
        set_param(powerloc, 'LabelModeActiveChoice', 'vsm');
        dampingFreqChoice = get_param(blockPath,'freqOption');
        if strcmp(dampingFreqChoice,'Grid Frequency Measurement')
            set_param(freqLoc, 'LabelModeActiveChoice', 'freqMeas');
        else
            set_param(freqLoc, 'LabelModeActiveChoice', 'constFreq');
        end
    case 'Droop Control'
         set_param(powerloc, 'LabelModeActiveChoice', 'droop');
   otherwise
        disp('Choose proper active power control method')
end
switch currentChoice
    case 'Virtual Impedance'
          set_param(currentloc, 'LabelModeActiveChoice', 'virimp');
    case 'Current Limiting'
         set_param(currentloc, 'LabelModeActiveChoice', 'ctSat');
    case 'Virtual Impedance and Current Limiting'
            set_param(currentloc, 'LabelModeActiveChoice', 'both');
    otherwise
        disp('Choose proper current limiting method')
end
end