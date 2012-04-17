//
// MandelbrotView.xaml.cpp
// Implementation of the MandelbrotView.xaml class.
//

#include "pch.h"
#include "MandelbrotView.xaml.h"

#include <complex>
#include <algorithm>
#include <cmath>
#include <stdint.h>
#include <amp.h>
#include <amp_math.h>

/* BEGIN HACK - see below */
#define NOMINMAX 1
#include <Windows.h>
#include <INITGUID.H>
/* END HACK */

using namespace MandelbrotViewer;

using namespace Platform;
using namespace Windows::Foundation;
using namespace Windows::Foundation::Collections;
using namespace Windows::UI::Xaml;
using namespace Windows::UI::Xaml::Controls;
using namespace Windows::UI::Xaml::Controls::Primitives;
using namespace Windows::UI::Xaml::Data;
using namespace Windows::UI::Xaml::Input;
using namespace Windows::UI::Xaml::Media;
using namespace Windows::UI::Xaml::Navigation;
using namespace Windows::UI::Xaml::Media::Imaging;

using namespace concurrency;
using namespace concurrency::fast_math;

// The Blank Page item template is documented at http://go.microsoft.com/fwlink/?LinkId=234238

/* BEGIN HACK - ATM there's no way to access an IBuffer object in WinRT */
//905a0fef-bc53-11df-8c49-001e4fc686da
DEFINE_GUID(IID_IBufferInternal, 0x905a0fef, 0xbc53, 0x11df, 0x8c, 0x49, 0x00, 0x1e, 0x4f, 0xc6, 0x86, 0xda);
struct IBufferInternal : IUnknown
{
	STDMETHOD(GetBuffer)(unsigned char** c) PURE;
};
unsigned char* GetBitmapBuffer(WriteableBitmap^ bmp)
{
	auto buf = bmp->PixelBuffer;
	IUnknown* pUnk = reinterpret_cast<IUnknown*>(buf);
	IBufferInternal* pBufferInternal = nullptr;
	HRESULT hr = pUnk->QueryInterface(IID_IBufferInternal, (void**)&pBufferInternal);
	if(hr != S_OK)
		return nullptr;
	unsigned char* pBuff = nullptr;
	pBufferInternal->GetBuffer(&pBuff);
	pBufferInternal->Release();
	return pBuff;
}
/* END HACK */

// ********************************************************************
// Mandelbrot
#define N  1000      // grid size
#define depth  200   // max iterations
#define escape2  400.0f // escape radius ^ 2

float trans_x(int x) restrict(amp)
{
    return 3.0f * ((float)x / N) - 2.0f;
}
float trans_y(int y) restrict(amp)
{
    return 3.0f * ((float)y / N) - 1.5f;
}

float mag2(float real, float imag) restrict(amp)
{
	return real*real + imag*imag;
}

float mandel(int idx) restrict(amp)
{
    float z0_r = trans_x(idx % N);
    float z0_i = trans_y(idx / N);

	float z_r = 0;
	float z_i = 0;
	int k = 0;
	for(; k <= depth && mag2(z_r, z_i) < escape2 ; ++k) {
		float t_r = z_r; float t_i = z_i;
	  	z_r = t_r * t_r - t_i * t_i + z0_r;
	   	z_i = 2 * t_r * t_i + z0_i;
	}
    return log(k + 1.0f - log(log(fmax(mag2(z_r, z_i), (float)escape2)) / 2.0f) / log(2.0f));
}

// ********************************************************************
// Color mapping
const static float color_map[][3] =
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

inline int interpolate(const float& d, const float& v0, const float& v1)
{
    return int((d * (v1 - v0) + v0) * 255.0);
}

static float min_result = 0.0;
static float max_result = 0.0;

const static int stops = sizeof(color_map) / sizeof(color_map[0]) - 1;

inline uint32_t map_to_argb(float x)
{
    x = (x - min_result) / (max_result - min_result) * stops;
    int bin = (int) x;
    if(bin >= stops)
        return 0xff000000;
    else
    {
        const float& r0 = color_map[bin][0];
        const float& g0 = color_map[bin][1];
        const float& b0 = color_map[bin][2];
        const float& r1 = color_map[bin+1][0];
        const float& g1 = color_map[bin+1][1];
        const float& b1 = color_map[bin+1][2];
        float d = x - bin;
        int r = interpolate(d, r0, r1);
        int g = interpolate(d, g0, g1);
        int b = interpolate(d, b0, b1);
        return b | (g << 8) | (r << 16) | 0xff000000;
    }
}

static float   log_count[N*N];
static uint32_t argb_array[N*N];

void do_mandel()
{
	array_view<float> log_count_view(N*N, log_count);
	parallel_for_each(log_count_view.extent,
		[=](index<1> idx) restrict(amp)
	{
		log_count_view[idx] = mandel(idx[0]);
	});
}
void do_map_to_argb()
{
    min_result = *(std::min_element(log_count, log_count + N*N));
    max_result = *(std::max_element(log_count, log_count + N*N));

    for(int i = 0; i < N*N; ++i)
        argb_array[i] = map_to_argb(log_count[i]);
}

MandelbrotView::MandelbrotView()
{
	InitializeComponent();
}

/// <summary>
/// Invoked when this page is about to be displayed in a Frame.
/// </summary>
/// <param name="e">Event data that describes how this page was reached.  The Parameter
/// property is typically used to configure the page.</param>
void MandelbrotView::OnNavigatedTo(NavigationEventArgs^ e)
{
	Windows::Globalization::Calendar begin;
	begin.SetToNow();
	try
	{
		do_mandel();
		do_map_to_argb();
	}
	catch (const Concurrency::runtime_exception& e)
	{
		this->elapsed->Text = "error";
	}
	Windows::Globalization::Calendar end;
	end.SetToNow();
	
	Windows::Globalization::NumberFormatting::DecimalFormatter fmt;
	this->elapsed->Text = fmt.Format(float(end.Nanosecond - begin.Nanosecond)/1000000) + " ms";

	WriteableBitmap^ bmp = ref new WriteableBitmap(1000, 1000);
	unsigned char* p = GetBitmapBuffer(bmp);
	memcpy(p, argb_array, N*N*4);
	this->viewport->Source = bmp;
}
