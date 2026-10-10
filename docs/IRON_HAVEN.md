# Iron Haven

A fictional industrial river city inspired by Pittsburgh and Cleveland in the
late 1980s and early 1990s. The **Calder River** separates an older western city
from the eastern mill belt. Freight yards, working docks, steel mills, brick
neighborhoods, markets, and hillside homes give each area its character.

![Iron Haven in the Family Ledger prototype](family_ledger.png)

The interface now uses a 1950s mafia ledger aesthetic. Iron Haven retains its
24-district industrial geography, with a larger pan-and-zoom map workspace.
See [the interface and navigation guide](FAMILY_LEDGER.md).

## Geography and expansion

The map has 24 selectable districts, 12 on each bank. Districts connect to the
district immediately above, below, left, or right on the same bank. The river
removes all cross-bank connections except these two bridges:

| Bridge | West-bank approach | East-bank approach |
| --- | --- | --- |
| City Bridge | City Hall (8) | East Market (9) |
| Foundry Bridge | Southbank (20) | Iron Gate (21) |

A faction may claim the opposite approach if it owns the approach on its own
bank. Normal claim costs and contested-claim odds still apply. Bridges have no
separate ownership: controlling an approach creates the opportunity to expand
across. Player orders and rival AI use the same district connections.

Both banks remain fully connected. No district can be selected in the river.
This remains a simple strategic schematic, with the visible bridge locations
matching simulation rules.

## Starting districts

IDs are stable, zero-based save indices. Rows run north to south, and each group
of six districts runs west to east. Player starts with 3 districts and 4
businesses; Romano starts with 5 districts and 5 businesses; Moretti starts with
4 districts and 4 businesses. The remaining 12 districts are independent.

| ID | District | Bank | Starting owner | Businesses |
| --- | --- | --- | --- | --- |
| 0 | North End | West | Romano | 1 |
| 1 | Little Italy | West | Romano | 1 |
| 2 | Old Quarter | West | Romano | 1 |
| 3 | East Heights | East | Independent | 0 |
| 4 | Oak Hill | East | Independent | 0 |
| 5 | Parkside | East | Independent | 0 |
| 6 | West Market | West | Player | 1 |
| 7 | Downtown | West | Player | 2 |
| 8 | City Hall | West | Romano | 1 |
| 9 | East Market | East | Moretti | 1 |
| 10 | Bricktown | East | Moretti | 1 |
| 11 | Mill End | East | Independent | 0 |
| 12 | West Docks | West | Player | 1 |
| 13 | Depot Row | West | Independent | 0 |
| 14 | Rail Yards | West | Romano | 1 |
| 15 | Foundry | East | Moretti | 1 |
| 16 | Steelworks | East | Moretti | 1 |
| 17 | East Docks | East | Independent | 0 |
| 18 | South End | West | Independent | 0 |
| 19 | Old Freight | West | Independent | 0 |
| 20 | Southbank | West | Independent | 0 |
| 21 | Iron Gate | East | Independent | 0 |
| 22 | Coal Yard | East | Independent | 0 |
| 23 | Workers Row | East | Independent | 0 |

Click a district to inspect its owner, businesses, police attention, bank, and
local description. Bridge approaches identify their crossing in the inspector
and hover tooltip. These descriptions are flavor; this iteration uses the same
income, business, and police rules across all districts. Operations now add
$500 per business in the selected district to their $1,900–$4,100 base payout.

## Saved games

New cities use Iron Haven. Existing v0.1 and earlier v0.2 development saves load
with their original grid geography, district names, businesses, and ownership,
and display as **Prototype City**. Current saves record their layout explicitly
and preserve it on subsequent loads. Use **New city** for Iron Haven; the previous
disk save remains available until you save over it.

The game remains v0.2.0-dev. Save schema version 3 identifies layouts; it is a
storage format number, not a new game release.
