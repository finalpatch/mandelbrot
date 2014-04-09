
#![allow(unused_must_use)]

extern crate num;
extern crate time;

use std::num::ln;
use std::num::Bounded;
use num::complex::{Cmplx,Complex64};
use time::precise_time_ns;
use std::io::File;
use std::path::Path;

//static parallelism: uint = 16;
static parallelism: uint = 1;

// ********************************************************************
// Mandelbrot
static N: uint = 1000;      // grid size
static depth: uint = 200;   // max iterations
static escape2: f64 = 400.0; // escape radius ^ 2

#[inline]
fn trans_x(x: uint) -> f64 {
    3.0 * (x as f64 / N as f64) - 2.0
}

#[inline]
fn trans_y(y: uint) -> f64 {
    3.0 * (y as f64 / N as f64) - 1.5
}

#[inline]
fn mandel(idx: uint) -> f64 {
    let z0: Complex64 = Cmplx::new(trans_x(idx % N), trans_y(idx / N));
    let mut z: Complex64 = Cmplx::new(0.0, 0.0);
    let mut k: uint = 0;
    let mut magz2: f64 = 0.0;

    for kn in range(0, depth) {
        k = kn;
        z = z * z + z0;

        magz2 = z.norm_sqr();
        if magz2 >= escape2 {
            break;
        }
    }

    let v = if magz2 > escape2 { magz2 } else { escape2 };

    ln((k+1) as f64 + 1.0 - ln(ln(v) / 2.0) / ln(2.0))
}

// ********************************************************************
// Color mapping
static color_map: [[f32, ..3], ..19] =
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

#[inline]
fn interpolate(d: &f32, v0: &f32, v1: &f32) -> uint {
    ((*d * (*v1 - *v0) + *v0) * 255.0).round() as uint
}

static mut min_result: f64 = 0.0;
static mut max_result: f64 = 0.0;

static stops: uint = 18;

#[inline]
fn map_to_argb(x: f64) -> uint {
    let mut x1: f64 = 0.0;
    unsafe {x1 = (x - min_result) / (max_result - min_result) * (stops as f64);}
    let bin: uint = x1 as uint;
    if bin >= stops {
        0xff000000
    } else {
        let r0: &f32 = &color_map[bin][0];
        let g0: &f32 = &color_map[bin][1];
        let b0: &f32 = &color_map[bin][2];
        let r1: &f32 = &color_map[bin+1][0];
        let g1: &f32 = &color_map[bin+1][1];
        let b1: &f32 = &color_map[bin+1][2];
        let d = x1 as f32 - bin as f32;
        let r = interpolate(&d, r0, r1);
        let g = interpolate(&d, g0, g1);
        let b = interpolate(&d, b0, b1);
        b | (g << 8) | (r << 16) | 0xff000000
    }
}

static mut log_count: [f64, ..N*N] = [0.0, .. N*N];
static mut argb_array: [uint, ..N*N] = [0, .. N*N];

fn do_mandel_range(beg: uint, end: uint) {
    for idx in range(beg, end) {
        unsafe { log_count[idx] = mandel(idx);}
    }
}

fn do_map_to_argb_range(beg: uint, end: uint) {
    for i in range(beg, end) {
        unsafe {
            argb_array[i] = map_to_argb(log_count[i]);
        }
    }
}

static job_size: uint = N*N / parallelism;
static worker_threads: uint = parallelism - 1;

fn do_mandel() {
    if parallelism > 1 {
/*
        QFuture<void> results[worker_threads];
        for(int i = 0; i < worker_threads; ++i)
            results[i] = QtConcurrent::run(do_mandel_range, job_size * i, job_size * (i + 1));

        do_mandel_range(job_size * worker_threads, N*N);

        for(int i = 0; i < worker_threads; ++i)
            results[i].waitForFinished();
*/
    }
    else {
        do_mandel_range(0, N*N);
    }
}

fn do_map_to_argb() {

    // We can't use these because TotalOrd is not defined for f32/f64
    //    min_result = log_count.iter().min();
    //    max_result = log_count.iter().max();

    unsafe { // mut static
        min_result = Bounded::max_value();
        max_result = Bounded::min_value();
        for val in log_count.iter() {
            if *val < min_result {
                min_result = *val;
            }
            if *val > max_result {
                max_result = *val;
            }
        }
    }

    if parallelism > 1
    {
/*
        QFuture<void> results[worker_threads];
        for(int i = 0; i < worker_threads; ++i)
            results[i] = QtConcurrent::run(do_map_to_argb_range, job_size * i, job_size * (i + 1));

        do_map_to_argb_range(job_size * worker_threads, N*N);

        for(int i = 0; i < worker_threads; ++i)
            results[i].waitForFinished();
*/
    } else {
        do_map_to_argb_range(0, N*N);
    }
}

fn main() {

    let time_start = precise_time_ns();

    do_mandel();
    do_map_to_argb();

    let time_stop = precise_time_ns();

    let time_elapsed_ms = (time_stop - time_start) as f32 / 1000000.0;

    println!("Elapsed: {} ms", time_elapsed_ms);

    // Save image

    // Header
    let mut file = File::create(&Path::new("out.ppm"));
    file.write(bytes!("P6\n"));
    file.write_str(format!("{} {}\n255\n", N, N));

    // Extract RGB from RGBA
    for i in range(0, N*N) {
        let mut rgba: u32;
        unsafe {
            rgba = argb_array[i] as u32;
        }
        let r: u8 = ((rgba & 0x00ff0000) >> 16) as u8;
        let g: u8 = ((rgba & 0x0000ff00) >>  8) as u8;
        let b: u8 = ((rgba & 0x000000ff))       as u8;
        file.write_u8(r);
        file.write_u8(g);
        file.write_u8(b);
    }
}
