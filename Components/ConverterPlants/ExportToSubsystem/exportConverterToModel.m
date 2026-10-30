function exportedModel = exportConverterToModel(blockPath, targetDir, structName, modelName, options)
%EXPORTCONVERTERTOMODEL Export a masked converter library block to a standalone model.
%   exportedModel = EXPORTCONVERTERTOMODEL(blockPath, targetDir, structName)
%   takes a configured converter library block and produces, in targetDir:
%     1. <modelName>.slx - a standalone model whose top level is a single
%        subsystem (carrying the block icon). Inside is the unmasked circuit,
%        reduced to the topology and device fidelity that the mask had selected
%        at export time, with no variant subsystems left. It has no links back
%        to the custom converter library (product-library links to
%        fl_lib/ee_lib/etc. are kept - those are the Simscape component
%        definitions).
%     2. <modelName>_params.m - a script that assigns every parameter into a
%        base-workspace struct (DAB.Lr = 3e-5; % H, ...). The exported
%        model's PreLoadFcn runs this file.
%
%   Parameter expressions are kept as formulas rather than baked to numbers,
%   with each mask "_SI" variable retargeted to its struct field. The parametric
%   relationships remain editable in the M-file.
%
%   The parameter mask is replaced by an icon-only mask, so the exported block
%   still reads as the converter it came from while its internals are open.
%
%   exportedModel = EXPORTCONVERTERTOMODEL(blockPath, targetDir, structName, modelName)
%   sets the model name (such as a timestamped "DAB_exported_23Jul_154805")
%   instead of the default "<structName>_exported". The base-workspace struct
%   still uses the clean structName so the retargeted formulas stay readable.
%
%   The circuit is reduced to the variant choice that was active at export time,
%   leaving no variant machinery. This uses the native Variant Reducer and
%   requires the "Variant Manager for Simulink" add-on and its license.
%
%   exportedModel = EXPORTCONVERTERTOMODEL(..., FlattenToActiveVariant=false)
%   instead keeps every variant subsystem, and needs no add-on.
%
%   Inputs:
%     blockPath  - full path to the configured library block (like gcb)
%     targetDir  - folder to write the model and M-file into
%     structName - base name for the parameter struct (like 'DAB')
%     modelName  - (optional) model / file base name; default [structName '_exported']
%
%   Name-value arguments:
%     FlattenToActiveVariant - reduce to the active choice; default true
%
%   A generic exporter driven by the library's shared architecture
%   (variant subsystems + "_SI" mask variables via convMap). It is not
%   specific to any one converter.

% Copyright 2026 The MathWorks, Inc.

arguments
    blockPath (1,:) char
    targetDir (1,:) char
    structName (1,:) char
    modelName (1,:) char = ''   % optional; defaults to [structName '_exported']
    options.FlattenToActiveVariant (1,1) logical = true
end

if ~exist(targetDir, 'dir')
    mkdir(targetDir);
end

% The model file name. Callers can set a timestamped name (such as
% "DAB_exported_23Jul_154805") so repeated exports do not overwrite each other;
% otherwise fall back to the plain "<struct>_exported".
if isempty(modelName)
    modelName = [structName '_exported'];
end

% ------------------------------------------------------------------
% 1. Read the active mask configuration (parameter values + units) and capture
%    the icon SVG before anything is flattened, so it can be re-applied as an
%    icon-only mask.
% ------------------------------------------------------------------
maskObj = Simulink.Mask.get(blockPath);
paramInfo = readMaskParameters(maskObj);   % struct array: name, value, unit, siName, description
iconSpec = captureIcon(maskObj);

% ------------------------------------------------------------------
% 2. Create the target model and copy the block in.
% ------------------------------------------------------------------
exportedModel = modelName;
if bdIsLoaded(exportedModel)
    close_system(exportedModel, 0);
end
new_system(exportedModel);
load_system(exportedModel);

topBlock = [exportedModel '/' get_param(blockPath, 'Name')];
add_block(blockPath, topBlock);

% Break the top-level link immediately so we can edit the copy.
if ~strcmp(get_param(topBlock, 'LinkStatus'), 'none')
    set_param(topBlock, 'LinkStatus', 'none');
end

