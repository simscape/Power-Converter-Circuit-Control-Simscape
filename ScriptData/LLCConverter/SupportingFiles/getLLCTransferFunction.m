function llcTF = getLLCTransferFunction(sys, options)
% Function to plot the bode plot

% Copyright 2026 The MathWorks, Inc.

arguments
    sys
    options.numPole (1,1) {mustBeNonnegative} = 2; % Number of poles
    options.numZero (1,1) {mustBeNonnegative} = 1; % Number of zeros
end
H = tf(sys);
[b,a] = tfdata(H);
[z,p] = tf2zp(cell2mat(b),cell2mat(a));
llcTF.numerator = b;
llcTF.demonimator = a;
llcTF.allPoles = p;
llcTF.allZeros = z;
poleAscending = sort(llcTF.allPoles(real(llcTF.allPoles)<=0));
zeroAscending = sort(llcTF.allZeros);
if length(poleAscending)>options.numPole
    llcTF.poles = poleAscending(1:options.numPole);
else
    llcTF.poles = poleAscending;
end
if length(zeroAscending)>options.numZero
    llcTF.zeros = zeroAscending(1:options.numZero);
else
    llcTF.zeros = zeroAscending;
end
llcTF.poleWn = abs(sqrt((real(llcTF.poles(1)))^2-(imag(llcTF.poles(1)))^2));
llcTF.poleDampingRatio = abs(real(llcTF.poles(1))/llcTF.poleWn);
disp("LLC Power Circuit Poles");
disp(llcTF.poles);
disp("LLC Power Circuit zeros");
disp(llcTF.zeros);
llcTF.transferFunction = H;
end


