# Troubleshooting


## General troubleshooting tips

* If you ran into a problem with the above steps, after fixing the
problem you can type `Pkg.build()` to try to rerun the install scripts.
* If you tried it a while ago, try running `Pkg.update()` and try again:
  this will fetch the latest versions of the Julia packages in case
  the problem you saw was fixed.  Run `Pkg.build("IJulia")` if your Julia version may have changed.  If this doesn't work, you could try just deleting the whole `.julia` directory in your home directory (on Windows, it is called `Users\USERNAME\.julia` in your home directory) via `rm(Pkg.dir(),recursive=true)` in Julia and re-adding the packages.
* On MacOS, you currently need MacOS 10.7 or later; [MacOS 10.6 doesn't work](https://github.com/JuliaLang/julia/issues/4215) (unless you compile Julia yourself, from source code).
* Internet Explorer 8 (the default in Windows 7) or 9 don't work with the notebook; use Firefox (6 or later) or Chrome (13 or later).  Internet Explorer 10 in Windows 8 works (albeit with a few rendering glitches), but Chrome or Firefox is better.
* If the notebook opens up, but doesn't respond (the input label is `In[*]` indefinitely), try creating a new Python notebook (not Julia) from the `New` button in the Jupyter dashboard, to see if `1+1` works in Python.  If it is the same problem, then probably you have a [firewall running](https://github.com/ipython/ipython/issues/2499) on your machine (this is common on Windows) and you need to disable the firewall or at least to allow the IP address 127.0.0.1.  (For the [Sophos](https://en.wikipedia.org/wiki/Sophos) endpoint security software, go to "Configure Anti-Virus and HIPS", select "Authorization" and then "Websites", and add 127.0.0.1 to "Authorized websites"; finally, restart your computer.)
* Try running `jupyter --version` and make sure that it prints `3.0.0` or larger; earlier versions of IPython are no longer supported by IJulia.
* You can try setting `ENV["JUPYTER"]=""; Pkg.build("IJulia")` to force IJulia to go back to its own Conda-based Jupyter version (if you previously tried a different `jupyter`).


## Debugging IJulia problems

If IJulia is crashing (e.g. it gives you a "kernel appears to have
died" message), you can modify it to print more descriptive error
messages to the terminal by doing:

```jl
ENV["IJULIA_DEBUG"]=true
Pkg.build("IJulia")
```

Restart the notebook and look for the error message when IJulia dies.
(This changes IJulia to default to `verbose = true` mode, and sets
`capture_stderr = false`, hopefully sending a bunch of debugging to
the terminal where you launched `jupyter`).

When you are done, set `ENV["IJULIA_DEBUG"]=false` and re-run
`Pkg.build("IJulia")` to turn off the debugging output.
