function selectTotemPolePFCControllerType(blockPath)
%SELECTTOTEMPOLEPFCCTRLCONTROLLERTYPE Switch both cascaded PI loops between continuous and discrete.
%   One dropdown drives the outer voltage loop and the inner current loop together.
%   A mixed continuous and discrete cascade is not offered, because it needs a
%   rate transition between the loops.
%
%   This controller keeps its sample times visible when the continuous PI is
%   selected. See the note beside the visibility call below.

% Copyright 2025-2026 The MathWorks, Inc.

cntrlChoice = get_param(blockPath, 'cntrlSelect');

if strcmp(cntrlChoice, 'PI controller (Continuous)')
    activeChoice = 'PIContinuous';
elseif strcmp(cntrlChoice, 'PI controller (Discrete)')
    activeChoice = 'PIDiscrete';
else
    return
end

% Both loops carry the same variant choices. The existence check keeps this
% callback usable on a block whose contents have not been updated yet, instead
% of failing on the first missing path.
loopBlockNames = {'Voltage Controller', 'Current Controller'};
for loopIndex = 1:numel(loopBlockNames)
    loopBlockPath = [blockPath, '/', loopBlockNames{loopIndex}];
    if getSimulinkBlockHandle(loopBlockPath) > 0
        set_param(loopBlockPath, 'LabelModeActiveChoice', activeChoice);
    end
end

% Both sample times stay visible in both time domains, which departs from the
% convention in the rest of ConverterLibrary (where a Ts is hidden whenever the
% continuous PI is active). The convention holds where Ts is used by nothing but
% the discrete PID. Here each Ts has a second, always-active job:
%   TsVoltage - rate of the 'Per-Unit Scaling/Vmeas ADC Sample' unit delay
%   TsCurrent - rate of the 'Per-Unit Scaling/Imeas ADC Sample' and
%               'Per-Unit Scaling/Vac ADC Sample' unit delays, which also set the rate
%               the gate logic sees the line voltage at
% Those blocks sit outside the PI variant subsystems, so they keep sampling when
% the continuous PI is selected. Hiding either parameter would leave a hidden
% value still setting a sample rate you can see in the results but not reach
% on the dialog.
setVisibilityIfParameterExists(blockPath, 'TsVoltage', 'on');
setVisibilityIfParameterExists(blockPath, 'TsCurrent', 'on');

end

function setVisibilityIfParameterExists(blockPath, parameterName, visibility)
% Guarded wrapper: setVisibilityForMaskParameter indexes the parameter list
% directly and errors on a name that is not there.

maskObject = Simulink.Mask.get(blockPath);
if any(strcmp({maskObject.Parameters.Name}, parameterName))
    setVisibilityForMaskParameter(BlockPath=blockPath, ...
        ParameterVec={parameterName}, Visibility=visibility);
end

end
