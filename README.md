# Psych 251 PS3: Reproducibility checks

- **Part A** (known case: Joel, Teper, & MacDonald, 2014, Study 1): [`partA.qmd`](partA.qmd) / [`partA.html`](partA.html). Data in `partA_data/`.
- **Part B** (Jara-Ettinger & Rubio-Fernandez, 2021, *Science Advances*, Experiment 1): [`partB.qmd`](partB.qmd) / [`partB.html`](partB.html). The reproduction code is in [`partB_reproduce.R`](partB_reproduce.R). The data, model predictions, and the authors' analysis scripts in `partB_osf/files/` are copied from the authors' OSF project, <https://osf.io/h8qfy/>.
- **Agent transcripts:** [`transcripts/`](transcripts/)

To re-render a report, run `quarto render partB.qmd` from this folder (needs R with `tidyverse` and `boot`).
