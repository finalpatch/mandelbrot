#-------------------------------------------------
#
# Project created by QtCreator 2012-03-01T12:19:08
#
#-------------------------------------------------

QT       += core gui widgets concurrent

greaterThan(QT_MAJOR_VERSION, 4): QT += widgets

TARGET = cppmandel
TEMPLATE = app

# QMAKE_CXXFLAGS_RELEASE += -ffast-math

SOURCES += main.cpp\
    mandelbrotview.cpp

HEADERS  += mandelbrotview.h
