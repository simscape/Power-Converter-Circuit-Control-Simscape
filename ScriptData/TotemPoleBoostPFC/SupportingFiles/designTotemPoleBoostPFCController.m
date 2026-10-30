function [controllerTable, totemPoleController] = designTotemPoleBoostPFCController( ...
    totemPoleDesign, totemPoleControllerSpec, options)
%DESIGNTOTEMPOLEBOOSTPFCCONTROLLER Tune the totem-pole boost PFC controller.
%
%   [controllerTable, totemPoleController] = designTotemPoleBoostPFCController(
%   totemPoleDesign, totemPoleControllerSpec, Name=Value) places both loops of the
%   average-current-mode PFC controller against the sized power stage and returns the
%   structure the "Totem-Pole Boost PFC Controller" block mask reads. The controller is a
%   cascade: an inner inductor current loop following a reference shaped by the rectified
%   line voltage, and an outer bus-voltage loop that sets the power command. Every gain is
%   a closed-form match to the plant its loop sees.
%
%   Inputs:
%     totemPoleDesign          Design structure from designTotemPoleBoostPFCConverter.
%     totemPoleControllerSpec  Controller specification.
%
%   Controller specification fields:
%     phaseMargin                Phase margin asked of both loops (deg).
%     currentCrossoverRatio      Current-loop crossover, as the switching frequency over
%                                this ratio.
%     voltageCrossoverFrequency  Voltage-loop crossover frequency (Hz).
%     iRefPeakMaxPu              Peak current-reference limit protecting the fast-leg
%                                devices (pu).
%     loadFraction               Power command, as a fraction of rated.
%     gateVoltageOn              Gate drive on level (V).
%     gateVoltageOff             Gate drive off level (V).
%
%   Name-value options:
%     DisplayTableFlag  Display the controller table. Default false.
%
%   Outputs:
%     controllerTable      Table of the gains, the sample times and the achieved placement.
%     totemPoleController  Structure the controller block mask reads, in per-unit on two
%                          base sets. The caller adds the two dead times the mask also
%                          reads, fastLegDeadTime and slowLegTurnOnDelay.
%
%   See also designTotemPoleBoostPFCConverter, selectTotemPoleDeviceRating.

% Copyright 2026 The MathWorks, Inc.

arguments
    totemPoleDesign struct
    totemPoleControllerSpec struct
    options.DisplayTableFlag (1,1) {mustBeNumericOrLogical} = false
end

% ---- Validate that every required specification field is present ------------
% None has a defensible default - each is a loop-placement or protection decision - so a
% missing one is named here rather than shipping a silently untuned controller.
requiredSpecFields = [ ...
    "phaseMargin", "currentCrossoverRatio", "voltageCrossoverFrequency", ...
    "iRefPeakMaxPu", "loadFraction", "gateVoltageOn", "gateVoltageOff"];
missingSpecFields = requiredSpecFields(~isfield(totemPoleControllerSpec, requiredSpecFields));
if ~isempty(missingSpecFields)
    error("designTotemPoleBoostPFCController:MissingSpecField", ...
        "totemPoleControllerSpec is missing required field(s): %s.", ...
        strjoin(missingSpecFields, ", "));
end

% ---- Extract the specification to plain doubles in SI base units ------------
% A struct field carries no argument validation, so the ranges are checked explicitly below.
PhaseMargin           = scalarValue(totemPoleControllerSpec.phaseMargin, "deg");
CurrentCrossoverRatio = scalarValue(totemPoleControllerSpec.currentCrossoverRatio);
FcVoltage             = scalarValue(totemPoleControllerSpec.voltageCrossoverFrequency, "Hz");
iRefPeakMaxPu         = scalarValue(totemPoleControllerSpec.iRefPeakMaxPu);
loadFraction          = scalarValue(totemPoleControllerSpec.loadFraction);
gateVoltageOn         = scalarValue(totemPoleControllerSpec.gateVoltageOn, "V");
gateVoltageOff        = scalarValue(totemPoleControllerSpec.gateVoltageOff, "V");

