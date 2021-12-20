function results = method_lnp( spikes , predictors , setup, varargin)
% Linear Non-Linear Poisson.
% response  : P x N  spike matrix
% predictor : P x C  stimuli of C cells of npred


%% Inputs
session=[];
inputP = inputParser;
addRequired(inputP, 'spikes');      % TIME x CELLS
addRequired(inputP, 'predictors');  % TIME x PREDICTORS
addOptional(inputP, 'setup', []);
addParameter(inputP, 'tag'        , '' , @ischar);
addParameter(inputP, 'infoPredictors'  , {} , @iscell);
addParameter(inputP, 'uniqPredictors'  , {} , @iscell);
addParameter(inputP, 'lambdaSmooth', 0 , @isnumeric);
addParameter(inputP, 'runDecode', true , @islogical);
addParameter(inputP, 'deltaTime'  , 10 , @isnumeric);
addParameter(inputP, 'lambdaJump' ,  0 , @isnumeric);
addParameter(inputP, 'stdJump'    , 10 , @isnumeric);
addParameter(inputP, 'session'  , struct([]), @isstruct);
addParameter(inputP, 'idxY'     , [], @islogical);
addParameter(inputP, 'fitMethod'    , 'fminsearch', @(x)ismember(x,{'glmfit','fminsearch','fminunc'}));
addParameter(inputP, 'plotLogL'     , false, @islogical);
addParameter(inputP, 'makeVideoLogL', false, @islogical);
%addParameter(inputP, 'interlaceTrainTest', false, @islogical);    % interlace odd-even trial
addParameter(inputP, 'idxTrainTest' , {}, @(x)iscell(x) && length(x)==2);
addParameter(inputP,'trialNo',[],@isinteger)
addParameter(inputP, 'trialType'    , 'conjunctive' );  % trialNo
addParameter(inputP, 'nDecode', [], @(x)isempty(x) || (isnumeric(x) && all(x>0)) )
addParameter(inputP, 'kfold', [], @isnumeric)
parse(inputP, spikes, predictors, setup, varargin{:})
v2struct(inputP.Results)
if isempty(setup)
    setup.tag = tag;
    setup.distrib = 'poisson';
    setup.link = 'log';
    setup.trialType = ''; %'conjunctive';
    setup.hdcircular = true;
    setup.runDecode = true;
    setup.method_lnp_new = true;
    setup.fitMethod = 'fminsearch';
end
circular = false;

% Convert input to cell
if ~iscell(predictors) && ~isempty(predictors)
    predictors = {predictors};
end
nPredictors = length(predictors);

% Find number of responses
[P,N] = size(spikes);
%if isempty(predictors)
%    X = ones(P,1);
%    classX = ones(P,1);
%    stateUnique = [ 1 ];
%    classUnique{1} = 1;
%    %keyboard
%else
[X, classX, stateUnique, classUnique] = class_into_boolean(predictors, uniqPredictors);
%end
Y = spikes;

%% CREATE TRAIN AND TEST SET
% Train and test set

if ~isempty(idxTrainTest) % if train set is given
    idxTrain = idxTrainTest{1};
    idxTest  = idxTrainTest{2};
else % if not, split half
    idxTrain = find([1:P] <= (P/2));
    idxTest  = find([1:P]  > (P/2));
end
Xtrain = X(idxTrain,:);
Ytrain = Y(idxTrain,:);
Xtest = X(idxTest,:);
Ytest = Y(idxTest,:);
if islogical(idxTrain)
    Ptrain = sum(idxTrain);
    Ptest  = sum(idxTest);
else
    Ptrain = length(idxTrain);
    Ptest = length(idxTest);
end



%% LEARN
%fprintf(1,'Use old method method_lnp line 89\n')
[ binfer, fitstats, exitflag] = method_lnp_learn(Xtrain,Ytrain,setup); %,'session',session);



