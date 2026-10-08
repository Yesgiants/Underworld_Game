# City concepts for v0.2.0

Setting: a fictional city inspired by the late 1980s and early 1990s. These are
visual directions for discussion. The game still uses its existing 24-district
map; choosing a concept is a separate step before implementation.

![Four fictional city concepts](city_concepts.png)

| Option | City and character | Strategic possibilities | Implementation scope |
| --- | --- | --- | --- |
| 1 | **Port Alder — coastal port.** A compact older downtown, working docks, rail yards, and wealthy northern hills. Baltimore/Philadelphia atmosphere. | A readable core with a distinct industrial waterfront and room for later expansion into hillside neighborhoods. | Best first step: compact geography and simple district connections. |
| 2 | **Ironhaven — river city.** Older brick neighborhoods and industry divided by a river. Pittsburgh/Cleveland atmosphere. | Bridges create a few important connections between competing sides of the city. | Add explicit bridge connections to district adjacency. |
| 3 | **Bellwick — island boroughs.** A dense central island, outer residential boroughs, markets, and a working harbor. New York atmosphere. | Each borough can support its own faction identity; crossings connect several local struggles into one city. | More connections to author and more care needed to keep the map readable. |
| 4 | **San Paloma — inland sprawl.** A valley city with freeways, industrial belts, older downtown blocks, suburbs, and hills. Southern California atmosphere. | Several commercial centers encourage a wider, less centralized territorial game. | A larger map; travel and distance could become useful later systems. |

**Recommendation:** start with **Port Alder**. It supports a strong city identity
while keeping the first strategic map easy to understand. Ironhaven is the next
best choice if bridges and geographic choke points are the main attraction.

The concept art illustrates geography and neighborhood character. Neighborhood
colors in this sheet are design accents, not current faction ownership. Details
such as bridge effects, neighborhood-specific income, travel, and regional police
behavior would need actual game rules before being playable features.

After choosing a city, the next design step is an authoritative list of roughly
24 districts, their connections, and their starting businesses. We can then adapt
the renderer while keeping the world simulation independent of the artwork.
