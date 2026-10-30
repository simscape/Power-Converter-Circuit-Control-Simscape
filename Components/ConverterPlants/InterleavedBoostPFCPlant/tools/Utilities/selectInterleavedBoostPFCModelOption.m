function selectInterleavedBoostPFCModelOption(blockPath)
%SELECTINTERLEAVEDBOOSTPFCMODELOPTION Mask callback for variant selection.

% Copyright 2025-2026 The MathWorks, Inc.

choice = get_param(blockPath, 'modelOption');

variantPath = [blockPath, '/InterleavedBoostPFCVariant'];
switch choice
    case 'Simplified'
        activeChoice = 'SimplifiedModel';
    case 'Detailed'
        activeChoice = 'DetailedModel';
    otherwise
        warning('Invalid selection: %s', choice);
        activeChoice = '';
end

if ~isempty(activeChoice)
    setVariantActiveChoice(variantPath, activeChoice);
end

if strcmp(choice, 'Simplified')
    setVisibilityForMaskParameter(BlockPath=blockPath, ...
        ParameterVec={'RdsOn', 'RdsOn_unit', 'GdsOff', 'GdsOff_unit', 'Vth', 'Vth_unit', 'VfDiode', ...
            'VfDiode_unit', 'RdDiode', 'RdDiode_unit', 'GdDiode', 'GdDiode_unit'}, Visibility='on');
    setVisibilityForMaskParameter(BlockPath=blockPath, ...
        ParameterVec={'switchDeviceOption', 'diodeDeviceOption'}, Visibility='off');
    setVisibilityForMaskDialogControl(BlockPath=blockPath, ControlVec={'openMOSFETMask'}, Visibility='off');
    setVisibilityForMaskDialogControl(BlockPath=blockPath, ControlVec={'applyMOSFETParam'}, Visibility='off');
    setVisibilityForMaskDialogControl(BlockPath=blockPath, ControlVec={'openDiodeMask'}, Visibility='off');
    setVisibilityForMaskDialogControl(BlockPath=blockPath, ControlVec={'applyDiodeParam'}, Visibility='off');
    % The Rectifier Devices group is always visible. In Simplified mode there is no rectifier
    % diode model choice, so hide the dropdown and its Tabulated-diode buttons, but show
    % the rectifier ideal parameters (VfRect/RdRect/GdRect) - they always apply here.
    setVisibilityForMaskDialogControl(BlockPath=blockPath, ControlVec={'RectifierDevices'}, Visibility='on');
    setVisibilityForMaskParameter(BlockPath=blockPath, ...
        ParameterVec={'VfRect', 'VfRect_unit', 'RdRect', 'RdRect_unit', 'GdRect', 'GdRect_unit'}, Visibility='on');
    setVisibilityForMaskParameter(BlockPath=blockPath, ParameterVec={'rectDiodeDeviceOption'}, Visibility='off');
    setVisibilityForMaskDialogControl(BlockPath=blockPath, ControlVec={'openRectDiodeMask'}, Visibility='off');
    setVisibilityForMaskDialogControl(BlockPath=blockPath, ControlVec={'applyRectDiodeParam'}, Visibility='off');
end

if strcmp(choice, 'Detailed')
    % The Rectifier Devices group is always visible. In Detailed mode the rectifier
    % diode model dropdown is shown; selectInterleavedBoostPFCRectifierDiodeDevice then sets
    % the parameter and button visibility according to the selected diode model.
    setVisibilityForMaskDialogControl(BlockPath=blockPath, ControlVec={'RectifierDevices'}, Visibility='on');
    setVisibilityForMaskParameter(BlockPath=blockPath, ...
        ParameterVec={'switchDeviceOption', 'diodeDeviceOption', 'rectDiodeDeviceOption'}, Visibility='on');
    selectInterleavedBoostPFCSwitchDevice(blockPath);
    selectInterleavedBoostPFCDiodeDevice(blockPath);
    selectInterleavedBoostPFCRectifierDiodeDevice(blockPath);
end

% The shared device simulation temperature reaches only the Detailed variant's
% temperature-sensitive devices, so its visibility follows this choice as well as the three
% device choices. Called for both branches: Simplified must hide it.
updateInterleavedBoostPFCTemperatureVisibility(blockPath);

end
