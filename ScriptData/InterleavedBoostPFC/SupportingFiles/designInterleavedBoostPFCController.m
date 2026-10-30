function [controllerTable, interleavedController] = designInterleavedBoostPFCController(interleavedDesign, options)
%DESIGNINTERLEAVEDBOOSTPFCCONTROLLER Tune the interleaved boost PFC controller.
%
%   [controllerTable, interleavedController] = designInterleavedBoostPFCController(
%   interleavedDesign, Name=Value) places all three loops of the average-current-mode PFC
%   controller against the sized power stage. It returns the structure the "Interleaved Boost
%   PFC Controller" block mask reads. One controller serves all legs: an outer voltage loop
%   and a shared current loop produce a single common duty. The interleaving is a
%   phase offset between the legs' PWM carriers. The third loop is the per-leg one,
%   a differential loop that trims the legs apart without changing their sum. Every gain
%   is a closed-form match to the plant its loop sees.
%
%   Inputs:
%     interleavedDesign  Design structure from designInterleavedBoostPFCConverter.
%
%   Name-value options:
%     PhaseMargin                Phase margin asked of all three loops (deg). Default 60.
%     CurrentCrossoverRatio      Current-loop crossover, as the switching frequency over
%                                this ratio. Default 20.
%     VoltageCrossoverFrequency  Voltage-loop crossover frequency (Hz). Default 3.
%     BalanceCrossoverRatio      Balance-loop crossover, as the switching frequency over
%                                this ratio. Default 100.
%     DutyBalanceMax             Limit on the differential duty trim. Default 0.1.
%     IrefPeakMaxPu              Peak current-reference limit protecting the boost switches
%                                (pu). Default 1.3.
%     LoadFraction               Power command, as a fraction of rated. Default 1.
%     ModulatorGuardTime         Guaranteed off window at each end of the carrier period
%                                (s), returned as the two duty limits. Default 100e-9.
%     PwmStepsPerPeriod          Modulator carrier steps per switching period, setting the
%                                duty resolution. Default 200.
%     GateVoltageOn              Gate drive on level (V). Default 15.
%     GateVoltageOff             Gate drive off level (V). Default 0.
%     DisplayTableFlag           Display the controller table. Default false.
%
%   Outputs:
%     controllerTable        Table of the gains, the sample times, the carrier phase offset
%                            and the achieved placement.
%     interleavedController  Structure the controller block mask reads, in per-unit on two
%                            base sets.
%
%   See also designTotemPoleBoostPFCController.

% Copyright 2026 The MathWorks, Inc.

arguments
    interleavedDesign struct
    options.PhaseMargin (1,1) double {mustBePositive} = 60
    options.CurrentCrossoverRatio (1,1) double {mustBePositive} = 20
    options.VoltageCrossoverFrequency (1,1) double {mustBePositive} = 3
    options.BalanceCrossoverRatio (1,1) double {mustBePositive} = 100
    options.DutyBalanceMax (1,1) double {mustBePositive} = 0.1
    options.IrefPeakMaxPu (1,1) double {mustBeGreaterThanOrEqual(options.IrefPeakMaxPu,1)} = 1.3
    options.LoadFraction (1,1) double {mustBePositive} = 1
    % mustBePositive, not mustBeNonnegative: zero is the failure mode noted at dutyMin, and
    % on this converter it loses 11.95 efficiency points.
    options.ModulatorGuardTime (1,1) double {mustBePositive} = 100e-9
    options.PwmStepsPerPeriod (1,1) double {mustBePositive} = 200
    options.GateVoltageOn (1,1) double = 15
    options.GateVoltageOff (1,1) double = 0
    options.DisplayTableFlag (1,1) logical = false
end

% scalarValue accepts either simscape.Value or a plain double.
VOut       = scalarValue(interleavedDesign.outputVoltage);
Pbase      = scalarValue(interleavedDesign.ratedPower);
VacRMS     = scalarValue(interleavedDesign.nomInputVoltage);
Fsw        = scalarValue(interleavedDesign.switchingFrequency);
LBoost     = scalarValue(interleavedDesign.boostInductance);
CBoost     = scalarValue(interleavedDesign.outputCapacitance);
numberOfLegs = scalarValue(interleavedDesign.numberOfLegs);

