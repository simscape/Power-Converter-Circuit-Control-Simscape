function llcSimulationData = plotLLCResonantTankVoltageCurrent(logsoutLLCConverter, options)
% This function extracts and plots key voltage and current waveforms from the simulation
% output of an LLC resonant converter. The following signals are visualized:
%   - Primary and secondary transformer voltages (Vprimary, Vsecondary)
%   - Primary and secondary transformer AC currents (Iprimary, Isecondary)
%   - Input and output DC currents (Iin, Iout)
%   - Output DC voltage (Vout)
%
% The script automatically determines the last five cycles of the output voltage,
% based on the specified resonant frequency, and focuses the plots on this interval
% to highlight steady-state behavior.
%
% Inputs:
%   logsoutLLCConverter      Simulation log (Simulink.SimulationData.Dataset) containing
%                           the required signals: Vprimary, Vsecondary, Iprimary, Isecondary,
%                           Iin, Iout, Vout.
%   options.ResonantFrequency (optional)
%                           Resonant frequency of the converter as a simscape.Value object.

% Copyright 2025-2026 The MathWorks, Inc.

arguments
    logsoutLLCConverter
    options.ResonantFrequency = simscape.Value(100e3, "Hz"); % Hz
end

ResonantFrequency_Hz = convert(options.ResonantFrequency, "Hz");

% Plot the transformer voltage and currents
llcSimulationData.Vprimary = logsoutLLCConverter.get('Vprimary').Values.Data;
llcSimulationData.VprimaryTime = logsoutLLCConverter.get('Vprimary').Values.Time;

llcSimulationData.Vsecondary = logsoutLLCConverter.get('Vsecondary').Values.Data;
llcSimulationData.VsecondaryTime = logsoutLLCConverter.get('Vsecondary').Values.Time;

llcSimulationData.Iprimary = logsoutLLCConverter.get('Iprimary').Values.Data;
llcSimulationData.IprimaryTime = logsoutLLCConverter.get('Iprimary').Values.Time;

llcSimulationData.Isecondary = logsoutLLCConverter.get('Isecondary').Values.Data;
llcSimulationData.IsecondaryTime = logsoutLLCConverter.get('Isecondary').Values.Time;

llcSimulationData.Iin = logsoutLLCConverter.get('Iin').Values.Data;
llcSimulationData.IinTime = logsoutLLCConverter.get('Iin').Values.Time;

llcSimulationData.Iout = logsoutLLCConverter.get('Iout').Values.Data;
llcSimulationData.IoutTime = logsoutLLCConverter.get('Iout').Values.Time;

llcSimulationData.Vout = logsoutLLCConverter.get('Vout').Values.Data;
llcSimulationData.VoutTime = logsoutLLCConverter.get('Vout').Values.Time;

simTime = llcSimulationData.VoutTime(end);
if simTime>5/ResonantFrequency_Hz.value
    timeFor5CycleStart = simTime-5/ResonantFrequency_Hz.value;
    timeIdx = find(llcSimulationData.VoutTime>=timeFor5CycleStart,1);
else
    timeIdx = 1;
end

figure("Name","LLC Converter Voltage and Current Waveform")
set(gcf, 'Position',  [400, 300, 800, 700]);

subplot(4,1,1)
plot(llcSimulationData.VprimaryTime(timeIdx:end),llcSimulationData.Vprimary(timeIdx:end), 'LineWidth',2);
hold on;
plot(llcSimulationData.VsecondaryTime(timeIdx:end),llcSimulationData.Vsecondary(timeIdx:end), 'LineWidth',2);
grid on
box on
xlabel('time (s)');
ylabel('Voltage (V)');
xlim([llcSimulationData.VsecondaryTime(timeIdx),llcSimulationData.VsecondaryTime(end)]);

legendData = {"Vinverter", "Vsecondary"};
legend(legendData);
box on
hold on
title("Input and Output AC Voltage",'FontSize',13);

subplot(4,1,2)
plot(llcSimulationData.IprimaryTime(timeIdx:end),llcSimulationData.Iprimary(timeIdx:end), 'LineWidth',2);
hold on
plot(llcSimulationData.IsecondaryTime(timeIdx:end),llcSimulationData.Isecondary(timeIdx:end), 'LineWidth',2);
grid on
box on
xlabel('time (s)');
ylabel('Current (A)');
xlim([llcSimulationData.IinTime(timeIdx),llcSimulationData.IinTime(end)]);
legendData = {"Iprimary", "Isecondary"};
legend(legendData);
box on
hold on
title("Input and Output AC Current",'FontSize',13);

subplot(4,1,3)
plot(llcSimulationData.IinTime(timeIdx:end),llcSimulationData.Iin(timeIdx:end), 'LineWidth',2);
hold on
plot(llcSimulationData.IoutTime(timeIdx:end),llcSimulationData.Iout(timeIdx:end), 'LineWidth',2);
grid on
box on
xlabel('time (s)');
ylabel('Current (A)');
legendData = {"Iin", "Iout"};
xlim([llcSimulationData.IinTime(timeIdx),llcSimulationData.IinTime(end)]);

legend(legendData);
box on
hold on
title("Input and Output DC Current",'FontSize',13);


subplot(4,1,4)
plot(llcSimulationData.VoutTime(timeIdx:end),llcSimulationData.Vout(timeIdx:end), 'LineWidth',2);
hold on
grid on
box on
xlabel('time (s)');
ylabel('Output Voltage (V)');
box on
hold on
title("Output DC Voltage",'FontSize',13);
ylim([0.5*max(llcSimulationData.Vout(timeIdx:end)),1.25*max(llcSimulationData.Vout(timeIdx:end))]);
xlim([llcSimulationData.VoutTime(timeIdx),llcSimulationData.VoutTime(end)])
set(gcf, 'Position',  [400, 300, 800, 700]);
end

