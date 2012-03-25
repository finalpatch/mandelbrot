open System
open System.IO
open System.Drawing
open System.Windows.Forms
open SharpDX
open SharpDX.DXGI
open SharpDX.Direct3D
open SharpDX.Direct3D11
open SharpDX.D3DCompiler
open System.Diagnostics
open System.Runtime.InteropServices

let N = 1000
let depth = 200
let escape2 = 400

[<Struct>]
type ShaderArgs(n: int, d: int, e: int) =
    member v.N = n
    member v.depth = d
    member v.escape2 = e

let device = new Device(Direct3D.DriverType.Hardware, DeviceCreationFlags.None, [|FeatureLevel.Level_11_0|])
let context = device.ImmediateContext

let loadShader filename entry profile =
    ShaderBytecode.CompileFromFile(filename, entry, profile, ShaderFlags.None, EffectFlags.None)

let createTexture2D w h fmt flags =
    let texDesc = new Texture2DDescription(ArraySize = 1, BindFlags = flags, CpuAccessFlags = CpuAccessFlags.None,
                                           Format = fmt, Width = w, Height = h, MipLevels = 1,
                                           OptionFlags = ResourceOptionFlags.None, Usage = ResourceUsage.Default,
                                           SampleDescription = new SampleDescription(1,0))
    new Texture2D (device, texDesc)

let createCpuTexture2D w h fmt =
    let texDesc = new Texture2DDescription(ArraySize = 1, BindFlags = BindFlags.None, CpuAccessFlags = CpuAccessFlags.Read,
                                           Format = fmt, Width = w, Height = h, MipLevels = 1,
                                           OptionFlags = ResourceOptionFlags.None, Usage = ResourceUsage.Staging,
                                           SampleDescription = new SampleDescription(1,0))
    new Texture2D (device, texDesc)

let createArgBuffer (a:'T)  =
    let bufDesc = new BufferDescription(16, ResourceUsage.Default, BindFlags.ConstantBuffer, CpuAccessFlags.None,
                                        ResourceOptionFlags.None, 0)
    let argBuf = new Buffer(device, bufDesc)
    use argData = new DataStream(16, true, true)
    argData.Write<'T> a
    context.UpdateSubresource(new DataBox(argData.DataPointer), argBuf, 0)
    argBuf

let compute () =
    try
        // prepare resources
        let cs = new ComputeShader(device, (loadShader "compute.hlsl" "main" "cs_5_0"))
        let texout = createTexture2D N N Format.R8G8B8A8_UNorm BindFlags.UnorderedAccess
        let accessview = new UnorderedAccessView (device, texout)
        let args = createArgBuffer(new ShaderArgs(N, depth, escape2))
        let cpuTexture = createCpuTexture2D N N Format.R8G8B8A8_UNorm

        // run computation on gpu
        let stopWatch = Stopwatch.StartNew()
        context.ComputeShader.Set(cs)
        context.ComputeShader.SetUnorderedAccessView(0, accessview)
        context.ComputeShader.SetConstantBuffer(0, args)
        context.Dispatch(N/20,N/20,1) |> ignore
        
        // copy resoult to cpu accessable memory
        context.CopyResource(texout, cpuTexture)

        // read results back to f# array
        let databox, strm = context.MapSubresource(cpuTexture, 0, MapMode.Read, MapFlags.None)
        let data = Array.zeroCreate (N*N)
        for row = 0 to N-1 do
            for col = 0 to N-1 do
                data.[row * N + col] <- strm.Read<int>()
            strm.Position <- (int64 row) * (int64 databox.RowPitch)
        let elapsed = sprintf "%f milliseconds" stopWatch.Elapsed.TotalMilliseconds

        let bmp = new Bitmap(N, N)
        let rect = new System.Drawing.Rectangle(0, 0, bmp.Width, bmp.Height)
        let bmpdata = bmp.LockBits(rect, Imaging.ImageLockMode.WriteOnly, bmp.PixelFormat)
        Marshal.Copy(data, 0, bmpdata.Scan0, (Array.length data))
        bmp.UnlockBits(bmpdata)
        use gfx = Graphics.FromImage(bmp)
        gfx.DrawString(elapsed, SystemFonts.MessageBoxFont, new SolidBrush(Color.White), new PointF(20.0f, 20.0f))
        bmp
    with
        | e -> failwith e.InnerException.Message

let box = new PictureBox (BackColor = Color.White, Dock = DockStyle.Fill,
                          SizeMode = PictureBoxSizeMode.CenterImage, Image = compute ())
let form = new Form(ClientSize=Size(N,N), Text = "Mandelbrot Set", StartPosition = FormStartPosition.CenterScreen)
form.Controls.Add(box)

[<STAThread>]
do
    Application.Run(form)
