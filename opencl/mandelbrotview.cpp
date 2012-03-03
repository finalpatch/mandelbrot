#include "mandelbrotview.h"
#include <CL/cl.hpp>
#include <iostream>
#include <fstream>
#include <string>
#include <QtGui>
#include <algorithm>

const static int N = 1000;           // grid size
const static int depth = 200;        // max iterations
const static double escape2 = 400.0; // escape radius ^ 2

const static int parallelism = 8;
const static int oclplatform = 1;
const static int workgroups = N / 10;

double   log_count[N*N];
uint32_t argb_array[N*N];

class CLMandel
{
    cl::Context m_context;
    cl::Device  m_device;
    cl::CommandQueue m_cmdq;
    cl::Kernel m_kernel;

    void checkErr(cl_int err, const char * name)
    {
        if (err != CL_SUCCESS) {
            std::cerr << "ERROR: " << name << " (" << err << ")" << std::endl;
            exit(EXIT_FAILURE);
        }
    }
public:
    CLMandel()
    {
        cl_int err;
        std::vector< cl::Platform > platformList;
        cl::Platform::get(&platformList);
        checkErr(platformList.size()!=0 ? CL_SUCCESS : -1, "cl::Platform::get");
        std::cerr << "Platform number is: " << platformList.size() << std::endl;

        std::string platformVendor;
        for(unsigned i = 0; i < platformList.size(); ++i)
        {
            platformList[i].getInfo((cl_platform_info)CL_PLATFORM_VENDOR, &platformVendor);
            std::cerr << "Platform is by: " << platformVendor << "\n";
        }

        cl_context_properties cprops[3] =
            {CL_CONTEXT_PLATFORM, (cl_context_properties)(platformList[oclplatform])(), 0};

        m_context = cl::Context (
           CL_DEVICE_TYPE_ALL,
           cprops,
           NULL,
           NULL,
           &err);
        checkErr(err, "Conext::Context()");

        std::vector<cl::Device> devices;
        devices = m_context.getInfo<CL_CONTEXT_DEVICES>();
        checkErr(devices.size() > 0 ? CL_SUCCESS : -1, "devices.size() > 0");

        for(unsigned i = 0; i < devices.size(); ++i)
        {
            cl_int deviceType = devices[i].getInfo<CL_DEVICE_TYPE>();
            std::cerr << "Device " << i << ": ";
            if(deviceType & CL_DEVICE_TYPE_CPU)
                std::cerr << "CL_DEVICE_TYPE_CPU ";
            if(deviceType & CL_DEVICE_TYPE_GPU)
                std::cerr << "CL_DEVICE_TYPE_GPU ";
            if(deviceType & CL_DEVICE_TYPE_ACCELERATOR)
                std::cerr << "CL_DEVICE_TYPE_ACCELERATOR ";
            if(deviceType & CL_DEVICE_TYPE_DEFAULT)
                std::cerr << "CL_DEVICE_TYPE_DEFAULT ";
            std::cerr << std::endl;
        }

        m_device = devices[0];

        m_cmdq = cl::CommandQueue(m_context, m_device, 0, &err);
        checkErr(err, "CommandQueue::CommandQueue()");

        std::ifstream file("mandel.cl");
        std::string prog((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());

        cl::Program::Sources source(1, std::make_pair(prog.c_str(), prog.length()+1));
        cl::Program program(m_context, source);
        err = program.build(devices,"");

        m_kernel = cl::Kernel(program, "mandel", &err);
        checkErr(err, "Kernel::Kernel()");
    }
    template <class T>
    void run(T* buf)
    {
        cl_int err;
        cl::Buffer outbuf(
            m_context,
            CL_MEM_WRITE_ONLY | CL_MEM_COPY_HOST_PTR,
            N*N*sizeof(T),
            buf,
            &err);
        checkErr(err, "Buffer::Buffer()");

        err = m_kernel.setArg(0, outbuf);
        checkErr(err, "Kernel::setArg(0)");

        err = m_kernel.setArg(1, N);
        checkErr(err, "Kernel::setArg(1)");

        err = m_kernel.setArg(2, depth);
        checkErr(err, "Kernel::setArg(2)");

        err = m_kernel.setArg(3, escape2);
        checkErr(err, "Kernel::setArg(3)");

        cl::Event event;
        err = m_cmdq.enqueueNDRangeKernel(
            m_kernel,
            cl::NullRange,
            cl::NDRange(N*N),
             cl::NDRange(workgroups, 1),
            NULL,
            &event);
        checkErr(err, "ComamndQueue::enqueueNDRangeKernel()");

        event.wait();
        err = m_cmdq.enqueueReadBuffer(
            outbuf,
            CL_TRUE,
            0,
            N*N*sizeof(T),
            buf);
        checkErr(err, "ComamndQueue::enqueueReadBuffer()");
    }
};

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

inline uint32_t map_to_argb(double x)
{
    x = (x - min_result) / (max_result - min_result) * 18.0;
    int bin = (int) x;
    if(bin >= 18)
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

void do_map_to_argb_range(int beg, int end)
{
    for(int i = beg; i < end; ++i)
        argb_array[i] = map_to_argb(log_count[i]);
}

const static int job_size = N*N / parallelism;

void do_map_to_argb()
{
    min_result = *(std::min_element(log_count, log_count + N*N));
    max_result = *(std::max_element(log_count, log_count + N*N));

    if(parallelism > 1)
    {
        QFuture<void> results[parallelism];
        for(int i = 0; i < parallelism; ++i)
            results[i] = QtConcurrent::run(do_map_to_argb_range, job_size * i, job_size * (i + 1));
        for(int i = 0; i < parallelism; ++i)
            results[i].waitForFinished();
    }
    else
        do_map_to_argb_range(0, N*N);
}


MandelbrotView::MandelbrotView(QWidget *parent)
    : QWidget(parent)
{
    setGeometry(QStyle::alignedRect(Qt::LeftToRight,
                                    Qt::AlignCenter,
                                    QSize(N, N),
                                    qApp->desktop()->availableGeometry()));
    CLMandel clmandel;

    QTime time;
    time.start();
    {
        clmandel.run(log_count);
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