%% LIKELIHOOD FOR EACH NEURON
logLiTrain = zeros(1,N);
logLiTest  = zeros(1,N);
for n=1:N
    bvec = binfer(:,n);
    columnOnes = ones( size(Xtrain,1), 1);
    X1 = [ columnOnes , Xtrain];
    [~,logLi ] = logLikelihood(bvec,X1,Ytrain(:,n));
    logLiTrain(n) = logLi;
    columnOnes = ones(size(Xtest,1),1);
    X1 = [ columnOnes , Xtest];
    [~, logLi] = logLikelihood(bvec,X1,Ytest(:,n));
    logLiTest(n) = logLi;
end



%% DECODE
if setup.runDecode
    
    for i=1:length(infoPredictors)
        if strcmpi(infoPredictors,'HD')
            circular(i) = setup.hdcircular;
        else circular(i) = false;
        end
    end
    
    %% DECODE STATE
    classInfer = zeros(P,1);
    logL = []; movieFrames = []; classInferSubset = []; movieLogLSubset = [];
    [ classInfer, logL, movieFrames, classInferSubset, movieLogLSubset ] = method_lnp_decode(...
        classUnique, spikes, predictors,binfer, setup, ...
        'deltaTime',deltaTime,'stdJump',stdJump,'lambdaJump',lambdaJump,'plotLogL',plotLogL,...
        'trialType',trialType,'infoPredictors' ,infoPredictors, 'session', session, 'idxY', logical(idxY), ...
        'circular', circular, 'nDecode', nDecode,'idxY',idxY); 
    class_train_q = classInfer(idxTrain,:);
    class_test_q = classInfer(idxTest,: );
    logLTrain = logL(idxTrain,:);
    logLTest  = logL(idxTest,: );
    
    
    %% ACCURACY
    
    
    [ errorTrain, meanErrorTrain, binSquareErrorTrain, binRmsErrorTrain, statsTrain ]  = ...
        method_lnp_error(predictors,classX(idxTrain,:) ,classInfer(idxTrain,:) , 'circular', circular );
    [ errorTest , meanErrorTest,  binSquareErrorTest,  binRmsErrorTest , statsTest ]  = ...
        method_lnp_error(predictors,classX(idxTest,:) ,classInfer(idxTest,:) , 'circular', circular);
    for j=1:nPredictors
        if ~isempty(infoPredictors), predictorName = infoPredictors{j};
        else predictorName = '';
        end
        fprintf(1,'Predictor %d (%s) error train: %.02f / test: %.02f , p-value train: %.02g / test: %.02g \n', ...
            j, predictorName, meanErrorTrain(j), meanErrorTest(j), statsTrain.pvalError(j), statsTest.pvalError(j) )
        fprintf(1,'Predictor %d (%s) rms error (in bins) train: %.02f / test: %.02f , p-value train: %.02g / test: %.02g\n', ...
            j, predictorName, binRmsErrorTrain(j), binRmsErrorTest(j), statsTrain.pvalRmsError(j), statsTest.pvalRmsError(j) )
    end
    
    
    %% Make video subset
    if (0)
        %try
        makeVideo(movieLogLSubset,'tag',session.sessionID)
        %catch
        %warning('makeVideo:movieLogLSubset fail')
    end
    
    
    
    %% ACCURACY, SUBSET
    idxVelo = find(strcmp('Velo',infoPredictors));
    if ~isempty(idxVelo)  && ~isempty(classInferSubset)
        subsetN = 1:10:N;
        clear subsetError
        %idxVelo = find(strcmp('Velo',infoPredictors));
        for n= length(subsetN):-1:1
            nn = subsetN(n);
            subsetError(n) = calculateErrorStruct(classInferSubset{nn},classX,idxTrain,idxTest,predictors,circular,nPredictors,infoPredictors);
        end
        
        %% PLOT VELOCITY ERROR VS SUBSET N
        
        nTrialTrain = length(unique(trialNo(idxTrainTest{1})));
        nTrialTest = length(unique(trialNo(idxTrainTest{2})));
        
        plot_error_subsetN(subsetError,infoPredictors,session,subsetN,classUnique,idxVelo,nTrialTrain,nTrialTest)
        dirName = sprintf( '../tmp/%s', datestr(now,'yyyymmdd'));
        if ~exist(dirName), mkdir(dirName), fprintf(1,'mkdir %s',dirName), end
        savename = sprintf('%s/%s_kfold%d',dirName, setup.tag, kfold);
        saveas(gcf, savename , 'png')
        fprintf(1,'%s\n', savename)
        
    else
        subsetError = [];
        subsetN = [];
    end
    
