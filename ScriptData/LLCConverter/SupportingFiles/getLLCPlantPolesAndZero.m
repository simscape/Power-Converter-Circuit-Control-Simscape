function systemModel = getLLCPlantPolesAndZero(sys, options)
%   This function estimates the poles and zeros of an LLC resonant converter by
%   fitting a transfer function to its estimated frequency response data.
%   The number of poles and zeros in the fitted model can be specified.
%
%   Inputs:
%     sys         Identified frequency response data (idfrd object, or compatible)
%
%     options     Structure with optional fields:
%                   - numPole: Number of poles in fitted transfer function (default: 2)
%                   - numZero: Number of zeros in fitted transfer function (default: 1)
%
%   Output:
%     systemModel   Structure containing:
%         - transferFunctionVec: Identified transfer function object (tfest output)
%         - transferFunction:    Numerator/denominator transfer function (tf object)
%         - numerator:           Numerator coefficients vector
%         - demonimator:         Denominator coefficients vector
%         - allPoles:            All poles (complex values)
%         - allZeros:            All zeros (complex values)
%         - poles:               Dominant poles (sorted, up to numPole)
%         - zeros:               Dominant zeros (sorted, up to numZero)
%         - poleWn:              Natural frequency of dominant pole
%         - poleDampingRatio:    Damping ratio of dominant pole
%
%   Method:
%     - Fits a transfer function model to frequency response data using tfest.
%     - Extracts and sorts poles and zeros.
%     - Calculates natural frequency and damping ratio of the dominant pole.
%     - Displays the transfer function, poles, and zeros.
%
%   Example:
%     sys = idfrd(mag.*exp(1j*deg2rad(phase)), freq, Ts);
%     options.numPole = 2;
%     options.numZero = 1;
%     systemModel = getLLCPlantPolesAndZero(sys, options);
%
%   Notes:
%     - Requires System Identification Toolbox.
%     - sys should be an idfrd object or compatible frequency response data.
%     - The function prints the fitted transfer function, poles, and zeros.

% Copyright 2025-2026 The MathWorks, Inc.

arguments
    sys
    options.numPole (1,1) {mustBeNonnegative} = 2; % Number of poles
    options.numZero (1,1) {mustBeNonnegative} = 1; % Number of zeros
end

systemModel.transferFunctionVec = tfest(sys, options.numPole,options.numZero);

systemModel.transferFunction = tf(systemModel.transferFunctionVec.Numerator,systemModel.transferFunctionVec.Denominator);
[b,a] = eqtflength(systemModel.transferFunctionVec.Numerator,systemModel.transferFunctionVec.Denominator);
disp("LLC converter transfer function")
tf(b,a)

[z,p,~]= tf2zp(b,a);
systemModel.numerator = b;
systemModel.demonimator = a;
systemModel.allPoles = p;
systemModel.allZeros = z;
poleAscending = sort(systemModel.allPoles(real(systemModel.allPoles)<=0));
zeroAscending = sort(systemModel.allZeros(real(systemModel.allZeros)<=0));
if length(poleAscending)>options.numPole
    systemModel.poles = poleAscending(1:options.numPole);
else
    systemModel.poles = poleAscending;
end
if length(zeroAscending)>options.numZero
    systemModel.zeros = zeroAscending(1:options.numZero);
else
    systemModel.zeros = zeroAscending;
end
systemModel.poleWn = abs(sqrt((real(systemModel.poles(1)))^2-(imag(systemModel.poles(1)))^2));
systemModel.poleDampingRatio = abs(real(systemModel.poles(1))/systemModel.poleWn);
fprintf("\n LLC Power Circuit Poles \n");
disp(systemModel.poles);
fprintf("\n LLC Power Circuit zeros \n");
disp(systemModel.zeros);
end



