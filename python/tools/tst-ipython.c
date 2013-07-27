#include <Python.h>
#include <stdio.h>

#include "traceback.c"

int main() {
        Py_InitializeEx(0) ;
		PyObject *sys = PyImport_ImportModule("sys");
		PyObject *o = Py_BuildValue("[s]", "python");
		PyModule_AddObject(sys, "argv", o);
        if (PyImport_ImportModule("IPython")==NULL){
		printf("NULL\n");
		formatPythonError();
	}
    	return 0 ;
}
