
import Control.Monad
import System.IO
import System.CPUTime
import Text.Printf
import Data.Complex
import Data.Bits
import Data.Binary
import Text.Printf

import qualified Data.ByteString as BS

parallelism = 16

-- ********************************************************************
-- Mandelbrot

grid_dim = 100::Int        -- grid size (N)

depth = 200::Int           -- max iterations

escape2 = 400.0            -- escape radius ^ 2

trans_x :: Int -> Double
trans_x x =
  3.0*fromIntegral x/fromIntegral grid_dim - 2.0

trans_y :: Int -> Double
trans_y y =
  3.0*fromIntegral y/fromIntegral grid_dim - 1.5

fm :: Int -> Complex Double -> Complex Double
fm k z0
  | k <= 0    = z0
  | otherwise = (fm (k-1) z0)^2 + z0

mandel :: Int -> Double
mandel idx =
  let z0 = (trans_x (idx `mod` grid_dim)) :+ (trans_y (idx `div` grid_dim))
      k = [0..depth]
      zs = map (\k -> fm k z0) k
      zmags = map magnitude zs
      zmags' = takeWhile (< escape2) zmags
      magz2 = maximum zmags'
      kn = length zmags'
      v = max magz2 escape2
  in
    log (fromIntegral kn + 1.0 - log (log v / 2.0) / log 2.0)

-- ********************************************************************
-- Color mapping
color_map :: [[Double]]
color_map =
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
      [ 0.0, 0.0, 0.0 ] ]

interpolate :: Double -> Double -> Double -> Int
interpolate d v0 v1 =
  round ((d * (v1 - v0) + v0) * 255.0)

stops = 18

map_to_argb :: Double -> Double -> Double -> Int
map_to_argb min_result max_result x =
  let
    x1 = (x - min_result) / (max_result - min_result) * (fromIntegral stops)
    bin = round x1
  in
    if bin >= stops
    then 0xff000000
    else let
          r0 = color_map !! (fromIntegral bin) !! 0
          g0 = color_map !! (fromIntegral bin) !! 1
          b0 = color_map !! (fromIntegral bin) !! 2
          r1 = color_map !! (fromIntegral (bin+1)) !! 0
          g1 = color_map !! (fromIntegral (bin+1)) !! 1
          b1 = color_map !! (fromIntegral (bin+1)) !! 2
          d = x1 - (fromIntegral bin)
          r = interpolate d r0 r1
          g = interpolate d g0 g1
          b = interpolate d b0 b1
        in
          b + (g * 256) + (r * 65536) + 0xff000000

job_size = grid_dim*grid_dim `div` parallelism

worker_threads = parallelism

do_mandel =
  let
    r = [0 .. (grid_dim*grid_dim)]
  in
   map mandel r

do_map_to_argb :: [Double] -> [Int]
do_map_to_argb log_count =
  let
    min_result = minimum log_count
    max_result = maximum log_count
  in
   map (map_to_argb min_result max_result) log_count

-- Converts ARGB32 into RGB24
hPutRGB :: Handle -> Int -> IO ()
hPutRGB hfile word =
  let
    r = fromIntegral ((word .&. 0x00ff0000::Int) `shiftR` 16)::Word8
    g = fromIntegral ((word .&. 0x0000ff00::Int) `shiftR`  8)::Word8
    b = fromIntegral ((word .&. 0x000000ff::Int))::Word8
    bs = BS.pack [r,g,b]
  in
    BS.hPut hfile bs

saveAsPPM :: [Int] -> String -> IO ()
saveAsPPM bin filename = do
  outf <- openFile filename WriteMode
  hPutStrLn outf "P6"
  hPutStrLn outf $ printf "%u %u" grid_dim grid_dim
  hPutStrLn outf "255"
  mapM_ (hPutRGB outf) bin
  hClose outf

time :: IO t -> IO t
time a = do
    start <- getCPUTime
    v <- a
    end   <- getCPUTime
    let diff = (fromIntegral (end - start)) / (10^12)
    printf "Computation time: %0.3f sec\n" (diff :: Double)
    return v

process =
  let
    log_count = do_mandel
    argb_array = do_map_to_argb log_count
  in do
    saveAsPPM argb_array "output.ppm"

main = do
  putStrLn "mandelbrot"
  time process
