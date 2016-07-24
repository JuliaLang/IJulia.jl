using Base.Test
using Compat
import IJulia: Msg

idents = ["idents"]
header = @compat Dict("msg_id"=>"c673eed8-7c36-47f4-82af-df8ec546a87d",
              "msg_type"=>"comm_msg",
              "username"=>"username",
              "version"=>"5.0",
              "session"=>"980FF7B5F8A24ECF9876A91F38F4EC09")
content = @compat Dict("comm_id"=>"d733be5d-fd21-4194-95da-db364346f2c9",
               "data"=>Dict(:value=>Dict("text/plain"=>"10")))
msg = Msg(idents, header, content)

@test 1 == length(msg.idents)
@test "c673eed8-7c36-47f4-82af-df8ec546a87d" == msg.header["msg_id"]
