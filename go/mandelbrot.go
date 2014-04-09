package main

import "math"
import "os"
import "fmt"
import "time"

const parallelism = 16

// ********************************************************************
// Mandelbrot
const N = 1000        // grid size
const depth = 200     // max iterations
const escape2 = 400.0 // escape radius ^ 2

func trans_x(x int) float64 {
	return 3.0*(float64(x)/N) - 2.0
}

func trans_y(y int) float64 {
	return 3.0*(float64(y)/N) - 1.5
}

func mag2(x complex128) float64 {
	return float64(real(x)*real(x) + imag(x)*imag(x))
}

func mandel(idx int) float64 {
	var z0 complex128 = complex(trans_x(idx%N), trans_y(idx/N))
	var z complex128 = complex(0.0, 0.0)
	var magz2 float64
	var k uint

	for k = 0; k < depth; k++ {
		z = z*z + z0
		magz2 = mag2(z)
		if magz2 >= escape2 {
			break
		}
	}
	return math.Log(float64(k) + 1.0 - math.Log(math.Log(math.Max(magz2, escape2))/2.0)/math.Log(2.0))
}

// ********************************************************************
// Color mapping
// @todo Make const
var color_map = [][3]float64{
	{0.0, 0.0, 0.5},
	{0.0, 0.0, 1.0},
	{0.0, 0.5, 1.0},
	{0.0, 1.0, 1.0},
	{0.5, 1.0, 0.5},
	{1.0, 1.0, 0.0},
	{1.0, 0.5, 0.0},
	{1.0, 0.0, 0.0},
	{0.5, 0.0, 0.0},
	{0.5, 0.0, 0.0},
	{1.0, 0.0, 0.0},
	{1.0, 0.5, 0.0},
	{1.0, 1.0, 0.0},
	{0.5, 1.0, 0.5},
	{0.0, 1.0, 1.0},
	{0.0, 0.5, 1.0},
	{0.0, 0.0, 1.0},
	{0.0, 0.0, 0.5},
	{0.0, 0.0, 0.0}}

func interpolate(d float64, v0 float64, v1 float64) uint {
	return uint((d*(v1-v0) + v0) * 255.0)
}

var min_result float64 = 0.0
var max_result float64 = 0.0

const stops = 18

func map_to_argb(x float64) uint {
	x = (x - min_result) / (max_result - min_result) * stops
	var bin = uint32(x)
	if bin >= stops {
		return 0xff000000
	} else {
		r0 := color_map[bin][0]
		g0 := color_map[bin][1]
		b0 := color_map[bin][2]
		r1 := color_map[bin+1][0]
		g1 := color_map[bin+1][1]
		b1 := color_map[bin+1][2]
		d := x - float64(bin)
		r := interpolate(d, r0, r1)
		g := interpolate(d, g0, g1)
		b := interpolate(d, b0, b1)
		return b | (g << 8) | (r << 16) | 0xff000000
	}
}

var log_count [N * N]float64
var argb_array [N * N]uint

func do_mandel_range(beg int, end int) {
	for idx := beg; idx < end; idx++ {
		log_count[idx] = mandel(idx)
	}
}

func do_map_to_argb_range(beg int, end int) {

	for i := beg; i < end; i++ {
		argb_array[i] = map_to_argb(log_count[i])
	}
}

const job_size = N * N / parallelism
const worker_threads = parallelism

func do_mandel() {
	if parallelism > 1 {
		results := make([]chan int, worker_threads)

		for i := 0; i < worker_threads; i++ {
			results[i] = make(chan int)
			go func(n int) {
				do_mandel_range(job_size*n, job_size*(n+1))
				results[n] <- 1
			}(i)
		}

		for i := 0; i < worker_threads; i++ {
			<-results[i]
		}
	} else {
		do_mandel_range(0, N*N)
	}
}

func do_map_to_argb() {
	min_result = math.MaxFloat64
	max_result = math.SmallestNonzeroFloat64
	for _, val := range log_count {
		min_result = math.Min(min_result, val)
		max_result = math.Max(max_result, val)
	}

	if parallelism > 1 {
		results := make([]chan int, worker_threads)

		for i := 0; i < worker_threads; i++ {
			results[i] = make(chan int)
			go func(n int) {
				do_map_to_argb_range(job_size*n, job_size*(n+1))
				results[n] <- 1
			}(i)
		}

		for i := 0; i < worker_threads; i++ {
			<-results[i]
		}
	} else {
		do_map_to_argb_range(0, N*N)
	}
}

func main() {

	time_start := time.Now()

	do_mandel()
	do_map_to_argb()

	time_stop := time.Now()

	time_elapsed := time_stop.Sub(time_start)
	fmt.Printf("elapsed: %v\n", time_elapsed)

	// Save image file

	imgfile, _ := os.Create("out.ppm")
	imgfile.WriteString(fmt.Sprintf("P6\n%v %v\n255\n", N, N))

	// Extract RGB from RGBA
	for i := 0; i < N*N; i++ {
		rgba := argb_array[i]
		r := uint8((rgba & 0x00ff0000) >> 16)
		g := uint8((rgba & 0x0000ff00) >> 8)
		b := uint8((rgba & 0x000000ff))
		rgb_out := make([]byte, 3)
		rgb_out[0] = r
		rgb_out[1] = g
		rgb_out[2] = b
		imgfile.Write(rgb_out)
	}
}
