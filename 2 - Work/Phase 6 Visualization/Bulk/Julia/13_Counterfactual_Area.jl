# Purpose: Generate "The Counterfactual Area Comparison"
# Concept: Visualizes the physical land footprint of U.S. Golf compared to solar energy and housing.

using CairoMakie
using Printf

# === 1. BARE BONES DATA ===
# Areas in acres
area_golf = 2_300_000.0
# Estimate for utility-scale solar to power a large chunk of the U.S.
area_solar = 5_000_000.0
# Estimate for 1 million high-density housing units (at ~20 units per acre)
area_housing = 50_000.0

# Side lengths for squares (Area = side^2)
side_golf = sqrt(area_golf)
side_solar = sqrt(area_solar)
side_housing = sqrt(area_housing)

# === 2. CREATE SQUARE COMPARISON PLOT ===

fig = Figure(size = (1000, 600), backgroundcolor = :white)
ax = Axis(fig[1, 1],
    title = "The Physical Footprint of U.S. Golf Courses vs. Competing Land Uses",
    titlesize = 22,
    aspect = DataAspect()
)
hidedecorations!(ax)
hidespines!(ax)

# Position parameters
gap = 250.0 # gap between squares

# X positions for bottom-left corners
x_solar = 0.0
x_golf = side_solar + gap
x_housing = x_golf + side_golf + gap

# Draw squares using poly!
poly!(ax, Rect2f(x_solar, 0.0, side_solar, side_solar), color = :gold)
poly!(ax, Rect2f(x_golf, 0.0, side_golf, side_golf), color = :forestgreen)
poly!(ax, Rect2f(x_housing, 0.0, side_housing, side_housing), color = :slategray)

# Annotations (Titles)
text!(ax, x_solar + side_solar/2, side_solar + 100, text = "Utility-Scale Solar\n(5.0M Acres)", align = (:center, :bottom), fontsize = 18, font = :bold)
text!(ax, x_golf + side_golf/2, side_golf + 100, text = "U.S. Golf Courses\n(2.3M Acres)", align = (:center, :bottom), fontsize = 18, font = :bold)
text!(ax, x_housing + side_housing/2, side_housing + 100, text = "1 Million High-Density\nHomes (50k Acres)", align = (:center, :bottom), fontsize = 18, font = :bold)

# Add smaller text inside the larger squares
text!(ax, x_solar + side_solar/2, side_solar/2, text = "Theoretical Area to Power\nSignificant U.S. Demand", align = (:center, :center), color = :black, fontsize = 16)
text!(ax, x_golf + side_golf/2, side_golf/2, text = "Existing Institutional\nFriction", align = (:center, :center), color = :white, fontsize = 16)

# Set limits
xlims!(ax, -100, x_housing + side_housing + 500)
ylims!(ax, -50, side_solar + 500)

# Define output path
SCRIPT_DIR = @__DIR__
OUTPUT_DIR = joinpath(SCRIPT_DIR, "output")
mkpath(OUTPUT_DIR) # Ensure output directory exists

output_path = joinpath(OUTPUT_DIR, "13_Counterfactual_Area.png")

# Save the plot
save(output_path, fig)
println("Successfully generated Counterfactual Area plot at: ", output_path)
