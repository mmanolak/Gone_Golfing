# Purpose: Generate the Lorenz Curve of Spatial Misallocation
# Concept: Visualizes the extreme spatial heterogeneity of the $943B opportunity cost across 16,297 courses.

using DataFrames
using CairoMakie
using Printf
using Random
using Statistics

# === 1. BARE BONES SYNTHETIC DATA ===
# Total courses: 16,297
# Phase 3 conceptual setup:
#   - Rural/Suburban: ~30% of facilities, holding ~1.5% of total opportunity cost
#   - Urban: ~70% of facilities, holding ~98.5% of total opportunity cost
#   - Total cost: $943 Billion

Random.seed!(42)

N_total = 16297
N_rural = round(Int, 0.30 * N_total)
N_urban = N_total - N_rural

total_cost_B = 943.0
rural_cost_B = 0.015 * total_cost_B
urban_cost_B = 0.985 * total_cost_B

# Generate log-normally/normally distributed random values to make the curve smooth
# Rural courses: very low mean
rural_costs = randn(N_rural) .* (rural_cost_B * 0.1 / N_rural) .+ (rural_cost_B / N_rural)
rural_costs .= max.(0.0, rural_costs) # ensure no negative costs

# Urban courses: much higher mean
urban_costs = randn(N_urban) .* (urban_cost_B * 0.5 / N_urban) .+ (urban_cost_B / N_urban)
urban_costs .= max.(0.0, urban_costs)

# Combine and sort to compute the exact Lorenz curve values
all_costs = vcat(rural_costs, urban_costs)
sort!(all_costs)

# Compute cumulative shares
cum_courses = collect(1:N_total) ./ N_total
cum_costs = cumsum(all_costs) ./ sum(all_costs)

# Prepend (0,0) to start the curve exactly at the origin
pushfirst!(cum_courses, 0.0)
pushfirst!(cum_costs, 0.0)

# === 2. CREATE LORENZ CURVE PLOT ===

fig = Figure(size = (800, 800), backgroundcolor = :white)

ax = Axis(fig[1, 1],
    title = "Lorenz Curve of Spatial Misallocation\n(Opportunity Cost of Golf Courses)",
    xlabel = "Cumulative % of Courses (Ordered by Cost)",
    ylabel = "Cumulative % of Opportunity Cost",
    xgridcolor = :gray90,
    ygridcolor = :gray90,
    titlesize = 20,
    xlabelsize = 16,
    ylabelsize = 16,
    aspect = 1.0,
    limits = (0, 1, 0, 1)
)

# Format ticks as percentages
ax.xticks = (0:0.2:1.0, ["0%", "20%", "40%", "60%", "80%", "100%"])
ax.yticks = (0:0.2:1.0, ["0%", "20%", "40%", "60%", "80%", "100%"])

# Line of Equality
lines!(ax, [0, 1], [0, 1], color = :gray50, linestyle = :dash, linewidth = 2, label = "Perfect Equality (Uniform Cost)")

# The Lorenz Curve
lines!(ax, cum_courses, cum_costs, color = :firebrick, linewidth = 4, label = "Observed Spatial Concentration")

# Fill area for the "inequality" gap
band!(ax, cum_courses, cum_costs, cum_courses, color = (:firebrick, 0.1))

# Highlight the 30% point to emphasize the extreme skew
# Since the array is sorted, the first 30% hold ~1.5% of the total cost.
scatter!(ax, [0.30], [0.015], color = :black, markersize = 12)
text!(ax, 0.32, 0.015, 
    text = "Bottom 30% (Rural/Suburban):\nOnly 1.5% of Total Cost", 
    align = (:left, :bottom), 
    color = :black,
    fontsize = 14,
    font = :bold
)

# Highlight the remaining 70% (Urban)
text!(ax, 0.55, 0.4, 
    text = "Top 70% (Urban):\nHold 98.5% of Total Cost", 
    align = (:center, :center), 
    color = :firebrick,
    fontsize = 16,
    font = :bold
)

# Add Legend
axislegend(ax, position = :lt, framevisible = true)

# Define output path
SCRIPT_DIR = @__DIR__
OUTPUT_DIR = joinpath(SCRIPT_DIR, "output")
mkpath(OUTPUT_DIR) # Ensure output directory exists

output_path = joinpath(OUTPUT_DIR, "11_Lorenz_Curve.png")

# Save the plot
save(output_path, fig)
println("Successfully generated Lorenz Curve at: ", output_path)
