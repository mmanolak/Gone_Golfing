# Purpose: Generate the "Urban/Rural Bifurcation Scatter" Plot
# Concept: A log-log scatter plot showing the universe of data and the distinct economic stratospheres of Urban vs. Rural courses.

using CairoMakie
using Printf
using Random

# === 1. BARE BONES SYNTHETIC DATA ===
# Mocking a sample of the 16,297 courses (e.g. 1000 courses for visual clarity)
Random.seed!(42)

n_urban = 700
n_rural = 300

# Acreage: Golf courses are roughly similar in size, mostly clustering between 100 and 200 acres
acreage_urban = randn(n_urban) .* 30 .+ 150
acreage_urban .= max.(50.0, acreage_urban) # bound minimum size

acreage_rural = randn(n_rural) .* 40 .+ 160
acreage_rural .= max.(50.0, acreage_rural)

# Baseline Value Per Acre:
# Urban courses are in high-value real estate markets (e.g., $100k - $2M per acre)
value_per_acre_urban = exp.(randn(n_urban) .* 0.8 .+ 13.0) 

# Rural courses are in low-value agricultural/rural markets (e.g., $2k - $30k per acre)
value_per_acre_rural = exp.(randn(n_rural) .* 0.6 .+ 9.0)

# Calculate Log10
log_acreage_urban = log10.(acreage_urban)
log_value_urban = log10.(value_per_acre_urban)

log_acreage_rural = log10.(acreage_rural)
log_value_rural = log10.(value_per_acre_rural)

# === 2. CREATE SCATTER PLOT ===

fig = Figure(size = (900, 700), backgroundcolor = :white)

ax = Axis(fig[1, 1],
    title = "The Urban vs. Rural Bifurcation\n(Log-Log Baseline Value Distribution)",
    xlabel = "Log10(Acreage)",
    ylabel = "Log10(Baseline Value Per Acre)",
    xgridcolor = :gray90,
    ygridcolor = :gray90,
    titlesize = 20,
    xlabelsize = 16,
    ylabelsize = 16
)

# Scatter plot for Rural courses (Green)
scatter!(ax, log_acreage_rural, log_value_rural, 
    color = (:forestgreen, 0.6), 
    markersize = 10, 
    strokewidth = 0.5, strokecolor = :white,
    label = "Rural (RUCC 4-9)"
)

# Scatter plot for Urban courses (Blue)
scatter!(ax, log_acreage_urban, log_value_urban, 
    color = (:dodgerblue, 0.6), 
    markersize = 10, 
    strokewidth = 0.5, strokecolor = :white,
    label = "Urban (RUCC 1-3)"
)

# Optional: Add faint ellipses or bounding boxes to emphasize the "clouds"
# A simple way to emphasize without complex math is text annotations pointing to the clusters
text!(ax, 2.2, 5.8, text = "Urban Stratosphere\n(High Opportunity Cost)", align = (:center, :bottom), color = :dodgerblue, font = :bold, fontsize = 16)
text!(ax, 2.2, 3.8, text = "Rural Stratosphere\n(Low Opportunity Cost)", align = (:center, :bottom), color = :forestgreen, font = :bold, fontsize = 16)

# Add Legend
axislegend(ax, position = :rb, framevisible = true, labelsize = 14)

# Define output path
SCRIPT_DIR = @__DIR__
OUTPUT_DIR = joinpath(SCRIPT_DIR, "output")
mkpath(OUTPUT_DIR) # Ensure output directory exists

output_path = joinpath(OUTPUT_DIR, "14_Urban_Rural_Scatter.png")

# Save the plot
save(output_path, fig)
println("Successfully generated Urban/Rural Scatter plot at: ", output_path)
