function selectDCDCControllerType(blockPath)
%SELECTDCDCCONTROLLERTYPE Mask callback for controller variant selection.

% Copyright 2025-2026 The MathWorks, Inc.

% The Non-Isolated DC-DC Controller can run as a single loop (inner duty
% controller only) or a double loop (outer voltage PI cascaded into the inner
% loop). Each loop has its own continuous/discrete controller-type selector,
% mapped here onto its own variant subsystem. The matching discrete
% sample-time parameter is shown only when that loop is present and discrete.

% --- Inner loop (always present) ---
innerChoice = get_param(blockPath, 'cntrlSelect');
innerCtrlLoc = [blockPath, '/Controller'];
applyLoopChoice(innerChoice, innerCtrlLoc);
setVisibilityForMaskParameter(BlockPath=blockPath, ...
    ParameterVec={'TsController'}, ...
    Visibility=discreteVisibility(innerChoice));

% --- Outer voltage loop (only active in the double-loop structure) ---
% Library copies of the block that predate the single/double-loop option have no
% loopStructure parameter and no outer voltage loop to switch, so stop here
% rather than erroring out of the mask initialization.
maskObject = Simulink.Mask.get(blockPath);
if isempty(maskObject.getParameter('loopStructure'))
    return
end

isDoubleLoop = strcmp(get_param(blockPath, 'loopStructure'), 'Double loop');
voltageChoice = get_param(blockPath, 'cntrlSelectVoltage');
voltageCtrlLoc = [blockPath, '/Loop Structure/DoubleLoop/Voltage PI'];
if isDoubleLoop
    % The double-loop branch is active, so its nested voltage-loop variant
    % can be switched and its discrete sample time may be exposed.
    applyLoopChoice(voltageChoice, voltageCtrlLoc);
    tsVoltageVisibility = discreteVisibility(voltageChoice);
else
    % Single-loop structure: the voltage loop is unused; hide its sample time.
    % (The voltage variant is synced when the double loop is next activated.)
    tsVoltageVisibility = 'off';
end
setVisibilityForMaskParameter(BlockPath=blockPath, ...
    ParameterVec={'TsVoltage'}, Visibility=tsVoltageVisibility);

end

% ------------------------------------------------------------------------
function applyLoopChoice(choice, variantLoc)
% Switch one loop's label-mode variant subsystem to match its selector.
if strcmp(choice, 'PI controller (Continuous)')
    set_param(variantLoc, 'LabelModeActiveChoice', 'PIContinuous');
elseif strcmp(choice, 'PI controller (Discrete)')
    set_param(variantLoc, 'LabelModeActiveChoice', 'PIDiscrete');
end
end

% ------------------------------------------------------------------------
function vis = discreteVisibility(choice)
% Discrete controllers expose a sample-time parameter; continuous ones hide it.
if strcmp(choice, 'PI controller (Discrete)')
    vis = 'on';
else
    vis = 'off';
end
end
