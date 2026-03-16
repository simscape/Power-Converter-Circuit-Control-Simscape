classdef LLCResonantConverterUnit < matlab.unittest.TestCase
    % This MATLAB unit test is used to run all the codes used in the
    % Design and Analysis of LLC Resonant Converter example.

    % Copyright 2025 The MathWorks, Inc.

    properties
        openfigureListBefore;
        openModelsBefore;
    end

     methods(TestMethodSetup)
         
         function listOpenFigures(testCase)
            % List all open figures
            testCase.openfigureListBefore = findall(0,'Type','Figure');
        end

        function listOpenModels(testCase)
            % List all open simulink models
            testCase.openModelsBefore = get_param(Simulink.allBlockDiagrams('model'),'Name');
        end

        function setupWorkingFolder(testCase)
            % Set up working folder
            import matlab.unittest.fixtures.WorkingFolderFixture;
            testCase.applyFixture(WorkingFolderFixture);
        end
     end

      methods(TestMethodTeardown)

        function closeOpenedFigures(testCase)
            % Close all figure opened during test
            figureListAfter = findall(0,'Type','Figure');
            figuresOpenedByTest = setdiff(figureListAfter, testCase.openfigureListBefore);
            arrayfun(@close, figuresOpenedByTest);
        end

        function closeOpenedModels(test)
            % Close all models opened during test
            openModelsAfter = get_param(Simulink.allBlockDiagrams('model'),'Name');
            modelsOpenedByTest = setdiff(openModelsAfter, test.openModelsBefore);
            close_system(modelsOpenedByTest, 0);
        end

    end

    methods (Test)

        function LLCSimulateFullBridgeModelModel(testCase)
            % Test for the LLCResonantConverterFullBridge example model
            % Load system and add teardown
            modelname = "LLCResonantConverterFullBridge";
            load_system(modelname)

            % Simulate model
            testCase.verifyWarningFree(@()localSim(modelname), sprintf("'%s' should simulate without any errors or warnings.", modelname));
        end

        function LLCSimulateGainCurveModel(testCase)
            % Test for the LLCResonantConverterFullBridge example model
            % Load system and add teardown
            modelname = "GainCurveLLCConverter";
            load_system(modelname)

            % Simulate model
            testCase.verifyWarningFree(@()localSim(modelname), sprintf("'%s' should simulate without any errors or warnings.", modelname));
        end

        function LLCSimulateFrequencyResponseModel(testCase)
            % Test for the LLCResonantConverterFullBridge example model
            % Load system and add teardown
            modelname = "EstimateFrequencyResponse";
            load_system(modelname)

            % Simulate model
            testCase.verifyWarningFree(@()localSim(modelname), sprintf("'%s' should simulate without any errors or warnings.", modelname));
        end

        function LLCResonantConverterMainLiveScript(~)
            %  Test for the LLCResonantConverterFullBridgMain live script

            % Run live script
            LLCResonantConverterFullBridgeMain;
        end

        function LLCResonantConverterEstimateParameterLiveScript(~)
            %  Test for the LLCResonantConverterFullBridgMain live script

            % Run live script
            EstimateLLCConverterResonantTankParameters;
        end

        function LLCResonantConvertersControllerDesignLivescript(~)
            % Test for LinearizeLLCConverterResonantConverter live script

            % Run live script
            LLCResonantConvertersControllerDesign;
        end

        function SelectLLCConverterComponentsLivescirpt(~)
            % Test for LinearizeLLCConverterResonantConverter live script

            % Run live script
            SelectLLCConverterComponents;
        end

    end
    
end

function localSim(model)
[~] = sim(model);
end


