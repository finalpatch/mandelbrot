from numpy import *
from matplotlib.colors import LinearSegmentedColormap
import pylab, time

N = 1000
depth = 50
escape2 = 400

def mandel():
    esc = sqrt(escape2)
    x = linspace(-2, 1, N)
    y = x + 0.5
    X,Y = meshgrid(x,y)
    z0 = X+Y*1j
    z = zeros([N,N])
    c = copy(z)
    for k in xrange(depth):
        inset = abs(z) < esc
        c = c + inset
        z = inset * (z * z + z0) + (1-inset) * z
    return c, z

t = time.clock()
c, z = mandel()
magz2 = abs(z)**2
log_count = log(c+1-log(log(maximum(magz2,escape2))/2)/log(2))
elapsed = "%.f ms"%((time.clock()-t)*1000)

cmap = [ [ 0.0, 0.0, 0.5 ] ,
         [ 0.0, 0.0, 1.0 ] ,
         [ 0.0, 0.5, 1.0 ] ,
         [ 0.0, 1.0, 1.0 ] ,
         [ 0.5, 1.0, 0.5 ] ,
         [ 1.0, 1.0, 0.0 ] ,
         [ 1.0, 0.5, 0.0 ] ,
         [ 1.0, 0.0, 0.0 ] ,
         [ 0.5, 0.0, 0.0 ] ,
         [ 0.5, 0.0, 0.0 ] ,
         [ 1.0, 0.0, 0.0 ] ,
         [ 1.0, 0.5, 0.0 ] ,
         [ 1.0, 1.0, 0.0 ] ,
         [ 0.5, 1.0, 0.5 ] ,
         [ 0.0, 1.0, 1.0 ] ,
         [ 0.0, 0.5, 1.0 ] ,
         [ 0.0, 0.0, 1.0 ] ,
         [ 0.0, 0.0, 0.5 ] ,
         [ 0.0, 0.0, 0.0 ] ]

pylab.imshow(log_count, LinearSegmentedColormap.from_list('cmap', cmap))
pylab.title(elapsed)
pylab.show()
