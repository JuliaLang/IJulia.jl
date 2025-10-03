function hmac(s1, s2, s3, s4, kernel)
    if !isassigned(kernel.sha_ctx)
        return ""
    else
        hmac = SHA.HMAC_CTX(copy(kernel.sha_ctx[]), kernel.hmac_key)
        for s in (s1, s2, s3, s4)
            GC.@preserve s SHA.update!(hmac, unsafe_wrap(Vector{UInt8}, s))
        end

        digest = SHA.digest!(hmac)
        return bytes2hex(digest)
    end
end
