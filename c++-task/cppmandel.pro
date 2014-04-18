#-------------------------------------------------
#
# Project created by QtCreator 2012-03-01T12:19:08
#
#-------------------------------------------------

QT       += core gui

TARGET = cppmandel
TEMPLATE = app

greaterThan(QT_MAJOR_VERSION, 4): QT += widgets

INCLUDEPATH += $$(TBBROOT)/include
win32 {
  contains(QMAKE_TARGET.arch, x86_64) {
    Release:LIBPATH += $$(TBBROOT)/build/windows_intel64_cl_vc12_release
    Debug:LIBPATH += $$(TBBROOT)/build/windows_intel64_cl_vc12_debug
  }
  else {
    Release:LIBPATH += $$(TBBROOT)/build/windows_ia32_cl_vc12_release
    Debug:LIBPATH += $$(TBBROOT)/build/windows_ia32_cl_vc12_debug
  }
}

# QMAKE_CXXFLAGS_RELEASE += -ffast-math

SOURCES += main.cpp\
    mandelbrotview.cpp

HEADERS  += mandelbrotview.h
