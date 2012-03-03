#pragma OPENCL EXTENSION cl_khr_fp64 : enable

double trans_x(int x, int N)
{
    return 3.0 * ((double)x / N) - 2.0;
}
double trans_y(int y, int N)
{
    return 3.0 * ((double)y / N) - 1.5;
}
double mag2(double r, double i)
{
    return r * r + i * i;
}
__kernel void mandel(__global double* out, int N, int depth, double escape2)
{
    size_t idx = get_global_id(0);

    double z0_r = trans_x(idx % N, N);
    double z0_i = trans_y(idx / N, N);
	
    double z_r = 0;
    double z_i = 0;
    int k = 0;
    for(; k <= depth && mag2(z_r, z_i) < escape2 ; ++k)
    {
        double t_r = z_r; double t_i = z_i;
        z_r = t_r * t_r - t_i * t_i + z0_r;
        z_i = 2 * t_r * t_i + z0_i;
    }
    out[idx] = log(k + 1.0 - log(log(max(mag2(z_r, z_i), escape2)) / 2.0) / log(2.0));
}
