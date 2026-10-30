function exportConverterModelFromMask(blockPath)
%EXPORTCONVERTERMODELFROMMASK Mask-button callback for "Export to Model".
%   Exports the configured converter library block to a standalone model and
%   parameter M-file in the current MATLAB folder (pwd). The struct/file base
%   name is derived automatically from the block name.
%
%   A wrapper around exportConverterToModel that supplies the
%   target folder and struct name. It needs no dialog, so it works on Windows,
%   Linux, macOS and in headless sessions.

% Copyright 2026 The MathWorks, Inc.

% Derive a valid MATLAB identifier for the struct/file base name from the
% block name, for example "DAB Converter" -> "DAB", "Interleaved Boost PFC" ->
% "InterleavedBoostPFC". Drop the trailing words that name the block's role
% rather than the converter, and any characters not valid in an identifier.
%
% The role words are stripped repeatedly because a block name can carry more than
% one: the LLC and CLLC plants are named "<C> Converter Power Circuit", which
% without the repeat becomes "LLCConverterPowerCircuit" and puts that in front of
% every line of the generated parameter file.
blockName = get_param(blockPath, 'Name');
structName = blockName;
roleWordPattern = '\s*(Converter|Plant|Power|Circuit)\s*$';
while ~isempty(regexp(structName, roleWordPattern, 'once'))
    structName = regexprep(structName, roleWordPattern, '');
end
structName = regexprep(structName, '[^A-Za-z0-9]', '');              % keep identifier chars
if isempty(structName) || ~isletter(structName(1))
    structName = ['Converter' structName];   % ensure a valid leading letter
end

targetDir = pwd;

% Timestamp the model name so repeated exports do not overwrite each other,
% for example "DAB_exported_23Jul_154805" (day, month, HHMMSS). The base
% struct name stays clean (structName) so the retargeted formulas remain
% readable (DAB.Lr = ...).
timeStamp = datestr(now, 'ddmmm_HHMMSS');   %#ok<TNOW1,DATST> e.g. 23Jul_154805
exportedModelName = sprintf('%s_exported_%s', structName, timeStamp);

exportedModel = exportConverterToModel(blockPath, targetDir, structName, exportedModelName);

% Report the absolute paths written; pwd is not always obvious.
modelFile = fullfile(targetDir, [exportedModel '.slx']);
paramFile = fullfile(targetDir, [exportedModel '_params.m']);
fprintf('Exported "%s" to current folder:\n  %s\n  %s\n', ...
    blockName, modelFile, paramFile);

end
