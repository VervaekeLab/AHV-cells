function [logL, logLi] = logLikelihood(bvec,predictors,spikes)


inputP = inputParser;

% number of bins / parameters
nbins = size(predictors,2); 

% number of neurons
[T, N] = size(spikes); 

% reshape
b = reshape( bvec, nbins, N);

% choose nonlinearity
nonlinear = @(x) exp(x) ;

% firing rates
lambda = nonlinear( predictors * b );

% log likelihood (without constant terms)
% http://statweb.stanford.edu/~susan/courses/s200/lectures/lect11.pdf
% l(lambda) = log(lambda) * sum_i^n spikes(i) - n*lambda - sum_i^N log(spikes!)

%for i=1:N
%logLi(i) = sum(spikes(:,i) * log(lambda(i))) -  T*lambda(i) ;
%end
%logLi = sum(bsxfun(@times, spikes, log(lambda)),1) - T*lambda;
logLi = sum( spikes .* log(lambda)   - lambda) /T;
logL  = sum(logLi) /N;


% log likelihood (with constant terms)
%logLi = sum(spikes .* log( lambda ) -  lambda - gamma(spikes) ) /T;
%logL  = sum(logLi) /N;

% poisson
%meanSpikes = mean(spikes,1);
%Pi = exp( -lambda) .* lambda.^meanSpikes ./ gamma(meanSpikes);
%Pi = poisspdf( sum(spikes,1) ,lambda);
%P = prod(Pi);


pause(0)
% penalty for smoothness
% sum_i( beta_i (sum_j 1/2(w(i,j)-w(i,j+1))))
%beta = 1;