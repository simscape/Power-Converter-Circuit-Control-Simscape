function cllcControllerMaskInitialization(blockPath)
%   cllcControllerMaskInitialization(blockPath) initializes the mask parameters and
%   variant subsystems of the CLLC controller Simulink block from the
%   selections for the time domain, the compensator and the VCO
%   (Voltage-Controlled Oscillator) types. Call it from mask initialization code only.
%
%   Input Arguments:
%   ----------------
%   blockPath : char
%       Character vector specifying the path to the CLLC controller Simulink block.
%
%   Description:
%   ------------
%   This function writes the synchronous rectifier detection frequencies into the mask
%   workspace and then calls selectCLLCControllerVariants, which configures the variant
%   subsystems for the voltage controller, the compensator, the VCO and the PWM carrier.
%
%   Only mask initialization code may write the mask workspace, so a dialog callback calls
%   selectCLLCControllerVariants instead of this function.
%
%   Example:
%   --------
%       cllcControllerMaskInitialization('myModel/CLLCController');
%
%   See also: selectCLLCControllerVariants, selectCLLCControllerDomain,
%   selectCLLCMaskController, selectCLLCControllerMaskVCO, applyDerivedPWMCarrier

% Copyright 2025-2026 The MathWorks, Inc.
maskObj = Simulink.Mask.get(blockPath);
workspaceObj = maskObj.getWorkspace;
resFreqVal = get_param(blockPath,"resFreq");
workspaceObj.set("resFreqLowSR",str2double(resFreqVal)*0.98);
workspaceObj.set("resFreqHighSR",str2double(resFreqVal)*1.02);

selectCLLCControllerVariants(blockPath);
end
