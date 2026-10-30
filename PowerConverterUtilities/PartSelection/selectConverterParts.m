function partTable = selectConverterParts(deviceRating, options)
%SELECTCONVERTERPARTS Rank Simscape catalog parts against a converter device rating.
%   partTable = selectConverterParts(deviceRating)
%   partTable = selectConverterParts(deviceRating, Name=Value)
%
%   Inputs:
%     deviceRating  Table with one row per rating. Columns:
%                     Rating            Rating value.
%                     Unit              Unit of Rating, voltage or current.
%                     MetadataField     Catalog metadata field to compare against.
%                     DeviceRole        Device role key.
%                     ModelingEntityId  Simscape modeling entity of the catalog.
%
%   Name-value options:
%     NumberOfParts  Parts to return per device role. Default 5.
%     Display        Print the ranked list per role. Default true.
%
%   Outputs:
%     partTable  Table of parts that meet both ratings, least margin first per role.
%                Columns:
%                  - DeviceRole, Rank, Manufacturer, PartNumber
%                  - VoltageRating, CurrentRating, in the rating units
%                  - VoltageMarginPercent, CurrentMarginPercent, TotalMarginPercent
%                  - CollectionId, PartId
%
%   See also selectDeviceRating, applyPartToDeviceRole, applyConverterPart,
%   catalogPartRatings, converterRegistry.

% Copyright 2026 The MathWorks, Inc.

arguments
    deviceRating table
    options.NumberOfParts (1,1) {mustBeInteger, mustBePositive} = 5
    options.Display (1,1) logical = true
end

requiredColumns = ["Rating" "Unit" "MetadataField" "DeviceRole" "ModelingEntityId"];
missingColumns = requiredColumns(~ismember(requiredColumns, string(deviceRating.Properties.VariableNames)));
if ~isempty(missingColumns)
    error('selectConverterParts:missingColumns', ...
        'The device rating table is missing required column(s): %s.', strjoin(missingColumns, ', '));
end

deviceRoles = unique(string(deviceRating.DeviceRole), 'stable');
partTable = emptyPartTable();

