function plotLLCBodePlot(sys, options)
% Function to plot the bode plot

% Copyright 2026 The MathWorks, Inc.

arguments
    sys
    options.FreqLimit {mustBeNonnegative} = [100 100e3]; % Frequency limit
end

% Linearizing the model
titleInput = "LLC Power Circuit Bode Plot";

% Finding Bode plot
[mag,phase,wout] = bode(sys,2*pi*linspace(options.FreqLimit(1),options.FreqLimit(2),150));
bodeMagnitude = reshape(mag,[1,length(mag)]);
bodePhase = reshape(phase,[1,length(phase)]);

% Plotting gain and phase margin
figure('Name','LLCResonantConverterFullBridgeControllerBodePlot');

hsubplot = subplot(2,1,1); %#ok<*NASGU>
semilogx(wout/(2*pi),20*log10(bodeMagnitude),'LineWidth',2);
hold on
xlabel('Frequency (Hz)','FontSize',12);
ylabel('Magnitude (dB)','FontSize',12);
title('Magnitude Bode Plot','FontSize',13);
grid on
box on

hsubplot = subplot(2,1,2);
semilogx(wout/(2*pi),bodePhase+720,'LineWidth',2);
hold on
xlabel('Frequency (Hz)','FontSize',12);
ylabel('Phase (deg)','FontSize',12);
title('Phase Bode Plot','FontSize',13);
grid on
box on
sgtitle(titleInput,'FontSize',13);
set(gcf, 'Position',  [400, 300, 600, 600]);
end