% ------------------------------------------------------------------
% 2b. Scrub every custom-library link before flattening. Some library
%     blocks contain intra-library links - a block linked to a SIBLING block in
%     the same library (like Boost PFC's SimplifiedModel/Iin -> .../SimplifiedModel/IL).
%     These resolve correctly against the live library here, so breaking them now
%     converts each into a self-contained local copy with its content intact.
%     If we waited until after reduceModel (step 6), reduceModel would first
%     rebase them to its transient reduced-model name ("ConverterLibrary_r"),
%     leaving them unresolved (no content, uncompilable). Breaking pre-flatten
%     avoids that. Step 6 repeats the scrub as a safety net.
% ------------------------------------------------------------------
scrubCustomLibraryLinks(topBlock);

% ------------------------------------------------------------------
% 2c. Replay any imperative write the mask Initialization performs on an inner
%     block, so the copy carries the literal the mask would have produced. Each
%     write is recorded (by path relative to the top block) for step 4c.
% ------------------------------------------------------------------
maskWrittenParams = replayMaskInitializationWrites(blockPath, topBlock, maskObj);

% ------------------------------------------------------------------
% 3. Flatten every variant subsystem to a plain subsystem containing only its
%    active choice (zero variants remain), using the native Variant Reducer
%    (Simulink.VariantManager.reduceModel). It reconnects via Simulink's own
%    engine, so it preserves branched Simscape physical nets and
%    signal/PS-Converter/gate routing that a geometry rebuild cannot.
%
%    On by default, which is the point of the button: the export is a plain
%    editable circuit at the configuration you selected, with no variant
%    machinery left to navigate. Set FlattenToActiveVariant=false to keep every
%    choice instead, which also removes the add-on requirement.
% ------------------------------------------------------------------
if options.FlattenToActiveVariant
    topBlock = flattenViaReduceModel(exportedModel, topBlock);

    % ------------------------------------------------------------------
    % 3b. Restore the original library layout. reduceModel preserves connectivity
    %     and hierarchy (wrappers kept as normal subsystems) but re-lays-out the
    %     diagram, moving nearly every block. Because the flattened hierarchy and
    %     block names match the source block exactly, copy each block's Position and
    %     Orientation back from the library block by relative path, so the exported
    %     circuit looks identical to the library block.
    %
    %     Only needed after reduction: the plain block copy of step 2 already
    %     carries the library layout untouched.
    % ------------------------------------------------------------------
    restoreLayoutFromLibrary(blockPath, topBlock);
end

% ------------------------------------------------------------------
% 4. Retarget parameter expressions from "_SI" vars to struct fields.
% ------------------------------------------------------------------
retargetParameters(topBlock, paramInfo, structName);

% ------------------------------------------------------------------
% 4b. Capture DEVICE-block parameters (thermal MOSFET, Temperature Source,
%     Thermal Resistor, tabulated diode, ...) into the struct. These blocks
%     hold literal values directly (not driven by the converter mask), so after
%     retargeting their visible edit fields still hold literals - we externalize
%     each into a per-role sub-struct (DAB.SwitchPri.*, DAB.SwitchSec.*) and
%     rewrite the block to reference it, so they become editable from the M-file.
% ------------------------------------------------------------------
extraParams = captureDeviceParams(topBlock, structName);

% ------------------------------------------------------------------
% 4c. Externalize the values step 2c replayed. The source mask computes them and
%     pushes them in with num2str, so the copy holds a bare number where every
%     other parameter now holds a struct reference - and a number cannot be
%     edited from the M-file. Move each into the struct and point the block at it,
%     so the whole exported circuit is driven from one file.
% ------------------------------------------------------------------
extraParams = externalizeMaskWrittenParams( ...
    topBlock, structName, maskWrittenParams, extraParams);

% ------------------------------------------------------------------
% 5. Replace the original (parameter-laden) mask with an icon-only mask
%    that embeds the active-config SVG. The subsystem internals stay fully
%    open and editable; only a cosmetic icon remains on the block face.
% ------------------------------------------------------------------
applyIconOnlyMask(topBlock, exportedModel, structName, iconSpec);

% ------------------------------------------------------------------
% 6. Scrub every remaining custom-library link (keep product libs).
% ------------------------------------------------------------------
scrubCustomLibraryLinks(topBlock);

% ------------------------------------------------------------------
% 7. Write the parameter M-file.
% ------------------------------------------------------------------
% Name the parameter file after the (possibly timestamped) MODEL so each export
% carries its own file, but the base-workspace struct keeps the clean name so
% the retargeted formulas (like DAB.Lr) stay readable and editable.
mFileName = [modelName '_params.m'];
mFilePath = fullfile(targetDir, mFileName);
writeParamFile(mFilePath, structName, paramInfo, extraParams);

% ------------------------------------------------------------------
% 8. Wire PreLoadFcn to run the M-file (and re-emit the embedded icon),
%    then save the model.
% ------------------------------------------------------------------
set_param(exportedModel, 'PreLoadFcn', sprintf('run(''%s'');', mFileName));
% Run it now so the freshly-opened model already has the struct. An undefined
% variable here means an inner block referenced something the plant mask's
% Initialization derives that retargetParameters does not know about, so the
% identifier reached the M-file verbatim. Name that cause instead of letting the
% bare MATLAB error surface a long way from its origin.
% Run it in the BASE workspace. A bare run() inside a function executes the
% script in the FUNCTION's workspace, so the struct the exported model needs was
% created and then discarded on return - leaving the just-exported model open but
% uncompilable until someone closed and reopened it to fire the PreLoadFcn.
try
    evalin('base', sprintf('run(''%s'');', mFilePath));
catch paramFileError
    if strcmp(paramFileError.identifier, 'MATLAB:UndefinedFunction')
        error('exportConverterToModel:unresolvedMaskVariable', ...
            ['The generated parameter file does not evaluate: %s\n' ...
             'An inner block references a variable derived by the plant ' ...
             'mask Initialization that the retarget dictionary does not ' ...
             'register. It knows the bare mask name, the "_SI" name and the ' ...
             '"_K" temperature form; add the missing form in ' ...
             'retargetParameters.\nParameter file kept for inspection: %s'], ...
            paramFileError.message, mFilePath);
    end
    rethrow(paramFileError);
end

save_system(exportedModel, fullfile(targetDir, [exportedModel '.slx']));

fprintf('Exported:\n  %s\n  %s\n', fullfile(targetDir, [exportedModel '.slx']), mFilePath);

end

% ======================================================================
function topBlock = flattenViaReduceModel(exportedModel, topBlock)
% Flatten every Variant Subsystem to its active choice using the native Variant
% Reducer (Simulink.VariantManager.reduceModel). Returns the (possibly updated)
% top-block path. Requires the "Variant Manager for Simulink" add-on.
%
% Two things reduceModel needs that we handle here:
%   (a) It compiles the model to validate and does not save output if that
%       compile fails. Our subsystem has no Solver Configuration (the solver
%       lives in your harness), so a bare compile fails
%       NoSolverBlockConnected. We add a TEMPORARY Solver Configuration on the
%       top block's first connection port before reducing, and remove it after.
%   (b) reduceModel writes the reduced model into an output folder with a
%       suffixed name. We load it back, rename it to the original model name,
%       and swap it in for the pre-reduction model so the downstream steps
%       (retarget, icon mask, scrub, params) operate on the reduced model.

% Preflight: the native Variant Reducer requires the "Variant Manager for
% Simulink" add-on. Without it, reduceModel fails with an uncatchable low-level
% error, so check up front and report the install steps.
assertVariantManagerAvailable();

topName = get_param(topBlock, 'Name');

% (a) Add a temporary Solver Configuration so the validation compile passes.
tmpSolver = [exportedModel '/__ExportTmpSolver'];
solverAdded = false;
try
    connNames = simscape.connectionPortProperties(topBlock);
    if ~isempty(connNames)
        add_block('nesl_utility/Solver Configuration', tmpSolver, ...
            'Position', [20 20 60 60]);
        simscape.addConnection(tmpSolver, 'port', topBlock, connNames(1).Name, ...
            'autorouting', 'on');
        solverAdded = true;
    end
catch ME
    if getSimulinkBlockHandle(tmpSolver) > 0, delete_block(tmpSolver); end
    warning('exportConverterToModel:tmpSolver', ...
        'Could not attach temporary Solver Configuration: %s', ME.message);
end

% Save the model so reduceModel has a file to work on.
reduceDir = fullfile(tempdir, ['reduce_' exportedModel]);
if exist(reduceDir, 'dir'), rmdir(reduceDir, 's'); end
mkdir(reduceDir);
preReduceFile = fullfile(reduceDir, [exportedModel '.slx']);
save_system(exportedModel, preReduceFile);

% Run the native Variant Reducer.
%   RemoveVariantSubsystemLayer = FALSE: keep each Variant Subsystem wrapper as a
%   normal (Variant='off') subsystem holding only its active choice, and preserve
%   the internal layout untouched. Setting it true instead pulls the active-choice
%   blocks up a level, which forces a full re-route of every line (visually
%   chaotic). We keep the wrapper layer so the exported circuit looks exactly like
%   the library block - just with zero variants.
suffix = '_r';
outFolder = fullfile(reduceDir, 'reducedModel');
Simulink.VariantManager.reduceModel(exportedModel, ...
    'RemoveVariantSubsystemLayer', false, ...
    'ModelSuffix', suffix, ...
    'OutputFolder', outFolder);

reducedName = [exportedModel suffix];
reducedFile = fullfile(outFolder, [reducedName '.slx']);
if ~exist(reducedFile, 'file')
    error('exportConverterToModel:reduceFailed', ...
        'Variant Reducer did not produce %s.', reducedFile);
end

% Swap the reduced model in for the original: close the pre-reduction model,
% load the reduced one, and rename it back to the original model name.
close_system(exportedModel, 0);
load_system(reducedFile);
save_system(reducedName, fullfile(reduceDir, [exportedModel '.slx']), ...
    'OverwriteIfChangedOnDisk', true);
close_system(reducedName, 0);
load_system(fullfile(reduceDir, [exportedModel '.slx']));

% (a-cont) Remove the temporary Solver Configuration from the reduced model.
tmpSolver = [exportedModel '/__ExportTmpSolver'];
if solverAdded && getSimulinkBlockHandle(tmpSolver) > 0
    deleteBlockAndLines(tmpSolver);
end

% (b) Remove the Ground/Terminator caps reduceModel adds at the root level on
%     the top block's open ports (the converter's gate inputs and measurement
%     output). These are validation-compile artifacts; the exported subsystem
%     must expose open ports for your harness to connect to.
capBlocks = find_system(exportedModel, 'SearchDepth', 1, 'LookUnderMasks', 'none', ...
    'FollowLinks', 'off', 'RegExp', 'on', 'BlockType', 'Ground|Terminator');
for i = 1:numel(capBlocks)
    deleteBlockAndLines(capBlocks{i});
end

% Return the top-block path (name is preserved through reduction).
topBlock = [exportedModel '/' topName];
end

% ======================================================================
function assertVariantManagerAvailable()
% Verify the "Variant Manager for Simulink" add-on is installed and enabled.
% Simulink.VariantManager.reduceModel needs it; without it, it fails with an
% uncatchable low-level error. Error early with clear install instructions.
%
% Do not rely on license('test','Variant_Manager') - it can report 0 even
% when the add-on is installed (stale in-session license cache). The reliable
% source is the installed-add-ons table.
available = false;
try
    a = matlab.addons.installedAddons;
    match = contains(lower(string(a.Name)), 'variant manager') & logical(a.Enabled);
    available = any(match);
catch
    % If the add-ons API itself is unavailable, fall through to the error below.
end

if ~available
    error('exportConverterToModel:variantManagerMissing', ...
        ['The "Variant Manager for Simulink" add-on is required to export an ' ...
         'unmasked subsystem, but it is not installed (or not enabled).\n\n' ...
         'To install it:\n' ...
         '  1. On the MATLAB Home tab, click Add-Ons > Get Add-Ons.\n' ...
         '  2. Search for "Variant Manager for Simulink".\n' ...
         '  3. Click Add / Install and follow the prompts.\n' ...
         '  4. Restart MATLAB so the add-on activates.\n\n' ...
         'Then click "Export to Unmasked Subsystem" again.']);
