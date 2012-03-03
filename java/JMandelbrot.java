import javax.swing.*;
import java.awt.*;
import java.awt.image.*;
import java.util.concurrent.*;

public class JMandelbrot extends JPanel {
	
	int parallelism = 8;
	
    // ********************************************************************
    // Mandelbrot
	int    N       = 1000;
	int    depth   = 200;
	double escape2 = 400.0;
	
	private double[] log_count = new double[N*N];
	private int[] argb_array = new int[N*N];

	double trans_x(int x)
	{
	    return 3.0 * ((double)x / N) - 2.0;
	}
	double trans_y(int y)
	{
	    return 3.0 * ((double)y / N) - 1.5;
	}
	
	double mag2(double real, double imag)
	{
		return real*real + imag*imag;
	}
	
	double mandel(int idx)
	{
	    double z0_r = trans_x(idx % N);
	    double z0_i = trans_y(idx / N);
	    
	    double z_r = 0;
	    double z_i = 0;
	    int k = 0;
	    for(; k <= depth && mag2(z_r, z_i) < escape2 ; ++k) {
	    	double t_r = z_r; double t_i = z_i;
	    	z_r = t_r * t_r - t_i * t_i + z0_r;
	    	z_i = 2 * t_r * t_i + z0_i;
	    }
	    return Math.log(k + 1.0 - Math.log(Math.log(Math.max(mag2(z_r, z_i), escape2)) / 2.0) / Math.log(2.0));
	}
	
    // ********************************************************************
    // Color mapping
	double[][] color_map =
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
	        return 0xff000000;
	    else {
	        double r0 = color_map[bin][0];
	        double g0 = color_map[bin][1];
	        double b0 = color_map[bin][2];
	        double r1 = color_map[bin+1][0];
	        double g1 = color_map[bin+1][1];
	        double b1 = color_map[bin+1][2];
	        double d = x - bin;
	        int r = interpolate(d, r0, r1);
	        int g = interpolate(d, g0, g1);
	        int b = interpolate(d, b0, b1);
	        return b | (g << 8) | (r << 16) | 0xff000000;
	    }
	}
	
    // ********************************************************************
    // Boilerplate
	class do_mandel_range implements Runnable
	{
		int beg;
		int end;
		do_mandel_range(int b, int e) {
			beg = b;
			end = e;
		}
		public void run() {
		    for(int idx = beg; idx < end; ++idx)
		        log_count[idx] = mandel(idx);
		}
	}
	class do_map_to_argb_range implements Runnable
	{
		int beg;
		int end;
		do_map_to_argb_range(int b, int e) {
			beg = b;
			end = e;
		}
		public void run() {
		    for(int idx = beg; idx < end; ++idx)
		    	argb_array[idx] = map_to_argb(log_count[idx]);
		}
	}
	
	int job_size = N*N / parallelism;
	ExecutorService executor = Executors.newFixedThreadPool(parallelism);
	
	void do_mandel() throws InterruptedException, ExecutionException
	{
		if(parallelism > 1) {
			Future[] results = new Future[parallelism]; 
	        for(int i = 0; i < parallelism; ++i)
	        	results[i] = executor.submit(new do_mandel_range(job_size * i, job_size * (i + 1)));

            for(int i = 0; i < parallelism; ++i)
                results[i].get();
		}
		else {
			new do_mandel_range(0, N*N).run();
        }
	}
	
	void do_map_to_argb() throws InterruptedException, ExecutionException
	{
	    min_result = log_count[0];
	    max_result = log_count[0];
	    for(int i = 1; i < log_count.length; ++i) {
	    	if(log_count[i] > max_result)
	    		max_result = log_count[i];
	    	if(log_count[i] < min_result)
	    		min_result = log_count[i];
	    }

		if(parallelism > 1) {
			Future[] results = new Future[parallelism]; 
	        for(int i = 0; i < parallelism; ++i)
	            results[i] = executor.submit(new do_map_to_argb_range(job_size * i, job_size * (i + 1)));
            for(int i = 0; i < parallelism; ++i)
                results[i].get();
		}
		else {
			new do_map_to_argb_range(0, N*N).run();
        }
	}
	
	String m_elapsed;
	
	JMandelbrot() {
		this.setPreferredSize(new Dimension(N, N));		
		long startTime = System.nanoTime();
        try {
            do_mandel();
            do_map_to_argb();
        } catch (InterruptedException e) {
            e.printStackTrace();
        } catch (ExecutionException e) {
            e.printStackTrace();
        }        
        float elapsed = (System.nanoTime() - startTime) / 1000000.0f;
		m_elapsed = String.format("%f milliseconds", elapsed);
	}
	
	public void paint(Graphics g) {
		Graphics2D g2d = (Graphics2D) g;
		MemoryImageSource imgsrc = new MemoryImageSource(N, N, argb_array, 0, N);
		Image img = createImage(imgsrc);
		g2d.drawImage(img, 0, 0, null);
		g2d.setColor(Color.white); 
		g2d.drawString(m_elapsed, 20, 30);
	}
	
	public static void main(String[] args) {
		JFrame frame = new JFrame("Mandelbrot Set");
		JMandelbrot view = new JMandelbrot();
		frame.add(view);
		frame.pack();
        frame.setLocationRelativeTo(null);
		frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        frame.setVisible(true);
	}
}
