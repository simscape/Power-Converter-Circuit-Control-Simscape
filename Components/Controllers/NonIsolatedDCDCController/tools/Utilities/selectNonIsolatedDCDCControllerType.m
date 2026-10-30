function selectNonIsolatedDCDCControllerType(blockPath)
%SELECTNONISOLATEDDCDCCTRLCONTROLLERTYPE Mask callback for continuous/discrete.
%
%   One selector drives both loops, so the cascade is either entirely continuous
%   or entirely discrete. Each loop still owns its own sample time, and a sample
%   time is shown only when that loop both exists and is discrete.

% Copyright 2026 The MathWorks, Inc.

controllerChoice = get_param(blockPath, 'cntrlSelect');
isDiscrete = strcmp(controllerChoice, 'PI controller (Discrete)');
isDoubleLoop = strcmp(get_param(blockPath, 'loopStructure'), 'Double loop');

% The outer voltage loop is present in both structures.
applyControllerDomain([blockPath, '/Voltage Controller'], controllerChoice);
setVisibilityForMaskParameter(BlockPath=blockPath, ...
    ParameterVec={'TsVoltage'}, Visibility=onOff(isDiscrete));

% The inner current loop lives inside the double-loop variant choice. Its
% variant can be switched even while that choice is inactive, which keeps the two
% loops in step for the next time the double loop is selected.
applyControllerDomain([blockPath, '/Loop Structure/DoubleLoop/Current Controller'], ...
    controllerChoice);
setVisibilityForMaskParameter(BlockPath=blockPath, ...
    ParameterVec={'TsCurrent'}, Visibility=onOff(isDiscrete && isDoubleLoop));

end

% ------------------------------------------------------------------------
function applyControllerDomain(controllerLoc, controllerChoice)
% Switch one loop's label-mode variant subsystem to match the selector. A dialog open
% runs this with the choice already in force, so the write compares first: writing the
% value a block already holds throws Simulink:Libraries:LockViolation on a locked library.
switch controllerChoice
    case 'PI controller (Continuous)'
        setControllerVariantActiveChoice(controllerLoc, 'PIContinuous');
    case 'PI controller (Discrete)'
        setControllerVariantActiveChoice(controllerLoc, 'PIDiscrete');
    otherwise
        error('nonIsolatedDCDC:unknownControllerType', ...
            'Unsupported controller type "%s".', controllerChoice);
end
end

% ------------------------------------------------------------------------
function visibility = onOff(isVisible)
if isVisible
    visibility = 'on';
else
    visibility = 'off';
end
end
