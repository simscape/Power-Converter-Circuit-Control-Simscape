function selectBoostPFCDiodeDevice(blockPath)
%SELECTBOOSTPFCDIODEDEVICE Mask callback for variant selection.

% Copyright 2025-2026 The MathWorks, Inc.

choice = get_param(blockPath, 'diodeDeviceOption');

variantPath = [blockPath, '/BoostPFCVariant/DetailedModel/BoostDiode'];
switch choice
    case 'Ideal Diode'
        setVariantActiveChoice(variantPath, 'IdealDiode');
    case 'Tabulated Diode'
        setVariantActiveChoice(variantPath, 'TabulatedDiode');
    otherwise
        warning('Invalid selection: %s', choice);
end

% Simulink runs a mask parameter callback whenever the dialog opens, and again on a
% programmatic set_param, so this one runs even while the block is in Simplified mode and
% this popup is hidden. Without this guard it hides the ideal-diode parameters the
% Simplified branch does use and shows the tabulated-diode button it does not have. The
% variant switch above still has to happen, so the Detailed branch is right if you
% switch back; in Simplified mode the visibility belongs to selectBoostPFCModelOption.
if ~strcmp(get_param(blockPath, 'modelOption'), 'Detailed')
    return;
end

if strcmp(choice, 'Ideal Diode')
    setVisibilityForMaskParameter(BlockPath=blockPath, ...
        ParameterVec={'VfDiode', 'VfDiode_unit', 'RdDiode', 'RdDiode_unit', 'GdDiode', ...
            'GdDiode_unit'}, Visibility='on');
    setVisibilityForMaskDialogControl(BlockPath=blockPath, ControlVec={'openDiodeMask'}, Visibility='off');
elseif strcmp(choice, 'Tabulated Diode')
    setVisibilityForMaskParameter(BlockPath=blockPath, ...
        ParameterVec={'VfDiode', 'VfDiode_unit', 'RdDiode', 'RdDiode_unit', 'GdDiode', ...
            'GdDiode_unit'}, Visibility='off');
    setVisibilityForMaskDialogControl(BlockPath=blockPath, ControlVec={'openDiodeMask'}, Visibility='on');
end

% Only the tabulated diode interpolates its forward drop over temperature, so the shared
% simulation temperature parameter follows this choice.
updateBoostPFCTemperatureVisibility(blockPath);

end