% The PI zero sits at wc/tan(PM), so a phase margin at or above 90 deg gives a zero or
% negative integral gain - an unstable loop from an innocent-looking number.
if ~(PhaseMargin > 0 && PhaseMargin < 90)
    error("designTotemPoleBoostPFCController:BadPhaseMargin", ...
        "phaseMargin must lie in (0, 90) deg; got %g.", PhaseMargin);
end
if ~(CurrentCrossoverRatio > 0 && FcVoltage > 0)
    error("designTotemPoleBoostPFCController:BadCrossover", ...
        "currentCrossoverRatio (%g) and voltageCrossoverFrequency (%g Hz) must be positive.", ...
        CurrentCrossoverRatio, FcVoltage);
end
% Below 1 pu the clamp would cut into the rated power command itself.
if ~(iRefPeakMaxPu >= 1)
    error("designTotemPoleBoostPFCController:BadPeakLimit", ...
        "iRefPeakMaxPu must be at least 1 pu; got %g.", iRefPeakMaxPu);
end
if ~(loadFraction > 0)
    error("designTotemPoleBoostPFCController:BadLoadFraction", ...
        "loadFraction must be positive; got %g.", loadFraction);
end

if ~(gateVoltageOn > gateVoltageOff)
    error("designTotemPoleBoostPFCController:BadGateLevels", ...
        "gateVoltageOn (%g V) must exceed gateVoltageOff (%g V).", ...
        gateVoltageOn, gateVoltageOff);
end

% scalarValue accepts either simscape.Value or a plain double.
VOut  = scalarValue(totemPoleDesign.outputVoltage);
Pbase = scalarValue(totemPoleDesign.ratedPower);
VacRMS = scalarValue(totemPoleDesign.nomInputVoltage);
Fsw   = scalarValue(totemPoleDesign.switchingFrequency);
LBoost = scalarValue(totemPoleDesign.boostInductance);
CBoost = scalarValue(totemPoleDesign.outputCapacitance);

% TWO base sets, because a PFC straddles an AC and a DC port. On these
% iref_pu = P_pu*|vac|_puAC with |vac|_puAC peaking at 1, so the PEAK of iref_pu is the
% power command itself - which is what makes iRefPeakMaxPu meaningful as a device limit.
% Pbase is RATED power, not the momentary load: tying a base to the load would make the
% per-unit peak-current limit track the load instead of protecting the device.
VbaseDC = VOut;
VbaseAC = sqrt(2) * VacRMS;
IbaseAC = 2 * Pbase / VbaseAC;

% Loop placement.
%   current loop  i/d = VOut/(s*L)     -> Kp = wc*L*sin(PM)/VOut
%   voltage loop  v/p = 1/(s*Co*VOut)  -> Kp = wc*Co*VOut*sin(PM)
% PI zero at wc/tan(PM) in both cases, so Ki = Kp*wc/tan(PM). The sin(PM) factor cancels the
% PI's own magnitude boost so each crossover lands where it was asked for.
%
% The voltage loop is held near 3 Hz: any 100 Hz bus ripple reaching the current reference
% comes back as third-harmonic input distortion. Load-step recovery takes about 1 s.
FcCurrent = Fsw / CurrentCrossoverRatio;

wcCurrent = 2*pi*FcCurrent;
wcVoltage = 2*pi*FcVoltage;

% Placed in PHYSICAL units first, then converted on the base set of the side each loop works
% on: the voltage gain maps bus volts to watts (VbaseDC/Pbase), the current gain maps line
% amps to duty (IbaseAC). Crossovers and phase margins are unchanged by the conversion.
KpVoltagePhysical = wcVoltage * CBoost * VOut * sind(PhaseMargin);              % W/V
KiVoltagePhysical = KpVoltagePhysical * wcVoltage / tand(PhaseMargin);          % W/(V*s)
KpCurrentPhysical = wcCurrent * LBoost * sind(PhaseMargin) / VOut;              % 1/A
KiCurrentPhysical = KpCurrentPhysical * wcCurrent / tand(PhaseMargin);          % 1/(A*s)

