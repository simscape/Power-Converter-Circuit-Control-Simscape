function selectDABConverterSwitchDevice(blockPath)
%SELECTDABCONVERTERSWITCHDEVICE Mask callback for switch device variant selection.

% Copyright 2025-2026 The MathWorks, Inc.

h = Simulink.Mask.get(blockPath);

% The "Simulation temperature" parameters (simTempPri/simTempSec) exist only on the
% DABConverter model block, not on the shared library copies. Guard every reference
% so this callback stays valid for blocks that do not carry those parameters.
maskParamNames = {h.Parameters.Name};
hasSimTempPri = any(strcmp(maskParamNames, 'simTempPri'));
hasSimTempSec = any(strcmp(maskParamNames, 'simTempSec'));

%% Primary Bridge
choicePri = get_param(blockPath, 'switchDeviceOptionPri');
variantPathPri = [blockPath, '/DABConverterVariant/DetailedModel/PrimaryBridge'];
switch choicePri
    case 'Ideal Switch'
        set_param(variantPathPri, 'LabelModeActiveChoice', 'IdealSwitch');
        setVisibilityForMaskParameter(BlockPath=blockPath, ...
            ParameterVec={'RdsOnPri', 'RdsOnPri_unit', 'GdsOffPri', 'GdsOffPri_unit', 'VthPri', ...
                'VthPri_unit'}, Visibility='on');
        setVisibilityForMaskParameter(BlockPath=blockPath, ParameterVec={'CossPri','CossPri_unit'}, Visibility='off');
        % Simulation temperature applies only to the thermal MOSFET device, so hide it.
        if hasSimTempPri
            setVisibilityForMaskParameter(BlockPath=blockPath, ...
                ParameterVec={'simTempPri', 'simTempPri_unit'}, Visibility='off');
        end
        % Ideal Switch carries a protection diode, so expose its diode params.
        setDABIdealSwitchDiodeVisibility(blockPath, 'Pri', 'on');
        h.getDialogControl('openMOSFETPriMask').Visible = 'off';
        h.getDialogControl('applyMOSFETPriParam').Visible = 'off';
    case 'MOSFET (Ideal, Switching) with Thermal'
        set_param(variantPathPri, 'LabelModeActiveChoice', 'SwitchingMOSFETwithThermal');
        setVisibilityForMaskParameter(BlockPath=blockPath, ...
            ParameterVec={'RdsOnPri', 'RdsOnPri_unit', 'GdsOffPri', 'GdsOffPri_unit', 'VthPri', ...
                'VthPri_unit'}, Visibility='off');
        setVisibilityForMaskParameter(BlockPath=blockPath, ParameterVec={'CossPri','CossPri_unit'}, Visibility='on');
        % The thermal MOSFET device runs at a fixed junction temperature, so expose it.
        if hasSimTempPri
            setVisibilityForMaskParameter(BlockPath=blockPath, ...
                ParameterVec={'simTempPri', 'simTempPri_unit'}, Visibility='on');
        end
        % The MOSFET device manages its own body diode, so hide the ideal-switch diode params.
        setDABIdealSwitchDiodeVisibility(blockPath, 'Pri', 'off');
        h.getDialogControl('openMOSFETPriMask').Visible = 'on';
        h.getDialogControl('applyMOSFETPriParam').Visible = 'on';
end

%% Secondary Bridge
choiceSec = get_param(blockPath, 'switchDeviceOptionSec');
variantPathSec = [blockPath, '/DABConverterVariant/DetailedModel/SecondaryBridge'];
switch choiceSec
    case 'Ideal Switch'
        set_param(variantPathSec, 'LabelModeActiveChoice', 'IdealSwitch');
        setVisibilityForMaskParameter(BlockPath=blockPath, ...
            ParameterVec={'RdsOnSec', 'RdsOnSec_unit', 'GdsOffSec', 'GdsOffSec_unit', 'VthSec', ...
                'VthSec_unit'}, Visibility='on');
        setVisibilityForMaskParameter(BlockPath=blockPath, ParameterVec={'CossSec','CossSec_unit'}, Visibility='off');
        % Simulation temperature applies only to the thermal MOSFET device, so hide it.
        if hasSimTempSec
            setVisibilityForMaskParameter(BlockPath=blockPath, ...
                ParameterVec={'simTempSec', 'simTempSec_unit'}, Visibility='off');
        end
        % Ideal Switch carries a protection diode, so expose its diode params.
        setDABIdealSwitchDiodeVisibility(blockPath, 'Sec', 'on');
        h.getDialogControl('openMOSFETSecMask').Visible = 'off';
        h.getDialogControl('applyMOSFETSecParam').Visible = 'off';
    case 'MOSFET (Ideal, Switching) with Thermal'
        set_param(variantPathSec, 'LabelModeActiveChoice', 'SwitchingMOSFETwithThermal');
        setVisibilityForMaskParameter(BlockPath=blockPath, ...
            ParameterVec={'RdsOnSec', 'RdsOnSec_unit', 'GdsOffSec', 'GdsOffSec_unit', 'VthSec', ...
                'VthSec_unit'}, Visibility='off');
        setVisibilityForMaskParameter(BlockPath=blockPath, ParameterVec={'CossSec','CossSec_unit'}, Visibility='on');
        % The thermal MOSFET device runs at a fixed junction temperature, so expose it.
        if hasSimTempSec
            setVisibilityForMaskParameter(BlockPath=blockPath, ...
                ParameterVec={'simTempSec', 'simTempSec_unit'}, Visibility='on');
        end
        % The MOSFET device manages its own body diode, so hide the ideal-switch diode params.
        setDABIdealSwitchDiodeVisibility(blockPath, 'Sec', 'off');
        h.getDialogControl('openMOSFETSecMask').Visible = 'on';
        h.getDialogControl('applyMOSFETSecParam').Visible = 'on';
end

end
