# Purpose: Generate the "Zoning Tax" Dumbbell Plot (The Hawaii Gap)
# Concept: Visualizes the 1.33x gap between the HBU model and official tax assessments for 6 pilot courses in Hawaii.

using DataFrames
using CairoMakie
using Printf

# === 1. BARE BONES DATA ===
# Mock data for the 6 pilot courses (representing Phase 5a)
# Incorporating the roughly 1.33x gap between Assessed Value and HBU Value
courses_data = DataFrame(
    Course = ["Waialae", "Turtle Bay", "Kapalua", "Mauna Kea", "Princeville", "Ko Olina"],
    Assessed_Value_M = [150.0, 120.0, 95.0, 110.0, 85.0, 140.0]
)

# Apply the ~1.33x multiplier to get the HBU Model Value
courses_data.HBU_Value_M = courses_data.Assessed_Value_M .* 1.33

# Sort by Assessed Value for a cleaner plot
sort!(courses_data, :Assessed_Value_M)

# === 2. CREATE DUMBBELL PLOT ===

fig = Figure(size = (1000, 600), backgroundcolor = :white)

# Axis setup
ax = Axis(fig[1, 1],
    title = "The Hawaii Gap: Model HBU vs. Official Tax Assessment",
    xlabel = "Estimated Value (Millions USD)",
    ylabel = "Golf Course",
    yticks = (1:nrow(courses_data), courses_data.Course),
    xgridcolor = :gray90,
    ygridvisible = false,
    titlesize = 24,
    xlabelsize = 16,
    ylabelsize = 16
)

# Y-positions for each course
y_positions = 1:nrow(courses_data)

# Draw the connecting lines (The Zoning Tax / Deadweight Loss)
xs = Float64[]
ys = Float64[]
for i in 1:nrow(courses_data)
    push!(xs, courses_data.Assessed_Value_M[i], courses_data.HBU_Value_M[i])
    push!(ys, y_positions[i], y_positions[i])
end
linesegments!(ax, xs, ys, color = :gray70, linewidth = 4)

# Scatter plot for Dot 1 (Gray): Official Assessed Value
scatter!(ax, courses_data.Assessed_Value_M, y_positions,
         color = :gray50, markersize = 18, label = "Official Assessed Value (Current Legally Restricted)")

# Scatter plot for Dot 2 (Blue/Gold): Model HBU Value
# Using a gold-ish/blue-ish theme color
scatter!(ax, courses_data.HBU_Value_M, y_positions,
         color = :dodgerblue, markersize = 18, label = "Model HBU Value (Unrestricted Coasian)")

# Add annotations to label the gap directly on the plot (for the top entry as an example)
top_idx = nrow(courses_data)
text!(ax, 
    (courses_data.Assessed_Value_M[top_idx] + courses_data.HBU_Value_M[top_idx]) / 2, 
    y_positions[top_idx] + 0.25, 
    text = "The Zoning Tax / Deadweight Loss", 
    align = (:center, :bottom), 
    color = :darkred,
    fontsize = 14,
    font = :bold
)

# Add Legend
axislegend(ax, position = :rb, framevisible = true)

# Define output path
SCRIPT_DIR = @__DIR__
OUTPUT_DIR = joinpath(SCRIPT_DIR, "output")
mkpath(OUTPUT_DIR) # Ensure output directory exists

output_path = joinpath(OUTPUT_DIR, "10_Hawaii_Gap_Dumbbell.png")

# Save the plot
save(output_path, fig)
println("Successfully generated dumbbell plot at: ", output_path)

# fig # Return the figure object if running in REPL
