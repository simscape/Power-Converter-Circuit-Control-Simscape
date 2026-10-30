function setControllerVariantActiveChoice(variantPath, activeChoice)
%SETCONTROLLERVARIANTACTIVECHOICE Point a label-mode Variant Subsystem at one of its choices.
%   setControllerVariantActiveChoice(variantPath, activeChoice) sets the active choice of the
%   Variant Subsystem at variantPath, but only when it does not already hold that choice.
%   Writing the value a block already holds still counts as modifying the block, which throws
%   Simulink:Libraries:LockViolation on a locked library.
%   A mask callback runs on every dialog open, not
%   only when the value changes, so it has to compare before it writes.
%
%   Input Arguments:
%   ----------------
%   variantPath : Character vector specifying the path to the Variant Subsystem block.
%   activeChoice : Character vector specifying the variant choice label to activate.
%
%   Example:
%   --------
%       setControllerVariantActiveChoice('MyModel/Controller/Output Mode', 'PWMSignal');
%
%   See also setVisibilityForMaskParameter.

% Copyright 2026 The MathWorks, Inc.

arguments
    variantPath (1,:) char
    activeChoice (1,:) char
end

if ~strcmp(get_param(variantPath, 'LabelModeActiveChoice'), activeChoice)
    set_param(variantPath, 'LabelModeActiveChoice', activeChoice);
end

end
