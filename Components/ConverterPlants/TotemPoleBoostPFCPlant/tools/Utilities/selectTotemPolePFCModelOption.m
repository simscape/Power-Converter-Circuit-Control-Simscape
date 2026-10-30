function selectTotemPolePFCModelOption(blockPath)
%SELECTTOTEMPOLEPFCMODELOPTION Mask callback for the Simplified/Detailed variant.
%   Switches the top-level model-option variant and then puts the whole device section
%   of the dialog into the state that option implies.

% Copyright 2025-2026 The MathWorks, Inc.

choice = get_param(blockPath, 'modelOption');

variantPath = [blockPath, '/TotemPoleBoostPFCVariant'];
switch choice
    case 'Simplified'
        activeChoice = 'SimplifiedModel';
    case 'Detailed'
        activeChoice = 'DetailedModel';
    otherwise
        warning('selectTotemPolePFCModelOption: Invalid selection: %s', choice);
        activeChoice = '';
end

if ~isempty(activeChoice)
    setVariantActiveChoice(variantPath, activeChoice);
end

controlGroups = totemPoleMaskControlGroups();

if strcmp(choice, 'Simplified')
    % The Simplified branch is four ideal switches and the passive components. Both
    % legs' switch data and both protection diodes apply; there is no thermal device,
    % no standalone diode and no thyristor, so those controls must go off explicitly.
    % Leaving them to whatever the last Detailed selection set is how the simulation
    % temperature and the holding current used to leak onto this dialog.
    setTotemPoleDialogVisibility(blockPath, [ ...
        controlGroups.fastSwitch, controlGroups.fastBodyDiode, ...
        controlGroups.slowSwitch, controlGroups.slowBodyDiode], 'on');
    setTotemPoleDialogVisibility(blockPath, [ ...
        controlGroups.slowDiode, controlGroups.fastThermal, ...
        controlGroups.slowThermal, controlGroups.slowHolding, ...
        controlGroups.legPopups, controlGroups.nestedPopups, ...
        controlGroups.fastButtons, controlGroups.slowMOSFETButtons, ...
        controlGroups.slowDiodeButtons], 'off');
end

if strcmp(choice, 'Detailed')
    setTotemPoleDialogVisibility(blockPath, controlGroups.legPopups, 'on');
    selectTotemPolePFCFastLeg(blockPath);
    selectTotemPolePFCSlowLeg(blockPath);
end

end
