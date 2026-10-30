function bridgePath = getCLLCBridgePath(blockPath, bridgeName)
%GETCLLCBRIDGEPATH Locate a CLLC full-bridge variant subsystem inside the plant block.
%
%   bridgePath = getCLLCBridgePath(blockPath, 'Primary Converter Full Bridge')
%
% The device-selection callbacks need the path of the bridge whose variant choice they set. That
% path depends on whether the block has been restructured into the top-level Simplified/Detailed
% variant, so it is resolved by search rather than hard-coded: an earlier LLC block hard-coded a
% variant child name inside its mask and threw "Unable to find block" the moment that child was
% renamed.
%
% Only the Detailed branch carries a bridge variant - the Simplified branch hard-wires ideal
% switches - so when several matches exist the Detailed one wins.

% Copyright 2026 The MathWorks, Inc.

candidatePaths = find_system(blockPath, 'MatchFilter', @Simulink.match.allVariants, ...
    'LookUnderMasks', 'all', 'BlockType', 'SubSystem', 'Name', bridgeName);

if isempty(candidatePaths)
    error('getCLLCBridgePath:notFound', ...
        'No block named "%s" found inside "%s".', bridgeName, blockPath);
end

if numel(candidatePaths) > 1
    detailedMatches = candidatePaths(contains(candidatePaths, '/DetailedModel/'));
    if ~isempty(detailedMatches)
        candidatePaths = detailedMatches;
    end
end

bridgePath = candidatePaths{1};
end
