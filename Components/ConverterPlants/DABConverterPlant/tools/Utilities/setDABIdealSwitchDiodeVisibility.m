function setDABIdealSwitchDiodeVisibility(blockPath, side, visibility)
%SETDABIDEALSWITCHDIODEVISIBILITY Toggle Ideal-Switch protection-diode mask params.
%
%   setDABIdealSwitchDiodeVisibility(blockPath, side, visibility) shows or hides
%   the Ideal Semiconductor Switch protection-diode parameters for the requested
%   bridge side. Those are the forward voltage Vf, the on resistance Rd and the
%   off conductance Gd, each with its unit popup.
%
%   Input Arguments:
%   ----------------
%   blockPath  : Path to the DAB Converter plant block.
%   side       : 'Pri' for the primary bridge or 'Sec' for the secondary bridge.
%   visibility : 'on' or 'off'.
%
%   The diode parameters only exist on plant blocks that expose them. Older
%   copies do not have these parameters, for example the library DAB plant. This
%   helper first checks which of them are present and only toggles those.
%   This keeps the shared mask callbacks safe to reuse across every DAB plant
%   instance regardless of whether the diode parameters have been added.

% Copyright 2025-2026 The MathWorks, Inc.

maskObj = Simulink.Mask.get(blockPath);
existingNames = string({maskObj.Parameters.Name});

diodeParams = {['Vf' side], ['Vf' side '_unit'], ...
               ['Rd' side], ['Rd' side '_unit'], ...
               ['Gd' side], ['Gd' side '_unit']};

presentParams = diodeParams(ismember(diodeParams, existingNames));

if ~isempty(presentParams)
    setVisibilityForMaskParameter(BlockPath=blockPath, ParameterVec=presentParams, Visibility=visibility);
end

end
