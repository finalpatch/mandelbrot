#-------------------------------------------------
#
# Project created by QtCreator 2012-03-03T12:17:42
#
#-------------------------------------------------

QT       += core gui

greaterThan(QT_MAJOR_VERSION, 4): QT += widgets

TARGET = clmandel
TEMPLATE = app

win32:LIBS += OpenCL.lib
unix:LIBS += opencl

win32{
  INCLUDEPATH += $$(INTELOCLSDKROOT)/include

  contains(QMAKE_TARGET.arch, x86_64) {
    LIBPATH += $$(INTELOCLSDKROOT)/lib/x64
  }
  else{
    LIBPATH += $$(INTELOCLSDKROOT)/lib/x86
  }
}

SOURCES += main.cpp\
        mandelbrotview.cpp

HEADERS  += mandelbrotview.h
