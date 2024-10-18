local countryIndices = {}

local function generateCountryIndices(StationData)
    local countries = {}
    for country, _ in pairs(StationData) do
        table.insert(countries, country)
    end
    
    table.sort(countries)
    
    for index, country in ipairs(countries) do
        countryIndices[country] = index
    end
end

-- This function should be called after StationData is fully loaded
local function initializeCountryIndices(StationData)
    if next(countryIndices) == nil then
        generateCountryIndices(StationData)
    end
end

return {
    countryIndices = countryIndices,
    initializeCountryIndices = initializeCountryIndices
}