% TWO base sets, because a PFC straddles an AC and a DC port. On these
% iref_pu = P_pu*|vac|_puAC with |vac|_puAC peaking at 1, so the PEAK of iref_pu is the power
% command itself - which is what makes iRefPeakMaxPu meaningful as a device limit.
% Pbase is RATED power, not the momentary load: tying a base to the load would make the
% per-unit peak-current limit track the load instead of protecting the device. IbaseAC is the
% TOTAL line-current base, not per-leg, because the shared current loop regulates the total.
VbaseDC = VOut;
VbaseAC = sqrt(2) * VacRMS;
IbaseAC = 2 * Pbase / VbaseAC;

% Loop placement.
%   current loop  iTotal/d  =  numberOfLegs*VOut/(s*L)  -> Kp = wc*L*sin(PM)/(numberOfLegs*VOut)
%   voltage loop  v/p       =  1/(s*Co*VOut)            -> Kp = wc*Co*VOut*sin(PM)
%   balance loop  iDiff/t   = -VOut/(s*L)               -> Kp = wc*L*sin(PM)/VOut
% PI zero at wc/tan(PM) in all three cases, so Ki = Kp*wc/tan(PM). The sin(PM) factor cancels
% the PI's own magnitude boost so each crossover lands where it was asked for.
%
% The current loop divides by numberOfLegs and the balance loop does not: the shared duty
% drives every leg at once, so the COMMON mode sees N inductors in parallel, an effective L/N,
% while the trim drives the legs in opposition and the DIFFERENTIAL mode sees one leg's L.
%
% The voltage loop is held at 3 Hz: any 100 Hz bus ripple reaching the current reference comes
% back as third-harmonic input distortion. Load-step recovery takes about 1 s.
%
% The balance loop sits 5x below the current loop so the two do not interact through the
% per-leg duty saturation. It cannot be P-only: the differential plant is an integrator, and a
% leg inductance or diode-drop mismatch asks for a standing duty offset.
PhaseMargin = options.PhaseMargin;
FcCurrent = Fsw / options.CurrentCrossoverRatio;
FcVoltage = options.VoltageCrossoverFrequency;
FcBalance = Fsw / options.BalanceCrossoverRatio;

wcCurrent = 2*pi*FcCurrent;
wcVoltage = 2*pi*FcVoltage;
wcBalance = 2*pi*FcBalance;

% Placed in PHYSICAL units first, then converted on the base set of the side each loop works
% on: the voltage gain maps bus volts to watts (VbaseDC/Pbase), the current gains map line
% amps to duty (IbaseAC). Crossovers and phase margins are unchanged by the conversion.
KpVoltagePhysical = wcVoltage * CBoost * VOut * sind(PhaseMargin);                       % W/V
KiVoltagePhysical = KpVoltagePhysical * wcVoltage / tand(PhaseMargin);                   % W/(V*s)
KpCurrentPhysical = wcCurrent * LBoost * sind(PhaseMargin) / (numberOfLegs * VOut);      % 1/A
KiCurrentPhysical = KpCurrentPhysical * wcCurrent / tand(PhaseMargin);                   % 1/(A*s)
KpBalancePhysical = wcBalance * LBoost * sind(PhaseMargin) / VOut;                       % 1/A
KiBalancePhysical = KpBalancePhysical * wcBalance / tand(PhaseMargin);                   % 1/(A*s)

% The structure the block mask reads. Field names match the mask parameter names.
interleavedController.KpVoltage = KpVoltagePhysical * VbaseDC / Pbase;
interleavedController.KiVoltage = KiVoltagePhysical * VbaseDC / Pbase;
interleavedController.TsVoltage = 1/(2*Fsw);   % the current loop is 5x faster

interleavedController.KpCurrent = KpCurrentPhysical * IbaseAC;
interleavedController.KiCurrent = KiCurrentPhysical * IbaseAC;
interleavedController.TsCurrent = 1/(10*Fsw);

% The balance loop shares the current loop's sample time - its bandwidth, not its rate, is
% what keeps it out of the way.
interleavedController.KpBalance = KpBalancePhysical * IbaseAC;
interleavedController.KiBalance = KiBalancePhysical * IbaseAC;

% Hard limit on the differential duty trim: it bounds how far apart the legs can be driven
% however much the balance loop asks, so a mis-scaled current sensor cannot walk a leg into
% full conduction.
interleavedController.dutyBalanceMax = options.DutyBalanceMax;

% Peak current-reference limit. The hard clamp is not redundant: VbaseAC is the NOMINAL line
% peak, so on a swell |vac|_puAC exceeds 1 and the reference peak would exceed the command.
interleavedController.iRefPeakMaxPu = options.IrefPeakMaxPu;

