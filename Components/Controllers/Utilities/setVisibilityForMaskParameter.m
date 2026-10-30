function setVisibilityForMaskParameter(options)
%SETVISIBILITYFORMASKPARAMETER Show or hide parameters on a Simulink block mask.
%   setVisibilityForMaskParameter(options) sets the visibility of the named mask
%   parameters on a Simulink block mask.
%
%   Input Arguments:
%   ----------------
%   options : struct
%       Structure with the following fields:
%         - BlockPath     : Character vector specifying the path to the Simulink block.
%         - ParameterVec  : Cell array of character vectors specifying the names of the mask parameters to update.
%         - Visibility    : Character vector specifying the desired visibility state ('on' or 'off').
%
%   Example:
%   --------
%       opts.BlockPath = 'myModel/myBlock';
%       opts.ParameterVec = {'Gain', 'Offset'};
%       opts.Visibility = 'off';
%       setVisibilityForMaskParameter(opts);

% Copyright 2025-2026 The MathWorks, Inc.

arguments (Input)
    options.BlockPath char
    options.ParameterVec
    options.Visibility char
end
maskHandle = Simulink.Mask.get(options.BlockPath);
parameterNames = string({maskHandle.Parameters.Name});
for i = 1:numel(options.ParameterVec)
  parameterIndex = find(parameterNames == options.ParameterVec{i}, 1);
  if isempty(parameterIndex)
    continue
  end
  % Write only when the visibility changes. Assigning the value a parameter
  % already holds still counts as modifying the block, which throws
  % Simulink:Libraries:LockViolation on a locked library and dirties a clean model.
  if ~strcmp(maskHandle.Parameters(parameterIndex).Visible, options.Visibility)
    maskHandle.Parameters(parameterIndex).Visible = options.Visibility;
  end
end
end