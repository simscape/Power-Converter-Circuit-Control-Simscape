function selectCLLCConverterModelOption(blockPath)
%SELECTCLLCCONVERTERMODELOPTION Mask callback selecting the CLLC plant model variant.
%
% Switches CLLCConverterVariant between its two top-level branches and shows only the parameters
% that branch uses:
%
%   Simplified - ideal semiconductor switches and a linear mutual inductor. The device-type choice
%                does not exist here, so the selector popup, the MOSFET output capacitance and the
%                MOSFET helper buttons are hidden and the ideal-switch parameters are always shown.
%   Detailed   - nonlinear transformer, and the per-side device choice is available. The selector is
%                shown and the existing per-side callbacks decide the rest.
%
% Mirrors selectDABConverterModelOption. Unlike DAB this is not called from the mask Initialization:
% mask parameter callbacks fire on programmatic set_param as well as on dialog edits, so the popup
% and the variant cannot drift apart, and CLLC's initialization does not drive its device selectors
% either.

% Copyright 2026 The MathWorks, Inc.

modelChoice = get_param(blockPath, 'modelOption');

variantPath = [blockPath '/CLLCConverterVariant'];
switch modelChoice
    case 'Simplified'
        set_param(variantPath, 'LabelModeActiveChoice', 'SimplifiedModel');
    case 'Detailed'
        set_param(variantPath, 'LabelModeActiveChoice', 'DetailedModel');
    otherwise
        warning('Invalid model option selection: %s', modelChoice);
        return
end

cllcMask = Simulink.Mask.get(blockPath);
cllcMask.getDialogControl('PrimarySwitch').Visible = 'on';
cllcMask.getDialogControl('SecondarySwitch').Visible = 'on';

% Every dimensional parameter has a sibling <name>_unit popup, so both must be shown and hidden
% together - otherwise a unit selector is left on the dialog with no value field beside it, or a
% value field appears with no way to set its unit.
for side = {'Primary', 'Secondary'}
    idealSwitchParameters = { ...
        [side{1} 'Ron'],             [side{1} 'Ron_unit'], ...
        [side{1} 'Goff'],            [side{1} 'Goff_unit'], ...
        [side{1} 'Vth'],             [side{1} 'Vth_unit'], ...
        [side{1} 'VbodydiodeOn'],    [side{1} 'VbodydiodeOn_unit'], ...
        [side{1} 'RbodydiodeOn'],    [side{1} 'RbodydiodeOn_unit'], ...
        [side{1} 'GbodydiodeOff'],   [side{1} 'GbodydiodeOff_unit']};
    % The output capacitance pair, plus the simulation-temperature pair where the mask has one. That
    % pair is on the model's plant mask but not on the library copies, which predate it, and
    % setVisibilityForMaskParameter throws MATLAB:emptyObjectDotAssignment on a name it cannot find.
    mosfetOnlyParameters = {[side{1} 'Cparasitic'], [side{1} 'Cparasitic_unit']};
    if any(strcmp({cllcMask.Parameters.Name}, [side{1} 'SimTemp']))
        mosfetOnlyParameters = [mosfetOnlyParameters, ...
            {[side{1} 'SimTemp'], [side{1} 'SimTemp_unit']}]; %#ok<AGROW>
    end

    switch modelChoice
        case 'Simplified'
            % The simplified branch hard-wires ideal switches, so there is nothing to choose.
            setVisibilityForMaskParameter(BlockPath=blockPath, ...
                ParameterVec=idealSwitchParameters, Visibility='on');
            setVisibilityForMaskParameter(BlockPath=blockPath, ...
                ParameterVec=[{[side{1} 'DeviceOption']}, mosfetOnlyParameters], Visibility='off');
            cllcMask.getDialogControl([side{1} 'OpenMOSFETMask']).Visible = 'off';
            cllcMask.getDialogControl([side{1} 'ApplyMOSFETParam']).Visible = 'off';

        case 'Detailed'
            % Show the selector and let the per-side callback set everything below it.
            setVisibilityForMaskParameter(BlockPath=blockPath, ...
                ParameterVec={[side{1} 'DeviceOption']}, Visibility='on');
    end
end

if strcmp(modelChoice, 'Detailed')
    selectCLLCPrimaryMOSFET(blockPath);
    selectCLLCSecondaryMOSFET(blockPath);
end

end
