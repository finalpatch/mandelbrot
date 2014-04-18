{ Compile for SDL1.2: fpc mandelbrot.pas }
{ Compile for SDL2: fpc -dSDL2 -FuPATH_TO_SDL2_UNIT mandelbrot.pas }
program mandelbrot;

uses ucomplex, math, sysutils, dateutils,
  {$ifdef unix}cthreads,{$endif}
  {$if defined(SDL2)} SDL2; {$else} sdl; {$endif}

const
   N                                = 1000;  { grid size }
   depth                            = 200;   { max iterations }
   escape2                          = 400.0; { escape radius ^ 2 }
   color_map: array[0..18, 0..2] of real = 
     (( 0.0, 0.0, 0.5 ) ,
      ( 0.0, 0.0, 1.0 ) ,
      ( 0.0, 0.5, 1.0 ) ,
      ( 0.0, 1.0, 1.0 ) ,
      ( 0.5, 1.0, 0.5 ) ,
      ( 1.0, 1.0, 0.0 ) ,
      ( 1.0, 0.5, 0.0 ) ,
      ( 1.0, 0.0, 0.0 ) ,
      ( 0.5, 0.0, 0.0 ) ,
      ( 0.5, 0.0, 0.0 ) ,
      ( 1.0, 0.0, 0.0 ) ,
      ( 1.0, 0.5, 0.0 ) ,
      ( 1.0, 1.0, 0.0 ) ,
      ( 0.5, 1.0, 0.5 ) ,
      ( 0.0, 1.0, 1.0 ) ,
      ( 0.0, 0.5, 1.0 ) ,
      ( 0.0, 0.0, 1.0 ) ,
      ( 0.0, 0.0, 0.5 ) ,
      ( 0.0, 0.0, 0.0 ) );

   parallelism = 16;
   jobsize = N*N div parallelism;

var
   min_result : real = 0.0; 
   max_result : real = 0.0;
   log_count  : array[0..(N*N-1)] of real;
   argb_array : array[0..(N*N-1)] of longword;

   threads : array [0..(parallelism-1)] of TThreadID;

{ ---------------------------------------------------------------------------- }

function trans_x(x: integer) : real; inline;
begin
   trans_x := 3.0 * (real(x) / N) - 2.0;
end;

{ ---------------------------------------------------------------------------- }

function trans_y(y: integer) : real; inline;
begin
   trans_y := 3.0 * (real(y) / N) - 1.5;
end;

{ ---------------------------------------------------------------------------- }

function mag2(const x: complex) : real; inline;
begin
   mag2 := x.re * x.re + x.im * x.im;
end;

{ ---------------------------------------------------------------------------- }

function mandel(idx : longword) : real; inline;
var
   z0    : complex;
   z     : complex;
   k     : integer;
   magz2 : real;
begin
   z0 := cinit(trans_x(idx mod N), trans_y(idx div N));
   z  := cinit(0.0, 0.0);
   k := 0;
   while k < depth do
   begin
      magz2 := mag2(z);
      if magz2 >= escape2 then
         break;
      z := z * z + z0;
      k := k + 1;
   end;
   mandel := log10(k + 1.0 - log10(log10(max(magz2, escape2)) / 2.0) / log10(2.0));
end;

{ ---------------------------------------------------------------------------- }

function interpolate(d : real; v0 : real; v1 : real) : integer; inline;
begin
   interpolate := trunc((d * (v1 - v0) + v0) * 255.0);
end;

{ ---------------------------------------------------------------------------- }

function map_to_argb(x :real) : longword; inline;
var
   bin                    : integer;
   r0, g0, b0, r1, g1, b1 : real;
   d                      : real;
   r,g,b                  : integer;
begin
   x := (x - min_result) / (max_result - min_result) * 18;
   bin := trunc(x);
   if (bin >= 18) then
      map_to_argb := $ff000000
   else
      begin
         r0 := color_map[bin][0];
         g0 := color_map[bin][1];
         b0 := color_map[bin][2];
         r1 := color_map[bin+1][0];
         g1 := color_map[bin+1][1];
         b1 := color_map[bin+1][2];
         d := x - bin;
         r := interpolate(d, r0, r1);
         g := interpolate(d, g0, g1);
         b := interpolate(d, b0, b1);
         map_to_argb := b or (g << 8) or (r << 16) or $ff000000;
      end;
end;

{ ---------------------------------------------------------------------------- }

function do_mandel(p : pointer) : ptrint;
var
   a, idx : longword;
begin
   for a := 0 to jobsize-1 do
   begin
      idx := a*parallelism+longword(p);
      log_count[idx] := mandel(idx);
   end;
   do_mandel := 0;
end;

{ ---------------------------------------------------------------------------- }

procedure do_map_to_argb;
var
   idx : longword;
begin
   max_result := maxvalue(log_count, N*N);
   min_result := minvalue(log_count, N*N);
   for idx := 0 to (N*N-1) do
      begin
         argb_array[idx] := map_to_argb(log_count[idx]);
      end;
end;

{ ---------------------------------------------------------------------------- }

var
{$if defined(SDL2)}
   win    : PSDL_Window;
   ren    : PSDL_Renderer;
   tex    : PSDL_Texture;
{$else}
   scr    : PSDL_Surface;
   row    : integer;
   col    : integer;
   line   : ^longword;
   stride : integer;
   idx    : longword;
{$endif}
   evt    : TSDL_Event;
   start  : TDateTime;
   finish : TDateTime;
   i      : integer;

begin
   start := now;
   for i := 0 to parallelism do
      threads[i] := beginthread(@do_mandel, pointer(i));
   for i := 0 to parallelism do
       waitforthreadterminate(threads[i], 0);
   do_map_to_argb();
   finish := now;
   writeln(MilliSecondSpan(start, finish):4:2, ' ms');

   SDL_init(SDL_INIT_VIDEO);

{$if defined(SDL2)}
   SDL_CreateWindowAndRenderer(N, N, 0, @win, @ren);
   SDL_SetRenderDrawColor(ren, 0, 0, 0, 255);
   SDL_RenderClear(ren);
   tex := SDL_CreateTexture(ren, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, N, N);
   SDL_UpdateTexture(tex, nil, @argb_array[0], N*4);
   SDL_RenderCopy(ren, tex, nil, nil);
   SDL_RenderPresent(ren);
{$else}
   scr := SDL_SetVideoMode(1000, 1000, 32, SDL_SWSURFACE);
   SDL_LockSurface(scr);
   line := scr^.pixels;
   stride := scr^.pitch div 4;   
   idx := 0;   
   for row := 1 to scr^.h do
      begin
         for col := 0 to scr^.w-1 do
            begin
               line[col] := argb_array[idx];
               idx := idx + 1;
            end;
         line := line + stride;
      end;   
   SDL_UnlockSurface(scr);
   SDL_Flip(scr);
{$endif}

   while SDL_WaitEvent(@evt) <> 0 do
   begin
      case evt.type_ of 
         SDL_KEYUP:     break;
         SDL_QUITEV:    break;
      end;              
   end;

   SDL_Quit;

end.