end
end

% ======================================================================
function deleteBlockAndLines(blk)
% Delete a block after removing every line on its ports.
lh = get_param(blk, 'LineHandles');
for f = fieldnames(lh)'
    h = lh.(f{1});
    h = h(h ~= -1);
    for i = 1:numel(h), try, delete_line(h(i)); catch, end; end
end
delete_block(blk);
end

% ======================================================================
function restoreLayoutFromLibrary(libBlock, expBlock)
% Reinstate the library block's exact visual layout on the exported model.
% reduceModel preserves connectivity and hierarchy (wrappers kept as normal
% subsystems with identical block names) but re-lays out the diagram, moving
% nearly every block and rerouting every line. Because the flattened hierarchy
% and block names match the source block one-to-one, we can copy the layout back:
%   (1) block Position + Orientation, matched by path relative to each top.
%   (2) line routing (Points), matched net by net, at every depth. We only set
%       Points (never delete/add lines), so branched Simscape physical nets are
%       left structurally untouched.
%
% Three properties of Simulink line geometry shape part (2), each of which broke
% an earlier single-line-at-a-time implementation that left most of a converter's
% wiring at whatever reduceModel drew:
%   - A physical net is a flat set of segments. Every segment reports the whole
%     set in LineChildren, itself included, and LineParent is -1 on all of them.
%     find_system returns only one representative per net, so iterating
%     find_system reaches a minority of the segments.
%   - A net is drawn as the union of its segment polylines, so reproducing the
%     library's set of polylines reproduces the library's picture; which exported
%     segment gets which polyline does not matter to the result.
%   - Setting one segment's Points moves its siblings, because a branch point is
%     shared. The sets fight each other, so the assignment and the order are
%     searched and the result verified against the library.

% --- (1) block Position + Orientation ---
expBlocks = find_system(expBlock, 'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
    'Type', 'block');
for i = 1:numel(expBlocks)
    if strcmp(expBlocks{i}, expBlock), continue; end
    rel = strrep(expBlocks{i}, [expBlock '/'], '');
    libCand = [libBlock '/' rel];
    if getSimulinkBlockHandle(libCand) <= 0, continue; end
    try
        set_param(expBlocks{i}, 'Position',    get_param(libCand, 'Position'));
        set_param(expBlocks{i}, 'Orientation', get_param(libCand, 'Orientation'));
    catch
        % Some mask internals reject Position edits; skip.
    end
end
try
    set_param(expBlock, 'Position',    get_param(libBlock, 'Position'));
    set_param(expBlock, 'Orientation', get_param(libBlock, 'Orientation'));
catch
end

% --- (2) line routing, per subsystem scope, at every depth ---
% The scope set is expBlock plus every SubSystem under it. expBlock is itself a
% SubSystem so find_system returns it too; without unique, every top-level net
% would be restored twice.
expScopes = unique([{expBlock}; find_system(expBlock, 'LookUnderMasks', 'all', ...
    'FollowLinks', 'on', 'BlockType', 'SubSystem')], 'stable');
for s = 1:numel(expScopes)
    expScope = expScopes{s};
    rel = strrep(expScope, [expBlock '/'], '');
    if strcmp(expScope, expBlock)
        libScope = libBlock;
    else
        libScope = [libBlock '/' rel];
    end
    if getSimulinkBlockHandle(libScope) <= 0, continue; end
    % A line inside a resolved library link cannot be modified
    % (Simulink:Libraries:RefModificationViolation) and need not be: a linked
    % block's interior is its library definition.
    if isInsideLinkedBlock(expScope, expBlock), continue; end
    copyNetRouting(libScope, expScope);
end
end

% ======================================================================
function tf = isInsideLinkedBlock(scope, expBlock)
% True when this scope, or any ancestor below expBlock, resolves a library link.
tf = false;
current = scope;
while ~strcmp(current, expBlock)
    try
        if ~strcmp(get_param(current, 'LinkStatus'), 'none')
            tf = true;
            return;
        end
    catch
        % A block with no LinkStatus property cannot be a link.
    end
    % Ask Simulink for the parent rather than splitting the path text: a literal
    % forward slash in a block name is escaped as '//', which fileparts would cut
    % in the wrong place.
    current = get_param(current, 'Parent');
    if isempty(current), return; end
end
end

% ======================================================================
function copyNetRouting(libScope, expScope)
% Make every net in expScope draw exactly as the same net in libScope. Only sets
% Points on existing lines - never deletes or adds - so connectivity, including
% every branched physical net, is untouched.
libNets = collectScopeNets(libScope);
expNets = collectScopeNets(expScope);
if libNets.Count == 0 || expNets.Count == 0, return; end

expKeys = keys(expNets);
for i = 1:numel(expKeys)
    if isKey(libNets, expKeys{i})
        reproduceNet(libNets(expKeys{i}), expNets(expKeys{i}));
    end
end
end

% ======================================================================
function netMap = collectScopeNets(scope)
% Group one scope's line segments into nets, keyed by the set of block:port
% endpoints the net touches. The key is built from connectivity only, so a
% re-laid-out export still matches its library counterpart.
netMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
ambiguous = {};
reps = find_system(scope, 'SearchDepth', 1, 'LookUnderMasks', 'all', ...
    'FollowLinks', 'on', 'FindAll', 'on', 'Type', 'line');

seen = [];
for i = 1:numel(reps)
    if any(seen == reps(i)), continue; end
    % Every segment of a net lists the whole net in LineChildren, itself
    % included, so one get_param yields the complete segment set.
    segs = unique([reps(i); reshape(get_param(reps(i), 'LineChildren'), [], 1)]);
    seen = [seen; segs]; %#ok<AGROW>

    anchors = cell(numel(segs), 1);
    endpoints = {};
    for k = 1:numel(segs)
        segEnds = segmentEndpoints(segs(k), scope);
        anchors{k} = strjoin(sort(segEnds), '+');
        endpoints = [endpoints, segEnds]; %#ok<AGROW>
    end
    if isempty(endpoints), continue; end

    netKey = strjoin(unique(endpoints), ';');
    if isKey(netMap, netKey)
        % Two nets touching the same ports cannot be told apart; drop both rather
        % than risk copying geometry onto the wrong one.
        ambiguous{end+1} = netKey; %#ok<AGROW>
    else
        netMap(netKey) = struct('segments', segs, 'anchors', {anchors});
    end
end
for i = 1:numel(ambiguous)
    if isKey(netMap, ambiguous{i}), remove(netMap, ambiguous{i}); end
end
end

% ======================================================================
function endpointList = segmentEndpoints(lineHandle, scope)
% The resolved block:port endpoints of one segment. A branch segment has an
% unresolved source, an unresolved destination, or both, so the count varies.
endpointList = {};
for p = 1:2
    if p == 1
        ports = get_param(lineHandle, 'SrcPortHandle');
    else
        ports = get_param(lineHandle, 'DstPortHandle');
    end
    for k = 1:numel(ports)
        if ports(k) == -1, continue; end
        endpointList{end+1} = sprintf('%s|%s|%d', ...
            strrep(get_param(ports(k), 'Parent'), [scope '/'], ''), ...
            get_param(ports(k), 'PortType'), ...
            get_param(ports(k), 'PortNumber')); %#ok<AGROW>
    end
end
end

% ======================================================================
function reproduceNet(libNet, expNet)
% Install the library net's polylines on the exported net's segments, then verify
% that the net now draws the same picture. Because setting one segment moves its
% siblings, both the assignment of trunk polylines and the order of the sets are
% searched, and every attempt is checked against the library.
target = sort(polylineSet(libNet.segments));
if isequal(sort(polylineSet(expNet.segments)), target), return; end

% A segment carrying a port is identified by that port. A trunk segment carries
% none, so which library trunk polyline belongs on it has to be searched.
libTrunks = [];
libByAnchor = containers.Map('KeyType', 'char', 'ValueType', 'any');
for i = 1:numel(libNet.segments)
    if isempty(libNet.anchors{i})
        libTrunks = [libTrunks; libNet.segments(i)]; %#ok<AGROW>
    else
        libByAnchor(libNet.anchors{i}) = libNet.segments(i);
    end
