function selectDCDCOutputMode(blockPath)
%SELECTDCDCOUTPUTMODE Mask callback for output mode variant selection.

% Copyright 2025-2026 The MathWorks, Inc.

outputChoice = get_param(blockPath, 'outputSelect');
outLoc = [blockPath, '/Output Mode'];

if strcmp(outputChoice, 'Duty Cycle')
    set_param(outLoc, 'LabelModeActiveChoice', 'DutyCycle');
    setVisibilityForMaskParameter(BlockPath=blockPath, ...
        ParameterVec={'Fsw', 'Tdead'}, Visibility='off');
elseif strcmp(outputChoice, 'PWM Signal')
    set_param(outLoc, 'LabelModeActiveChoice', 'PWMSignal');
    setVisibilityForMaskParameter(BlockPath=blockPath, ...
        ParameterVec={'Fsw', 'Tdead'}, Visibility='on');
end

end
