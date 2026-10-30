function dabControllerMaskInit(blockPath)
%DABCONTROLLERMASKINIT Apply the DAB controller mask dropdowns to the block contents.
%   dabControllerMaskInit(blockPath) runs every selector callback on the DAB
%   controller mask, so the block contents match the dialog box.

% Copyright 2025-2026 The MathWorks, Inc.

selectDABControllerType(blockPath);
selectDABControllerOutputMode(blockPath);

end