for roleIndex = 1:numel(deviceRoles)
    deviceRole = deviceRoles(roleIndex);
    roleRows = deviceRating(string(deviceRating.DeviceRole) == deviceRole, :);

    % Get the voltage and current rating rows.
    [voltageRow, currentRow] = splitRatingRows(roleRows, deviceRole);
    modelingEntityId = char(string(roleRows.ModelingEntityId(1)));

    % Read the catalog in the rating units; warn and skip the role if none is installed.
    try
        catalog = catalogPartRatings(modelingEntityId, ...
            char(string(voltageRow.MetadataField)), char(string(voltageRow.Unit)), ...
            char(string(currentRow.MetadataField)), char(string(currentRow.Unit)));
    catch catalogError
        if strcmp(catalogError.identifier, 'catalogPartRatings:emptyCatalog')
            warning('selectConverterParts:emptyRoleCatalog', ...
                ['No part collection is installed for %s (modeling entity "%s"), so ' ...
                 'no part can be listed for this role. Its rating still stands - ' ...
                 '%g %s and %g %s - so select a device from a vendor datasheet, or ' ...
                 'install a collection with partrepo.collection.install.'], ...
                deviceRole, modelingEntityId, ...
                double(voltageRow.Rating), string(voltageRow.Unit), ...
                double(currentRow.Rating), string(currentRow.Unit));
            continue
        end
        rethrow(catalogError);
    end

    requiredVoltage = double(voltageRow.Rating);
    requiredCurrent = double(currentRow.Rating);

    % Keep parts that meet both ratings; exclude missing ratings.
    qualifies = catalog.voltageRating >= requiredVoltage & ...
                catalog.currentRating >= requiredCurrent & ...
                isfinite(catalog.voltageRating) & isfinite(catalog.currentRating);

    numberQualifying = sum(qualifies);
    if numberQualifying == 0
        warning('selectConverterParts:noQualifyingPart', ...
            ['No catalog part meets the %s rating (%g %s and %g %s). ' ...
             'The closest available part is %g %s / %g %s - relax the rating, ' ...
             'lower the safety factor, or parallel devices.'], ...
            deviceRole, requiredVoltage, string(voltageRow.Unit), ...
            requiredCurrent, string(currentRow.Unit), ...
            max(catalog.voltageRating), string(voltageRow.Unit), ...
            max(catalog.currentRating), string(currentRow.Unit));
        continue
    end

    % Rank by the sum of the fractional voltage and current margins.
    voltageMargin = (catalog.voltageRating(qualifies) - requiredVoltage) / requiredVoltage;
    currentMargin = (catalog.currentRating(qualifies) - requiredCurrent) / requiredCurrent;
    [totalMargin, rankOrder] = sort(voltageMargin + currentMargin, 'ascend');

    qualifyingIndices = find(qualifies);
    keepCount = min(options.NumberOfParts, numberQualifying);
    keepIndices = qualifyingIndices(rankOrder(1:keepCount));

    roleTable = table( ...
        repmat(deviceRole, keepCount, 1), (1:keepCount)', ...
        catalog.manufacturer(keepIndices), catalog.partNumber(keepIndices), ...
        catalog.voltageRating(keepIndices), catalog.currentRating(keepIndices), ...
        100 * voltageMargin(rankOrder(1:keepCount)), ...
        100 * currentMargin(rankOrder(1:keepCount)), ...
        100 * totalMargin(1:keepCount), ...
        catalog.collectionId(keepIndices), catalog.partId(keepIndices), ...
        'VariableNames', emptyPartTable().Properties.VariableNames);
    partTable = [partTable; roleTable]; %#ok<AGROW>

    if numberQualifying < options.NumberOfParts
        warning('selectConverterParts:fewerPartsThanRequested', ...
            ['Only %d of the %d catalog part(s) for %s meet the %g %s / %g %s ' ...
             'rating; %d requested. Listing the %d that qualify.'], ...
            numberQualifying, catalog.numberOfParts, deviceRole, ...
            requiredVoltage, string(voltageRow.Unit), ...
            requiredCurrent, string(currentRow.Unit), ...
            options.NumberOfParts, numberQualifying);
    end

    if options.Display
        fprintf('\n%s - %d of %d catalog parts meet %g %s and %g %s (closest first):\n', ...
            deviceRole, numberQualifying, catalog.numberOfParts, ...
            requiredVoltage, string(voltageRow.Unit), requiredCurrent, string(currentRow.Unit));
        disp(roleTable(:, {'Rank','Manufacturer','PartNumber','VoltageRating', ...
            'CurrentRating','VoltageMarginPercent','CurrentMarginPercent'}));
    end
end
end

% ======================================================================
function [voltageRow, currentRow] = splitRatingRows(roleRows, deviceRole)
% Return the voltage and current rating rows of one role, found by unit.
isVoltage = false(height(roleRows),1);
isCurrent = false(height(roleRows),1);
for k = 1:height(roleRows)
    unitText = char(string(roleRows.Unit(k)));
    isVoltage(k) = isCompatibleUnit(unitText, 'V');
    isCurrent(k) = isCompatibleUnit(unitText, 'A');
end
if sum(isVoltage) ~= 1 || sum(isCurrent) ~= 1
    error('selectConverterParts:badRatingRows', ...
        ['Device role "%s" needs exactly one voltage rating row and one current ' ...
         'rating row; found %d voltage and %d current row(s).'], ...
        deviceRole, sum(isVoltage), sum(isCurrent));
end
voltageRow = roleRows(isVoltage, :);
currentRow = roleRows(isCurrent, :);
end

% ======================================================================
function tf = isCompatibleUnit(unitText, referenceUnit)
% Return true if unitText converts to referenceUnit.
try
    simscape.Value(1, unitText).convert(referenceUnit);
    tf = true;
catch
    tf = false;
end
end

% ======================================================================
function emptyTable = emptyPartTable()
% Return an empty output table with all columns.
emptyTable = table(strings(0,1), zeros(0,1), strings(0,1), strings(0,1), ...
    zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), zeros(0,1), ...
    strings(0,1), strings(0,1), ...
    'VariableNames', {'DeviceRole','Rank','Manufacturer','PartNumber', ...
    'VoltageRating','CurrentRating','VoltageMarginPercent', ...
    'CurrentMarginPercent','TotalMarginPercent','CollectionId','PartId'});
end
