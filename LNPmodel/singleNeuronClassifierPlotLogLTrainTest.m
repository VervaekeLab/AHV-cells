function hfigTrainTest = singleNeuronClassifierPlotLogLTrainTest(results,varargin)
% compare logL training and test set

nTests = length(results.testPredictors);
inputP = inputParser;
addRequired(inputP, 'results')
addParameter(inputP, 'tag', '', @ischar)
addParameter(inputP, 'uid', {''}, @iscell)
addParameter(inputP, 'testSelect', 1:nTests , @(x)isnumeric(x) && x<=nTests)
parse(inputP, results, varargin{:});
v2struct(inputP.Results)

logLiTrain = results.logLiTrain;
logLiTest  = results.logLiTest;
          
N = results(1).testPredictors(1).outFold(1).N;
idxRoi = 1:N;  % unsorted
NplotMax = 48;
NplotRows = 6;
NplotCols = 8;
hfigTrainTest = [];
for ii = 1:length(nTests)
    testNum = testSelect(ii);
    predictorName = results.testPredictors(testNum).predictorName;

    h1 = figure();
    set(gcf,'Units','normalized','OuterPosition',[0.2,0.1,0.6,0.8])
    set(h1,'Name', sprintf('LogL_Train_Test %s',predictorName) )        
    for i=1:min(NplotMax,N)
        
        % select cell, sorted
        n = idxRoi(i); 
  
        subplot(NplotRows,NplotCols,i)
        compare2( logLiTrain{testNum}(n,:), logLiTest{testNum}(n,:) );
        axis equal
        xymin=min([xlim,ylim]);  xymax=max([xlim,ylim]);
        xlim( [xymin,xymax] );   ylim( [xymin,xymax] );
        legend off
        %xlabel('LLHi Train'), ylabel('LLHi Test')
    end
    suplabel('LLHi Train');
    suplabel('LLHi Test','y');
    
    hfigTrainTest = [hfigTrainTest, h1];
end