end
anchoredPairs = zeros(0, 2);
expTrunks = [];
for i = 1:numel(expNet.segments)
    if isempty(expNet.anchors{i})
        expTrunks = [expTrunks; expNet.segments(i)]; %#ok<AGROW>
    elseif isKey(libByAnchor, expNet.anchors{i})
        anchoredPairs(end+1, :) = [expNet.segments(i), ...
            libByAnchor(expNet.anchors{i})]; %#ok<AGROW>
    end
end
trunkCount = min(numel(expTrunks), numel(libTrunks));
if isempty(anchoredPairs) && trunkCount == 0, return; end

original = arrayfun(@(h) get_param(h, 'Points'), expNet.segments, ...
    'UniformOutput', false);
bestScore = numel(intersect(sort(polylineSet(expNet.segments)), target));
best = original;

for assignment = trunkAssignments(trunkCount)
    pairing = anchoredPairs;
    for t = 1:trunkCount
        pairing(end+1, :) = [expTrunks(t), libTrunks(assignment{1}(t))]; %#ok<AGROW>
    end
    for order = setOrders(size(pairing, 1))
        writeNetPoints(expNet.segments, original);
        for step = order{1}
            try
                set_param(pairing(step, 1), 'Points', ...
                    get_param(pairing(step, 2), 'Points'));
            catch
                % A read-only or rejected segment keeps its current geometry.
            end
        end
        current = sort(polylineSet(expNet.segments));
        if isequal(current, target), return; end
        score = numel(intersect(current, target));
        if score > bestScore
            bestScore = score;
            best = arrayfun(@(h) get_param(h, 'Points'), expNet.segments, ...
                'UniformOutput', false);
        end
    end
end

% No attempt reproduced the library exactly; keep the closest result rather than
% reverting to what the variant reduction drew.
writeNetPoints(expNet.segments, best);
end

% ======================================================================
function assignments = trunkAssignments(trunkCount)
% Which library trunk polyline to try on which exported trunk segment. Every
% permutation for a small net, identity only for a large one.
if trunkCount == 0
    assignments = {[]};
elseif trunkCount <= 4
    assignments = num2cell(perms(1:trunkCount), 2)';
else
    assignments = {1:trunkCount};
end
end

% ======================================================================
function orders = setOrders(pairCount)
% Orders to apply the sets in. The search exists because setting one segment moves
% its siblings, so only the final state matters.
identity = 1:pairCount;
if pairCount <= 4
    orders = num2cell(perms(identity), 2)';
    return;
end
orders = {identity, fliplr(identity)};
for shift = 1:min(4, pairCount - 1)
    orders{end+1} = circshift(identity, shift); %#ok<AGROW>
end
end

% ======================================================================
function writeNetPoints(segments, pointsList)
% Restore a snapshot of one net's geometry. Applied twice because each set moves
% the siblings already written, and the snapshot is self-consistent.
for repeat = 1:2
    for i = 1:numel(segments)
        try
            set_param(segments(i), 'Points', pointsList{i});
        catch
            % A read-only segment cannot be restored; it was never changed.
        end
    end
end
end

% ======================================================================
function polylines = polylineSet(segments)
% Each segment's Points serialized, so two nets compare regardless of order.
polylines = cell(numel(segments), 1);
for i = 1:numel(segments)
    polylines{i} = mat2str(get_param(segments(i), 'Points'));
end
end

% ======================================================================
function paramInfo = readMaskParameters(maskObj)
% Build a struct array of the numeric mask parameters (edit fields), each
% paired with its unit popup value and its "_SI" variable name.
paramInfo = struct('name', {}, 'value', {}, 'unit', {}, 'siName', {}, 'description', {});
for i = 1:numel(maskObj.Parameters)
    p = maskObj.Parameters(i);
    % Skip unit popups and non-edit controls; keep numeric edit fields.
    if strcmp(p.Type, 'popup') || endsWith(p.Name, '_unit')
        continue;
    end
    if ~strcmp(p.Type, 'edit')
        continue;   % skip selectors (model option, series inductor)
    end
    unitParam = maskObj.getParameter([p.Name '_unit']);
    unitStr = '';
    if ~isempty(unitParam)
        unitStr = unitParam.Value;
    end
    entry.name = p.Name;
    entry.value = p.Value;
    entry.unit = unitStr;
    entry.siName = [p.Name '_SI'];    % convention: mask init defines <name>_SI
    entry.description = p.Prompt;
    paramInfo(end+1) = entry; %#ok<AGROW>
end
end

% ======================================================================
function iconSpec = captureIcon(maskObj)
% Capture the block's icon before flattening: the SVG file content, so the
% icon-only mask applied in step 5 can embed it.
%
% The port names are part of the SVG drawing, so there is nothing else to carry.
iconSpec = struct('svgContent', '');
display = maskObj.Display;

% Extract the SVG filename from an image('file.svg') call and read it.
tok = regexp(display, 'image\(\s*''([^'']+\.svg)''', 'tokens', 'once');
if ~isempty(tok)
    svgFile = which(tok{1});
    if isempty(svgFile)
        svgFile = tok{1};   % maybe already a full path
    end
    if exist(svgFile, 'file')
        iconSpec.svgContent = fileread(svgFile);
    end
end
end

% ======================================================================
function applyIconOnlyMask(topBlock, exportedModel, structName, iconSpec)
% Remove the original parameter-laden mask and apply an icon-only mask that
% draws the embedded SVG. The SVG content is stored in the model workspace
% and written to a temp file by the model's PreLoadFcn (self-contained, no
% external SVG dependency).

% Drop the inherited mask (parameters, init, callbacks all reference the
% pre-flatten structure and are no longer valid).
if ~isempty(Simulink.Mask.get(topBlock))
    Simulink.Mask.get(topBlock).delete;
end

svgVarName = [structName '_iconSVG'];
svgFileName = [structName '_icon.svg'];

if ~isempty(iconSpec.svgContent)
    % Store SVG content in the model workspace (travels inside the .slx).
    mdlWS = get_param(exportedModel, 'ModelWorkspace');
    assignin(mdlWS, svgVarName, iconSpec.svgContent);

    % PreLoadFcn writes the SVG to a temp dir so the icon can reference it.
    iconEmit = sprintf([ ...
        'svgDir = fullfile(tempdir, ''%s_icon'');\n' ...
        'if ~exist(svgDir, ''dir''), mkdir(svgDir); end\n' ...
        'svgFile = fullfile(svgDir, ''%s'');\n' ...
        'mdlWS = get_param(bdroot, ''ModelWorkspace'');\n' ...
        'fid = fopen(svgFile, ''w''); fwrite(fid, getVariable(mdlWS, ''%s'')); fclose(fid);'], ...
        structName, svgFileName, svgVarName);
    existingPre = get_param(exportedModel, 'PreLoadFcn');
    set_param(exportedModel, 'PreLoadFcn', sprintf('%s\n%s', iconEmit, existingPre));
    % Emit it now so the icon renders in this session too. Use the explicit
    % model workspace (not bdroot, which may not resolve to the exported model
    % mid-export) and getVariable to fetch the stored SVG content.
    svgDir = fullfile(tempdir, [structName '_icon']);
    if ~exist(svgDir, 'dir'), mkdir(svgDir); end
    svgOut = fullfile(svgDir, svgFileName);
    fid = fopen(svgOut, 'w');
    fwrite(fid, getVariable(mdlWS, svgVarName));
    fclose(fid);

    % Build the icon-only mask display.
    displayLines = { ...
        sprintf('svgFile = fullfile(tempdir, ''%s_icon'', ''%s'');', structName, svgFileName), ...
        'image(svgFile, [0 0 1 1]);'};
    % No port_label() calls. Every plant icon draws its own port names inside the
    % SVG, so a generated label lands on top of the drawn one and the two overlap.
    % The source plant masks add none either, which is what makes the exported
    % block read exactly like the library block it came from.
    newMask = Simulink.Mask.create(topBlock);
    newMask.Display = strjoin(displayLines, newline);
    % Keep the outer block border visible (MaskIconFrame 'on') so the exported
    % block reads as a bordered block, not a borderless image.
    set_param(topBlock, 'MaskIconUnits', 'normalized', 'MaskIconFrame', 'on');
end
end

