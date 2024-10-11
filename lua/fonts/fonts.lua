local fontFiles = {
    "SFProDisplay-Regular.otf",
    "SFProDisplay-Bold.otf",
}

for _, fontFile in ipairs(fontFiles) do
    resource.AddFile("materials/fonts/" .. fontFile)
end
