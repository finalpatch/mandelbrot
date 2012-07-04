#-------------------------------------------------
#
# Project created by QtCreator 2012-03-01T12:19:08
#
#-------------------------------------------------

QT       += core gui

TARGET = cppmandel
TEMPLATE = app

INCLUDEPATH += $$(TBBROOT)/include
LIBS += -L$$(TBBROOT)/build/windows_ia32_gcc_mingw_release -ltbb

QMAKE_CXXFLAGS_RELEASE += -ffast-math

SOURCES += main.cpp\
    mandelbrotview.cpp

HEADERS  += mandelbrotview.h
