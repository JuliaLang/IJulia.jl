using Nettle
const hmacstate = HMACState[]
function hmac(s1,s2,s3,s4)
    if isempty(hmacstate)
        return ""
    else
        update!(hmacstate[1], s1)
        update!(hmacstate[1], s2)
        update!(hmacstate[1], s3)
        update!(hmacstate[1], s4)
        return hexdigest!(hmacstate[1])
    end
end
