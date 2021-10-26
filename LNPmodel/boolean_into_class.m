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
