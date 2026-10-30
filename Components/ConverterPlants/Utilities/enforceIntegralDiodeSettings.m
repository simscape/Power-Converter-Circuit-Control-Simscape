function issues = enforceIntegralDiodeSettings(deviceBlocks, options)
%ENFORCEINTEGRALDIODESETTINGS Correct or report device diode settings a plant cannot honor.
%   ISSUES = enforceIntegralDiodeSettings(DEVICEBLOCKS) finds the settings listed by
%   getIntegralDiodeSettingIssues on every device block in DEVICEBLOCKS and corrects them.
%
%   ISSUES = enforceIntegralDiodeSettings(DEVICEBLOCKS, OnIssue="warn") reports them in
%   the Command Window and writes nothing.
%
%   Correcting is what an automated parameterization does: applyConverterPart writes a
%   whole catalog data set, so a setting the plant cannot honor is corrected on the spot
%   and you never see it. Reporting is what a manual action does: the plant
%   mask's "Apply parameters to all ..." buttons copy what you typed into one device
%   onto its siblings, and silently changing a value you chose hides the choice
%   rather than explain it.
%
%   Inputs:
%     deviceBlocks  Block path, handle, or cell array of either, naming Simscape device
%                   blocks.
%
%   Name-value options:
%     OnIssue  "correct" to write the corrections, "warn" to report them and write
%              nothing. Default "correct".
%     Display  Print each correction. Default false. Ignored when OnIssue is "warn",
%              which always reports.
%
%   Outputs:
%     issues  Struct array as returned by getIntegralDiodeSettingIssues, with one extra
%             field, wasCorrected, true for each issue this call wrote.
%
%   Example:
%     % Correct, as the part-selection workflow does.
%     enforceIntegralDiodeSettings(mosfetBlock);
%
%     % Report, as a plant mask button does.
%     enforceIntegralDiodeSettings(mosfetBlock, OnIssue="warn");
%
%   See also getIntegralDiodeSettingIssues, applyPartToDeviceRole, applyConverterPart.

% Copyright 2026 The MathWorks, Inc.

arguments
    deviceBlocks
    options.OnIssue (1,1) string {mustBeMember(options.OnIssue, ["correct" "warn"])} = "correct"
    options.Display (1,1) logical = false
end

issues = addCorrectedField(getIntegralDiodeSettingIssues(deviceBlocks));
if isempty(issues)
    return
end

for issueIndex = 1:numel(issues)
    thisIssue = issues(issueIndex);

    % An issue whose correction would delete a connected port carries no writes, so it is
    % reported whichever mode this is called in.
    canCorrect = options.OnIssue == "correct" && ~isempty(thisIssue.writes);

    if canCorrect
        for writeIndex = 1:numel(thisIssue.writes)
            set_param(thisIssue.deviceBlock, thisIssue.writes(writeIndex).Name, ...
                thisIssue.writes(writeIndex).Value);
        end
        issues(issueIndex).wasCorrected = true;
        if options.Display
            fprintf('   %s: %s\n', blockLabel(thisIssue.deviceBlock), thisIssue.message);
        end
    else
        % One identifier per rule, so you can switch the
        % message off with warning('off', ...).
        warningIdentifier = char("enforceIntegralDiodeSettings:" + thisIssue.issueKind);
        warning(warningIdentifier, '%s %s\n         Device: %s', ...
            blockLabel(thisIssue.deviceBlock) + ":", thisIssue.message, thisIssue.deviceBlock);
    end
end

end

% ======================================================================
function issues = addCorrectedField(issues)
% Add wasCorrected whether or not anything was found. A caller that accumulates the
% results of one call per device block concatenates struct arrays, which needs the same
% field set every time, so an empty result has to carry the field too.
if isempty(issues)
    issues = reshape(struct('deviceBlock', {}, 'issueKind', {}, 'parameterName', {}, ...
        'currentValue', {}, 'writes', {}, 'message', {}, 'wasCorrected', {}), 0, 1);
    return
end
for issueIndex = 1:numel(issues)
    issues(issueIndex).wasCorrected = false;
end
end

% ======================================================================
function label = blockLabel(deviceBlock)
% Last two path elements, which is enough to tell sibling devices apart without printing
% the whole variant path.
pathParts = split(string(deviceBlock), "/");
label = strjoin(pathParts(max(1, end-1):end), "/");
end
