rRadio = rRadio or {}
rRadio.generatedPayload = rRadio.generatedPayload or {}

local generatedPayload = rRadio.generatedPayload

local FORMAT = "rradio.generated_payload.v1"
local ENCODING = "base64:gmod-lzma:json"

local function fail( label, message )
    return nil, tostring( label or "generated payload" ) .. ": " .. tostring( message or "unknown error" )
end

function generatedPayload.Decode( record, options )
    options = options or {}
    local label = options.label or "generated payload"

    if type( record ) ~= "table" then
        return fail( label, "wrapper did not return a table" )
    end

    if record.format ~= FORMAT then
        return fail( label, "invalid payload format " .. tostring( record.format ) )
    end

    if record.encoding ~= ENCODING then
        return fail( label, "invalid payload encoding " .. tostring( record.encoding ) )
    end

    if options.kind and record.kind ~= options.kind then
        return fail( label, "invalid payload kind " .. tostring( record.kind ) )
    end

    if type( record.data ) ~= "string" or record.data == "" then
        return fail( label, "missing base64 payload data" )
    end

    local compressed = util.Base64Decode( record.data )
    if type( compressed ) ~= "string" then
        return fail( label, "base64 decode failed" )
    end

    if record.compressedBytes and #compressed ~= tonumber( record.compressedBytes ) then
        return fail( label, "compressed byte count mismatch" )
    end

    local maxBytes = tonumber( options.maxBytes or record.uncompressedBytes )
    local jsonText = util.Decompress( compressed, maxBytes )
    if type( jsonText ) ~= "string" then
        return fail( label, "LZMA decompress failed" )
    end

    if record.uncompressedBytes and #jsonText ~= tonumber( record.uncompressedBytes ) then
        return fail( label, "uncompressed byte count mismatch" )
    end

    if record.sha256 and util.SHA256 and util.SHA256( jsonText ) ~= record.sha256 then
        return fail( label, "SHA256 mismatch" )
    end

    local decoded = util.JSONToTable( jsonText, true )
    if type( decoded ) ~= "table" then
        return fail( label, "JSON decode failed" )
    end

    return decoded
end

function generatedPayload.DecodeOrError( record, options )
    local decoded, err = generatedPayload.Decode( record, options )
    if decoded then return decoded end

    error( "[rRadio] " .. tostring( err ), 2 )
end

return generatedPayload
