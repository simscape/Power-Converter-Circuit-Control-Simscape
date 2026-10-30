classdef DABSPSPhysics
    %DABSPSPHYSICS Single-phase-shift power and soft-switching physics for a DAB converter.
    %
    %   sps = DABSPSPhysics(turnsRatio, switchingFrequency, seriesInductance) and
    %   sps = DABSPSPhysics(..., mosfetOutputCapacitance, Name=Value) hold the fixed
    %   power-stage parameters. The object exposes the single-phase-shift power law, its
    %   inverse, the series and commutation currents, the minimum commutation current each
    %   bridge needs, and the soft-switching duty boundary in either power direction. Both
    %   bridges run a fixed 50% duty throughout, and the phase shift phi is the only control
    %   variable. It is normalized as D = phi/pi over [-0.5, 0.5], with forward power for
    %   D > 0 and reverse power for D < 0.
    %
    %   The series inductance is a T network. PrimarySideFraction of it sits on the primary
    %   side of the magnetizing branch and the rest sits on the secondary side, so the
    %   magnetizing current divides between the two bridges in inverse proportion to those
    %   two inductances. With the defaults, all of the series inductance on the primary side
    %   and an infinite magnetizing inductance, the model is one series inductance.
    %
    %   Inputs:
    %     turnsRatio               Primary-to-secondary turns ratio n = N1/N2.
    %     switchingFrequency       Switching frequency (Hz).
    %     seriesInductance         Total primary-referred series inductance (H).
    %     mosfetOutputCapacitance  Output capacitance per primary switch (F), used by the
    %                              soft-switching methods. Default NaN.
    %
    %   Name-value options:
    %     SecondaryOutputCapacitance  Output capacitance per secondary switch (F). Default:
    %                                 the primary value.
    %     PrimarySideFraction         Share of the series inductance on the primary side of
    %                                 the magnetizing branch. Default 1.
    %     MagnetizingInductance       Primary-referred magnetizing inductance (H). Default Inf.
    %     DeadTime                    Dead time (s), used by the charge condition. Default NaN.
    %
    %   Example:
    %     sps = DABSPSPhysics(6, 100e3, 30e-6, 200e-12);
    %     P   = sps.powerForDuty(0.25, 400, 66);
    %     phi = sps.phaseShiftForPower(2000, 400, 66);
    %
    %   See also designDABConverter, plotDABPowerTransferCurve, plotDABZVSRegion.

    % Copyright 2026 The MathWorks, Inc.

    properties
        turnsRatio                  % n = N1/N2 (dimensionless, primary-to-secondary)
        switchingFrequency          % fsw (Hz)
        seriesInductance            % L (H), total primary-referred series inductance
        mosfetOutputCapacitance     % Coss (F) per primary switch
        secondaryOutputCapacitance  % Coss (F) per secondary switch
        primarySideFraction         % La/L, share of L on the primary side of Lm
        magnetizingInductance       % Lm (H), primary-referred; Inf removes the branch
        deadTime                    % Dead time (s), used by the charge condition
    end

    properties (Dependent)
        primarySideInductance             % La (H)
        secondarySideInductance           % Lb (H)
        primaryResonantInductance         % La + Lm||Lb (H), the primary commutation loop
        secondaryResonantInductance       % Lb + Lm||La (H), the secondary commutation loop
        primaryDifferentialCapacitance    % Coss of a primary switch (F)
        secondaryDifferentialCapacitance  % Coss of a secondary switch referred to the primary (F)
        magnetizingShareToPrimary         % Fraction of the magnetizing current the primary carries
        magnetizingShareToSecondary       % Fraction of the magnetizing current the secondary carries
    end

    methods
        function obj = DABSPSPhysics(turnsRatio, switchingFrequency, ...
                seriesInductance, mosfetOutputCapacitance, options)
            arguments
                turnsRatio (1,1) double
                switchingFrequency (1,1) double
                seriesInductance (1,1) double
                mosfetOutputCapacitance (1,1) double = NaN   % soft-switching methods only
                options.SecondaryOutputCapacitance (1,1) double = NaN
                options.PrimarySideFraction (1,1) double {mustBePositive} = 1
                options.MagnetizingInductance (1,1) double {mustBePositive} = Inf
                options.DeadTime (1,1) double = NaN
            end
            obj.turnsRatio = turnsRatio;
            obj.switchingFrequency = switchingFrequency;
            obj.seriesInductance = seriesInductance;
            obj.mosfetOutputCapacitance = mosfetOutputCapacitance;
            if isnan(options.SecondaryOutputCapacitance)
                obj.secondaryOutputCapacitance = mosfetOutputCapacitance;
            else
                obj.secondaryOutputCapacitance = options.SecondaryOutputCapacitance;
            end
            obj.primarySideFraction = options.PrimarySideFraction;
            obj.magnetizingInductance = options.MagnetizingInductance;
            obj.deadTime = options.DeadTime;
        end

        % ---- Dependent properties -------------------------------------------------------
        function La = get.primarySideInductance(obj)
            La = obj.primarySideFraction * obj.seriesInductance;
        end

        function Lb = get.secondarySideInductance(obj)
            Lb = (1 - obj.primarySideFraction) * obj.seriesInductance;
        end

        function Lres = get.primaryResonantInductance(obj)
            % The primary bridge resonates against everything in its own loop: its own side of
            % the series inductance, then the magnetizing branch in parallel with the far side.
            Lres = obj.primarySideInductance + ...
                localParallel(obj.magnetizingInductance, obj.secondarySideInductance);
        end

        function Lres = get.secondaryResonantInductance(obj)
            Lres = obj.secondarySideInductance + ...
                localParallel(obj.magnetizingInductance, obj.primarySideInductance);
        end

        function C = get.primaryDifferentialCapacitance(obj)
            C = obj.mosfetOutputCapacitance;
        end

        function C = get.secondaryDifferentialCapacitance(obj)
            % Referred to the primary, so every current in this class is primary-referred.
            C = obj.secondaryOutputCapacitance / obj.turnsRatio^2;
        end

        function share = get.magnetizingShareToPrimary(obj)
            % The magnetizing branch feeds the two bridges as a current divider, so each
            % bridge receives the fraction set by the inductance on the other side.
            share = obj.secondarySideInductance / obj.seriesInductance;
        end

        function share = get.magnetizingShareToSecondary(obj)
            share = obj.primarySideInductance / obj.seriesInductance;
        end

        % ---- Power transfer -------------------------------------------------------------
        function maximumPower = maxPower(obj, V1, V2)
            % Peak SPS power (at phase shift pi/2, D = 0.5) at one V1 and V2 pair.
            maximumPower = obj.turnsRatio .* V1 .* V2 ./ ...
                (8 * obj.switchingFrequency * obj.seriesInductance);
        end

        function transferredPower = powerForDuty(obj, D, V1, V2)
            % Forward power law P = n*V1*V2/(2*fsw*L) * D*(1-D), D in [0, 0.5]. Use
            % bidirectionalPowerForDuty when D can be negative.
            transferredPower = obj.turnsRatio .* V1 .* V2 ./ ...
                (2 * obj.switchingFrequency * obj.seriesInductance) .* D .* (1 - D);
        end

        function transferredPower = bidirectionalPowerForDuty(obj, D, V1, V2)
            % P = n*V1*V2/(2*fsw*L) * D*(1-|D|), antisymmetric in D over [-0.5, 0.5]
            % (reverse power flow for D < 0).
            transferredPower = obj.turnsRatio .* V1 .* V2 ./ ...
                (2 * obj.switchingFrequency * obj.seriesInductance) .* D .* (1 - abs(D));
        end

        function D = dutyForPower(obj, P, V1, V2)
            % The lower root of the power law, so D <= 0.5. Real only for P <= maxPower,
            % which phaseShiftForPower guards.
            D = 0.5 * (1 - sqrt(1 - 8 * obj.switchingFrequency * obj.seriesInductance .* P ./ ...
                (obj.turnsRatio .* V1 .* V2)));
        end

        function phi = phaseShiftForPower(obj, P, V1, V2)
            % Phase shift (rad) that transfers P at one V1 and V2 pair, NaN if that pair
            % cannot reach it, so callers can skip an infeasible operating point.
            if P > obj.maxPower(V1, V2)
                phi = NaN;
                return;
            end
            phi = obj.dutyForPower(P, V1, V2) * pi;
        end

        % ---- Series current -------------------------------------------------------------
        function [primaryCommutationCurrent, secondaryCommutationCurrent] = ...
                commutationCurrentMagnitudes(obj, D, V1, V2)
            % The series current is piecewise linear, with breakpoints at the primary
            % commutation (theta = 0) and the secondary one (theta = |phi| = pi*|D|):
            %     |i(0)|   = |V1 - n*V2*(1 - 2*|D|)| / (4*fsw*L)
            %     |i(phi)| = |n*V2 - V1*(1 - 2*|D|)| / (4*fsw*L)
            % This is the single-series-inductance form, which is what a device rating needs.
            %
            % D is signed over [-0.5, 0.5] (D < 0 is reverse flow) and only its magnitude
            % enters. Reversing the flow time-reverses the waveform, so it moves the larger
            % breakpoint to the other commutation instant and leaves both magnitudes alone.
            n = obj.turnsRatio;
            fourFswL = 4 * obj.switchingFrequency * obj.seriesInductance;
            dutyMagnitude = abs(D);
            primaryCommutationCurrent   = abs(V1 - n .* V2 .* (1 - 2 * dutyMagnitude)) ./ fourFswL;
            secondaryCommutationCurrent = abs(n .* V2 - V1 .* (1 - 2 * dutyMagnitude)) ./ fourFswL;
        end

        function peakCurrent = peakSeriesCurrent(obj, D, V1, V2)
            % Piecewise linear, so the extreme is the larger of the two commutation
            % currents. At a matched ratio (n*V2 = V1) they are equal.
            [primaryCommutationCurrent, secondaryCommutationCurrent] = ...
                obj.commutationCurrentMagnitudes(D, V1, V2);
            peakCurrent = max(primaryCommutationCurrent, secondaryCommutationCurrent);
        end

        % ---- Soft switching -------------------------------------------------------------
        function [primaryCurrent, secondaryCurrent, transferredPower] = ...
                bridgeCommutationCurrents(obj, D, V1, V2)
            % Current available to each bridge at its own commutation instant, and the exact
            % cycle-average power, from the T network at signed D.
            %
            % States are [i_a; i_b], both primary-referred: i_a flows in the primary-side
            % inductance, i_b in the secondary-side inductance, and i_a - i_b is the
            % magnetizing current. The state is piecewise linear over a half period and
            % half-wave odd symmetry x(T/2) = -x(0) closes it. Each returned current is
            % signed so a positive value moves that bridge's node charge the way its own
            % commutation needs, in either power direction.
            halfPeriod = 1 / (2 * obj.switchingFrequency);
            referredSecondaryVoltage = obj.turnsRatio * V2;
            if D >= 0
                % The primary leads. The secondary switches D of the way into the half period.
                directionSign = 1;
                segmentDuration = [D, 1 - D] * halfPeriod;
                appliedVoltage = [V1, V1; referredSecondaryVoltage, -referredSecondaryVoltage];
                secondaryVoltage = [-1, 1] * referredSecondaryVoltage;
            else
                % The secondary leads, so its switching instant comes 1+D of the way in.
                directionSign = -1;
                segmentDuration = [1 + D, -D] * halfPeriod;
                appliedVoltage = [V1, V1; -referredSecondaryVoltage, referredSecondaryVoltage];
                secondaryVoltage = [1, -1] * referredSecondaryVoltage;
            end

            firstSlope  = obj.networkSlope(appliedVoltage(:, 1));
            secondSlope = obj.networkSlope(appliedVoltage(:, 2));
            startState = -0.5 * (firstSlope * segmentDuration(1) + secondSlope * segmentDuration(2));
            edgeState  = startState + firstSlope  * segmentDuration(1);
            endState   = edgeState  + secondSlope * segmentDuration(2);

            primaryCurrent   = -startState(1);
            secondaryCurrent = directionSign * edgeState(2);

            % Exact average of n*v_CD * i_b over the half period, with i_b linear in each
            % segment, so it carries the finite magnetizing inductance.
            transferredPower = ( ...
                secondaryVoltage(1) * 0.5 * (startState(2) + edgeState(2)) * segmentDuration(1) + ...
                secondaryVoltage(2) * 0.5 * (edgeState(2)  + endState(2))  * segmentDuration(2)) ...
                / halfPeriod;
        end

        function [primaryAmplitude, primaryCharge, secondaryAmplitude, secondaryCharge] = ...
                thresholdCurrents(obj, V1, V2)
            % Minimum commutation current of each bridge, primary-referred, from the two
            % separate requirements a commutation has to meet:
            %   amplitude  the LC resonance must swing from one DC bus terminal to the
            %              other, so I >= 2*sqrt(V1*n*V2*Cdiff/Lres)
            %   charge     the node charge must move inside the dead time, so
            %              I >= 2*Cdiff*Vbus/deadTime
            referredSecondaryVoltage = obj.turnsRatio * V2;
            primaryAmplitude = 2 * sqrt(V1 * referredSecondaryVoltage * ...
                obj.primaryDifferentialCapacitance / obj.primaryResonantInductance);
            secondaryAmplitude = 2 * sqrt(V1 * referredSecondaryVoltage * ...
                obj.secondaryDifferentialCapacitance / obj.secondaryResonantInductance);
            primaryCharge = 2 * obj.primaryDifferentialCapacitance * V1 / obj.deadTime;
            secondaryCharge = 2 * obj.secondaryDifferentialCapacitance * ...
                referredSecondaryVoltage / obj.deadTime;
        end

        function [primaryMinimum, secondaryMinimum] = ...
                minimumCommutationCurrents(obj, powerDirection, V1, V2)
            % The requirement each bridge has to meet in a given power direction. The bridge
            % that leads sees a growing voltage across its own commutation loop, so it has to
            % clear the amplitude value. The bridge that lags sees a shrinking one and only
            % has to move its node charge inside the dead time.
            [primaryAmplitude, primaryCharge, secondaryAmplitude, secondaryCharge] = ...
                obj.thresholdCurrents(V1, V2);
            if powerDirection >= 0
                primaryMinimum   = primaryAmplitude;   % the primary leads
                secondaryMinimum = secondaryCharge;
            else
                primaryMinimum   = primaryCharge;
                secondaryMinimum = secondaryAmplitude; % the secondary leads
            end
        end

        function dutyBoundary = bridgeZvsDutyBoundary(obj, bridge, V1, V2, powerDirection)
            % Smallest signed D in the requested direction at which one named bridge reaches
            % its own minimum commutation current, or NaN if D = +-0.5 still falls short.
            % The available current grows with |D|, so a bisection finds the crossing.
            arguments
                obj
                bridge (1,1) string {mustBeMember(bridge, ["primary", "secondary"])}
                V1 (1,1) double
                V2 (1,1) double
                powerDirection (1,1) double
            end
            directionSign = 1;
            if powerDirection < 0
                directionSign = -1;
            end
            if obj.bridgeMeetsZvs(bridge, 0, V1, V2, directionSign)
                dutyBoundary = 0;
                return;
            end
            if ~obj.bridgeMeetsZvs(bridge, directionSign * 0.5, V1, V2, directionSign)
                dutyBoundary = NaN;
                return;
            end
            lowerDuty = 0;
            upperDuty = 0.5;
            for iteration = 1:60
                middleDuty = 0.5 * (lowerDuty + upperDuty);
                if obj.bridgeMeetsZvs(bridge, directionSign * middleDuty, V1, V2, directionSign)
                    upperDuty = middleDuty;
                else
                    lowerDuty = middleDuty;
                end
            end
            dutyBoundary = directionSign * upperDuty;
        end

        function [dutyBoundary, criticalBridge] = zvsDutyBoundary(obj, V1, V2, powerDirection)
            % Smallest signed D at which both bridges soft switch, and the bridge that
            % decides it. NaN when one of the bridges never reaches its minimum.
            primaryDuty   = obj.bridgeZvsDutyBoundary("primary", V1, V2, powerDirection);
            secondaryDuty = obj.bridgeZvsDutyBoundary("secondary", V1, V2, powerDirection);
            if abs(primaryDuty) >= abs(secondaryDuty) || isnan(primaryDuty)
                dutyBoundary = primaryDuty;
                criticalBridge = "primary";
            else
                dutyBoundary = secondaryDuty;
                criticalBridge = "secondary";
            end
        end

        function [floorPower, criticalBridge, dutyBoundary] = ...
                zvsFloorPower(obj, V1, V2, powerDirection)
            % Lowest power at which the converter still soft switches at one V1 and V2 pair,
            % in one power direction. Power is the exact T-network cycle average at the
            % boundary duty, so it carries the finite magnetizing inductance.
            [dutyBoundary, criticalBridge] = obj.zvsDutyBoundary(V1, V2, powerDirection);
            if isnan(dutyBoundary)
                floorPower = NaN;
                return;
            end
            [~, ~, transferredPower] = obj.bridgeCommutationCurrents(dutyBoundary, V1, V2);
            floorPower = abs(transferredPower);
        end
    end

    methods (Access = private)
        function slope = networkSlope(obj, appliedVoltage)
            % dx/dt for the T network with x = [i_a; i_b], from M*xdot = u after eliminating
            % the mid-node voltage. Written with the magnetizing inverse inductance so an
            % infinite magnetizing inductance collapses the network to one series inductance
            % instead of dividing by infinity.
            inductanceOnPrimarySide = obj.primarySideInductance;
            inductanceOnSecondarySide = obj.secondarySideInductance;
            magnetizingInverseInductance = 1 / obj.magnetizingInductance;
            denominator = inductanceOnPrimarySide * inductanceOnSecondarySide * ...
                magnetizingInverseInductance + inductanceOnPrimarySide + inductanceOnSecondarySide;
            slope = [ ...
                (inductanceOnSecondarySide * magnetizingInverseInductance + 1) * appliedVoltage(1) ...
                    + appliedVoltage(2); ...
                appliedVoltage(1) + ...
                    (inductanceOnPrimarySide * magnetizingInverseInductance + 1) * appliedVoltage(2)] ...
                / denominator;
        end

        function meetsZvs = bridgeMeetsZvs(obj, bridge, D, V1, V2, directionSign)
            % Does one bridge clear its own minimum at this duty?
            [primaryCurrent, secondaryCurrent] = obj.bridgeCommutationCurrents(D, V1, V2);
            [primaryMinimum, secondaryMinimum] = ...
                obj.minimumCommutationCurrents(directionSign, V1, V2);
            if bridge == "primary"
                meetsZvs = primaryCurrent >= primaryMinimum;
            else
                meetsZvs = secondaryCurrent >= secondaryMinimum;
            end
        end
    end
end

% =============================================================================
function parallelInductance = localParallel(firstInductance, secondInductance)
% Two inductances in parallel, defined when either one is zero or infinite.
if isinf(firstInductance)
    parallelInductance = secondInductance;
elseif isinf(secondInductance)
    parallelInductance = firstInductance;
elseif firstInductance + secondInductance == 0
    parallelInductance = 0;
else
    parallelInductance = firstInductance * secondInductance / (firstInductance + secondInductance);
end
end
