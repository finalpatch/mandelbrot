from numpy import *

clr.AddReference("System.Windows.Forms")
clr.AddReference("System.Drawing")
from System.Windows.Forms import *
from System.Drawing import *
from System.Runtime.InteropServices import *
from System.Diagnostics import *

N = 200
depth = 20
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
        z = inset * (z * z + z0) + (1-inset)*z
    return c, z

stopWatch = Stopwatch.StartNew()
c, z = mandel()
stopWatch.Stop()
elapsed = "%f milliseconds"%(stopWatch.Elapsed.TotalMilliseconds)

magz2 = abs(z)**2
log_count = log(c+1-log(log(maximum(magz2,escape2))/2)/log(2))

color_map = [ [ 0.0, 0.0, 0.5 ] ,
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

stops = len(color_map) - 1

min_result = amin(log_count)
max_result = amax(log_count)

def map_to_argb(x):
    x = (x - min_result) / (max_result - min_result) * stops
    bin = int(x);
    if bin >= stops:
        return 0,0,0
    else:
        c0 = array(color_map[bin][0:3])
        c1 = array(color_map[bin+1][0:3])
        d = x - bin        
        return ((d * (c1 - c0) + c0) * 255.0)

def bmp_from(data):
    bmp = Bitmap(N,N)
    for y in range(N):
        for x in range(N):
            r,g,b = map_to_argb(data[y,x])
            bmp.SetPixel(x, y, Color.FromArgb(255, r,g,b))
    gfx = Graphics.FromImage(bmp)
    gfx.DrawString(elapsed, SystemFonts.MessageBoxFont, 
                   SolidBrush(Color.White), PointF(20, 20))
    return bmp

def main():
    form = Form(Text = "Mandelbrot Set", StartPosition = FormStartPosition.CenterScreen)
    form.ClientSize=Size(N,N)
    box = PictureBox(BackColor = Color.White, Dock = DockStyle.Fill,
                     SizeMode = PictureBoxSizeMode.CenterImage)
    box.Image = bmp_from(log_count)
    form.Controls.Add(box)
    Application.Run(form)

if __name__ == '__main__':
    main()
