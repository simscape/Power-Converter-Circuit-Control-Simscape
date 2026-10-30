function selectCLLCSecondaryMOSFET(blockPath)
% Mask callback of the CLLC Converter Power Circuit block that selects
% the secondary MOSFET device option.
%
% Only the Detailed model exposes this choice. The Simplified model hard-wires ideal switches, so
% selectCLLCConverterModelOption hides this popup in that branch.

% Copyright 2026 The MathWorks, Inc.

h = Simulink.Mask.get(blockPath);

% The Simplified branch hard-wires ideal switches, so the device choice has no meaning there and must
% not put the selector or the MOSFET-only controls back on the dialog - which is what would otherwise
% happen the moment anything writes SecondaryDeviceOption while Simplified is selected, since this
% callback fires on a programmatic set_param too. Guarded on the parameter existing, because a copy of
% the block predating the model option popup does not have it. selectCLLCConverterModelOption calls
% this function again on the way back to Detailed, which syncs the bridge variant.
if any(strcmp({h.Parameters.Name}, 'modelOption')) && ...
        strcmp(get_param(blockPath, 'modelOption'), 'Simplified')
    return
end

secondarySwitchChoice = get_param(blockPath,'SecondaryDeviceOption');
secondarySwitchLoc = getCLLCBridgePath(blockPath, 'Secondary Converter Full Bridge');

% The controls that only the thermal MOSFET uses: its output capacitance pair and its
% simulation-temperature pair. The temperature pair exists on the model's plant mask but not on
% the library copies, which predate it, and setVisibilityForMaskParameter throws
% MATLAB:emptyObjectDotAssignment on a name it cannot find - so it is named only when the mask
% being updated has it.
mosfetOnlyParameters = {'SecondaryCparasitic', 'SecondaryCparasitic_unit'};
if any(strcmp({h.Parameters.Name}, 'SecondarySimTemp'))
    mosfetOnlyParameters = [mosfetOnlyParameters, {'SecondarySimTemp', 'SecondarySimTemp_unit'}];
end

% Every dimensional parameter has a sibling <name>_unit popup, so both must be shown and
% hidden together - otherwise a unit selector is left on the dialog with no value field
% beside it, or a value field appears with no way to set its unit.
switch secondarySwitchChoice
    case 'Ideal Switch'

        set_param(secondarySwitchLoc, 'LabelModeActiveChoice', 'IdealSwitch');

        setVisibilityForMaskParameter(BlockPath=blockPath,ParameterVec={'SecondaryDeviceOption',...
            'SecondaryRon','SecondaryRon_unit','SecondaryGoff','SecondaryGoff_unit',...
            'SecondaryVth','SecondaryVth_unit','SecondaryVbodydiodeOn','SecondaryVbodydiodeOn_unit',...
            'SecondaryRbodydiodeOn','SecondaryRbodydiodeOn_unit',...
            'SecondaryGbodydiodeOff','SecondaryGbodydiodeOff_unit'},Visibility='on');
        setVisibilityForMaskParameter(BlockPath=blockPath, ...
            ParameterVec=mosfetOnlyParameters,Visibility='off');

        h.getDialogControl("SecondaryOpenMOSFETMask").Visible = "off";
        h.getDialogControl("SecondaryApplyMOSFETParam").Visible = "off";

    case 'MOSFET (Ideal, Switching) with Thermal'
        set_param(secondarySwitchLoc, 'LabelModeActiveChoice', 'IdealMOSFETwithThermal');

        setVisibilityForMaskParameter(BlockPath=blockPath,ParameterVec={...
            'SecondaryRon','SecondaryRon_unit','SecondaryGoff','SecondaryGoff_unit',...
            'SecondaryVth','SecondaryVth_unit','SecondaryVbodydiodeOn','SecondaryVbodydiodeOn_unit',...
            'SecondaryRbodydiodeOn','SecondaryRbodydiodeOn_unit',...
            'SecondaryGbodydiodeOff','SecondaryGbodydiodeOff_unit'},Visibility='off');
        setVisibilityForMaskParameter(BlockPath=blockPath, ...
            ParameterVec=[{'SecondaryDeviceOption'}, mosfetOnlyParameters],Visibility='on');

        h.getDialogControl("SecondaryOpenMOSFETMask").Visible = "on";
        h.getDialogControl("SecondaryApplyMOSFETParam").Visible = "on";
        h.getDialogControl("SecondaryOpenMOSFETMask").Enabled = "on";
        h.getDialogControl("SecondaryApplyMOSFETParam").Enabled = "on";
    otherwise
        disp('Select the proper secondary switch option')
end
end
