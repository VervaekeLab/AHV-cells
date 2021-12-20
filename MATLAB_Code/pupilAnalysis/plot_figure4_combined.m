function ResultsAll

findGoodData = find(goodData);
findGoodData(7) = [];
sessionIDs = cellfun( @(x)x(1,1).sessionID, ResultsAll(findGoodData), 'UniformOutput', false)';


clear meanSession
figure
subplot(1,2,1)
idxCol = 3;
for i= 1:length(findGoodData)
    ix = findGoodData(i);
    A = (figuresDataAll{ix}.figure4);
    binedges = [-180-22.5 : 45: 180+22.5];
    bincenters = -180:45:180;
    clear meanY
    y = A(:,idxCol);
    for b = 1:length(binedges)-1
        idxbin = A(:,1) > binedges(b) & A(:,1) <= binedges(b+1); 
        meanY(b) = mean(y(idxbin,:));
    end
    
    %plot(A(:,1),A(:,2), '.')
    hold all
    plot(bincenters,meanY, '-','Color',0.8*[1,1,1])

    meanSession(i,:) = meanY;
end
%plot(bincenters, mean(meanSession), 'k.-', 'LineWidth',1.5)
shadedErrorBar(bincenters, mean(meanSession), std(meanSession)./ sqrt(size(meanSession,1)) ); %, 'k.-', 'LineWidth',1.5)
xlabel(  sprintf('Velocity (%s/s)',char(176)) )
ylabel( 'Frequency (Hz)'   )





subplot(1,2,2)
idxCol = 4;
for i= 1:length(findGoodData)
    ix = findGoodData(i);
    A = (figuresDataAll{ix}.figure4);
    binedges = [-180-22.5 : 45: 180+22.5];
    bincenters = -180:45:180;
    clear meanY
    y = A(:,idxCol);
    for b = 1:length(binedges)-1
        idxbin = A(:,1) > binedges(b) & A(:,1) <= binedges(b+1); 
        meanY(b) = mean(y(idxbin,:));
    end
    
    %plot(A(:,1),A(:,2), '.')
    hold all
    plot(bincenters,meanY,'-', 'Color',0.8*[1,1,1])


    meanSession(i,:) = meanY;
end

%errorbar(bincenters, mean(meanSession), std(meanSession), 'k.-', 'LineWidth',1.5)
shadedErrorBar(bincenters, mean(meanSession), std(meanSession)./ sqrt(size(meanSession,1)) ); %, 'k.-', 'LineWidth',1.5)
xlabel(  sprintf('Velocity (%s/s)',char(176)) )
ylabel( 'Avergate rate(a.u.)'   )

