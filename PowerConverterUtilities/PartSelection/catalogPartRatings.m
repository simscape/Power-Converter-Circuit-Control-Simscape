function catalog = catalogPartRatings(modelingEntityId, voltageField, voltageUnit, ...
        currentField, currentUnit)
%CATALOGPARTRATINGS Read every installed part for one Simscape modeling entity.
%   catalog = catalogPartRatings(modelingEntityId, voltageField, voltageUnit,
%   currentField, currentUnit)
%
%   Inputs:
%     modelingEntityId  Simscape modeling entity of the device.
%     voltageField      Metadata field of the voltage rating.
%     voltageUnit       Unit of the returned voltage rating.
%     currentField      Metadata field of the current rating.
%     currentUnit       Unit of the returned current rating.
%
%   Outputs:
%     catalog  Struct with fields:
%                numberOfParts  Number of installed parts.
%                collectionId   Collection ID of each part.
%                partId         Part ID, 'Manufacturer|PartNumber|schemaId'.
%                manufacturer   Manufacturer of each part.
%                partNumber     Part number of each part.
%                voltageRating  Voltage rating in voltageUnit, NaN if missing.
%                currentRating  Current rating in currentUnit, NaN if missing.
%
%   See also selectConverterParts, applyConverterPart, applyPartToDeviceRole,
%   converterRegistry, partrepo.collection.listDataSetsForBlock.

% Copyright 2026 The MathWorks, Inc.

% The parts that fit the device's library block. The library block stands for the entity,
% so a release that renames an entity (the R2027a diode) still finds its parts.
libraryBlock = libraryBlockForEntity(modelingEntityId);
if libraryBlock == ""
    error('catalogPartRatings:emptyCatalog', ...
        'No part collection is installed for modeling entity "%s".', modelingEntityId);
end
load_system(extractBefore(libraryBlock, "/"));
partsTable = partrepo.collection.listDataSetsForBlock(libraryBlock);
numberOfParts = height(partsTable);
if numberOfParts == 0
    error('catalogPartRatings:emptyCatalog', ...
        ['No parts are installed for modeling entity "%s". Install a part ' ...
         'collection with partrepo.collection.install.'], modelingEntityId);
end

catalog = struct();
catalog.numberOfParts = numberOfParts;
catalog.collectionId  = string(partsTable.CollectionId);
catalog.partId        = string(partsTable.PartId);

% Split PartId into manufacturer and part number.
partIdParts = split(catalog.partId, '|');
if numberOfParts == 1
    partIdParts = reshape(partIdParts, 1, []);
end
catalog.manufacturer = partIdParts(:,1);
catalog.partNumber   = partIdParts(:,2);

% The parts table carries the ratings as columns "<field> (<unit>)" from R2027a. In R2026a
% it holds the part identifiers only, and the ratings come from the part depot.
[voltageRating, hasVoltage] = ratingFromTable(partsTable, voltageField, voltageUnit);
[currentRating, hasCurrent] = ratingFromTable(partsTable, currentField, currentUnit);
if hasVoltage && hasCurrent
    catalog.voltageRating = voltageRating;
    catalog.currentRating = currentRating;
elseif ~isempty(which('simscape.parts.internal.depotForEntityId'))
    depot = simscape.parts.internal.depotForEntityId(modelingEntityId);
    partIdentifiers = depot.partIdList;
    [isListed, depotIndex] = ismember(catalog.partId, string({partIdentifiers.PartId}'));
    depotVoltage = ratingFromDepot(depot, partIdentifiers, voltageField, voltageUnit);
    depotCurrent = ratingFromDepot(depot, partIdentifiers, currentField, currentUnit);
    catalog.voltageRating = nan(numberOfParts, 1);
    catalog.currentRating = nan(numberOfParts, 1);
    catalog.voltageRating(isListed) = depotVoltage(depotIndex(isListed));
    catalog.currentRating(isListed) = depotCurrent(depotIndex(isListed));
else
    error('catalogPartRatings:noRatingMetadata', ...
        'The parts table for "%s" has no "%s" or "%s" column.', ...
        modelingEntityId, voltageField, currentField);
end
end

% ======================================================================
function libraryBlock = libraryBlockForEntity(modelingEntityId)
% Library block of each device the converter plants take catalog parts for. The R2027a
% diode entity is listed as well as the R2026a one.
switch string(modelingEntityId)
    case {"ee.semiconductors.ideal.mosfet", "ee.semiconductors.ideal.mosfet_thermal"}
        libraryBlock = "ee_lib/Semiconductors & Converters/MOSFET (Ideal, Switching)";
    case {"ee.semiconductors.diode", "ee.semiconductors.diode_thermal", ...
            "ee.semiconductors.diodes.ideal", "ee.semiconductors.diodes.idealThermal", ...
            "ee.semiconductors.diodes.physical"}
        libraryBlock = "ee_lib/Semiconductors & Converters/Diode";
    otherwise
        libraryBlock = "";
end
end

% ======================================================================
function [ratingValues, isFound] = ratingFromTable(partsTable, fieldName, targetUnit)
% Read the column "<fieldName> (<unit>)" in targetUnit, NaN where a part has no value.
columnNames = string(partsTable.Properties.VariableNames);
withUnit = startsWith(columnNames, fieldName + " (") & endsWith(columnNames, ")");
columnIndex = find(columnNames == fieldName | withUnit, 1);
isFound = ~isempty(columnIndex);
ratingValues = nan(height(partsTable), 1);
if ~isFound
    return
end
storedUnit = "";
if withUnit(columnIndex)
    storedUnit = extractBetween(columnNames(columnIndex), fieldName + " (", ")", 'Boundaries', 'exclusive');
    storedUnit = storedUnit(end);
end
rawValues = partsTable.(columnNames(columnIndex));
if iscell(rawValues)
    rawValues = cellfun(@firstNumber, rawValues);
end
ratingValues = double(rawValues(:));
if storedUnit ~= "" && storedUnit ~= string(targetUnit)
    ratingValues = value(simscape.Value(ratingValues, storedUnit), targetUnit);
end
end

% ======================================================================
function number = firstNumber(entry)
% First numeric value of a cell entry, NaN if it holds none.
number = NaN;
if isnumeric(entry) && ~isempty(entry)
    number = double(entry(1));
end
end

% ======================================================================
function normalizedValues = ratingFromDepot(depot, partIdentifiers, fieldName, targetUnit)
% Read one metadata field for every part in targetUnit, NaN if missing. R2026a only.
rawValues = depot.metadataValues(fieldName, partIdentifiers);
rawUnits  = depot.metadataUnits(fieldName, partIdentifiers);
normalizedValues = nan(numel(rawValues), 1);
for k = 1:numel(rawValues)
    rawValue = rawValues{k};
    if isempty(rawValue) || ~isnumeric(rawValue)
        continue
    end
    storedUnit = '';
    if k <= numel(rawUnits) && ~isempty(rawUnits{k})
        storedUnit = char(string(rawUnits{k}));
    end
    if isempty(storedUnit) || strcmp(storedUnit, targetUnit)
        normalizedValues(k) = double(rawValue(1));
    else
        normalizedValues(k) = simscape.Value(double(rawValue(1)), storedUnit).convert(targetUnit).value;
    end
end
end
