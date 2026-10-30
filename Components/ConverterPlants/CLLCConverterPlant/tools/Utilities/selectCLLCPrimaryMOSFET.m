function selectCLLCPrimaryMOSFET(blockPath)
% Mask callback of the CLLC Converter Power Circuit block that selects
% the primary MOSFET device option.
%
% Only the Detailed model exposes this choice. The Simplified model hard-wires ideal switches, so
% selectCLLCConverterModelOption hides this popup in that branch.

% Copyright 2026 The MathWorks, Inc.

h = Simulink.Mask.get(blockPath);

% The Simplified branch hard-wires ideal switches, so the device choice has no meaning there and must
% not put the selector or the MOSFET-only controls back on the dialog - which is what would otherwise
% happen the moment anything writes PrimaryDeviceOption while Simplified is selected, since this
% callback fires on a programmatic set_param too. Guarded on the parameter existing, because a copy of
% the block predating the model option popup does not have it. selectCLLCConverterModelOption calls
% this function again on the way back to Detailed, which syncs the bridge variant.
if any(strcmp({h.Parameters.Name}, 'modelOption')) && ...
        strcmp(get_param(blockPath, 'modelOption'), 'Simplified')
    return
end

primarySwitchChoice = get_param(blockPath,'PrimaryDeviceOption');
primarySwitchLoc = getCLLCBridgePath(blockPath, 'Primary Converter Full Bridge');

% The controls that only the thermal MOSFET uses: its output capacitance pair and its
% simulation-temperature pair. The temperature pair exists on the model's plant mask but not on
% the library copies, which predate it, and setVisibilityForMaskParameter throws
% MATLAB:emptyObjectDotAssignment on a name it cannot find - so it is named only when the mask
% being updated has it.
mosfetOnlyParameters = {'PrimaryCparasitic', 'PrimaryCparasitic_unit'};
if any(strcmp({h.Parameters.Name}, 'PrimarySimTemp'))
    mosfetOnlyParameters = [mosfetOnlyParameters, {'PrimarySimTemp', 'PrimarySimTemp_unit'}];
end

% Every dimensional parameter has a sibling <name>_unit popup, so both must be shown and
% hidden together - otherwise a unit selector is left on the dialog with no value field
% beside it, or a value field appears with no way to set its unit.
switch primarySwitchChoice
    case 'Ideal Switch'

        set_param(primarySwitchLoc, 'LabelModeActiveChoice', 'IdealSwitch');

        setVisibilityForMaskParameter(BlockPath=blockPath,ParameterVec={'PrimaryDeviceOption',...
            'PrimaryRon','PrimaryRon_unit','PrimaryGoff','PrimaryGoff_unit',...
            'PrimaryVth','PrimaryVth_unit','PrimaryVbodydiodeOn','PrimaryVbodydiodeOn_unit',...
            'PrimaryRbodydiodeOn','PrimaryRbodydiodeOn_unit',...
            'PrimaryGbodydiodeOff','PrimaryGbodydiodeOff_unit'},Visibility='on');
        setVisibilityForMaskParameter(BlockPath=blockPath, ...
            ParameterVec=mosfetOnlyParameters,Visibility='off');

        h.getDialogControl("PrimaryOpenMOSFETMask").Visible = "off";
        h.getDialogControl("PrimaryApplyMOSFETParam").Visible = "off";

    case 'MOSFET (Ideal, Switching) with Thermal'
        set_param(primarySwitchLoc, 'LabelModeActiveChoice', 'IdealMOSFETwithThermal');

        setVisibilityForMaskParameter(BlockPath=blockPath,ParameterVec={...
            'PrimaryRon','PrimaryRon_unit','PrimaryGoff','PrimaryGoff_unit',...
            'PrimaryVth','PrimaryVth_unit','PrimaryVbodydiodeOn','PrimaryVbodydiodeOn_unit',...
            'PrimaryRbodydiodeOn','PrimaryRbodydiodeOn_unit',...
            'PrimaryGbodydiodeOff','PrimaryGbodydiodeOff_unit'},Visibility='off');
        setVisibilityForMaskParameter(BlockPath=blockPath, ...
            ParameterVec=[{'PrimaryDeviceOption'}, mosfetOnlyParameters],Visibility='on');

        h.getDialogControl("PrimaryOpenMOSFETMask").Visible = "on";
        h.getDialogControl("PrimaryApplyMOSFETParam").Visible = "on";
        h.getDialogControl("PrimaryOpenMOSFETMask").Enabled = "on";
        h.getDialogControl("PrimaryApplyMOSFETParam").Enabled = "on";
    otherwise
        disp('Select the proper primary switch option')
end
end
