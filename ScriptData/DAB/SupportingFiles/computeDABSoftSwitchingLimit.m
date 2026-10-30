function [softSwitchingTable, commutationCurrentTable] = computeDABSoftSwitchingLimit(DABDesign, options)
%COMPUTEDABSOFTSWITCHINGLIMIT Soft-switching summary for a sized DAB design.
%
%   softSwitchingTable = computeDABSoftSwitchingLimit(DABDesign, Name=Value) reports the
%   powers and the series-inductance bounds that decide whether the converter can do both.
%   The (Description, Achieved, Unit) rows are:
%     - the single-phase-shift power ceiling at a pi/2 phase shift
%     - the largest inductance still good for rated power
%     - the smallest inductance that soft switches down to the minimum power
%     - the soft-switching floor of each bridge in each power direction, and the worst case
%     - the conversion-ratio spread and the selected inductance
%
%   [softSwitchingTable, commutationCurrentTable] = computeDABSoftSwitchingLimit(...) also
%   returns the minimum commutation current each bridge needs at each V1 and V2 combination,
%   split into the amplitude requirement and the charge requirement. Every current is
%   primary-referred and in amperes.
%
%   Inputs:
%     DABDesign  Design structure from designDABConverter.
%
%   Name-value options:
%     DisplayTableFlag  Display both tables. Default false.
%
%   Outputs:
%     softSwitchingTable       Table of the powers and the inductance bounds.
%     commutationCurrentTable  Table of the minimum commutation currents per V1 and V2 pair.
%
%   Example:
%     [designTable, DABDesign] = designDABConverter(DABSpec);
%     [softSwitchingTable, commutationCurrentTable] = ...
%         computeDABSoftSwitchingLimit(DABDesign, DisplayTableFlag = true);
%
%   See also designDABConverter, DABSPSPhysics, plotDABZVSRegion, plotDABPowerTransferCurve.

% Copyright 2026 The MathWorks, Inc.

arguments
    DABDesign struct
    options.DisplayTableFlag (1,1) {mustBeNumericOrLogical} = false
end

% Sealed or not: the design function builds these tables before sealing its outputs, and
% the live script calls it after.
peakPowerAtHalfPi             = localAsDouble(DABDesign.peakPowerAtHalfPi);
inductanceForRatedPeak        = localAsDouble(DABDesign.inductanceForRatedPeak);
minInductanceForSoftSwitching = localAsDouble(DABDesign.minInductanceForSoftSwitching);
seriesInductance              = localAsDouble(DABDesign.seriesInductance);
maxConversionRatio            = localAsDouble(DABDesign.maxConversionRatio);
minConversionRatio            = localAsDouble(DABDesign.minConversionRatio);
achievedMinSoftSwitchPower    = localAsDouble(DABDesign.achievedMinSoftSwitchPower);
V1min = localAsDouble(DABDesign.V1min);   V2min = localAsDouble(DABDesign.V2min);
V1max = localAsDouble(DABDesign.V1max);   V2max = localAsDouble(DABDesign.V2max);
V1nom = localAsDouble(DABDesign.V1nom);   V2nom = localAsDouble(DABDesign.V2nom);

% How far the voltage range departs from the matched condition M = 1. Soft switching needs
% L at or above its minimum while rated power needs it at or below its maximum, so a wider
% spread pushes the two bounds towards each other.
conversionRatioSpread = maxConversionRatio / minConversionRatio;

Description = { ...
    'Maximum power at pi/2 phase shift'; ...
    'Max series inductance to deliver rated output power'; ...
    'Min series inductance to achieve soft switching'; ...
    'Primary-bridge min power for soft switching (forward)'; ...
    'Secondary-bridge min power for soft switching (forward)'; ...
    'Primary-bridge min power for soft switching (reverse)'; ...
    'Secondary-bridge min power for soft switching (reverse)'; ...
    ['Worst case (' char(DABDesign.criticalSoftSwitchingCase) ')']; ...
    'Conversion-ratio spread (Mmax/Mmin)'; ...
    'Selected DAB inductance'};