% The structure the block mask reads. Field names match the mask parameter names.
totemPoleController.KpVoltage = KpVoltagePhysical * VbaseDC / Pbase;
totemPoleController.KiVoltage = KiVoltagePhysical * VbaseDC / Pbase;
totemPoleController.TsVoltage = 1/(2*Fsw);   % the current loop is 5x faster

totemPoleController.KpCurrent = KpCurrentPhysical * IbaseAC;
totemPoleController.KiCurrent = KiCurrentPhysical * IbaseAC;
totemPoleController.TsCurrent = 1/(10*Fsw);

% Peak current-reference limit, protecting the fast-leg devices. The hard clamp is not
% redundant: VbaseAC is the NOMINAL line peak, so on a swell |vac|_puAC exceeds 1 and the
% reference peak would exceed the power command.
totemPoleController.iRefPeakMaxPu = iRefPeakMaxPu;

% Power command in pu of rated. No separate power-trim limit: the command must lie in
% [0, iRefPeakMaxPu], so the voltage PI's limits are derived rather than offered as a third
% pair the dialog could contradict.
totemPoleController.PrefPu = loadFraction;

% Duty limits.
totemPoleController.dutyMax = 1;
totemPoleController.dutyMin = 0;

% The two legs commutate on different time scales, so each gets its own dead time - and
% neither is set here. fastLegDeadTime and slowLegTurnOnDelay are gate-driver and device
% limits, not derivable ones: this leg is hard-switched in CCM, so there is no resonant
% transition to invert for a dead time the way there is in a DAB. The caller writes them
% onto this structure, as EstimateTotemPoleBoostPFCParameters and
% TotemPoleBoostPFCDefaultInputParameters both do.

totemPoleController.gateVoltageOn  = gateVoltageOn;
totemPoleController.gateVoltageOff = gateVoltageOff;

% Placement metadata, so the achieved design is inspectable.
totemPoleController.phaseMargin = PhaseMargin;
totemPoleController.FcVoltage   = FcVoltage;
totemPoleController.FcCurrent   = FcCurrent;

controllerTable = table( ...
    ["Voltage-loop crossover frequency (FcVoltage)"
     "Voltage-loop proportional gain (KpVoltage)"
     "Voltage-loop integral gain (KiVoltage)"
     "Voltage-loop sample time (TsVoltage)"
     "Current-loop crossover frequency (FcCurrent)"
     "Current-loop proportional gain (KpCurrent)"
     "Current-loop integral gain (KiCurrent)"
     "Current-loop sample time (TsCurrent)"
     "Phase margin, both loops (phaseMargin)"
     "Peak current-reference limit (iRefPeakMaxPu)"
     "Power command (PrefPu)"], ...
    [FcVoltage
     totemPoleController.KpVoltage
     totemPoleController.KiVoltage
     totemPoleController.TsVoltage
     FcCurrent
     totemPoleController.KpCurrent
     totemPoleController.KiCurrent
     totemPoleController.TsCurrent
     PhaseMargin
     totemPoleController.iRefPeakMaxPu
     totemPoleController.PrefPu], ...
    ["Hz"; "pu"; "pu/s"; "s"; "Hz"; "pu"; "pu/s"; "s"; "deg"; "pu"; "pu"], ...
    'VariableNames', ["Parameter", "Value", "Unit"]);

if options.DisplayTableFlag
    disp(table(controllerTable, 'VariableNames', "Totem-Pole Boost PFC Controller Parameters"));
end
end

% ======================================================================
function numericValue = scalarValue(quantity, unit)
% Read a scalar out of either a simscape.Value or a plain double; simscape.Value does not
% convert, so .value must be read explicitly. Set UNIT when the caller may have written the
% quantity in a submultiple, so simscape.Value(3,"kHz") reads as 3000 Hz. A plain double is
% taken to be in UNIT already.
if isa(quantity, 'simscape.Value')
    if nargin > 1
        numericValue = value(quantity, unit);
    else
        numericValue = quantity.value;
    end
else
    numericValue = quantity;
end
end
