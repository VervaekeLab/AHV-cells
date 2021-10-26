function [hfig3] = psthPupilReset_figure3( SN, session, nShowPlots, plotOnlySignificant, hfig3)

s = SN.stats;
pupilCellShuffle = SN.pupilCellShuffle;
v2struct(s)

findh = find(pupilCellShuffle);
if plotOnlySignificant
    noutplot = findh;
else
    noutplot = 1:session.nRois;
    for n=1:size(meanDeconvPupil,1)
        C = corrcoef(meanDeconvPupil(1,:), meanDeconvPupil(n,:) );
        C1(n) = C(1,2);
    end
    [~,idxsort] = sort(C1,'descend');
    noutplot = noutplot(idxsort);
end


if isempty(hfig3)
    hfig3 = figure();
    set(gca,'Units','normalized', 'OuterPosition', [0.1,0.1,0.8,0.8] );
end
figure(hfig3)
%nrows = 6;
ncols = 7;
%nsp = nrows*ncols;
nsp = nShowPlots;
nrows = ceil(nsp/ncols);


subplot(nrows,ncols,1)
x = PSTH.bodyMovementMat;
y = PSTH.velocityMat ;
plot( x(:),y(:), '.' ) 
xlabel('body movement');
ylabel('velocity'); 

subplot(nrows,ncols,2)
x = PSTH.bodyMovementMat;
y = nanmean(PSTH.DeconvPupilMat(:,:,:),3) ;
plot( x(:),y(:), '.' ) 
xlabel('body movement(sec)'); 
ylabel( sprintf('population\n activity'));

subplot(nrows,ncols,3)
yyaxis left
x = [-intv:intv] * session.dt;
y = nanmean( nanmean(PSTH.DeconvPupilMat(:,:,:),3), 1) ;
plot( x,y, '.' ) , hold all
ylabel( sprintf('population\n activity'));
yyaxis right
x = [-intv:intv] * session.dt;
y = nanmean( PSTH.bodyMovementMat ) ;
plot( x,y, '.' ) , hold all
xlabel('time around pupil reset (sec)'); 
ylabel( sprintf('body movement'));
xlabel('time around pupil reset (sec)'); 


for in = 1 : length(noutplot)   %i= (ncols) : min( length(noutplot)-ncols , nsp)

    i = (ncols) + in ;
    if i > nsp, break, end
    n = noutplot(in);
     
    subplot(nrows,ncols,i)
    x = PSTH.bodyMovementMat;
    y = PSTH.DeconvPupilMat(:,:,n) ;
    plot( x(:),y(:), '.' ) 

    if i > (nrows-1)*ncols,  xlabel('body movement(sec)'); end
    if mod(n-1, ncols)==0,   ylabel('deconv (smoothed) + sd'); end
    
end

end
