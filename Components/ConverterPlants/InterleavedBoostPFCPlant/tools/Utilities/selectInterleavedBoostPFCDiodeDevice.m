function selectInterleavedBoostPFCDiodeDevice(blockPath)
%SELECTINTERLEAVEDBOOSTPFCDIODEDEVICE Mask callback for variant selection.

% Copyright 2025-2026 The MathWorks, Inc.

choice = get_param(blockPath, 'diodeDeviceOption');

% Both legs carry the same boost diode, so one dialog choice drives both variant blocks.
switch choice
    case 'Ideal Diode'
        activeChoice = 'IdealDiode';
    case 'Tabulated Diode'
        activeChoice = 'TabulatedDiode';
    otherwise
        warning('Invalid selection: %s', choice);
        return;
end

legVariantNames = {'BoostDiode1', 'BoostDiode2'};
for legIndex = 1:numel(legVariantNames)
    setVariantActiveChoice([blockPath, '/InterleavedBoostPFCVariant/DetailedModel/', ...
        legVariantNames{legIndex}], activeChoice);
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
    setVisibilityForMaskParameter(BlockPath=blockPath, ...
        ParameterVec={'VfDiode', 'VfDiode_unit', 'RdDiode', 'RdDiode_unit', 'GdDiode', ...
            'GdDiode_unit'}, Visibility='on');
    setVisibilityForMaskDialogControl(BlockPath=blockPath, ControlVec={'openDiodeMask'}, Visibility='off');
    setVisibilityForMaskDialogControl(BlockPath=blockPath, ControlVec={'applyDiodeParam'}, Visibility='off');
end

if strcmp(choice, 'Tabulated Diode')
    setVisibilityForMaskParameter(BlockPath=blockPath, ...
        ParameterVec={'VfDiode', 'VfDiode_unit', 'RdDiode', 'RdDiode_unit', 'GdDiode', ...
            'GdDiode_unit'}, Visibility='off');
    setVisibilityForMaskDialogControl(BlockPath=blockPath, ControlVec={'openDiodeMask'}, Visibility='on');
    setVisibilityForMaskDialogControl(BlockPath=blockPath, ControlVec={'applyDiodeParam'}, Visibility='on');
end

% Only the tabulated diodes interpolate their forward drop over temperature, so the shared
% simulation temperature follows this choice.
updateInterleavedBoostPFCTemperatureVisibility(blockPath);

end
