APP = dcmandel

$(APP): dcmandel.fs
	fsc --optimize+ -r SharpDX.dll -r SharpDX.DXGI.dll -r SharpDX.Direct3D11.dll -r SharpDX.D3DCompiler.dll \
	dcmandel.fs

all: $(APP)

clean:
	rm -f *.exe

rebuild : clean all
