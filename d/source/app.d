import std.stdio;
import std.conv;
import std.complex;
import std.math;
import std.algorithm;
import std.datetime;
import std.parallelism;
import std.range;
import derelict.sdl2.sdl;

// ********************************************************************
// Mandelbrot
immutable N = 1000;      // grid size
immutable depth = 200;   // max iterations
immutable escape2 = 400.0; // escape radius ^ 2

double trans_x(int x)
{
    return 3.0 * (cast(double)x / N) - 2.0;
}
double trans_y(int y)
{
    return 3.0 * (cast(double)y / N) - 1.5;
}

T mag2(T)(const Complex!T x)
{
    return x.re * x.re + x.im * x.im;
}

double mandel(int idx)
{
    immutable z0 = Complex!double(trans_x(idx % N), trans_y(idx / N));
    auto z = Complex!double(0.0, 0.0);
    int k = 0;
    double magz2;
    for(; k < depth && (magz2 = mag2(z)) < escape2 ; ++k)
        z = z * z + z0;
    return log(k + 1.0 - log(log(max(magz2, escape2)) / 2.0) / log(2.0));
}

// ********************************************************************
// Color mapping
immutable color_map =
    [ [ 0.0, 0.0, 0.5 ] ,
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
      [ 0.0, 0.0, 0.0 ] ];

int interpolate(double d, double v0, double v1)
{
    return cast(int)((d * (v1 - v0) + v0) * 255.0);
}

double min_result = 0.0;
double max_result = 0.0;

immutable int stops = color_map.length - 1;

uint map_to_argb(double x)
{
    x = (x - min_result) / (max_result - min_result) * stops;
    int bin = cast(int) x;
    if(bin >= stops)
        return 0xff000000;
    else
    {
        try{
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
        catch(Exception e)
        {
        writefln("%s\n", bin);
        return 0;
        }
    }
}

shared double[N*N] log_count;
uint[N*N] argb_array;

void do_mandel_range(int beg, int end)
{
    for(int idx = beg; idx < end; ++idx)
        log_count[idx] = mandel(idx);
}
void do_map_to_argb_range(int beg, int end)
{
    for(int i = beg; i < end; ++i)
        argb_array[i] = map_to_argb(log_count[i]);
}

void do_mandel()
{
    foreach (idx; parallel(iota(N*N)))
        log_count[idx] = mandel(idx);
    //do_mandel_range(0, N*N);
}
void do_map_to_argb()
{
    min_result = minPos(log_count[])[0];
    max_result = minPos!("a > b")(log_count[])[0];
    do_map_to_argb_range(0, N*N);
}

int main(char[][] args)
{
    DerelictSDL2.load();

    if (SDL_Init(SDL_INIT_VIDEO) == -1)
        throw new Exception(SDL_GetError().to!string());
    scope(exit)
        SDL_Quit();

    SDL_Window* win;
    SDL_Renderer* ren;
    SDL_CreateWindowAndRenderer(N, N, 0, &win, &ren);
    if (!win || !ren)
        throw new Exception(SDL_GetError().to!string());

    SDL_SetRenderDrawColor(ren, 0, 0, 0, 255);
    SDL_RenderClear(ren);

    auto start = Clock.currTime();
    do_mandel();
    do_map_to_argb();
    auto elapsed = Clock.currTime() - start;
    writefln("%s", elapsed);

    SDL_Texture* tex = SDL_CreateTexture(ren, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, N, N);
    SDL_UpdateTexture(tex, null, cast(const(void)*)argb_array, N * uint.sizeof);
    SDL_RenderCopy(ren, tex, null, null);
    
    SDL_RenderPresent(ren);

    SDL_Event event;
    while (SDL_WaitEvent(&event))
    {
        switch (event.type)
        {
        case SDL_KEYUP:
            if (event.key.keysym.sym == SDLK_ESCAPE)
                return 0;
            break;
        case SDL_QUIT:
            return 0;
        default:
            break;
        }
    }
    return 0;
}