% ======================================================================
function maskWrittenParams = replayMaskInitializationWrites(sourceBlock, topBlock, maskObj)
% Land a plant mask's imperative inner-block writes onto the exported copy.
%
% Most plant masks drive an inner block declaratively: the block's dialog holds an
% expression in mask variables, which retargetParameters rewrites to struct
% fields. A mask may instead push a value in with set_param from its
% Initialization. The LLC plant is the one that does, for the center-tapped
% transformer, because the value depends on the rectifier topology popup:
%     turnsRatio = n/2 (Center-Tap) or n;   set_param(xfmrBlk__,'n',num2str(turnsRatio));
%     set_param(xfmrBlk__,'L2', num2str(2*Llk2))  or  num2str(Llk2);
%
% A parameter written that way is saved empty in the .slx - it only ever holds a
% value while the mask is evaluating - and the export replaces the parameter mask
% with an icon-only mask (step 5). Nothing would refill it, so the exported
% transformer shipped n = '' and L2 = '', which fails to evaluate. The export
% itself died here first: retargetParameters set_params its way through the same
% block and Simulink rejected the empty mask value.
%
% Replaying is more faithful than teaching the exporter each formula: evaluate the
% Initialization in a sandbox where every mask parameter holds its evaluated
% value and "gcb" names the exported top block, so the mask's own set_param calls
% execute against the copy and write exactly what the mask would have written.
%
% Only masks that call set_param are replayed. Evaluating an
% Initialization has side effects, so there is no reason to run it for the six
% plants that need nothing from it.
%
% Returns one record per write - relativePath (from topBlock), paramName, value -
% so step 4c can move the value into the parameter struct.

maskWrittenParams = struct('relativePath', {}, 'paramName', {}, 'value', {});

initCode = get_param(sourceBlock, 'MaskInitialization');
if isempty(initCode) || ~contains(initCode, 'set_param')
    return;
end

% Seed the sandbox with every mask parameter: an edit field evaluated in the base
% workspace (values are frequently design-struct references), a popup or unit
% selector as its literal string.
sandbox = struct();
unresolvedNames = {};
for i = 1:numel(maskObj.Parameters)
    p = maskObj.Parameters(i);
    rawValue = get_param(sourceBlock, p.Name);
    if strcmp(p.Type, 'edit')
        numericValue = str2double(rawValue);
        if isnan(numericValue)
            try
                numericValue = evalin('base', rawValue);
            catch
                % The base workspace cannot resolve this dialog value. Record it:
                % the Initialization is about to fail on whichever unseeded name
                % it reads first, and that error alone does not say why.
                unresolvedNames{end+1} = sprintf('%s = %s', p.Name, rawValue); %#ok<AGROW>
                continue;
            end
        end
        sandbox.(p.Name) = numericValue;
    else
        sandbox.(p.Name) = rawValue;
    end
end

% containers.Map is a handle object, so the recorder can append to it from inside
% the evaluated code. A plain struct or cell would be copied and the writes lost.
writeLog = containers.Map('KeyType', 'char', 'ValueType', 'any');

try
    evaluateMaskInitializationInSandbox(initCode, sandbox, topBlock, writeLog);
    maskWrittenParams = collectRecordedWrites(writeLog, topBlock);
catch replayError
    % Never fail the export over the replay: the empty parameter it would have
    % filled is reported downstream, and naming the cause here is more useful
    % than aborting.
    if isempty(unresolvedNames)
        unresolvedReport = '';
    else
        unresolvedReport = sprintf( ...
            '\nThese dialog values do not resolve in the base workspace: %s', ...
            strjoin(unresolvedNames, ', '));
    end
    warning('exportConverterToModel:maskInitReplay', ...
        ['Could not replay the mask Initialization onto the copy (%s).%s\nAny ' ...
         'inner-block parameter the mask writes with set_param stays empty in ' ...
         'the export.'], replayError.message, unresolvedReport);
end
end

% ======================================================================
function evaluateMaskInitializationInSandbox(initCode, sandbox, topBlock, writeLog)
% Evaluate mask Initialization code with the mask parameters in scope.
%
% Two names are deliberately shadowed by variables, because a variable takes
% precedence over a function of the same name:
%   gcb       - holds the exported top block path, so an inner-block path the
%               Initialization builds ([gcb '/Resonant Tank/...']) addresses the
%               copy rather than the library block it came from.
%   set_param - holds a function handle that performs the real write and logs it,
%               so step 4c knows which parameters the mask supplied.
gcb = topBlock; %#ok<NASGU> - referenced by the evaluated Initialization code
set_param = @(varargin) recordMaskWrite(writeLog, varargin{:}); %#ok<NASGU>

parameterNames = fieldnames(sandbox);
for nameIndex = 1:numel(parameterNames)
    eval([parameterNames{nameIndex} ' = sandbox.(parameterNames{nameIndex});']);
end

eval(initCode);
end

% ======================================================================
function recordMaskWrite(writeLog, blockPath, varargin)
% Perform a mask Initialization's set_param and log the parameter it wrote.
%
% Only the block's own name-value pairs are logged. Inside this function
% set_param is the real Simulink function again, since the shadowing variable
% belongs to the caller's workspace.
set_param(blockPath, varargin{:});

% A mask may address a block by handle rather than by path. That write still
% happens, it just cannot be carried into the parameter struct, which needs a path
% that survives into the exported model.
if ~(ischar(blockPath) || isstring(blockPath))
    return;
end

for pairIndex = 1:2:numel(varargin) - 1
    paramName = varargin{pairIndex};
    if ~(ischar(paramName) || isstring(paramName))
        continue;
    end
    record.blockPath = char(blockPath);
    record.paramName = char(paramName);
    record.value = varargin{pairIndex + 1};
    % Keyed so a repeated write to the same parameter keeps only the last value,
    % which is what the mask leaves behind. The record carries the path itself, so
    % the key never has to be parsed back apart.
    writeLog(sprintf('%s | %s', record.blockPath, record.paramName)) = record;
end
end

% ======================================================================
function maskWrittenParams = collectRecordedWrites(writeLog, topBlock)
% Turn the recorded set_param calls into records keyed by relative block path.
%
% The path is stored relative to the top block because flattening (step 3) can
% rename it, and only the relative path is stable across that.
maskWrittenParams = struct('relativePath', {}, 'paramName', {}, 'value', {});
loggedWrites = values(writeLog);
for writeIndex = 1:numel(loggedWrites)
    loggedWrite = loggedWrites{writeIndex};
    if ~startsWith(loggedWrite.blockPath, topBlock)
        continue;   % the mask wrote outside the exported copy; not ours to carry
    end
    record.relativePath = extractAfter(loggedWrite.blockPath, numel(topBlock));
    record.paramName = loggedWrite.paramName;
    record.value = loggedWrite.value;
    maskWrittenParams(end+1) = record; %#ok<AGROW>
end
end

% ======================================================================
function extraParams = externalizeMaskWrittenParams( ...
    topBlock, structName, maskWrittenParams, extraParams)
% Move each value the source mask pushed in with set_param into the parameter
% struct, and point the block parameter at the new field.
%
% Without this the exported block keeps the bare number the mask produced with
% num2str, so editing the M-file has no effect on it - the one parameter in the
% export that silently ignores its own parameter file. The field is grouped under
% the block's name (like LLC.Transformer.n), matching how captureDeviceParams
% groups device literals.
%
% A written value that is not a plain number is left alone: the mask is setting
% something like a popup or a visibility, which is structure rather than data.

structPrefix = [structName '.'];
for recordIndex = 1:numel(maskWrittenParams)
    record = maskWrittenParams(recordIndex);
    blockPath = [topBlock record.relativePath];
    if getSimulinkBlockHandle(blockPath) <= 0
        continue;   % flattening dropped the block with its variant choice
    end

    writtenValue = record.value;
    if ~(ischar(writtenValue) || isstring(writtenValue))
        continue;
    end
    writtenValue = char(writtenValue);
    if isnan(str2double(writtenValue)) || contains(writtenValue, structPrefix)
        continue;
    end

    group = regexprep(get_param(blockPath, 'Name'), '[^A-Za-z0-9]', '');
    if isempty(group)
        group = 'MaskWritten';
    end

    % Two variant choices can hold same-named blocks. Sharing one field is only
    % correct when the value is identical, so a clash gets its own field name.
    field = record.paramName;
    existingIndex = find(strcmp({extraParams.group}, group) & ...
        strcmp({extraParams.field}, field), 1);
    if ~isempty(existingIndex) && ~strcmp(extraParams(existingIndex).value, writtenValue)
        field = sprintf('%s_%s', field, ...
            regexprep(record.relativePath, '[^A-Za-z0-9]', ''));
        existingIndex = [];
    end

    if isempty(existingIndex)
        entry.group = group;
        entry.field = field;
        entry.value = writtenValue;
        entry.unit = '';
        entry.description = maskWrittenDescription(blockPath, record.paramName);
        extraParams(end+1) = entry; %#ok<AGROW>
    end

    set_param(blockPath, record.paramName, ...
        sprintf('%s%s.%s', structPrefix, group, field));