Achieved = [ ...
    round(peakPowerAtHalfPi, 1); ...
    round(inductanceForRatedPeak * 1e6, 3); ...
    round(minInductanceForSoftSwitching * 1e6, 3); ...
    round(localAsDouble(DABDesign.primaryZVSFloorForward), 1); ...
    round(localAsDouble(DABDesign.secondaryZVSFloorForward), 1); ...
    round(localAsDouble(DABDesign.primaryZVSFloorReverse), 1); ...
    round(localAsDouble(DABDesign.secondaryZVSFloorReverse), 1); ...
    round(achievedMinSoftSwitchPower, 1); ...
    round(conversionRatioSpread, 3); ...
    round(seriesInductance * 1e6, 3)];
Unit = {'W'; 'uH'; 'uH'; 'W'; 'W'; 'W'; 'W'; 'W'; '-'; 'uH'};

softSwitchingTable = table(char(Description), Achieved, char(Unit), ...
    'VariableNames', {'Description', 'Achieved', 'Unit'});

% ---- Minimum commutation current per bridge, per V1 and V2 pair --------------
% Two separate requirements, reported separately because a bridge meets one or the other
% depending on the power direction: the leading bridge has to reach the amplitude value, the
% lagging bridge only has to move its node charge inside the dead time.
sps = localPhysicsFrom(DABDesign);
cornerVoltages = [ ...
    V1min V2min; ...
    V1min V2max; ...
    V1max V2min; ...
    V1max V2max; ...
    V1nom V2nom];
numberOfCorners = size(cornerVoltages, 1);
cornerLabel = cell(numberOfCorners, 1);
primaryAmplitude = zeros(numberOfCorners, 1);
primaryCharge = zeros(numberOfCorners, 1);
secondaryAmplitude = zeros(numberOfCorners, 1);
secondaryCharge = zeros(numberOfCorners, 1);
for cornerIndex = 1:numberOfCorners
    cornerInputVoltage  = cornerVoltages(cornerIndex, 1);
    cornerOutputVoltage = cornerVoltages(cornerIndex, 2);
    cornerLabel{cornerIndex} = sprintf('%g V / %g V', ...
        cornerInputVoltage, cornerOutputVoltage);
    [primaryAmplitude(cornerIndex), primaryCharge(cornerIndex), ...
        secondaryAmplitude(cornerIndex), secondaryCharge(cornerIndex)] = ...
        sps.thresholdCurrents(cornerInputVoltage, cornerOutputVoltage);
end
commutationCurrentTable = table(char(cornerLabel), ...
    round(primaryAmplitude, 3), round(primaryCharge, 3), ...
    round(secondaryAmplitude, 3), round(secondaryCharge, 3), ...
    'VariableNames', {'V1 / V2', 'PrimaryAmplitude', 'PrimaryCharge', ...
    'SecondaryAmplitude', 'SecondaryCharge'});

if options.DisplayTableFlag
    disp(table(softSwitchingTable, 'VariableNames', "Soft-Switching Summary"));
    disp(table(commutationCurrentTable, ...
        'VariableNames', "Minimum Commutation Current, Primary-Referred (A)"));
end
end

% =============================================================================
function sps = localPhysicsFrom(DABDesign)
% Rebuild the physics object the design was sized with, so the currents reported here come
% from the same model as the floors above.
secondaryCapacitance = localAsDouble(DABDesign.mosfetOutputCapacitance);
if isfield(DABDesign, 'mosfetOutputCapacitanceSecondary')
    secondaryCapacitance = localAsDouble(DABDesign.mosfetOutputCapacitanceSecondary);
end
sps = DABSPSPhysics( ...
    localAsDouble(DABDesign.turnsRatio), ...
    localAsDouble(DABDesign.switchingFrequency), ...
    localAsDouble(DABDesign.seriesInductance), ...
    localAsDouble(DABDesign.mosfetOutputCapacitance), ...
    SecondaryOutputCapacitance = secondaryCapacitance, ...
    PrimarySideFraction = localAsDouble(DABDesign.primarySideFraction), ...
    MagnetizingInductance = localAsDouble(DABDesign.Lm), ...
    DeadTime = localAsDouble(DABDesign.deadTime));
end

% =============================================================================
function v = localAsDouble(x)
% Read a scalar out of either a simscape.Value or a plain double.
if isa(x, 'simscape.Value')
    v = x.value;
else
    v = x;
end
end
