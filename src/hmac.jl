using MbedTLS
const hmacstate = Ref{MbedTLS.MD{true}}()

function hmac(s1,s2,s3,s4)
    if !isdefined(hmacstate, :x)
        return ""
    else
        MbedTLS.reset!(hmacstate[])
        for s in (s1, s2, s3, s4)
            write(hmacstate[], s)
        end
        # Take the digest (returned as a byte array) and convert it to hex string representation
        return join([hex(_, 2) for _ in MbedTLS.finish!(hmacstate[])])
    end
end