else
    classInfer = [];
    logL = [];
    movieFrames = [];
    class_train_q = [];
    class_test_q = [];
    logL = [];
    errorTrain  = [];
    meanErrorTrain = [];
    binSquareErrorTrain = [];
    binRmsErrorTrain = [] ;
    statsTrain  = [];
    errorTest = [];
    meanErrorTest = [];
    binSquareErrorTest = [];
    binRmsErrorTest= [];
    statsTest = [];
    subsetN = [];
    subsetError = [];
end


%% Compile results
cStates  = boolean_into_class(stateUnique,predictors,classUnique);
Ytrain_q = classX(idxTrain,:);
Ytest_q  = classX(idxTest, :);

clear results

results.N = N;
results.infoPredictors = infoPredictors;
results.classUnique = classUnique;
results.Ptrain = Ptrain;
results.Ptest = Ptest;
results.idxTrain = idxTrain;
results.idxTest = idxTest;
results.cStates = cStates;
results.Ytrain_q = Ytrain_q;    %predictors(idxTrain);
results.Ytest_q  = Ytest_q;     %predictors(idxTest);
results.class_train_q = class_train_q; %class_train_k;
results.class_test_q  = class_test_q; %class_test_k;
results.class_error_train = errorTrain; %train_error_k;
results.class_error_test  = errorTest; %test_error_k;
results.mean_error_train = meanErrorTrain; %mean_train_error;
results.mean_error_test  = meanErrorTest; %mean_test_error;
results.bin_square_error_train = binSquareErrorTrain;
results.bin_square_error_test  = binSquareErrorTest;
results.bin_rms_train = binRmsErrorTrain;
results.bin_rms_test  = binRmsErrorTest;
results.statsTrain = statsTrain;
results.statsTest = statsTest;
results.movieFrames = movieFrames; %[];
results.binfer = binfer;
results.logL = logL;
results.logLiTrain = logLiTrain;
results.logLiTest  = logLiTest;
results.subsetN = subsetN;
results.subsetError = subsetError;
results.fitstats = fitstats;
results.exitflag = exitflag;

fprintf(1,'method_lnp done.\n')






%% SUPPORTING FUNCTIONS




function [X, xClass, stateUnique, classUnique] = class_into_boolean(predictors, classUnique)

% Find number of unique predictors
nPredictors = numel(predictors);
if nargin<2
    for j=1:nPredictors
        classUnique{j} = unique(predictors{j});
    end
else
    if length(classUnique)~=length(predictors) || isempty(classUnique{1})
        for j=1:nPredictors
            classUnique{j} = unique(predictors{j});
        end
    end
end

% Find number of unique states
for j=1:nPredictors
    nUniqueClass(j) = numel(classUnique{j});
end

% create state  matrix
stateUnique = zeros( prod(nUniqueClass), sum(nUniqueClass) );
counter = ones( 1, nPredictors );
for j=1:size(stateUnique,1)
    statevec = [];
    %fprintf(1,'%d ', counter)
    %fprintf(1,'\n')
    for n=1:nPredictors
        vec = zeros(1,nUniqueClass(n));
        vec(counter(n)) = 1;
        statevec = [statevec, vec];
    end
    stateUnique(j,:) = statevec;
    
    % counter for next state
    if j<size(stateUnique,1)
        n=1;
        counter(n) = counter(n)+1;
        while counter(n) > nUniqueClass(n)
            counter(n) = 1;
            n=n+1;
            counter(n) = counter(n)+1;
        end
    end
end

