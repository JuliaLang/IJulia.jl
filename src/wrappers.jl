# Module-import wrappers that add our display hooks to types with graphical
# representation.  These should eventually be moved into the modules
# themselves, especially once DataDisplay is merged into Base.

module IPylab

using PyCall
import PyCall: PyObject
import Base: convert
import DataDisplay: write_png, write_svg
export PylabFigure, plt, PyObject, convert, write_png, write_svg

plt = pywrap(pyimport("pylab"))

type PylabFigure
    o::PyObject
end

PyObject(f::PylabFigure) = f.o
convert(::Type{PylabFigure}, o::PyObject) = PylabFigure(o)

pytype_mapping(plt.pymember("Figure"), PylabFigure)

write_png(io::IO, f::PylabFigure) = f.o["canvas"][:print_figure](io, format="png")
write_svg(io::IO, f::PylabFigure) = f.o["canvas"][:print_figure](io, format="svg")

end
