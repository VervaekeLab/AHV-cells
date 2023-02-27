function [ eventStartIdx, eventStopIdx ] = findTransitions( eventVector )
%findTransitions Find the transitions in an eventVector
%   [ eventStartIdx, eventStopIdx ]  = findTransitions( eventVector ) 
%   returns the indices in the eventVector where an event starts or stops.
%
%   Written by Eivind Hennestad | Vervaeke Lab

% Accept both row and columnvectors.
sizeEV = size(eventVector);
[~, longDim] = max(sizeEV);

% Find start and stop of events
eventStartStop = diff(eventVector);
eventStartIdx = find((eventStartStop == 1)) + 1; % diff shifts start transition 1 step forward, so add one...
eventStopIdx = find(eventStartStop == -1); % ...but stop transition is already one step after. Makes sense?

% Maybe event is ongoing in the beginning or in the end?
if eventVector(1);   eventStartIdx = cat(longDim, 1, eventStartIdx); end
if eventVector(end); eventStopIdx = cat(longDim, eventStopIdx, numel(eventVector)); end

end

