function compareTwoTests = singleNeuronClassifierWilcoxon(results)

%%

v2struct(results)
Nmax = results(1).testPredictors(1).outFold(1).N;
predNames = {testPredictors.predictorName}';
 
if (0)
    %two_test_name_mat = { 'None', 'HD' ;
    %                      'None', 'V'  ;
    %                      'HD'  , 'HD+V';
    %                      'V'   , 'HD+V' };
else
    two_test_name_mat = nchoosek(predNames,2); % Combinations of predNames taken two at a time
end

%for ij = 1:size(two_test_mat,1)
for ij = 1:size(two_test_name_mat,1)
    
    %two_test_idx = two_test_mat(ij,:);
    %two_test_name = { testPredictors(two_test_idx(1)).predictorName, ...
    %                  testPredictors(two_test_idx(2)).predictorName };
   two_test_name = two_test_name_mat(ij,:);
   two_test_idx(1) = find( strcmp(two_test_name{1}, predNames)  );
   two_test_idx(2) = find( strcmp(two_test_name{2}, predNames)  );
    
    clear pWilcox hWilcox statsWilcox
    for n=1:Nmax
        % Wilcoxon comparing logL of test sets
        LTest1 = logLiTest{two_test_idx(1)}(n,:);
        LTest2 = logLiTest{two_test_idx(2)}(n,:);
        [ pWilcox(n), hWilcox(n), statsWilcox(n)] = ...
            signrank(LTest2,LTest1,'tail','right'); 
    end
     compareTwoTests(ij) = v2struct( ...
        two_test_idx, two_test_name, ...
        pWilcox, hWilcox, statsWilcox );
end


if ~exist('compareTwoTests')
   % compareTwoTests = struct( ...
   %     'two_test_idx', [],   ...
   %     'two_test_name', [],  ...
   %     'pWilcox', [],        ...
   %     'hWilcox', [],        ...
   %     'statsWilcox', []) ;
    compareTwoTests = [];
end




%% Supporting function ------------------------------------------

function [ pWilcox, hWilcox, statsWilcox ] = compareTestPredictors(logL1, logL2)

[ Nmax , ~] = size(logL1);

clear pWilcox hWilcox statsWilcox
for n=1:Nmax
    % Wilcoxon comparing logL of test sets
    LTest1 = logL1(n,:);
    LTest2 = logL2(n,:);
    [ p , h , stats] = signrank(LTest2,LTest1,'tail','right','method','approximate');
    
    pWilcox(n) = p;
    hWilcox(n) = h;
    if ~isfield(stats, 'zval'), stats.zval = nan; end
    statsWilcox(n) = stats;
end



