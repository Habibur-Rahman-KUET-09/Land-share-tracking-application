# Play Console assets

Everything here is copy-paste material for the Play Console listing. It is
kept in the repository so the wording that went to the store is versioned
with the app that shipped it — the console has no history worth the name.

| File | Where it goes in the console |
|---|---|
| `icon-512.png` | Main store listing → App icon |
| `feature-graphic-1024x500.png` | Main store listing → Feature graphic |
| `listing-bn.md` | Main store listing (bn-BD) |
| `listing-en.md` | Main store listing (en-US), set as default |
| `data-safety-and-rating.md` | App content → Data safety, Content rating |
| `release-checklist.md` | Everything that must be true before Production |

Screenshots are not here — they have to come off a real device, and this
repository has no way to run the app. `release-checklist.md` says which
screens to shoot.

The graphics are regenerated from `assets/icon/` by the snippet in
`make_graphics.py`; edit that rather than the PNGs.
