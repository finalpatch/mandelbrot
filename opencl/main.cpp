#include "mandelbrotview.h"
#include <QApplication>

int main(int argc, char *argv[])
{
    QApplication a(argc, argv);
    MandelbrotView w;
    w.show();
    
    return a.exec();
}
