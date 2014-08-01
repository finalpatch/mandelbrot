//
//  AppDelegate.swift
//  mandelbrot
//
//  Created by l f on 1/08/2014.
//  Copyright (c) 2014 l f. All rights reserved.
//

import Cocoa

let N = 1000;
let depth = 200;
let escape2 = 400.0;

func trans_x(x:Int) -> Double
{
	return 3.0 * (Double(x) / Double(N)) - 2.0;
}
func trans_y(y:Int) -> Double
{
	return 3.0 * (Double(y) / Double(N)) - 1.5;
}

func mag2(r:Double, i:Double) -> Double {
	return r*r + i*i
}

func mandel(idx: Int) -> Double {
	let z0_r = trans_x(idx % N)
	let z0_i = trans_y(idx / N)
	
	var z_r = 0.0
	var z_i = 0.0
	
	var k = 0;
	for ; k <= depth && mag2(z_r, z_i) < escape2; ++k {
		let t_r = z_r
		let t_i = z_i
		z_r = t_r * t_r - t_i * t_i + z0_r
		z_i = 2 * t_r * t_i + z0_i
	}
	return log(Double(k) + 1.0 - log(log(max(mag2(z_r, z_i), escape2)) / 2.0) / log(2.0));
}

let color_map =
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

func interpolate(d:Double, v0:Double, v1:Double) -> UInt32
{
	return (UInt32)((d * (v1 - v0) + v0) * 255.0);
}

var min_result = 0.0;
var max_result = 0.0;

let stops = Int(color_map.count) - 1

func map_to_argb(xx:Double) -> UInt32
{
	let x = (xx - min_result) / (max_result - min_result) * Double(stops);
	let bin = Int(x);
	if(bin >= stops)
	{
		return 0xff000000
	}
	else
	{
		let r0 = color_map[bin][0];
		let g0 = color_map[bin][1];
		let b0 = color_map[bin][2];
		let r1 = color_map[bin+1][0];
		let g1 = color_map[bin+1][1];
		let b1 = color_map[bin+1][2];
		let d = x - Double(bin);
		let r = interpolate(d, r0, r1);
		let g = interpolate(d, g0, g1);
		let b = interpolate(d, b0, b1);
		return r | (g << 8) | (b << 16) | 0xff000000;
	}
}

class CustomView: NSView{
	var myImage = NSImage()
	func computeMandel() {
		var logcount = Array(count: N*N, repeatedValue: 0.0)
		var argb = Array(count: N*N, repeatedValue: UInt32(0))
		
		let start = NSDate()
		
		for i in 0...(N*N-1) {
			logcount[i] = mandel(i)
		}

		let end = NSDate()
		let elapsed = end.timeIntervalSinceDate(start);
		let text = NSTextField(frame: NSRect(x: 0, y: 0, width: 60, height: 20))
		text.editable = false;
		text.stringValue = String(format: "%dms", UInt(elapsed*1000.0))
		addSubview(text)

		min_result = logcount.reduce(9999.9, {min($0, $1)})
		max_result = logcount.reduce(0.0, {max($0, $1)})
		for i in 0...(N*N-1) {
			argb[i] = map_to_argb(logcount[i])
		}
		argb.withUnsafePointerToElements() { (cArray: UnsafePointer<UInt32>) -> () in
			let colorSpace:CGColorSpace = CGColorSpaceCreateDeviceRGB()
			let bitmapInfo = CGBitmapInfo.fromRaw(CGImageAlphaInfo.PremultipliedLast.toRaw())!
			let context = CGBitmapContextCreate(cArray, UInt(N), UInt(N), 8, UInt(N*4), colorSpace, bitmapInfo)
			self.myImage = NSImage(CGImage: CGBitmapContextCreateImage(context), size: NSSize(width: N, height: N))
		}
	}
	
	override func drawRect(dirtyRect: NSRect)
	{
		myImage.drawInRect(bounds)
	}
}

class AppDelegate: NSObject, NSApplicationDelegate {
	
	@IBOutlet weak var window: NSWindow!

	func applicationDidFinishLaunching(aNotification: NSNotification?) {
		let view = CustomView(frame: window.contentView.bounds)
		view.autoresizingMask = NSAutoresizingMaskOptions.ViewWidthSizable | NSAutoresizingMaskOptions.ViewHeightSizable
		view.computeMandel()
		window.contentView.addSubview(view)
	}

	func applicationWillTerminate(aNotification: NSNotification?) {
	}

	func applicationShouldTerminateAfterLastWindowClosed(sender: NSApplication!) -> Bool {
		return true
	}
}