% Power command in pu of rated. No separate power-trim limit: the command must lie in
% [0, iRefPeakMaxPu], so the voltage PI's limits are derived rather than offered as a third
% pair the mask could contradict.
interleavedController.PrefPu = options.LoadFraction;

% Modulator guard interval, as the two duty limits the modulator mask reads. NOT a dead time:
% a boost leg has one controlled switch and a diode, so there is no shoot-through path. It
% gives a guaranteed OFF window at both ends of the carrier period, needed for two reasons:
%   1. Each leg's duty latch samples at its OWN carrier reset, half a period apart. A gate
%      edge landing there makes the two legs latch DIFFERENT switching transients, and the
%      balance loop then acts on a difference that is not real.
%   2. Each boost diode needs a guaranteed conduction interval to charge the bus.
guardDutyFraction = options.ModulatorGuardTime * Fsw;
interleavedController.dutyMin = guardDutyFraction;
interleavedController.dutyMax = 1 - guardDutyFraction;

% FIXED-STEP modulator carrier only; the variable-step carrier declares no rate. The step size
% sets the duty resolution: 1/PwmStepsPerPeriod, 0.5% at the default 200.
interleavedController.TsPwm = 1/(options.PwmStepsPerPeriod * Fsw);

interleavedController.gateVoltageOn  = options.GateVoltageOn;
interleavedController.gateVoltageOff = options.GateVoltageOff;

% Placement metadata, so the achieved design is inspectable.
interleavedController.phaseMargin  = PhaseMargin;
interleavedController.FcVoltage    = FcVoltage;
interleavedController.FcCurrent    = FcCurrent;
interleavedController.FcBalance    = FcBalance;
interleavedController.numberOfLegs = numberOfLegs;

% The label and unit columns are char, so the display does not put quotes around every row.
controllerTable = table( ...
    char(["Number of interleaved legs (numberOfLegs)"
     "Voltage-loop crossover frequency (FcVoltage)"
     "Voltage-loop proportional gain (KpVoltage)"
     "Voltage-loop integral gain (KiVoltage)"
     "Voltage-loop sample time (TsVoltage)"
     "Current-loop crossover frequency (FcCurrent)"
     "Current-loop proportional gain (KpCurrent)"
     "Current-loop integral gain (KiCurrent)"
     "Current-loop sample time (TsCurrent)"
     "Balance-loop crossover frequency (FcBalance)"
     "Balance-loop proportional gain (KpBalance)"
     "Balance-loop integral gain (KiBalance)"
     "Balance-loop duty trim limit (dutyBalanceMax)"
     "Phase margin, all loops (phaseMargin)"
     "Peak current-reference limit (iRefPeakMaxPu)"
     "Power command (PrefPu)"
     "Modulator minimum duty (dutyMin)"
     "Modulator maximum duty (dutyMax)"
     "Modulator carrier phase offset per leg"
     "Fixed-step modulator sample time (TsPwm)"]), ...
    [numberOfLegs
     FcVoltage
     interleavedController.KpVoltage
     interleavedController.KiVoltage
     interleavedController.TsVoltage
     FcCurrent
     interleavedController.KpCurrent
     interleavedController.KiCurrent
     interleavedController.TsCurrent
     FcBalance
     interleavedController.KpBalance
     interleavedController.KiBalance
     interleavedController.dutyBalanceMax
     PhaseMargin
     interleavedController.iRefPeakMaxPu
     interleavedController.PrefPu
     interleavedController.dutyMin
     interleavedController.dutyMax
     360/numberOfLegs
     interleavedController.TsPwm], ...
    char(["-"; "Hz"; "pu"; "pu/s"; "s"; "Hz"; "pu"; "pu/s"; "s"; "Hz"; "pu"; "pu/s"; "-"; "deg"; ...
     "pu"; "pu"; "pu"; "pu"; "deg"; "s"]), ...
    'VariableNames', ["Parameter", "Value", "Unit"]);

if options.DisplayTableFlag
    disp(table(controllerTable, 'VariableNames', "Interleaved Boost PFC Controller Parameters"));
end
end

% ======================================================================
function numericValue = scalarValue(quantity)
% Read a scalar out of either a simscape.Value or a plain double.
if isa(quantity, 'simscape.Value')
    numericValue = quantity.value;
else
    numericValue = quantity;
end
end
