local fontFiles = {
    "Roboto-Regular.ttf",
    "Roboto-Black.ttf",
    "Roboto-Bold.ttf",
}

for _, fontFile in ipairs(fontFiles) do
    resource.AddFile("materials/fonts/" .. fontFile)
end
