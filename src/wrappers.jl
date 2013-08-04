# Module-import wrappers that add our display hooks to types with graphical
# representation.  These should eventually be moved into the modules
# themselves, especially once Multimedia is merged into Base.

module IPylab

using PyCall
import PyCall: PyObject
import Base: convert, isequal, hash
using Multimedia
import Multimedia: mm_write
export PylabFigure, plt

plt = pywrap(pyimport("pylab"))

type PylabFigure
    o::PyObject
end

PyObject(f::PylabFigure) = f.o
convert(::Type{PylabFigure}, o::PyObject) = PylabFigure(o)
isequal(f::PylabFigure, g::PylabFigure) = isequal(f.o, g.o)
hash(f::PylabFigure) = hash(f.o)

pytype_mapping(plt.pymember("Figure"), PylabFigure)

mm_write(io::IO, ::@MIME("image/png"), f::PylabFigure) = f.o["canvas"][:print_figure](io, format="png", bbox_inches="tight")
mm_write(io::IO, ::@MIME("image/svg+xml"), f::PylabFigure) = f.o["canvas"][:print_figure](io, format="svg", bbox_inches="tight")

end
