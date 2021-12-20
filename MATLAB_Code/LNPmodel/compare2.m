function compare2( X1, X2 , label1, label2, marker)

if nargin<3
    label1 = '';
    label2 = '';
end
if nargin<5
    marker = '.';
end

X1 = X1(:);
X2 = X2(:);

%figure
plot(X1,X2,marker,'MarkerSize',20)
hold all
axis equal tight
xl = xlim;
yl = ylim;
xopt = max( abs( [xl(1),xl(2),yl(1),yl(2)] )) ;
plot( [-xopt,xopt], [-xopt,xopt], ':' )
xlim( xl );
ylim( yl );
%legend( {label1,label2}, 'Location','southeast' )
xlabel(label1)
ylabel(label2)