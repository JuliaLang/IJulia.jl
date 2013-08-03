# Module-import wrappers that add our display hooks to types with graphical
# representation.  These should eventually be moved into the modules
# themselves, especially once MIMEDisplay is merged into Base.

module IPylab

using PyCall
import PyCall: PyObject
import Base: convert
using MIMEDisplay
import MIMEDisplay: mime_write
export PylabFigure, plt, PyObject, convert, mime_write

plt = pywrap(pyimport("pylab"))

type PylabFigure
    o::PyObject
end

PyObject(f::PylabFigure) = f.o
convert(::Type{PylabFigure}, o::PyObject) = PylabFigure(o)

pytype_mapping(plt.pymember("Figure"), PylabFigure)

mime_write(io::IO, ::@MIME("image/png"), f::PylabFigure) = f.o["canvas"][:print_figure](io, format="png", bbox_inches="tight")
mime_write(io::IO, ::@MIME("image/svg+xml"), f::PylabFigure) = f.o["canvas"][:print_figure](io, format="svg", bbox_inches="tight")

end
