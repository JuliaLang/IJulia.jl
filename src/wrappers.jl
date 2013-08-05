# Module-import wrappers that add our display hooks to types with graphical
# representation.  These should eventually be moved into the modules
# themselves, especially once Multimedia is merged into Base.

module PyPlot

using PyCall
import PyCall: PyObject
import Base: convert, isequal, hash
using Multimedia
import Multimedia: writemime
export PyPlotFigure, plt

pyimport("matplotlib")[:use]("Agg") # make sure no GUI windows pop up
const pltm = pyimport("matplotlib.pyplot")

type PyPlotFigure
    o::PyObject
end

PyObject(f::PyPlotFigure) = f.o
convert(::Type{PyPlotFigure}, o::PyObject) = PyPlotFigure(o)
isequal(f::PyPlotFigure, g::PyPlotFigure) = isequal(f.o, g.o)
hash(f::PyPlotFigure) = hash(f.o)

pytype_mapping(pltm["Figure"], PyPlotFigure)

writemime(io::IO, ::@MIME("image/png"), f::PyPlotFigure) =
    f.o["canvas"][:print_figure](io, format="png", bbox_inches="tight")
writemime(io::IO, ::@MIME("image/svg+xml"), f::PyPlotFigure) =
    f.o["canvas"][:print_figure](io, format="svg", bbox_inches="tight")

# monkey-patch pylab to call redisplay after each drawing command (which
# calls draw_if_interactive)

const Gcf = pyimport("matplotlib._pylab_helpers")["Gcf"]

function draw_if_interactive()
    if pltm[:isinteractive]()
        manager = Gcf[:get_active]()
        if manager != nothing
            fig = PyPlotFigure(manager["canvas"]["figure"])
            redisplay(fig)
        end
    end
end

function showfig()
    for manager in Gcf[:get_all_fig_managers]()
        display(PyPlotFigure(manager["canvas"]["figure"]))
    end
    pltm[:close]("all")
    return nothing
end

pltm["draw_if_interactive"] = draw_if_interactive
pltm["show"] = showfig

const plt = pywrap(pltm)
plt.ion()

end # module PyPlot
