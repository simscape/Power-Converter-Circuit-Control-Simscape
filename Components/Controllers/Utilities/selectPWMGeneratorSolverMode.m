function selectPWMGeneratorSolverMode(blockPath)
%SELECTPWMGENERATORSOLVERMODE Select the sawtooth ramp implementation.
%   selectPWMGeneratorSolverMode(blockPath) sets the active choice of every Ramp Mode
%   variant subsystem inside a PWM generator block from the block's solverMode
%   parameter. It shows the sample time Ts only for the fixed-step choice. The
%   choices are VariableStep, a continuous Integrator with no declared rate, and
%   FixedStep, a Discrete-Time Integrator clocked at Ts.
%
%   A block may hold more than one ramp, at any depth, so the variants are found by the
%   "Ramp Mode" suffix on their names rather than by one fixed path or a depth limit.
%   The CLLC generator has two, one inside each of its two subsystems: Ramp Mode for the
%   primary sawtooth and Rectifier Ramp Mode for the synchronous rectifier turn-on
%   delay. Both follow the one popup, since the solver a model runs under is a property
%   of the model and not of one ramp.
%
%   See also pwmGeneratorMaskInit, setVisibilityForMaskParameter.

% Copyright 2026 The MathWorks, Inc.

solverModeChoice = get_param(blockPath, 'solverMode');
% A Ramp Mode block is itself a Variant Subsystem, so MatchFilter is required rather than
% cosmetic: without it find_system warns that it skipped the inactive choice, and it also
% misses a ramp nested inside an inactive choice. @Simulink.match.allVariants searches
% every choice, which is what "every Ramp Mode variant, at any depth" asks for, and it
% needs no compiled model - @Simulink.match.activeVariants does, and a mask initialization
% runs before the model compiles.
rampModeLocations = find_system(blockPath, 'MatchFilter', @Simulink.match.allVariants, ...
    'LookUnderMasks', 'all', 'FollowLinks', 'on', 'Regexp', 'on', ...
    'BlockType', 'SubSystem', 'Name', 'Ramp Mode$');

% Only the fixed-step ramp uses a sample time, so hide it otherwise.
fixedStepOnlyParameters = {'Ts'};
existingParameters = get_param(blockPath, 'MaskNames');
fixedStepOnlyParameters = fixedStepOnlyParameters( ...
    ismember(fixedStepOnlyParameters, existingParameters));

if strcmp(solverModeChoice, 'Fixed-step (discrete)')
    activeChoice = 'FixedStep';
    sampleTimeVisibility = 'on';
elseif strcmp(solverModeChoice, 'Variable-step (continuous)')
    activeChoice = 'VariableStep';
    sampleTimeVisibility = 'off';
else
    return
end

% Compare before writing. This runs on every dialog open, not only on a change, and writing
% the choice a variant already holds throws Simulink:Libraries:LockViolation on a locked
% library.
for k = 1:numel(rampModeLocations)
    setControllerVariantActiveChoice(rampModeLocations{k}, activeChoice);
end
setVisibilityForMaskParameter(BlockPath=blockPath, ...
    ParameterVec=fixedStepOnlyParameters, Visibility=sampleTimeVisibility);

end
