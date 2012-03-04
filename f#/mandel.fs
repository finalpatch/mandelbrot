open System
open System.Numerics
open System.Drawing
open System.Windows.Forms
open System.Runtime.InteropServices
open System.Diagnostics

let parallelism = true

let array_init, array_map =
    if parallelism then
        Array.Parallel.init, Array.Parallel.map
    else
        Array.init, Array.map

let stopWatch = Stopwatch.StartNew()

// ********************************************************************
// Mandelbrot
let N       = 1000                      // grid size
let depth   = 200                       // max iterations
let escape2 = 400.0                     // escape radius ^ 2

// let trans_x x = 3.0 * ( x / (float N) ) - 2.0
// let trans_y y = 3.0 * ( y / (float N) ) - 1.5
let trans_x x = float ((3 * x) - 2 * N) / (float N)
let trans_y y = float ((3 * y) - 3 * N / 2) / (float N)

let mandel idx =
    let z0 = Complex(trans_x (idx % N), trans_y (idx / N))
    let inline mag2 (x : Complex) = x.Real * x.Real + x.Imaginary * x.Imaginary
    let rec iter k z =
        if k < depth && (mag2 z) < escape2 then
            iter (k+1)  (z * z + z0)
        else
            k, (mag2 z)
    let count, magz2 = iter 0 Complex.Zero
    log ((float count) + 1.0 - log(log(max magz2 escape2) / 2.0) / log(2.0))

let log_count = array_init (N*N) mandel

// ********************************************************************
// Color mapping
let max_result, min_result = Array.max log_count, Array.min log_count

let color_map = [|( 0.0, 0.0, 0.5 ) ;
                 ( 0.0, 0.0, 1.0 ) ;
                 ( 0.0, 0.5, 1.0 ) ;
                 ( 0.0, 1.0, 1.0 ) ;
                 ( 0.5, 1.0, 0.5 ) ;
                 ( 1.0, 1.0, 0.0 ) ;
                 ( 1.0, 0.5, 0.0 ) ;
                 ( 1.0, 0.0, 0.0 ) ;
                 ( 0.5, 0.0, 0.0 ) ;
                 ( 0.5, 0.0, 0.0 ) ;
                 ( 1.0, 0.0, 0.0 ) ;
                 ( 1.0, 0.5, 0.0 ) ;
                 ( 1.0, 1.0, 0.0 ) ;
                 ( 0.5, 1.0, 0.5 ) ;
                 ( 0.0, 1.0, 1.0 ) ;
                 ( 0.0, 0.5, 1.0 ) ;
                 ( 0.0, 0.0, 1.0 ) ;
                 ( 0.0, 0.0, 0.5 ) ;
                 ( 0.0, 0.0, 0.0 ) |]

let map_to_argb x =
    let x = (x - min_result) / (max_result - min_result) * 18.0
    let bin = int x
    if bin >= 18 then
        0xff000000
    else
        let d = x - float(bin)
        let interpolate v0 v1 = int((d * (v1 - v0) + v0) * 255.0)
        let r0, g0, b0 = color_map.[bin]
        let r1, g1, b1 = color_map.[bin + 1]
        let r, g, b = (interpolate r0 r1), (interpolate g0 g1), (interpolate b0 b1)
        b ||| (g <<< 8) ||| (r <<< 16) ||| 0xff000000

let argb_array = array_map map_to_argb log_count

stopWatch.Stop()
let elapsed = sprintf "%f milliseconds" stopWatch.Elapsed.TotalMilliseconds

// ********************************************************************
// Windows forms
let bmp_from (data : int array) =
    let bmp = new Bitmap(N, N)
    let rect = new Rectangle(0, 0, bmp.Width, bmp.Height)
    let bmpdata = bmp.LockBits(rect, Imaging.ImageLockMode.WriteOnly, bmp.PixelFormat)
    Marshal.Copy(data, 0, bmpdata.Scan0, (Array.length data))
    bmp.UnlockBits(bmpdata)
    let gfx = Graphics.FromImage(bmp)
    gfx.DrawString(elapsed, SystemFonts.MessageBoxFont, new SolidBrush(Color.White), new PointF(20.0f, 20.0f))
    bmp

let main_form = new Form(ClientSize=Size(N,N), Text = "Mandelbrot Set", StartPosition = FormStartPosition.CenterScreen)
let box = new PictureBox (BackColor = Color.White, Dock = DockStyle.Fill, SizeMode = PictureBoxSizeMode.CenterImage)
main_form.Controls.Add(box)

[<STAThread>]
do
    box.Image <- ((bmp_from argb_array) :> Image)
    Application.Run(main_form)
