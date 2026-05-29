# Pharmacy tool docs

These are the pharmacy-specific tool docs the agent reads on demand. They are part of the pharmacy vertical overlay — see `examples/farmacia/README.md` for the full apply recipe.

| File | Purpose |
|------|---------|
| `on-duty-pharmacies.md` | Weekly on-duty schedule, stored as a single `pharmacy_schedule` metaobject |
| `workshops.md` | In-person workshops, stored as a `workshop` metaobject collection |
| `home-content.md` | Home offer and featured services (`home_offer` + `home_service` metaobjects) |
| `competitors.md` | Competitor price comparison via `web_fetch` |

## Applying these

Copy the files into the live tool directory the engine reads (`hermes/tools/`, mounted at `/opt/data/tools/` in the container), then add the matching rows to the `hermes/TOOLS.md` Module Index using `brain/TOOLS.fragment.md`:

```
cp on-duty-pharmacies.md workshops.md home-content.md competitors.md ../../../hermes/tools/
```

All ids are generic placeholders (`${FARMACIAS_METAOBJECT_ID}`, `${THEME_ID}`, `${BLOG_ID}`) resolved from `.env` at load time. Set them per `examples/farmacia/README.md` § "Set the env vars and metaobject ids".
