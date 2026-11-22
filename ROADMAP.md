# Roadmap

Ideas and next steps for Test Prep and Kunskapsäventyret (the adventure game). Not built yet unless
marked done.

## Kunskapsäventyret — themes

**Done:** the theme follows season, weather and time of day by default (`/api/theme`, weather from
Open-Meteo for one configured place — `WEATHER_LAT`/`WEATHER_LON` in `config.json`, rounded to about
1 km, default central Stockholm), with Halloween and Christmas decorations around those dates. Presets
can be chosen on the start screen: Vår, Sommar, Höst, Vinter, Natt, Halloween, Jul.

Next:
- **The player's own location** instead of one place for everyone: ask the browser for position
  (with consent, coarse — city level is enough), or let the player pick a town. Never store or log the
  position; pass rounded coordinates to `/api/theme` and cache per rounded cell.
- **More holidays and Swedish traditions:** Lucia (13 Dec), Easter (påskkärringar, eggs), Midsummer
  (midsommarstång), Valborg (bonfire), birthdays (date in the player's profile).
- **Weather that affects the game,** not only the look: animals that hide in burrows when it rains,
  frogs out in the rain, footprints that show better in snow, harder to see in fog, owls awake at night.
- **Smooth day/night** — the light changing slowly during a long game instead of per refresh.
- **Theme for Test Prep too:** the same live theme as an accent colour/background in the regular app.
- **Sound:** gentle rain, wind, birdsong by day, crickets at night (off by default, follows the sound button).

## Kunskapsäventyret — game

- Global high-score list for the household (needs a shared store; today records live in the browser).
- More places (beach, winter forest, night forest), more heroes and hiding animals.
- Read questions aloud (speech synthesis) for younger players.
