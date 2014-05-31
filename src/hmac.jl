
function hmac(hmacstate,s1,s2,s3,s4)
    update!(hmacstate, s1)
    update!(hmacstate, s2)
    update!(hmacstate, s3)
    update!(hmacstate, s4)
    hexdigest!(hmacstate)
end
