#include <Python.h>
#include <stdio.h>

int main() {
        Py_InitializeEx(0) ;
        if (PyImport_ImportModule("IPython")==NULL){
		printf("NULL\n");
	}
    	return 0 ;
}