end
end

% ======================================================================
function description = maskWrittenDescription(blockPath, paramName)
% Describe a mask-written parameter using the target block's own dialog prompt.
description = sprintf('%s, set by the source plant mask', paramName);
try
    targetMask = Simulink.Mask.get(blockPath);
    if ~isempty(targetMask)
        targetParam = targetMask.getParameter(paramName);
        if ~isempty(targetParam)
            description = sprintf('%s, set by the source plant mask', ...
                resolvePrompt(targetParam.Prompt));
        end
    end
catch
    % A block without a mask keeps the parameter-name description above.
end
end

% ======================================================================
function kelvinExpr = kelvinReplacement(structName, entry)
% Replacement text for a mask's derived "<name>_K" variable, reproducing the
% offset conversion the mask Initialization performs for the recorded unit.
% Returns '' when the parameter is not a temperature, so nothing is registered.
% The parentheses matter: the derived name can appear inside a larger expression.
structField = [structName '.' entry.name];
switch entry.unit
    case 'degC'
        kelvinExpr = ['(' structField ' + 273.15)'];
    case 'K'
        kelvinExpr = structField;       % already absolute, the mask copies it
    otherwise
        kelvinExpr = '';                % not a temperature parameter
end
end

% ======================================================================
function retargetParameters(topBlock, paramInfo, structName)
% Rewrite every block parameter expression that references a mask parameter
% variable so it points at the corresponding struct field.
%
% The library masks do not use a single naming convention for the
% workspace variable a block ultimately reads. The mask Initialization converts
% each displayed value to SI in one of two ways, and both styles coexist within
% a single converter:
%   (a) into a separate "_SI" variable:   Lr_SI = Lr * convMap(Lr_unit);
%       -> the block references  Lr_SI.
%   (b) reassigned in place, bare name:    RdsOn = RdsOn * convMap(RdsOn_unit);
%       -> the block references  RdsOn.
% Some pass-through params (such as turnsRatio, n) are never scaled and are read
% bare as well. A block therefore may reference a mask parameter as either its
% bare name or its "_SI" name. To stay convention-agnostic we register both
% forms for every mask edit parameter, all mapping to the same struct field, so
% the exporter works regardless of which style a given library block uses.
%
% We substitute in a single alternation pass (not sequential per-name passes):
% the replacement text (like "DAB.Lr") itself contains the token "Lr", so a
% second pass would corrupt it. A one-pass regexprep never re-scans text it has
% already produced.

% Build the retarget dictionary: variableName -> structName.baseName, covering
% both the bare mask name and the "_SI" name for every parameter.
dict = containers.Map('KeyType', 'char', 'ValueType', 'char');
for i = 1:numel(paramInfo)
    target = [structName '.' paramInfo(i).name];
    dict(paramInfo(i).name) = target;    % bare, like RdsOn, turnsRatio, Vin
    dict(paramInfo(i).siName) = target;  % _SI form, e.g. Lr_SI
end

% A temperature parameter needs a third form. Every other quantity converts from
% its displayed unit to SI by a scale factor, which the mask can do through
% convMap in either of the two styles above. Temperature is an offset, so the
% masks instead derive a separate "<name>_K" variable in an if/else on the unit
% popup:
%     if strcmp(simTempPri_unit,'degC'), simTempPri_K = simTempPri + 273.15;
%     else,                             simTempPri_K = simTempPri;
% and every thermal device block (Temperature Source, the MOSFET junction
% target, a tabulated diode's Tdevice) reads that "_K" name - which is neither
% the bare mask name nor the "_SI" name. Left unregistered it survives
% retargeting as a bare identifier, is copied verbatim into the parameter
% M-file, and the export dies running it: "Unrecognized function or variable
% 'simTempPri_K'". Register it as a formula rather than as its own struct field
% so the struct keeps one source of truth per quantity, in the unit the dialog
% shows.
for i = 1:numel(paramInfo)
    kelvinName = [paramInfo(i).name '_K'];
    if isKey(dict, kelvinName)
        continue;   % a real mask parameter of that name always wins
    end
    kelvinExpr = kelvinReplacement(structName, paramInfo(i));
    if ~isempty(kelvinExpr)
        dict(kelvinName) = kelvinExpr;
    end
end

varNames = dict.keys;
if isempty(varNames), return; end
% Longest names first, so "Lr_SI" is matched before "Lr". The word-anchored
% pattern already prevents "Lr" from matching inside "Lr_SI" (the trailing "_SI"
% is word characters, so \> does not match between "Lr" and "_"), but ordering
% longest-first is a robust safeguard for any future overlapping names.
[~, ord] = sort(cellfun(@numel, varNames), 'descend');
varNames = varNames(ord);
% Never substitute an identifier that is part of a dotted reference. A mask
% parameter's value is frequently a field of a base-workspace design struct (the
% LLC plant ships with Llk2 = "LLCDesign.Llk2"), and "\<" matches immediately
% after the dot because "." is not a word character. That rewrote
% "LLCDesign.Llk2" into "LLCDesign.LLC.Llk2", which is unresolvable, so the mask
% workspace evaluated Llk2 to [] and the mask initialization pushed
% num2str([]) = '' into the transformer's L2 - leaving an unevaluatable block
% parameter that aborted the export. The negative lookbehind keeps the
% start-of-word behavior of "\<" while also refusing a preceding ".".
pattern = ['(?<![\w.])(' strjoin(varNames, '|') ')\>'];
lookup = @(tok) dict(tok);   % referenced by the ${...} dynamic replacement

% A few dialog parameters hold an identifier - a signal, bus-element or tag name -
% rather than an expression to be evaluated. Substituting inside one of those
% renames the signal instead of retargeting a value: the LLC plant's measurement
% bus carries a Bus Element Out whose Element is "VIn [V]", which was being
% rewritten to "LLC.VIn [V]", an element no downstream consumer can find.
% These parameter names are Simulink-owned name fields and are never expressions,
% so they are always safe to skip.
identifierParams = {'Element', 'GotoTag', 'SignalName', 'VariableName', ...
                    'OutputSignals', 'InputSignalNames', 'Name'};

