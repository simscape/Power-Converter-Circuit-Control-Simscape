function CLLCSimulationData = plotCLLCResonantTankVoltageCurrent(logsoutCLLCConverter, options)
% This function extracts and plots key voltage and current waveforms from the simulation
% output of a CLLC resonant converter. It plots these signals:
%   - Primary and secondary transformer voltages (Vprimary, Vsecondary)
%   - Primary and secondary transformer AC currents (Iprimary, Isecondary)
%   - Input and output DC currents (Iin, Iout)
%   - Output DC voltage (Vout)
%
% The function determines the last five cycles of the output voltage,
% based on the specified resonant frequency, and focuses the plots on this interval
% to highlight steady-state behavior.
%
% Inputs:
%   logsoutCLLCConverter      Simulation log (Simulink.SimulationData.Dataset) containing
%                           the required signals: Vprimary, Vsecondary, Iprimary, Isecondary,
%                           Iin, Iout, Vout.
%   options.ResonantFrequency (optional)
%                           Resonant frequency of the converter as a simscape.Value object.

% Copyright 2025-2026 The MathWorks, Inc.

arguments
    logsoutCLLCConverter
    options.ResonantFrequency = simscape.Value(100e3, "Hz"); % Hz
end

ResonantFrequency_Hz = convert(options.ResonantFrequency, "Hz");

% Plot the transformer voltage and currents
CLLCSimulationData.Vprimary = logsoutCLLCConverter.get('Vprimary').Values.Data;
CLLCSimulationData.VprimaryTime = logsoutCLLCConverter.get('Vprimary').Values.Time;

CLLCSimulationData.Vsecondary = logsoutCLLCConverter.get('Vsecondary').Values.Data;
CLLCSimulationData.VsecondaryTime = logsoutCLLCConverter.get('Vsecondary').Values.Time;

CLLCSimulationData.Iprimary = logsoutCLLCConverter.get('Iprimary').Values.Data;
CLLCSimulationData.IprimaryTime = logsoutCLLCConverter.get('Iprimary').Values.Time;

CLLCSimulationData.Isecondary = logsoutCLLCConverter.get('Isecondary').Values.Data;
CLLCSimulationData.IsecondaryTime = logsoutCLLCConverter.get('Isecondary').Values.Time;

CLLCSimulationData.Iin = logsoutCLLCConverter.get('Iin').Values.Data;
CLLCSimulationData.IinTime = logsoutCLLCConverter.get('Iin').Values.Time;

CLLCSimulationData.Iout = logsoutCLLCConverter.get('Iout').Values.Data;
CLLCSimulationData.IoutTime = logsoutCLLCConverter.get('Iout').Values.Time;

CLLCSimulationData.Vout = logsoutCLLCConverter.get('Vout').Values.Data;
CLLCSimulationData.VoutTime = logsoutCLLCConverter.get('Vout').Values.Time;

simTime = CLLCSimulationData.VoutTime(end);
if simTime>5/ResonantFrequency_Hz.value
    timeFor5CycleStart = simTime-5/ResonantFrequency_Hz.value;
    timeIdx = find(CLLCSimulationData.VoutTime>=timeFor5CycleStart,1);
else
    timeIdx = 1;
end

figure("Name","CLLC Converter Voltage and Current Waveform")
set(gcf, 'Position',  [400, 300, 800, 700]);

subplot(4,1,1)
plot(CLLCSimulationData.VprimaryTime(timeIdx:end),CLLCSimulationData.Vprimary(timeIdx:end), 'LineWidth',2);
hold on;
plot(CLLCSimulationData.VsecondaryTime(timeIdx:end),CLLCSimulationData.Vsecondary(timeIdx:end), 'LineWidth',2);
grid on
box on
xlabel('time (s)');
ylabel('Voltage (V)');
xlim([CLLCSimulationData.VsecondaryTime(timeIdx),CLLCSimulationData.VsecondaryTime(end)]);

legendData = {"Vinverter", "Vsecondary"};
legend(legendData);
box on
hold on
title("Input and Output AC Voltage",'FontSize',13);

subplot(4,1,2)
plot(CLLCSimulationData.IprimaryTime(timeIdx:end),CLLCSimulationData.Iprimary(timeIdx:end), 'LineWidth',2);
hold on
plot(CLLCSimulationData.IsecondaryTime(timeIdx:end),CLLCSimulationData.Isecondary(timeIdx:end), 'LineWidth',2);
grid on
box on
xlabel('time (s)');
ylabel('Current (A)');
xlim([CLLCSimulationData.IinTime(timeIdx),CLLCSimulationData.IinTime(end)]);
legendData = {"Iprimary", "Isecondary"};
legend(legendData);
box on
hold on
title("Input and Output AC Current",'FontSize',13);

subplot(4,1,3)
plot(CLLCSimulationData.IinTime(timeIdx:end),CLLCSimulationData.Iin(timeIdx:end), 'LineWidth',2);
hold on
plot(CLLCSimulationData.IoutTime(timeIdx:end),CLLCSimulationData.Iout(timeIdx:end), 'LineWidth',2);
grid on
box on
xlabel('time (s)');
ylabel('Current (A)');
legendData = {"Iin", "Iout"};
xlim([CLLCSimulationData.IinTime(timeIdx),CLLCSimulationData.IinTime(end)]);

legend(legendData);
box on
hold on
title("Input and Output DC Current",'FontSize',13);


subplot(4,1,4)
plot(CLLCSimulationData.VoutTime(timeIdx:end),CLLCSimulationData.Vout(timeIdx:end), 'LineWidth',2);
hold on
grid on
box on
xlabel('time (s)');
ylabel('Output Voltage (V)');
box on
hold on
title("Output DC Voltage",'FontSize',13);
ylim([0.5*max(CLLCSimulationData.Vout(timeIdx:end)),1.25*max(CLLCSimulationData.Vout(timeIdx:end))]);
xlim([CLLCSimulationData.VoutTime(timeIdx),CLLCSimulationData.VoutTime(end)])
set(gcf, 'Position',  [400, 300, 800, 700]);
end

