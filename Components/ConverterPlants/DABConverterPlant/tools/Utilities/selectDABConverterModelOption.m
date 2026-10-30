function selectDABConverterModelOption(blockPath)
%SELECTDABCONVERTERMODELOPTION Mask callback for variant selection.

% Copyright 2025-2026 The MathWorks, Inc.

choice = get_param(blockPath, 'modelOption');

variantPath = [blockPath, '/DABConverterVariant'];
switch choice
    case 'Simplified'
        set_param(variantPath, 'LabelModeActiveChoice', 'SimplifiedModel');
    case 'Detailed'
        set_param(variantPath, 'LabelModeActiveChoice', 'DetailedModel');
    otherwise
        warning('Invalid selection: %s', choice);
end

h = Simulink.Mask.get(blockPath);

if strcmp(choice, 'Simplified')
    % The Simplified model uses Ideal Semiconductor Switches for both bridges, so
    % show the Primary Switch and Secondary Switch groups with the
    % ideal-switch parameters: on-state resistance (RdsOn), off-state
    % conductance (GdsOff), and threshold voltage (Vth). The device-type
    % selector, MOSFET output capacitance (Coss), and MOSFET helper buttons
    % apply only to the Detailed model and stay hidden here.
    h.getDialogControl('PrimarySwitch').Visible = 'on';
    h.getDialogControl('SecondarySwitch').Visible = 'on';
    setVisibilityForMaskParameter(BlockPath=blockPath, ...
        ParameterVec={'RdsOnPri', 'RdsOnPri_unit', 'GdsOffPri', 'GdsOffPri_unit', 'VthPri', ...
            'VthPri_unit'}, Visibility='on');
    setVisibilityForMaskParameter(BlockPath=blockPath, ...
        ParameterVec={'RdsOnSec', 'RdsOnSec_unit', 'GdsOffSec', 'GdsOffSec_unit', 'VthSec', ...
            'VthSec_unit'}, Visibility='on');
    setVisibilityForMaskParameter(BlockPath=blockPath, ...
        ParameterVec={'switchDeviceOptionPri', 'CossPri', 'CossPri_unit'}, Visibility='off');
    setVisibilityForMaskParameter(BlockPath=blockPath, ...
        ParameterVec={'switchDeviceOptionSec', 'CossSec', 'CossSec_unit'}, Visibility='off');
    % The Ideal Semiconductor Switches carry a protection diode, so expose the
    % primary and secondary diode params alongside the ideal-switch params.
    setDABIdealSwitchDiodeVisibility(blockPath, 'Pri', 'on');
    setDABIdealSwitchDiodeVisibility(blockPath, 'Sec', 'on');
    h.getDialogControl('openMOSFETPriMask').Visible = 'off';
    h.getDialogControl('applyMOSFETPriParam').Visible = 'off';
    h.getDialogControl('openMOSFETSecMask').Visible = 'off';
    h.getDialogControl('applyMOSFETSecParam').Visible = 'off';
end

if strcmp(choice, 'Detailed')
    h.getDialogControl('PrimarySwitch').Visible = 'on';
    h.getDialogControl('SecondarySwitch').Visible = 'on';
    setVisibilityForMaskParameter(BlockPath=blockPath, ...
        ParameterVec={'switchDeviceOptionPri', 'switchDeviceOptionSec'}, Visibility='on');
    selectDABConverterSwitchDevice(blockPath);
end

% Apply the series-inductance option. Both model variants contain the Lr
% variant subsystem, so this is applied regardless of the selected model.
selectDABSeriesInductor(blockPath);

end