% MatchFilter allVariants: retarget every variant choice, not just the active one.
% An inactive branch keeps its own references to the mask variables (the DC-DC
% plant's ideal-switch branch reads VfBody_SI exactly as the thermal branch does),
% and those variables do not exist in the exported model. Left unretargeted, the
% export compiles only until you select a different choice.
allBlocks = find_system(topBlock, 'MatchFilter', @Simulink.match.allVariants, ...
    'LookUnderMasks', 'all', 'FollowLinks', 'on', 'Type', 'block');
for i = 1:numel(allBlocks)
    b = allBlocks{i};
    dp = get_param(b, 'DialogParameters');
    if isempty(dp), continue; end
    fn = fieldnames(dp);
    for f = 1:numel(fn)
        if any(strcmp(fn{f}, identifierParams)), continue; end
        try
            v = get_param(b, fn{f});
        catch
            continue;
        end
        if ~ischar(v) || isempty(v), continue; end
        newV = regexprep(v, pattern, '${lookup($1)}');
        if ~strcmp(newV, v)
            set_param(b, fn{f}, newV);
        end
    end
end

% Verification: no expression should still reference an undefined "_SI"
% variable. Any leftover indicates a stale library field (such as a dormant
% variant-mode parameter) that must be cleaned up at the source.
leftovers = {};
for i = 1:numel(allBlocks)
    b = allBlocks{i};
    dp = get_param(b, 'DialogParameters');
    if isempty(dp), continue; end
    fn = fieldnames(dp);
    for f = 1:numel(fn)
        try
            v = get_param(b, fn{f});
        catch
            continue;
        end
        if ischar(v) && ~isempty(regexp(v, '\<\w+_SI\>', 'once'))
            leftovers{end+1} = sprintf('%s (%s) = %s', ...
                get_param(b, 'Name'), fn{f}, v); %#ok<AGROW>
        end
    end
end
if ~isempty(leftovers)
    warning('exportConverterToModel:leftoverSI', ...
        ['%d block parameter(s) still reference an undefined "_SI" variable ' ...
         'after retargeting (likely stale library fields):\n  %s'], ...
        numel(leftovers), strjoin(leftovers, '\n  '));
end
end

% ======================================================================
function extraParams = captureDeviceParams(topBlock, structName)
% Externalize the visible EDIT parameters of DEVICE blocks (thermal MOSFET,
% Temperature Source, Thermal Resistor, tabulated diode, ...) into per-role
% sub-structs, and rewrite each block param to reference the struct.
%
% Device blocks hold literal values set by the library author (like Vth=2.4,
% temperature=293.15), unlike the converter's mask-driven passives (Co, Lr,
% transformer) whose params were already retargeted to DAB.* in step 4. So the
% selection rule is: a visible edit param whose value does not already reference
% the struct ("<structName>.") is a device param to externalize.
%
% Grouping ("grouped by role, shared"): all device blocks inside the same
% switch-device / device subsystem share one sub-struct, named from that
% subsystem's role (such as blocks under ".../PrimaryBridge/SwitchingMOSFETwithThermal"
% -> group "SwitchPri"; Secondary -> "SwitchSec"). Identical instances (the 4
% MOSFETs in a bridge) are captured once and all rewritten to the same field.
%
% Because every variant choice is now captured, two choices can land on the same
% group name: deviceGroupName maps both ".../MainSwitch/IdealSwitch" and
% ".../MainSwitch/SwitchingMOSFETwithThermal" to "Switch". Sharing a field across
% those is only correct when the value is identical, so a same-key/different-value
% collision is split out into its own group named after the wrapper subsystem.
%
% Returns a struct array of {group, field, value, unit, description} for the
% param-file writer.

extraParams = struct('group', {}, 'field', {}, 'value', {}, 'unit', {}, 'description', {});
seen = containers.Map('KeyType', 'char', 'ValueType', 'char');  % "group.field" -> value

structPrefix = [structName '.'];
% MatchFilter allVariants: capture the device blocks in every variant choice, so a
% choice you activate later is parameterized from the M-file too.
allBlocks = find_system(topBlock, 'MatchFilter', @Simulink.match.allVariants, ...
    'LookUnderMasks', 'all', 'FollowLinks', 'on', 'Type', 'block');
for i = 1:numel(allBlocks)
    b = allBlocks{i};
    mk = Simulink.Mask.get(b);
    if isempty(mk) || isempty(mk.Parameters), continue; end

    if ~isDeviceBlock(b), continue; end   % only switch/thermal/diode device blocks
    group = deviceGroupName(b, topBlock);
    if isempty(group), continue; end   % not inside a recognized device subsystem

    for p = 1:numel(mk.Parameters)
        pp = mk.Parameters(p);
        if ~strcmp(pp.Type, 'edit') || ~strcmp(pp.Visible, 'on'), continue; end
        rawVal = get_param(b, pp.Name);
        if ~ischar(rawVal) || isempty(rawVal), continue; end
        % Skip params already pointing at the struct (mask-driven passives).
        if contains(rawVal, structPrefix), continue; end

        cleanVal = stripInlineComment(rawVal);
        if isempty(cleanVal), continue; end

        field = pp.Name;

        % Resolve a group collision between two variant choices before writing:
        % same field name, different value means these are different devices, so
        % give this one its own group named after its wrapper subsystem.
        blockGroup = group;
        key = sprintf('%s.%s', blockGroup, field);
        if isKey(seen, key) && ~strcmp(seen(key), cleanVal)
            parentParts = strsplit(get_param(b, 'Parent'), '/');
            blockGroup = [group regexprep(parentParts{end}, '[^A-Za-z0-9]', '')];
            key = sprintf('%s.%s', blockGroup, field);
        end
        target = sprintf('%s.%s.%s', structName, blockGroup, field);

        if ~isKey(seen, key)
            seen(key) = cleanVal;
            unitVal = '';
            up = mk.getParameter([pp.Name '_unit']);
            if ~isempty(up), unitVal = up.Value; end
            e.group = blockGroup;
            e.field = field;
            e.value = cleanVal;
            e.unit = unitVal;
            e.description = resolvePrompt(pp.Prompt);
            extraParams(end+1) = e; %#ok<AGROW>
        end

        % Rewrite this instance's block param to reference the shared struct field.
        set_param(b, pp.Name, target);
    end
end
end

% ======================================================================
function tf = isDeviceBlock(block)
% True if the block is a power-device component whose literal parameters should
% be externalized: MOSFET / diode / IGBT semiconductors, and the thermal-network
% blocks (Temperature Source, Thermal Resistor). Gated on MaskType so it
% generalizes across converters (not tied to specific block names/locations).
tf = false;
mt = '';
try, mt = get_param(block, 'MaskType'); catch, return; end
if isempty(mt), return; end
mt = lower(regexprep(mt, '\s+', ' '));   % normalize whitespace/newlines
deviceKeywords = {'mosfet', 'diode', 'igbt', 'semiconductor switch', ...
    'temperature source', 'thermal resistor', 'thermal mass'};
for i = 1:numel(deviceKeywords)
    if contains(mt, deviceKeywords{i}), tf = true; return; end
end
end

% ======================================================================
function group = deviceGroupName(block, topBlock)
% Per-role group name = the name of the nearest enclosing "device wrapper"
% subsystem (the subsystem that bundles switches and thermal blocks, such as
% "SwitchingMOSFETwithThermal"), disambiguated by the switch role
% (Primary/Secondary) when present in the path. This groups all device blocks
% of one bridge into one shared sub-struct and generalizes to other converters.
%
% Returns '' if no suitable enclosing subsystem is found.
rel = strrep(block, [topBlock '/'], '');

% Role disambiguation from the path (works for the DAB bridges + similar).
rolePrefix = '';
if contains(rel, 'PrimaryBridge') || contains(lower(rel), 'primary')
    rolePrefix = 'Pri';
elseif contains(rel, 'SecondaryBridge') || contains(lower(rel), 'secondary')
    rolePrefix = 'Sec';
end

% Base name from the immediate parent subsystem (the device wrapper).
parent = get_param(block, 'Parent');
parts = strsplit(parent, '/');
base = regexprep(parts{end}, '[^A-Za-z0-9]', '');
if isempty(base) || ~isletter(base(1))
    base = 'Device';
end

% Concise, stable group name. For the common switching-MOSFET wrapper, use a
% short "Switch<Role>" name; otherwise fall back to "<Base><Role>".
if contains(lower(base), 'mosfet') || contains(lower(base), 'switch')
    group = ['Switch' rolePrefix];
else
    group = [base rolePrefix];
end
end

% ======================================================================
function txt = resolvePrompt(prompt)
% A device block's mask Prompt is often a message-catalog ID (like
% 'physmod:ee:library:comments:...:Vth') rather than display text. Resolve it to
% readable text when it looks like a catalog ID; otherwise return it as-is.
txt = prompt;
if isempty(prompt) || ~ischar(prompt), return; end
% Catalog IDs contain ':' and no spaces; plain prompts have spaces.
if contains(prompt, ':') && ~contains(prompt, ' ')
    try
        txt = getString(message(prompt));
    catch
        txt = prompt;   % not resolvable; keep the raw id
    end
end
end

% ======================================================================
function s = stripInlineComment(s)
% Remove a trailing "% ..." inline comment from a MATLAB value expression and
% trim whitespace. Careful not to cut a '%' inside brackets/quotes - device
% values here are numbers/vectors/reshape() with the comment always at the end,
% so a last-unquoted-'%' split is sufficient and safe.
pct = strfind(s, '%');
if ~isempty(pct)
    s = s(1:pct(1)-1);
end
s = strtrim(s);
end

