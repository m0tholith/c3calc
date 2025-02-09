# c3calc
a calculator terminal program made in C3
### this program is actually made in C3; the GitHub language detector doesn't support it yet
## syntax/features
this program has pretty much the same syntax as any other textual calculator app. with that in mind, some features i added are:
- variable assignment (`_x = 100; log10 x` -> `10`)
- functions (`log10(100) * log2(128)` -> `14`) (note that these are pre-defined and can't be created)
---
to evaluate more than one expression in the same context, either insert a newline, or use a semicolon `;`
## building
there are no dependencies other than c3c. if you have c3c then you can paste this code into a terminal:
```bash
git clone https://github.com/m0tholith/c3calc
cd c3calc
c3c build
```
and the resulting binary will be built and placed in `build/c3calc`.
