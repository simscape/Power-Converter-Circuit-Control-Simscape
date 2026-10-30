function setPWMRampVariantChoice(generatorPath, rampChoice)
%SETPWMRAMPVARIANTCHOICE Point every carrier ramp inside a PWM generator at one implementation.
%   setPWMRampVariantChoice(generatorPath, rampChoice) sets the active choice of every Ramp
%   Mode variant subsystem inside the PWM generator at generatorPath. rampChoice is
%   'VariableStep' for the continuous ramp or 'FixedStep' for the discrete one.
%
%   A generator holds one ramp per sawtooth, at any depth, so the variants are found by the
%   "Ramp Mode" suffix on their names rather than by a fixed path. The CLLC generator has
%   two, the primary sawtooth and the synchronous rectifier turn-on delay, and both follow
%   the one choice, since the solver a model runs under is a property of the model and not
%   of one ramp.
%
%   A variant active choice is instance data, so this write is legal on a block inside a
%   library link. Writing a mask parameter of such a block is not, which is why a controller
%   selects the ramp itself instead of setting the generator's solver mode.
%
%   The call does nothing when the generator is absent, which keeps a controller whose
%   modulator sits inside an inactive variant choice silent.
%
%   Input Arguments:
%   ----------------
%   generatorPath : Character vector specifying the path to the PWM generator subsystem.
%   rampChoice    : Character vector, 'VariableStep' or 'FixedStep'.
%
%   Example:
%   --------
%       setPWMRampVariantChoice('MyModel/Controller/LLC PWM Generator', 'FixedStep');
%
%   See also applyDerivedPWMCarrier, setControllerVariantActiveChoice.

% Copyright 2026 The MathWorks, Inc.

arguments
    generatorPath (1,:) char
    rampChoice (1,:) char {mustBeMember(rampChoice, {'VariableStep', 'FixedStep'})}
end

if getSimulinkBlockHandle(generatorPath) <= 0
    return
end

% MatchFilter is required rather than cosmetic here. A Ramp Mode block is itself a Variant
% Subsystem, so without it find_system warns that it skipped an inactive choice, and it
% misses a ramp nested inside one. allVariants needs no compiled model, which activeVariants
% does, and a mask initialization runs before the model compiles.
rampModeLocations = find_system(generatorPath, 'MatchFilter', @Simulink.match.allVariants, ...
    'LookUnderMasks', 'all', 'FollowLinks', 'on', 'Regexp', 'on', ...
    'BlockType', 'SubSystem', 'Name', 'Ramp Mode$');

for rampIndex = 1:numel(rampModeLocations)
    setControllerVariantActiveChoice(rampModeLocations{rampIndex}, rampChoice);
end

end
