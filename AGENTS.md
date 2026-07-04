# Agent Instructions

This repository contains a LaTeX manuscript for an Elsevier CAS single-column paper:

- Main file: `cas-sc-template.tex`
- Class/style files: `cas-sc.cls`, `cas-common.sty`
- Bibliography: `cas-refs.bib`
- Bibliography style: `model1-num-names.bst`
- Figures: `figs/`

## Working Style

- Keep edits focused on the manuscript, bibliography, or figures requested by the user.
- Do not rename the main `.tex`, `.bib`, `.cls`, `.sty`, `.bst`, or figure files unless explicitly asked.
- Preserve the existing Elsevier CAS structure and package choices unless there is a clear compile or formatting reason to change them.
- The manuscript currently uses numeric `natbib` citations via `\usepackage[numbers]{natbib}`.
- Use ASCII in new text unless the surrounding manuscript requires a specific non-ASCII character.

## Build And Verification

Preferred build command:

```powershell
latexmk -pdf cas-sc-template.tex
```

Fallback build sequence:

```powershell
pdflatex cas-sc-template.tex
bibtex cas-sc-template
pdflatex cas-sc-template.tex
pdflatex cas-sc-template.tex
```

After edits, check for:

- LaTeX errors and unresolved references/citations.
- Figure path issues, especially files under `figs/`.
- Overfull boxes in edited sections.
- Bibliography entries matching cited keys.

Clean generated LaTeX build artifacts only when useful, and avoid deleting source files or figures.

## UPPAAL Verification

The local UPPAAL command-line verifier is available at:

```powershell
C:\Program Files\UPPAAL-5.0.0\app\bin\verifyta.exe
```

Use the helper script for model checks:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\run_verifyta.ps1 -Model ".\LwM2M Models\Level 1\BaselineModel.xml" -QueryIndex 0
```

When possible, set `UPPAAL_VERIFYTA` instead of hard-coding paths in new scripts.

## Manuscript Conventions

- Section flow is: Introduction, Background, LwM2M-IFV Framework, Qualitative Security and Admission Profiles, Quantitative SMC Reliability Profiles, Conclusion/Future Work, Acknowledgments, References.
- Keep figure references in the existing style, such as `Fig.~\ref{...}`.
- Keep citations in the existing style, such as `\cite{...}` and `~\cite{...}`.
- Use `\texttt{...}` for UPPAAL query syntax and code-like terms where appropriate.
- Place new figures in `figs/` and reference them with relative paths, for example `\includegraphics{figs/example.png}`.

## Notes For Future Agents

- This directory is not currently a git repository.
- The main `.tex` file appears to contain some mojibake characters in prose. If editing nearby text, preserve meaning and fix only the touched passages unless the user asks for a broader cleanup.
- If adding or changing claims about standards, tools, or current research, verify the source and update `cas-refs.bib` accordingly.
