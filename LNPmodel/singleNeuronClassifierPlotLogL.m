function hfigLogL = singleNeuronClassifierPlotLogL(results,varargin)

inputP = inputParser;
addRequired(inputP, 'results')
addParameter(inputP, 'roiSelect', [], @isnumeric)
addParameter(inputP, 'tag', '', @ischar)
nTests = length(results.compareTwoTests);
addParameter(inputP, 'compareSelect', 1:nTests, @(x)isnumeric(x) && x<=nTests)
addParameter(inputP, 'uid', {''}, @iscell)
parse(inputP, results, varargin{:});
v2struct(inputP.Results)

logLiTrain = results.logLiTrain;
logLiTest  = results.logLiTest;
sessionID = results.sessionID;
testPredictors = results.testPredictors;
compareTwoTests = results.compareTwoTests;

NplotMax =  48;
NplotRows = 6;
NplotCols = 8;


%% Make plots logL

hfigLogL = [];

for ii = 1:length(compareSelect)
    ij = compareSelect(ii);

    % Get relevant properties
    two_test_idx  = compareTwoTests(ij).two_test_idx;
    two_test_name = compareTwoTests(ij).two_test_name;
    pWilcox       = compareTwoTests(ij).pWilcox;
    hWilcox       = compareTwoTests(ij).hWilcox;
    statsWilcox   = compareTwoTests(ij).statsWilcox;
    
    
    h1 = figure;
    set(h1,'Units','normalized','OuterPosition',[0.2,0.1,0.6,0.8]) %,[0.2,0.1,0.6,0.8])
    set(h1,'Name', sprintf('LogLH_%d_%s_%s',(ij),two_test_name{1},two_test_name{2}) )

    % choose which rois to plot
    if isempty(roiSelect)
        [pWilcoxSort,idxRoi] = sort(pWilcox,'ascend');
        %N = results(1).testPredictors(1).outFold(1).N;
    else
        idxRoi = roiSelect;
    end
    
    N = length(idxRoi);
    for i=1:min(NplotMax,N)
        
        % select cell, sorted
        n = idxRoi(i); 
        
        % Subplots
        subplot( NplotRows, NplotCols,i)
        L1 = logLiTest{two_test_idx(1)}(n,:);
        L2 = logLiTest{two_test_idx(2)}(n,:);
        compare2( L1 , L2 );
        axis equal
        xymin=min([xlim,ylim]);  xymax=max([xlim,ylim]);
        xlim( [xymin,xymax] );   ylim( [xymin,xymax] );
        legend off
        if ~isempty(uid{1}), uidstr = uid{n}(1:7);
        else uidstr = '';
        end
        txt = sprintf('roi #%d %s\n p: %.2g', n,uidstr,pWilcox(n));
        %txt = sprintf('roi #%d\n p: %.2g', n,pWilcox(n));
        title(txt)
        %xlabel('LLHi Train'), ylabel('LLHi Test')
    end
    txt = sprintf('%s%s (cells: %d), %s vs. %s, one-sided p<0.05: %.2f',...
        tag,sessionID, N,two_test_name{1}, two_test_name{2}, mean(hWilcox));
    suplabel( replace(txt,'_','\_'), 't' );
    suplabel( sprintf('LLHi %s', two_test_name{1}) ,'x' );
    suplabel( sprintf('LLHi %s', two_test_name{2}) ,'y' );
    
    
    %compareTwoTests(ij) = v2struct( ...
    %    two_test_idx, two_test_name, ...
    %    pWilcox, hWilcox, statsWilcox );
    
    hfigLogL = [hfigLogL, h1];
end


           
