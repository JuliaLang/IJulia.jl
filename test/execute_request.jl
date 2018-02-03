using Compat.Test

import IJulia: helpcode, error_content, docdict

content = error_content(UndefVarError(:a))
@test "UndefVarError" == content["ename"]

@test haskey(docdict("import"), "text/plain")
@test haskey(docdict("sum"), "text/plain")
