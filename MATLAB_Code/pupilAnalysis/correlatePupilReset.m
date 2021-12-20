function SN = correlatePupilReset(session, varargin)

inputP = inputParser;
addParameter( inputP, 'nShowPlots', 0)
parse(inputP, varargin{:})
v2struct(inputP.Results)


[freqPupilReset, pupilResetIdx] = velocityFromPupilReset(session);


timeidx = (session.velocity==0);  tag = 'Stationary'; % Stationary
%timeidx = true(size(session.velocity));  tag = 'Stationary & Moving'; % All

velo = session.velocity(timeidx);
clear h hc S SN
for n=1:session.nRois
    
    x0 = session.deconvolved( n,timeidx );
    y0 = pupilResetIdx( timeidx ) ;  
    lengthx0 = length(x0);
    %x = [ zeros(size(x0)), x0, zeros(size(x0)) ];
    %y = [ y0 y0 y0 ];
    x = x0;
    y = y0;
    [r,lags] = xcorr(x,y,2000) ;
    
%     [r0,lags0] = xcorr(x,y) ;
%     idxmiddle = (2*lengthx0) : (4*lengthx0);
%     r = r0( idxmiddle );
%     lags = lags0( idxmiddle );

%     x = x0;
%     y = y0;
%     r = ifft(fft(x).*conj(fft(y)));
%     lags = [1:length(r)] - ceil(length(r)/2); 

    dwindow = 11;
    rsmooth = smooth(r,dwindow);
   % lags    = lags(    dwindow : end-dwindow+1 );
   % rsmooth = rsmooth( dwindow : end-dwindow+1 );
    
    
    pthresh = 0.05;
    pthreshc = pthresh / session.nRois;
    r005  =  quantile( rsmooth, 1-pthresh );
    r005c =  quantile( rsmooth, 1-pthreshc );
    
    rzero = rsmooth( ceil(length(rsmooth)/2));
    
    h  = rzero > r005;
    hc = rzero > r005c;
    S = v2struct( x,y,rsmooth, lags, rzero, r005, r005c, h, hc );

    SN(n) = S; 
end 


findh = find( [SN.h] );
%findh = find( [SN.hc] )

meanh = mean( [SN.h] );
meanhc = mean( [SN.hc] );
pause(0)

%%

%findh =1:length([SN.hc]);

%figure
%set(gcf,'Units','normalized', 'OuterPosition',[0.1,0.1 0.8,0.8])
for i=1: min(length(findh), nShowPlots )
    
    n= findh(i);
    [ x,y,rsmooth, lags, r005, r005c, h, hc ] = v2struct(SN(n));
    
    
    %subplot(2,4,i)
    figure('Units','normalized', 'OuterPosition',[0.1,0.3 0.8,0.4])
    
    ax3=subplot(3,3,[1,2]);
    %t = find( timeidx );
    t = 1:length(find(timeidx));
    plot( t,velo )
    ylabel('velocity')
    title(session.sessionID)
    
    ax1=subplot(3,3,[7,8]);
    x1 = find( timeidx );
    plot( t, x )
    ylabel('deconv signal')
    title(session.sessionID)
    
    ax2=subplot(3,3,[4,5]);
    plot( t, y, 'k' )
    %pupilCenter = session.pupilCenter(:,:,1);
    %dpupil = [0, diff(pupilCenter) ];
    %plot( t, dpupil(timeidx)  ) 
    hold all
    plot( t(find(y)), 1, 'ok')
    %tmp = dpupil(timeidx);
    %plot( t(find(y)), tmp(find(y)), 'ok'  ) 
    ylabel('pupilReset')
    ylim([0,2])
    linkaxes( [ax1,ax2,ax3], 'x')
    xlim([0,2000])
    
    subplot(3,3,[3,6,9])
    plot( lags * session.dt, rsmooth )
    hold all
    plot( lags * session.dt, r005 * ones( size(lags) ) , 'k--')
    plot( lags * session.dt, r005c * ones( size(lags) ) , 'k--')
    %legend( { 'R', 'p=0.05', sprintf('p=%.2f(corrected)',pthreshc)  })
    xlabel('Time lag (s)')
    ylabel('xcorr')
    yl = ylim;
    ylim([0, yl(2)])
    title(tag)
    
    
    %pause
    drawnow
    pause
    
    
end
%suplabel('Time lag (s)', 'x')
%suplabel('xcorr' ,'y')
    


%%
%keyboard