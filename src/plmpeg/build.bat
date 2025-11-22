call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
cl /c /O2 pl_mpeg.c
lib pl_mpeg.obj /OUT:pl_mpeg.lib
del pl_mpeg.obj
