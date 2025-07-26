const sha_ctx = Ref{SHA.SHA_CTX}()
const hmac_key = Ref{Vector{UInt8}}()

function hmac(s1, s2, s3, s4)
    if !isassigned(sha_ctx)
        return ""
    else
        hmac = SHA.HMAC_CTX(copy(sha_ctx[]), hmac_key[])
        for s in (s1, s2, s3, s4)
            SHA.update!(hmac, codeunits(s))
        end

        digest = SHA.digest!(hmac)
        return bytes2hex(digest)
    end
end