% change predictors into categorical numbers and expand into [0,1] matrix
X = [];
for j=1:nPredictors
    Xn = []; %zeros( P, nUniqueX(j) );
    for k=1 : nUniqueClass(j)
        % idxbin = ( predictors{j} == classUnique{j}(k));
        idxbin = ismember( predictors{j}, classUnique{j}(k) );
        
        % class for each predictor
        xClass(idxbin,j) = k;
        
        % expanded into [0,1] matrix
        Xn( idxbin , k ) = 1;
    end
    X = [X , Xn];
end





function C = boolean_into_class(Xbool,predictors,classUnique)

nPredictors = numel(predictors);
for j=1:nPredictors
    % find # states for each predictor
    %uniqueX{j} = unique(predictors{j});
    uniqueX{j} = classUnique{j};
    nUniqueX(j) = numel(uniqueX{j});
end

idxPredStart = [0,cumsum(nUniqueX)] ;
for j=1:nPredictors
    idxPred = idxPredStart(j) + [1:nUniqueX(j)];
    for i=1:size(Xbool,1)
        C(i,j) = find(Xbool(i,idxPred));
    end
end



function [binfer, fitstats, exitflag] = method_lnp_learn(Xtrain,Ytrain,setup)
%%
fitMethod    = setup.fitMethod;
lambdaSmooth = setup.lambdaSmooth;
verbose = setup.verboseSearch;
[P,N] = size(Ytrain);
[~,C] = size(Xtrain);

% Initilize variable
exitflag = [];
binit  = zeros( 1 + C, N ); %+1 if constant on
binfer = zeros( 1 + C, N ); %+1 if constant on

% Initialize at means
binit0 = log( mean(Ytrain,1) );
clear binit1
for c=1:C
    idxY = find(Xtrain(:,c) == 1);
    %binit1(c,:) = mean( Ytrain(idxY,:) - binit0 ,1 );
    binit1(c,:) = zeros(1,N);
end
binit = vertcat( binit0 , binit1 );
binit = double(binit);

switch fitMethod
    
    case 'glmfit'
        
        clear fitstats
        for iRoi=1:N
            fprintf(1,'glmfit for roi=%d...\n',iRoi)    
            [ bfit , ~ , stats] = glmfit(Xtrain,Ytrain(:,iRoi), setup.distrib );
            binfer(:,iRoi) = bfit;
            fitstats(iRoi) = stats;
        end
        
    case 'fminsearch'
        
        fprintf(1,'fminsearch N=%d... ',N)
        % fprintf(1, 'No parpool\n'), for iRoi=1:N        
        fprintf(1, 'Parpool\n'), parfor iRoi=1:N
            printEveryNRoi = 50;
            if verbose && mod(iRoi-1,printEveryNRoi) == 0
                fprintf(1,'fminsearch for j=%d...\n',iRoi)
            end
            
            binitvec = binit(:,iRoi);
            if setup.lambdaCircular
                penaltySmooth = @(bvec) 1/2 * lambdaSmooth * sum( (bvec(2:end)-circshift(bvec(2:end),1)).^2 ) ;
            else
                penaltySmooth = @(bvec) 1/2 * lambdaSmooth * sum( diff(bvec(2:end)).^2 ) ;
            end
            
            columnOnes = ones(size(Xtrain,1),1);
            X1 = [ columnOnes , Xtrain];
            options = optimset('Display','none','MaxIter',5000); %,'PlotFcns',@optimplotfval);
        
            logLikelihoodSmooth = @(bvec) logLikelihood(bvec,X1,Ytrain(:,iRoi)) - penaltySmooth(bvec);
            [ bfit, ~, exitflag ] = fminsearch(@(bvec) (-1)*logLikelihoodSmooth(bvec), ...
                binitvec,options);
   
            binfer(:,iRoi) = bfit;
        end
        fitstats = [];
        
    otherwise
        error('fit Method?')
end
fprintf(1,'done\n')
pause(0);




