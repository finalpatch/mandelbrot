#include "MandelbrotView.h"
#include <QtGui>
#include <complex>
#include <algorithm>
#include <cmath>
#include <stdint.h>
#include <QtConcurrent/QtConcurrentMap>
#include <QtConcurrent/QtConcurrentRun>
#include <QApplication>
#include <QDesktopWidget>
#include <QStyle>

const static int parallelism = 16;

// ********************************************************************
// Mandelbrot
const static int N = 1000;      // grid size
const static int depth = 200;   // max iterations
const static double escape2 = 400.0; // escape radius ^ 2

inline double trans_x(int x)
{
    return 3.0 * ((double)x / N) - 2.0;
}
inline double trans_y(int y)
{
    return 3.0 * ((double)y / N) - 1.5;
}

template<class T>
double mag2(const std::complex<T>& x)
{
    return x.real() * x.real() + x.imag() * x.imag();
}

inline double mandel(int idx)
{
    const std::complex<double> z0(trans_x(idx % N), trans_y(idx / N));
    std::complex<double> z(0, 0);
    int k = 0;
    double magz2;
    for(; k < depth && (magz2 = mag2(z)) < escape2 ; ++k)
        z = z * z + z0;
    return log(k + 1.0 - log(log(std::max(magz2, escape2)) / 2.0) / log(2.0));
}

// ********************************************************************
// Color mapping
const static double color_map[][3] =
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

inline int interpolate(const double& d, const double& v0, const double& v1)
{
    return int((d * (v1 - v0) + v0) * 255.0);
}

static double min_result = 0.0;
static double max_result = 0.0;

const static int stops = sizeof(color_map) / sizeof(color_map[0]) - 1;

inline uint32_t map_to_argb(double x)
{
    x = (x - min_result) / (max_result - min_result) * stops;
    int bin = (int) x;
    if(bin >= stops)
        return 0xff000000;
    else
    {
        const double& r0 = color_map[bin][0];
        const double& g0 = color_map[bin][1];
        const double& b0 = color_map[bin][2];
        const double& r1 = color_map[bin+1][0];
        const double& g1 = color_map[bin+1][1];
        const double& b1 = color_map[bin+1][2];
        double d = x - bin;
        int r = interpolate(d, r0, r1);
        int g = interpolate(d, g0, g1);
        int b = interpolate(d, b0, b1);
        return b | (g << 8) | (r << 16) | 0xff000000;
    }
}

static double   log_count[N*N];
static uint32_t argb_array[N*N];

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

const static int job_size = N*N / parallelism;
const int worker_threads = parallelism - 1;

void do_mandel()
{
    if(parallelism > 1)
    {
        QFuture<void> results[worker_threads];
        for(int i = 0; i < worker_threads; ++i)
            results[i] = QtConcurrent::run(do_mandel_range, job_size * i, job_size * (i + 1));

        do_mandel_range(job_size * worker_threads, N*N);

        for(int i = 0; i < worker_threads; ++i)
            results[i].waitForFinished();
    }
    else
        do_mandel_range(0, N*N);
}
void do_map_to_argb()
{
    min_result = *(std::min_element(log_count, log_count + N*N));
    max_result = *(std::max_element(log_count, log_count + N*N));

    if(parallelism > 1)
    {
        QFuture<void> results[worker_threads];
        for(int i = 0; i < worker_threads; ++i)
            results[i] = QtConcurrent::run(do_map_to_argb_range, job_size * i, job_size * (i + 1));

        do_map_to_argb_range(job_size * worker_threads, N*N);

        for(int i = 0; i < worker_threads; ++i)
            results[i].waitForFinished();
    }
    else
        do_map_to_argb_range(0, N*N);
}

// ********************************************************************
// Qt
MandelbrotView::MandelbrotView(QWidget *parent) :
    QWidget(parent)
{
    setGeometry(QStyle::alignedRect(Qt::LeftToRight,
                                    Qt::AlignCenter,
                                    QSize(N, N),
                                    QApplication::desktop()->availableGeometry()));
    QTime time;
    time.start();
    {
        do_mandel();
        do_map_to_argb();
    }
    m_elapsed = QString("%1 milliseconds").arg(time.elapsed());
    m_image = new QImage((uchar*)argb_array, N, N, QImage::Format_RGB32);
}

MandelbrotView::~MandelbrotView()
{
    delete m_image;
}

void MandelbrotView::paintEvent(QPaintEvent * evt)
{
    QPainter painter(this);    
    painter.drawImage(0, 0, *m_image);
    painter.setPen(Qt::white);    
    painter.drawStaticText(20, 20, m_elapsed);
}