% ======================================================================
function scrubCustomLibraryLinks(topBlock)
% Break every link whose target is NOT a product library, so the exported model
% has zero dependency on any custom library. Product-library links (fl_lib,
% ee_lib, nesl_utility, simulink/..., sps_lib, etc.) are the Simscape/Simulink
% component definitions and must be kept.
%
% GENERALITY (allowlist, not blocklist): earlier this matched an explicit list of
% custom library names ('ConverterLibrary', 'ConverterPlantLibrary'). That is
% fragile - it misses (a) any newly added custom library, and (b) the TRANSIENT
% names the pipeline itself creates: reduceModel rebases links to the reduced
% model's suffixed name ('ConverterLibrary_r'), and intra-library links (a
% library block linked to a SIBLING block in the same library) then resolve to
% that transient name. Those slipped through and left unresolved links to a
% non-existent 'ConverterLibrary_r', breaking the standalone compile (Boost PFC).
% So instead we keep a known set of product libraries and break everything else.
%
% An unresolved link stores its target in 'SourceBlock', not
% 'ReferenceBlock' (which is empty until the link resolves). We check both.

% Root library names that are legitimate product-library dependencies to keep.
productLibs = {'fl_lib', 'ee_lib', 'nesl_utility', 'simulink', 'sps_lib', ...
    'powerlib', 'simscape', 'built-in'};

% Work outermost-first: collect linked blocks, break those NOT pointing at a
% product library, repeat until none remain (breaking an outer link can expose
% inner ones).
while true
    % MatchFilter allVariants: scrub links in every variant choice, not just the
    % active one. At step 2b the variant subsystems still exist; an unscrubbed
    % link in an inactive branch can survive into the reduced model. It also
    % silences the "find_system skips inactive Variant Subsystem" warning.
    linked = find_system(topBlock, 'MatchFilter', @Simulink.match.allVariants, ...
        'LookUnderMasks', 'all', 'FollowLinks', 'on', ...
        'RegExp', 'on', 'LinkStatus', 'resolved|implicit|inactive|unresolved');
    brokeAny = false;
    for i = 1:numel(linked)
        target = linkTarget(linked{i});
        if isempty(target), continue; end
        rootLib = regexp(target, '^[^/]*', 'match', 'once');   % text before first '/'
        if isempty(rootLib), continue; end
        if any(strcmpi(rootLib, productLibs))
            continue;   % keep product-library links
        end
        % Anything else is a custom / transient library reference: break it.
        % Guard the set_param: a few blocks report a LinkStatus but reject having
        % it cleared (like an unresolved link whose ancestor is itself a link);
        % skip those rather than aborting the whole scrub.
        try
            set_param(linked{i}, 'LinkStatus', 'none');
            brokeAny = true;
        catch
            % Could not break this link directly; leave it for the resolver
            % handling below and continue.
        end
    end
    if ~brokeAny
        break;
    end
end
end

% ======================================================================
function target = linkTarget(block)
% Return a linked block's library target path. For a resolved/implicit/inactive
% link this is 'ReferenceBlock'; for an unresolved link ReferenceBlock is empty
% and the intended target lives in 'SourceBlock'. Return '' if neither is set.
target = '';
try
    target = get_param(block, 'ReferenceBlock');
catch
end
if isempty(target)
    try
        target = get_param(block, 'SourceBlock');
    catch
    end
end
end

% ======================================================================
function writeParamFile(mFilePath, structName, paramInfo, extraParams)
% Write the parameter struct M-file with SI values and unit/description
% comments.
fid = fopen(mFilePath, 'w');
if fid < 0
    error('exportConverterToModel:openFile', 'Cannot open %s for writing.', mFilePath);
end
c = onCleanup(@() fclose(fid));

fprintf(fid, '%% %s_params.m\n', structName);
fprintf(fid, '%% Auto-generated by exportConverterToModel.\n');
fprintf(fid, '%% Edit the values below (base SI units) and re-run the model.\n\n');

convMap = unitConversionMap();
for i = 1:numel(paramInfo)
    p = paramInfo(i);
    siValue = evaluateSI(p.value, p.unit, convMap, p.name);
    % The value written is in base SI, so the comment states the SI unit
    % (not the original display unit, which would misread the value).
    unitComment = siUnitOf(p.unit);
    fprintf(fid, '%s.%s = %s;  %% %s, %s\n', structName, p.name, ...
        num2str(siValue, '%.10g'), unitComment, p.description);
end

if ~isempty(extraParams)
    fprintf(fid, '\n%% --- Device parameters (switch / thermal / diode blocks) ---\n');
    fprintf(fid, '%% Values are the block''s own settings (display units), grouped by role.\n');
    % Emit grouped by role sub-struct, one section per group in first-seen order.
    groups = {extraParams.group};
    [~, ia] = unique(groups, 'stable');
    orderedGroups = groups(sort(ia));
    for g = 1:numel(orderedGroups)
        grp = orderedGroups{g};
        fprintf(fid, '\n%% %s.%s\n', structName, grp);
        for i = 1:numel(extraParams)
            if ~strcmp(extraParams(i).group, grp), continue; end
            e = extraParams(i);
            unitComment = e.unit;
            if isempty(unitComment), unitComment = '-'; end
            fprintf(fid, '%s.%s.%s = %s;  %% %s, %s\n', structName, e.group, e.field, ...
                e.value, unitComment, e.description);
        end
    end
end
end

% ======================================================================
function siValue = evaluateSI(valueStr, unitStr, convMap, paramName)
% Convert a displayed value + unit to base SI. valueStr may be an
% expression (like '100e-12'); evaluate it, then scale by the unit factor.
val = str2double(valueStr);
if isnan(val)
    % A mask edit field holds either a literal expression ('100e-12') or a
    % reference to a design struct that lives in the base workspace (the LLC plant
    % ships with Cr = "LLCDesign.C", Cf = "LLCDesign.Co", n =
    % "LLCDesign.N1/LLCDesign.N2"). A plain "eval" here would run in this
    % function's workspace, which cannot see the base workspace, so every
    % design-struct reference failed. Resolve in the base workspace instead - the
    % same context the mask itself and the Variant Reducer use.
    try
        val = evalin('base', valueStr);
    catch evalError
        error('exportConverterToModel:unresolvedParameter', ...
            ['Cannot evaluate mask parameter "%s" = "%s" in the base workspace.\n' ...
             'Run the converter''s design script (for the LLC, ' ...
             'LLCConverterDefaultInputParameters) in the base workspace before ' ...
             'exporting, so the design struct it references exists.\n' ...
             'Underlying error: %s'], paramName, valueStr, evalError.message);
    end
end
factor = 1;
if ~isempty(unitStr) && isKey(convMap, unitStr)
    factor = convMap(unitStr);
end
siValue = val * factor;
end

% ======================================================================
function m = unitConversionMap()
% Mirror of the mask init convMap.
m = containers.Map( ...
    {'W','kW','MW','V','kV','mV','F','mF','uF','nF','pF', ...
     'H','mH','uH','nH','Ohm','kOhm','mOhm','S','mS','1/Ohm', ...
     'Hz','kHz','MHz'}, ...
    {1, 1e3, 1e6, 1, 1e3, 1e-3, 1, 1e-3, 1e-6, 1e-9, 1e-12, ...
     1, 1e-3, 1e-6, 1e-9, 1, 1e3, 1e-3, 1, 1e-3, 1, ...
     1, 1e3, 1e6});
end

% ======================================================================
function siUnit = siUnitOf(displayUnit)
% Map a display unit to its base-SI unit (the written value is in SI, so the
% comment must state the SI unit, not the original display prefix).
baseMap = containers.Map( ...
    {'W','kW','MW','V','kV','mV','F','mF','uF','nF','pF', ...
     'H','mH','uH','nH','Ohm','kOhm','mOhm','S','mS','1/Ohm', ...
     'Hz','kHz','MHz'}, ...
    {'W','W','W','V','V','V','F','F','F','F','F', ...
     'H','H','H','H','Ohm','Ohm','Ohm','S','S','1/Ohm', ...
     'Hz','Hz','Hz'});
if isempty(displayUnit)
    siUnit = '-';
elseif isKey(baseMap, displayUnit)
    siUnit = baseMap(displayUnit);
else
    siUnit = displayUnit;
end
end
