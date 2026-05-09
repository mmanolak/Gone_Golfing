# Purpose: Generate "The Preservation Paradox" Waffle Chart
# Concept: Visualizes the zoning breakdown of the 6,066 acres of Oahu golf land.

using CairoMakie
using Printf

# === 1. BARE BONES DATA ===
# Total squares = 100 (representing 100% of 6,066 acres)
n_preservation = 82  # Dark Green (81.7% rounded)
n_agriculture  = 10  # Brown
n_other        = 8   # Gray/Blue

total_squares = n_preservation + n_agriculture + n_other
@assert total_squares == 100 "Squares must sum to 100 for a Waffle Chart"

# Create a sequence of colors based on the counts
categories = vcat(
    fill("Preservation/Federal (82%)", n_preservation),
    fill("Agriculture (10%)", n_agriculture),
    fill("Resort/Residential/Other (8%)", n_other)
)

color_map = Dict(
    "Preservation/Federal (82%)" => :forestgreen,
    "Agriculture (10%)" => :saddlebrown,
    "Resort/Residential/Other (8%)" => :slategray
)

colors = [color_map[cat] for cat in categories]

# === 2. CREATE WAFFLE CHART PLOT ===

fig = Figure(size = (800, 750), backgroundcolor = :white)

# Remove standard axes for a clean waffle chart
ax = Axis(fig[1, 1],
    title = "The Preservation Paradox\nZoning of Oahu Golf Land (6,066 Acres)",
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
    text = "82% of land is legally\nfrozen in preservation",
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
labels = ["Preservation/Federal (82%)", "Agriculture (10%)", "Resort/Residential/Other (8%)"]

Legend(fig[2, 1], elements, labels, 
    orientation = :horizontal,
    framevisible = false,
    labelsize = 16,
    halign = :center
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
