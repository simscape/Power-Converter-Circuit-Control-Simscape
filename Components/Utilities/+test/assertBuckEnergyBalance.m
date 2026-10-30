function assertBuckEnergyBalance(testCase, comparison)
%ASSERTBUCKENERGYBALANCE Verify the device block's junction receives the energy it computed.
%
%   test.assertBuckEnergyBalance(testCase, comparison) verifies that the heat the device
%   block injected into its junction thermal mass equals the loss energy it computed, within
%   0.1 %.
%
%   Inputs:
%     testCase    matlab.unittest.TestCase.
%     comparison  Result of test.compareBuckDeviceModels.

% Copyright 2026 The MathWorks, Inc.

testCase.verifyEqual(comparison.InjectedEnergy, comparison.ComputedEnergy, "RelTol", 1e-3, ...
    sprintf("%s energy balance: heat injected %.6f J, loss energy computed %.6f J.", ...
    comparison.DeviceKind, comparison.InjectedEnergy, comparison.ComputedEnergy));
end
