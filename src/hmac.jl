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
        digest = MbedTLS.finish!(hmacstate[])
        hexdigest = Vector{UInt8}(undef, length(digest)*2)
        for i = 1:length(digest)
            b = digest[i]
            d = b >> 4
            hexdigest[2i-1] = UInt8('0')+d+39*(d>9)
            d = b & 0xf
            hexdigest[2i] = UInt8('0')+d+39*(d>9)
        end
        return String(hexdigest)
    end
end
