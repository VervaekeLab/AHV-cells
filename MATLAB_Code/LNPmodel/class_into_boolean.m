function [X, xClass, stateUnique, classUnique] = class_into_boolean(predictors,classUnique)

% Find number of unique predictors and states
nPredictors = numel(predictors);

% % Add classUnique if not available
% if ~exist('classUnique','var')
%      for j=1:nPredictors
%          % find # states for each predictor
%          classUnique{j} = unique(predictors{j});
%      end
%  end

% Find # states for each predictor
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
        %idxbin = ( predictors{j} == classUnique{j}(k));
        idxbin = ismember( predictors{j} , classUnique{j}(k));
        
        % class for each predictor
        xClass(idxbin,j) = k;
        
        % expanded into [0,1] matrix
        Xn( idxbin , k ) = 1;
    end
    X = [X , Xn];
end

