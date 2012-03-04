N = 1000;
depth = 200;
escape2 = 400;

% mandelbrot set
escape = sqrt(escape2);
x = linspace(-2, 1, N);
y = x + 0.5;
[X,Y] = meshgrid(x,y);
z0 = X + i*Y;
z = zeros(N,N);
c = zeros(N,N);
for k = 1:depth
    in = ((real(z).^2 + imag(z).^2) < escape2);
    c = c + in;
    z = in.*(z.*z + z0) + (1-in).*z;
end
magz2 = real(z).^2 + imag(z).^2;
log_count = log(c+1-log(log(max(magz2,escape2))/2)/log(2));
% color mapping
colors = [
    0.0  0.0  0.5
    0.0  0.0  1.0
    0.0  0.5  1.0
    0.0  1.0  1.0
    0.5  1.0  0.5
    1.0  1.0  0.0
    1.0  0.5  0.0
    1.0  0.0  0.0
    0.5  0.0  0.0    
    0.5  0.0  0.0
    1.0  0.0  0.0
    1.0  0.5  0.0
    1.0  1.0  0.0
    0.5  1.0  0.5
    0.0  1.0  1.0
    0.0  0.5  1.0
    0.0  0.0  1.0
    0.0  0.0  0.5
    0.0  0.0  0.0
    ];
cmap_size = size( colors, 1 );
idxIn = 1:cmap_size;
idxOut = linspace( 1, cmap_size, 1000 );
cmap = [
    interp1( idxIn, colors(:,1), idxOut )
    interp1( idxIn, colors(:,2), idxOut )
    interp1( idxIn, colors(:,3), idxOut )
    ]';
colormap(cmap);
set(gcf,'Renderer','zbuffer');
imagesc(log_count);
axis image;
