using System;
using System.Diagnostics;
using System.Drawing;
using System.Drawing.Imaging;
using System.Numerics;
using System.Runtime.InteropServices;
using System.Windows.Forms;
using System.Threading.Tasks;

public class MandelbrotView : Form
{
	const bool parallelism = true;
	const int N = 1000;           // grid size
	const int depth   = 200;      // max iterations
	const double escape2 = 400.0; // escape radius ^ 2
	
	double trans_x(int x)
	{
	    return 3.0 * ((double)x / N) - 2.0;
	}
	double trans_y(int y)
	{
	    return 3.0 * ((double)y / N) - 1.5;
	}
	double mag2(Complex c)
	{
		return c.Real * c.Real + c.Imaginary * c.Imaginary;
	}	
	double mandel(int idx)
	{
    	Complex z0 = new Complex(trans_x(idx % N), trans_y(idx / N));
    	Complex z = new Complex(0, 0);
    	int k = 0;
    	for(; k < depth && mag2(z) < escape2 ; ++k)
        	z = z * z + z0;
    	return Math.Log(k + 1.0 - Math.Log(Math.Log(Math.Max(mag2(z), escape2)) / 2.0) / Math.Log(2.0));
	}
	
	double[,] color_map = new double[,]
	    { { 0.0, 0.0, 0.5 } ,
	      { 0.0, 0.0, 1.0 } ,
	      { 0.0, 0.5, 1.0 } ,
	      { 0.0, 1.0, 1.0 } ,
	      { 0.5, 1.0, 0.5 } ,
	      { 1.0, 1.0, 0.0 } ,
	      { 1.0, 0.5, 0.0 } ,
	      { 1.0, 0.0, 0.0 } ,
	      { 0.5, 0.0, 0.0 } ,
	      { 0.5, 0.0, 0.0 } ,
	      { 1.0, 0.0, 0.0 } ,
	      { 1.0, 0.5, 0.0 } ,
	      { 1.0, 1.0, 0.0 } ,
	      { 0.5, 1.0, 0.5 } ,
	      { 0.0, 1.0, 1.0 } ,
	      { 0.0, 0.5, 1.0 } ,
	      { 0.0, 0.0, 1.0 } ,
	      { 0.0, 0.0, 0.5 } ,
	      { 0.0, 0.0, 0.0 } };
	
	int interpolate(double d, double v0, double v1)
	{
	    return (int)((d * (v1 - v0) + v0) * 255.0);
	}
	
	double min_result = 0.0;
	double max_result = 0.0;
	
	int map_to_argb(double x)
	{
	    x = (x - min_result) / (max_result - min_result) * 18.0;
	    int bin = (int) x;
	    if(bin >= 18)
	    	return unchecked((int)0xff000000);
	    else {
	        double r0 = color_map[bin,0];
	        double g0 = color_map[bin,1];
	        double b0 = color_map[bin,2];
	        double r1 = color_map[bin+1,0];
	        double g1 = color_map[bin+1,1];
	        double b1 = color_map[bin+1,2];
	        double d = x - bin;
	        int r = interpolate(d, r0, r1);
	        int g = interpolate(d, g0, g1);
	        int b = interpolate(d, b0, b1);
	        return unchecked(b | (g << 8) | (r << 16) | (int)0xff000000);
	    }
	}

	double[] log_count = new double[N*N];
	int[] argb_array = new int[N*N];
	
	void do_mandel()
	{
		if(parallelism)
		{
			Parallel.For(0, N*N, idx =>
        	{
            	log_count[idx] = mandel(idx);
        	});
		}
		else
		{
	    	for(int idx = 0; idx < N*N; ++idx)
	        	log_count[idx] = mandel(idx);
		}
	}
	void do_map_to_argb()
	{
	    min_result = log_count[0];
	    max_result = log_count[0];
	    for(int i = 1; i < log_count.Length; ++i)
	    {
	    	if(log_count[i] > max_result)
	    		max_result = log_count[i];
	    	if(log_count[i] < min_result)
	    		min_result = log_count[i];
	    }

		if(parallelism)
		{
			Parallel.For(0, N*N, idx =>
        	{
            	argb_array[idx] = map_to_argb(log_count[idx]);
        	});
		}
		else
		{
			for(int idx = 0; idx < N*N; ++idx)
				argb_array[idx] = map_to_argb(log_count[idx]);
		}
	}
	
	string m_elapsed;
	
	Image create_image()
	{
		Stopwatch stopWatch = Stopwatch.StartNew();
		do_mandel();
		do_map_to_argb();
		stopWatch.Stop();
		m_elapsed = String.Format("{0} milliseconds", stopWatch.Elapsed.TotalMilliseconds);
		
		Bitmap bmp = new Bitmap(N, N);
		Rectangle rect = new Rectangle(0, 0, bmp.Width, bmp.Height);
		BitmapData bmpdata = bmp.LockBits(rect, ImageLockMode.WriteOnly, bmp.PixelFormat);
		Marshal.Copy(argb_array, 0, bmpdata.Scan0, argb_array.Length);
		bmp.UnlockBits(bmpdata);
		Graphics g = Graphics.FromImage(bmp);
		g.DrawString(m_elapsed, SystemFonts.MessageBoxFont, new SolidBrush(Color.White), new PointF(20, 20));
		return bmp;
	}
	
	MandelbrotView()
	{
    	PictureBox box = new PictureBox();
    	box.BackColor = Color.White;
    	box.Dock = DockStyle.Fill;
    	box.SizeMode = PictureBoxSizeMode.CenterImage;
    	box.Image = create_image();    	
    	this.Controls.Add(box);
	}
	
	[STAThread]
    static void Main(string[] args)
    {
    	Form form = new MandelbrotView();
    	form.Text = "Mandelbrot Set";
    	form.ClientSize = new Size(N, N);
    	form.StartPosition = FormStartPosition.CenterScreen;
    	Application.Run(form);
    }
}
