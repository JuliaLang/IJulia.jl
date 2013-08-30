using Nettle

if isempty(profile["key"])
    hmac(s1,s2,s3,s4) = ""
else
    signature_scheme = get(profile, "signature_scheme", "hmac-sha256")
    isempty(signature_scheme) && (signature_scheme = "hmac-sha256")
    signature_scheme = split(signature_scheme, "-")
    if signature_scheme[1] != "hmac" || length(signature_scheme) != 2
        error("unrecognized signature_scheme")
    end
    const hmacstate = HMACState(eval(symbol(uppercase(signature_scheme[2]))),
                                profile["key"])
    function hmac(s1,s2,s3,s4)
        update!(hmacstate, s1)
        update!(hmacstate, s2)
        update!(hmacstate, s3)
        update!(hmacstate, s4)
        hexdigest!(hmacstate)
    end

end
