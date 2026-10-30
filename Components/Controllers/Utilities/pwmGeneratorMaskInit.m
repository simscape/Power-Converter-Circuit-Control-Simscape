function pwmGeneratorMaskInit(blockPath)
%PWMGENERATORMASKINIT Initialize a PWM generator block mask.
%   pwmGeneratorMaskInit(blockPath) re-applies every mask popup choice of a PWM
%   generator block. A block copied into a new model then has its variant selection
%   and its parameter visibility consistent with its stored mask values.
%
%   See also selectPWMGeneratorSolverMode.

% Copyright 2026 The MathWorks, Inc.

selectPWMGeneratorSolverMode(blockPath);

end
