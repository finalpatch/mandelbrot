#ifndef MANDELBROTVIEW_H
#define MANDELBROTVIEW_H

#include <QWidget>

class MandelbrotView : public QWidget
{
    Q_OBJECT
    QString m_elapsed;
    QImage* m_image;
    void paintEvent(QPaintEvent * evt);
public:
    MandelbrotView(QWidget *parent = 0);
    ~MandelbrotView();
};

#endif // MANDELBROTVIEW_H
