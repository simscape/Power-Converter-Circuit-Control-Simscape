function setTotemPoleDialogVisibility(blockPath, controlNames, visibility)
%SETTOTEMPOLEDIALOGVISIBILITY Show or hide totem-pole plant mask controls by name.
%   setTotemPoleDialogVisibility(BLOCKPATH, CONTROLNAMES, VISIBILITY) sets 'Visible' to
%   VISIBILITY ('on' or 'off') on every mask control named in CONTROLNAMES. Names may be
%   mask parameters or dialog controls such as pushbuttons, so one call can hide a
%   device's parameters and its buttons together.
%
%   Names the mask does not declare are skipped. These callbacks serve the plant block in
%   the model, the copy in ConverterPlantLibrary and any exported subsystem. Those copies
%   are not always at the same parameter set. The shared setVisibilityForMaskParameter
%   errors on an unknown name instead, so a new mask parameter needs no guard here.

% Copyright 2026 The MathWorks, Inc.

arguments
    blockPath (1,:) char
    controlNames cell
    visibility (1,:) char {mustBeMember(visibility, {'on', 'off'})}
end

maskHandle = Simulink.Mask.get(blockPath);
if isempty(maskHandle)
    return;
end

declaredParameterNames = string({maskHandle.Parameters.Name});

for nameIndex = 1:numel(controlNames)
    controlName = controlNames{nameIndex};

    % Write only when the visibility changes. Assigning the value a control
    % already holds still counts as modifying the block, which throws
    % Simulink:Libraries:LockViolation on a locked library and dirties a clean model.
    parameterIndex = find(declaredParameterNames == controlName, 1);
    if ~isempty(parameterIndex)
        if ~strcmp(maskHandle.Parameters(parameterIndex).Visible, visibility)
            maskHandle.Parameters(parameterIndex).Visible = visibility;
        end
        continue;
    end

    % Not a parameter, so try the dialog controls (buttons, text, images). This search
    % is recursive, so a button nested in a collapsible group is found.
    try
        dialogControl = maskHandle.getDialogControl(controlName);
    catch
        dialogControl = [];
    end
    if ~isempty(dialogControl) && ~strcmp(dialogControl.Visible, visibility)
        dialogControl.Visible = visibility;
    end
end

end
