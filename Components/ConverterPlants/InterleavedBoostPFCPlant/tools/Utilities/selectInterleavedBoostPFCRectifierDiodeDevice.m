function selectInterleavedBoostPFCRectifierDiodeDevice(blockPath)
%SELECTINTERLEAVEDBOOSTPFCRECTDIODEDEVICE Mask callback for rectifier diode selection.

% Copyright 2025-2026 The MathWorks, Inc.

choice = get_param(blockPath, 'rectDiodeDeviceOption');
variantPath = [blockPath, '/InterleavedBoostPFCVariant/DetailedModel/RectifierBridge'];

idealParams = {'VfRect', 'VfRect_unit', 'RdRect', 'RdRect_unit', 'GdRect', 'GdRect_unit'};

switch choice
    case 'Ideal Diode'
        setVariantActiveChoice(variantPath, 'IdealDiode');
    case 'Tabulated Diode'
        setVariantActiveChoice(variantPath, 'TabulatedDiode');
    otherwise
        warning('Invalid selection: %s', choice);
        return;
end

% Simulink runs a mask parameter callback whenever the dialog opens, and again on a
% programmatic set_param, so this one runs even while the block is in Simplified mode and
% this popup is hidden. Without this guard it hides the ideal-diode parameters the Simplified
% branch does use and shows the two tabulated-diode buttons it does not have. The variant
% switch above still has to happen, so the Detailed branch is right if you switch
% back; in Simplified mode the visibility belongs to selectInterleavedBoostPFCModelOption.
if ~strcmp(get_param(blockPath, 'modelOption'), 'Detailed')
    return;
end

if strcmp(choice, 'Ideal Diode')
    setVisibilityForMaskParameter(BlockPath=blockPath, ParameterVec=idealParams, Visibility='on');
    setVisibilityForMaskDialogControl(BlockPath=blockPath, ControlVec={'openRectDiodeMask'}, Visibility='off');
    setVisibilityForMaskDialogControl(BlockPath=blockPath, ControlVec={'applyRectDiodeParam'}, Visibility='off');
else
    setVisibilityForMaskParameter(BlockPath=blockPath, ParameterVec=idealParams, Visibility='off');
    setVisibilityForMaskDialogControl(BlockPath=blockPath, ControlVec={'openRectDiodeMask'}, Visibility='on');
    setVisibilityForMaskDialogControl(BlockPath=blockPath, ControlVec={'applyRectDiodeParam'}, Visibility='on');
end

% Only the tabulated bridge diodes interpolate their forward drop over temperature, so the
% shared simulation temperature follows this choice.
updateInterleavedBoostPFCTemperatureVisibility(blockPath);

end
