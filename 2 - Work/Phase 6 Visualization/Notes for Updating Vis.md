

gifs:
[ ] 2.101 & 2.141
[ ] 5.241, 5.242, 5.243, 5.244, 2.245
[ ] 3.101 Modifiy - Crap Zoom and Arrow on the Joke that is the Mililani and Totally Ewa Golf course that takes up a pixel


R Script:
[X] 1.101 & 1.141 : Updated Notes: Increase caption size, sliding bar updates, Change Color Gradient
[X] 2.101 & 2.141 : Updated Notes: Increase caption size, sliding bar updates, Change Color Gradient
[X] 3.101 : Updated Text Colors and Key Location, changed color to Lehua (Red)
[X] 4.101 : Updated Text color, follows the theme
[X] 7.101 & 7.141 : Legend to under Louisiana, added color theme to text, summary was also made more visible
[X] 9.101 & 9.141 : Adjusted the Caption to theme colors

Follow Ups:
[ ] Investigate Script 9 - Why is Turtle Bay the most valueable property when it should have the lowest valuation. Where as why is Hawaii Kai and Kailua valued at nothing? These two courses should be among the highest values. For Military bases, it makes sense why they are not valued or able to be valued due to missing area data and then being locked to federal land use.



Julia Script:
[ ] 5.141 : Have Better Explanation for the Graph (what is it's purpose)
[ ] 5.241, 5.242, 5.243, 5.244, 2.245 : Create gif of the five images for Slides
[ ] 6.141 : Adjust the Map Scaling for Better Visual Representation
[ ] 6.141 : Fix Text Summary overflowing
[ ] 6.141 : Add National Use context statement
[ ] 6.241 : Increase Summry Text size, make more clearly visible
[ ] 10.141 : Adjust the Summary overflow text, make more visible
[ ] 10.141 : Move Map Key around to give the graph better visiual scaling and representation
[ ] 11.141 : Adjust the Summary overflow text, make more visible
[ ] 11 : Review the JUlia only Lorenz Curve, see if singling it down to single source data produces anything meaningful visually
[ ] 12.141 Waffle Zoning Chart Trilang : Summary text overflowing
[ ] 13.141 Counterfactual Area Tri Lang : Summary Text overflowing
[ ] 14.141 : Adjust the subtext and make more visible
[ ] 14.141 : Make graph more dynamic..?
[ ] 15.141 & 15.241 : Explore what these graphs even really mean..?




R Script Updates:
UHM_GREEN <- "#024731"        #- [Green]
UHM_GOLD <- "#B3995D"      #- [Gold]
UHM_SILVER <- "#B2B2B2"    #- [Silver/Grey]
UHM_BLACK <- "#000000"     #- [Black]
UHM_WHITE <- "#FFFFFF"     #- [White]
OCEAN <- "#00758D"         #- [Darker Cyan]
SKY <- "#00A4E2"           #- [Lighter Blue]
LEHUA <- "#E3002C"         #- [Red]
ILIMA <- "#F2A900"         #- [Dark Yellow]
PUA_KENIKENI <- "#FAD561"  #- [Dark Gold]
KUKUI <- "#D6CBAE"         #- [Beige]
AKALA <- "#E06E8C"         #- [Dark Pink]
MAO <- "#82B53F"           #- [Dark Lime Green]
LAI <- "#00846B"           #- [Royal Green]
NA <- "#bdbdbd"               #- [Dark Grey]



1. Script 1
    build_state_map <- function(states_joined, subtitle, caption_text) {
        ggplot(states_joined) +
            geom_sf(
                aes(fill = pooled_opp_cost / 1e9),
                colour = "white",
                linewidth = 0.25
            ) +
            scale_fill_viridis_c(
                option = "magma",
                na.value = "#d4d4d4",
                name = "Opportunity Cost",
                labels = label_dollar(suffix = "B", accuracy = 1),
                guide = guide_colorbar(
                    barwidth       = unit(21, "cm"),
                    barheight      = unit(0.45, "cm"),
                    title.position = "top",
                    title.hjust    = 0.5,
                    ticks.colour   = "white"
                )
            ) +
            labs(
                title    = "Golf Course Opportunity Cost by State",
                subtitle = subtitle,
                caption  = stringr::str_wrap(caption_text, width = 192)
            ) +
            theme_void(base_size = 12) +
            theme(
                plot.title = element_text(
                    face = "bold", size = 18, hjust = 0.5, margin = margin(b = 5)
                ),
                plot.subtitle = element_text(
                    size = 10, hjust = 0.5, colour = "#024731", margin = margin(b = 0)
                ),
                plot.caption = element_text(
                    size = 10, colour = "#024731", hjust = 0, margin = margin(t = 6), lineheight = 0.9
                ),
                plot.caption.position = "plot",
                legend.position = "bottom",
                legend.title = element_text(size = 14, face = "bold"),
                legend.text = element_text(size = 12),
                plot.margin = margin(12, 24, 8, 24)
            )
    }

2. Script 2 
build_county_map <- function(counties_joined, subtitle, caption_text) {
ggplot(counties_joined) +
        geom_sf(
            aes(fill = pooled_opp_cost / 1e6),
            colour    = "white",
            linewidth = 0.08
        ) +
        scale_fill_viridis_c(
            option   = "magma",
            trans    = "log10",
            na.value = "#8f8f8f",
            name     = "Opportunity Cost",
            breaks   = c(1, 10, 100, 1000, 10000),
            labels   = c("$1M", "$10M", "$100M", "$1B", "$10B"),
            guide    = guide_colorbar(
                barwidth       = unit(21, "cm"),
                barheight      = unit(0.45, "cm"),
                title.position = "top",
                title.hjust    = 0.5,
                ticks.colour   = "white"
            )
        ) +
        labs(
            title    = "Golf Course Opportunity Cost by County",
            subtitle = subtitle,
            caption  = stringr::str_wrap(caption_text, width = 192)
        ) +
        theme_void(base_size = 12) +
        theme(
            plot.title      = element_text(
                face = "bold", size = 18, hjust = 0.5, margin = margin(b = 5)
            ),
            plot.subtitle   = element_text(
                size = 10, hjust = 0.5, colour = "#024731", margin = margin(b = 0)
            ),
            plot.caption    = element_text(
                size = 10, colour = "#024731", hjust = 0, margin = margin(t = 6), lineheight = 0.9
            ),
            plot.caption.position = "plot",
            legend.position = "bottom",
            legend.title    = element_text(size = 14, face = "bold"),
            legend.text     = element_text(size = 12),
            plot.margin     = margin(12, 24, 8, 24)
        )
}