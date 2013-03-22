/* print traceback from C, from
   http://www.gossamer-threads.com/lists/python/python/150924
*/

void formatPythonError()
{
	 
	 PyObject *pName, *pModule, *pDict, *pFunc;
	 PyObject *pArgs, *pValue;
	 PyObject *err = PyErr_Occurred();
	 char tb_string[1024];
	 if(err)
	 {
		  PyObject *temp, *exc_typ, *exc_val, *exc_tb;
		  
		  
		  PyErr_Fetch(&exc_typ,&exc_val,&exc_tb);
		  PyErr_NormalizeException(&exc_typ,&exc_val,&exc_tb);
		  
		  pName = PyString_FromString("traceback");
		  pModule = PyImport_Import(pName);
		  Py_DECREF(pName);
		  
		  temp = PyObject_Str(exc_typ);
		  if (temp != NULL)
		  {
			   printf("%s\n", PyString_AsString(temp));
		  }
		  temp = PyObject_Str(exc_val);
		  if (temp != NULL){
			   printf("%s\n", PyString_AsString(temp));
		  }
		  Py_DECREF(temp);
		  
		  if (exc_tb != NULL && pModule != NULL )
		  {
			   pDict = PyModule_GetDict(pModule);
			   pFunc = PyDict_GetItemString(pDict, "format_tb");
			   if (pFunc && PyCallable_Check(pFunc))
			   {
					pArgs = PyTuple_New(1);
					pArgs = PyTuple_New(1);
					PyTuple_SetItem(pArgs, 0, exc_tb);
					pValue = PyObject_CallObject(pFunc, pArgs);
					if (pValue != NULL)
					{
						 int len = PyList_Size(pValue);
						 if (len > 0) {
							  PyObject *t,*tt;
							  int i;
							  char *buffer;
							  for (i = 0; i < len;
								   i++) {
								   tt =
										PyList_GetItem(pValue,i);
								   t =
										Py_BuildValue("(O)",tt);
								   if
										(!PyArg_ParseTuple(t,"s",&buffer)){
										
										return;
								   }
								   
								   strcpy(tb_string,buffer);
								   printf("%s\n", tb_string);
							  }
						 }
					}
					Py_DECREF(pValue);
					Py_DECREF(pArgs);
			   }
		  }
		  Py_DECREF(pModule);
		  
		  PyErr_Restore(exc_typ, exc_val, exc_tb);
		  PyErr_Print();
		  return;
	 }
} 
