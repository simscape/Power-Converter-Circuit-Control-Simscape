function setVisibilityForMaskParameter(options)
%
%   setVisibilityForMaskParameter(options) sets the visibility of specified mask
%   parameters for a Simulink block mask.
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
%       setVisibilityMaskParameter(opts);

% Copyright 2025-2026 The MathWorks, Inc.

arguments (Input)
    options.BlockPath char
    options.ParameterVec
    options.Visibility char
end
maskHandle = Simulink.Mask.get(options.BlockPath);
for i=1:length( options.ParameterVec)
  maskHandle.Parameters(find(string({maskHandle.Parameters.Name}) == ...
      options.ParameterVec{i})).Visible = options.Visibility;
end
end