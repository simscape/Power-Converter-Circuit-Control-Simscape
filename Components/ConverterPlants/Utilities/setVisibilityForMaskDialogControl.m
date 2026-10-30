function setVisibilityForMaskDialogControl(options)
%SETVISIBILITYFORMASKDIALOGCONTROL Show or hide dialog controls on a Simulink block mask.
%   setVisibilityForMaskDialogControl(options) sets the visibility of the named dialog
%   controls on a Simulink block mask. Use it for buttons and groups, which are
%   dialog controls rather than mask parameters.
%
%   Input Arguments:
%   ----------------
%   options : struct
%       Structure with the following fields:
%         - BlockPath   : Character vector specifying the path to the Simulink block.
%         - ControlVec  : Cell array of character vectors specifying the names of the dialog controls to update.
%         - Visibility  : Character vector specifying the desired visibility state ('on' or 'off').
%
%   Example:
%   --------
%       opts.BlockPath = 'myModel/myBlock';
%       opts.ControlVec = {'openMOSFETMask', 'applyMOSFETParam'};
%       opts.Visibility = 'off';
%       setVisibilityForMaskDialogControl(opts);

% Copyright 2025-2026 The MathWorks, Inc.

arguments (Input)
    options.BlockPath char
    options.ControlVec
    options.Visibility char
end
maskHandle = Simulink.Mask.get(options.BlockPath);
for i = 1:numel(options.ControlVec)
  dialogControl = maskHandle.getDialogControl(options.ControlVec{i});
  if isempty(dialogControl)
    continue
  end
  % Write only when the visibility changes. Assigning the value a control already
  % holds still counts as modifying the block, which throws
  % Simulink:Libraries:LockViolation on a locked library and dirties a clean model.
  if ~strcmp(dialogControl.Visible, options.Visibility)
    dialogControl.Visible = options.Visibility;
  end
end
end
