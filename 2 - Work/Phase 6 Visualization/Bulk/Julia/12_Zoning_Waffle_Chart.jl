# Purpose: Generate "The Preservation Paradox" Waffle Chart
# Concept: Visualizes the zoning breakdown of the 6,066 acres of Oahu golf land.

using CairoMakie
using Printf

# === 1. BARE BONES DATA ===
# Total squares = 100 (representing 100% of 6,066 acres)
n_preservation = 82  # Dark Green (81.7% rounded)
n_agriculture  = 14  # Brown (13.8% rounded)
n_other        = 4   # Gray/Blue (4.5% rounded)

total_squares = n_preservation + n_agriculture + n_other
@assert total_squares == 100 "Squares must sum to 100 for a Waffle Chart"

# Create a sequence of colors based on the counts
categories = vcat(
    fill("Preservation/Federal (\$21.8B · 81.7%)", n_preservation),
    fill("Agriculture (\$3.7B · 13.8%)", n_agriculture),
    fill("Resort/Residential/Other (\$1.2B · 4.5%)", n_other)
)

color_map = Dict(
    "Preservation/Federal (\$21.8B · 81.7%)" => :forestgreen,
    "Agriculture (\$3.7B · 13.8%)"            => :saddlebrown,
    "Resort/Residential/Other (\$1.2B · 4.5%)" => :slategray
)

colors = [color_map[cat] for cat in categories]

# === 2. CREATE WAFFLE CHART PLOT ===

fig = Figure(size = (950, 700), backgroundcolor = :white)

# Remove standard axes for a clean waffle chart
ax = Axis(fig[1, 1],
    title = "The Preservation Paradox\nZoning of Oahu Golf Land (6,066 Acres)  ·  Grand Mean OC: \$26.67B",
    titlesize = 24,
    aspect = DataAspect()
)

hidedecorations!(ax)
hidespines!(ax)

# Generate grid coordinates (10x10)
# Filling bottom to top, then left to right
for i in 1:100
    col = cld(i, 10)
    row = (i - 1) % 10 + 1
    
    # Draw a rectangle for each square
    # We use a 0.9 x 0.9 rectangle centered at (col, row)
    poly!(ax, Rect2f(col - 0.45, row - 0.45, 0.9, 0.9), color = colors[i], strokecolor = :white, strokewidth = 1)
end

# Add a text annotation pointing out the friction
text!(ax, 5.5, 5.5,
    text = "81.7% of land is legally\nfrozen in preservation",
    align = (:center, :center),
    color = :white,
    fontsize = 20,
    font = :bold
)

# Add custom legend
elements = [
    PolyElement(color = :forestgreen, strokecolor = :transparent),
    PolyElement(color = :saddlebrown, strokecolor = :transparent),
    PolyElement(color = :slategray, strokecolor = :transparent)
]
labels = [
    "Preservation/Federal (\$21.8B · 81.7%)",
    "Agriculture (\$3.7B · 13.8%)",
    "Resort/Residential/Other (\$1.2B · 4.5%)"
]

Legend(fig[1, 2], elements, labels,
    orientation = :vertical,
    framevisible = false,
    labelsize = 16
)

# Set limits so the chart fits well
xlims!(ax, 0, 11)
ylims!(ax, 0, 11)

# Define output path
SCRIPT_DIR = @__DIR__
OUTPUT_DIR = joinpath(SCRIPT_DIR, "output")
mkpath(OUTPUT_DIR) # Ensure output directory exists

output_path = joinpath(OUTPUT_DIR, "12_Zoning_Waffle_Chart.png")

# Save the plot
save(output_path, fig)
println("Successfully generated Waffle Chart at: ", output_path)
