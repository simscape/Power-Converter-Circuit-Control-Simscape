function selectCLLCControllerVariants(blockPath)
%   selectCLLCControllerVariants(blockPath) selects every variant inside the CLLC controller
%   Simulink block from the choices made on its mask, and sets the visibility of the values
%   each choice needs.
%
%   Input Arguments:
%   ----------------
%   blockPath : char
%       Character vector specifying the path to the CLLC controller Simulink block.
%
%   Description:
%   ------------
%   The selectors run in dependency order, because the time domain decides both control loops
%   and the PWM carrier:
%       - selectCLLCControllerDomain reads 'controllerDomain' and selects the voltage
%         controller variant.
%       - selectCLLCMaskController reads 'cntrlSelect' with 'controllerDomain' and selects
%         the current controller variant.
%       - selectCLLCControllerMaskVCO reads 'vcoSelect' and selects the VCO
%         (Voltage-Controlled Oscillator) variant.
%       - applyDerivedPWMCarrier selects the PWM generator built for the carrier that
%         'controllerDomain' implies.
%
%   This is separate from cllcControllerMaskInitialization so that a dialog callback can run
%   it. Only mask initialization code may write the mask workspace, so a callback that called
%   the initialization function would error.
%
%   Example:
%   --------
%       selectCLLCControllerVariants('myModel/CLLCController');
%
%   See also: cllcControllerMaskInitialization, selectCLLCControllerDomain,
%   selectCLLCMaskController, selectCLLCControllerMaskVCO, applyDerivedPWMCarrier

% Copyright 2026 The MathWorks, Inc.

selectCLLCControllerDomain(blockPath);
selectCLLCMaskController(blockPath);
selectCLLCControllerMaskVCO(blockPath);

% The PWM carrier follows the controller time domain and is not asked for on this dialog box.
applyDerivedPWMCarrier(blockPath, 'Gate Signal/CLLC PWM Generator', 'pwmSampleTime', ...
    'controllerDomain');
end
