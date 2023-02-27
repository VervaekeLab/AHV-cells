function y = shiftvector(x, k)
%shiftvector Shift positions of elements
% Y = shiftvector(X, K) where K is an integer or decimal scalar shifts 
%     the elements in the vector X by K positions. If K is positive, then 
%     the values of X are shifted from the beginning to the end. If K is 
%     negative, they are shifted from the end to the  beginning.
%     If K is a decimal value, X is interpolated, shifted and decimated.
%    
%     NB: Only works for the first decimal value. 
%     NBB: Assumes no change on the edges, and uses end values for padding

if k == 0
    y = x;
    return
end


flipped = false;
isLogical = false;

if isrow(x)
    x = x';
    flipped=true;
end

if isa(x, 'logical')
    isLogical = true;
end


firstval = x(1);
lastval = x(end);

if mod(k, 1) == 0
    K = k;
else
    K = round(k*10);
    if isLogical
        x = upsampleLogical(x, 10);
    else
        x = interp(x, 10);
    end
end


if K < 0        % Shift right
    padding = ones(abs(K), 1) * lastval;
    y = vertcat(x(abs(K)+1:end), padding);
elseif K > 0    % Shift left 
    padding = ones(abs(K), 1) * firstval;
    y = vertcat(padding, x(1:end-K));
end


if ~mod(k, 1) == 0
    y = downsample(y, 10);
end

if flipped
    y = y';
end
 
if isLogical
    y = logical(y);
end
        
end