function plot_error_subsetN(subsetError,infoPredictors,session,subsetN,classUnique,idxVelo,nTrialTrain,nTrialTest)

%idxVelo = find( ismember(infoX,{'Velocity','V','Velo'} ))

clear subsetError1
for n=1:length(subsetN)
    subsetError1.meanErrorTrain(n) = subsetError(n).meanErrorTrain(idxVelo);
    subsetError1.meanErrorTest(n)  = subsetError(n).meanErrorTest(idxVelo);
    subsetError1.binRmsErrorTrain(n) = subsetError(n).binRmsErrorTrain(idxVelo);
    subsetError1.binRmsErrorTest(n)  = subsetError(n).binRmsErrorTest(idxVelo);
    subsetError1.meanErrorTrain_p05(n) = subsetError(n).statsTrain.meanError_p05(idxVelo);
    subsetError1.meanErrorTest_p05(n) = subsetError(n).statsTest.meanError_p05(idxVelo);
    subsetError1.meanErrorTrain_p005(n) = subsetError(n).statsTrain.meanError_p005(idxVelo);
    subsetError1.meanErrorTest_p005(n) = subsetError(n).statsTest.meanError_p005(idxVelo);
    subsetError1.binRmsErrorTrain_p05(n) = subsetError(n).statsTrain.binRmsError_p05(idxVelo);
    subsetError1.binRmsErrorTest_p05(n) = subsetError(n).statsTest.binRmsError_p05(idxVelo);
    subsetError1.binRmsErrorTrain_p005(n) = subsetError(n).statsTrain.binRmsError_p005(idxVelo);
    subsetError1.binRmsErrorTest_p005(n) = subsetError(n).statsTest.binRmsError_p005(idxVelo);
end


if ~isempty(session), sessionID = session.sessionID;
else sessionID = '';
end

% Figures of subsetError
figure
plot(subsetN,subsetError1.meanErrorTrain,'.-')
hold all
plot(subsetN,subsetError1.meanErrorTest,'.-')
hold all
plot(subsetN, subsetError1.meanErrorTest_p05,'-','Color',[0.5,0.5,0.5])
hold all
plot(subsetN, subsetError1.meanErrorTest_p005,'-.','Color',[0.5,0.5,0.5])
title(sprintf('Decoding %d speeds %s',length(classUnique{1}), sessionID))
ylabel('AHV')
ylabel('Decoding error')
xlabel('Number of cells')
legend({'Training set','Test set','Shuffled Median','Shuffled 95%'})
name = sprintf('Decoding %d speeds. Train %d Test %d trials\n%s', ...
    length(classUnique{idxVelo}), nTrialTrain, nTrialTest, sessionID);
title(name)
date = datestr(now,'yyyymmdd');
mkdir(sprintf('../tmp/%s',date))
savename = sprintf('../tmp/%s/subset_meanError_%s',date,sessionID);
saveas(gcf, savename, 'png');
fprintf(1, 'Saved to %s\n',savename);

figure
plot(subsetN,subsetError1.binRmsErrorTrain,'.-')
hold all
plot(subsetN,subsetError1.binRmsErrorTest,'.-')
hold all
plot(subsetN, subsetError1.binRmsErrorTest_p05,'-','Color',[0.5,0.5,0.5])
hold all
plot(subsetN, subsetError1.binRmsErrorTest_p005,'-.','Color',[0.5,0.5,0.5])
title(sprintf('Decoding %d speeds %s',length(classUnique{1}), sessionID))
ylabel('AHV')
ylabel('root-mean-square error (bins)')
xlabel('Number of cells')
legend({'Training set','Test set','Shuffled Median','Shuffled 95%'})
name = sprintf('Decoding %d speeds. Train %d Test %d trials\n%s', ...
    length(classUnique{idxVelo}), nTrialTrain, nTrialTest, sessionID);
title(name)
savename = sprintf('../tmp/%s/subset_binRmsError_%s',date,sessionID);
saveas(gcf, savename, 'png');
fprintf(1, 'Saved to %s\n',savename);

