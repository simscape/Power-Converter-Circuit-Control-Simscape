function selectDABControllerType(blockPath)
%SELECTDABCTRLCONTROLLERTYPE Switch the DAB control loops between continuous and discrete.
%   selectDABControllerType(blockPath) applies the mask controller-type choice to
%   both the CC current loop and the CV voltage loop, and shows Ts only for a discrete
%   controller.
%
%   The gating If block's rate is not set here. Its SampleTime field holds the expression
%   gatingSampleTimeForControllerType(cntrlSelect, Ts), so the rate follows the mask on its
%   own. A mask cannot set a parameter of a block that sits inside a library link, so
%   writing that rate made this controller error as soon as it was dragged out of a library
%   and switched to a discrete controller.
%
%   One selector drives both loops on purpose. The two loops are If Action Subsystems
%   gated by a single If block. They must therefore share a time domain and, when
%   discrete, the same sample time, so separate selectors allow a configuration
%   that cannot compile.

% Copyright 2025-2026 The MathWorks, Inc.

controllerChoice = get_param(blockPath, 'cntrlSelect');

% The single selector drives both loops' variant subsystems identically.
currentCtrlLoc = [blockPath, '/CC-CV Control/CC Mode/Controller'];
applyLoopChoice(currentCtrlLoc, controllerChoice);

voltageCtrlLoc = [blockPath, '/CC-CV Control/CV Mode/Voltage PI'];
applyLoopChoice(voltageCtrlLoc, controllerChoice);

% Ts is the discrete controllers' rate, so it is shown only for them.
if strcmp(controllerChoice, 'PI controller (Discrete)')
    setVisibilityForMaskParameter(BlockPath=blockPath, ParameterVec={'Ts'}, Visibility='on');
else
    setVisibilityForMaskParameter(BlockPath=blockPath, ParameterVec={'Ts'}, Visibility='off');
end

end

% ------------------------------------------------------------------------
function applyLoopChoice(variantLoc, choice)
% Switch one loop's variant subsystem to match the common controller-type
% selector. A dialog open runs this with the choice already in force, so it
% compares before writing: writing the choice a variant already holds throws
% Simulink:Libraries:LockViolation on a locked library.
if strcmp(choice, 'PI controller (Continuous)')
    setControllerVariantActiveChoice(variantLoc, 'PIContinuous');
elseif strcmp(choice, 'PI controller (Discrete)')
    setControllerVariantActiveChoice(variantLoc, 'PIDiscrete');
end
end
