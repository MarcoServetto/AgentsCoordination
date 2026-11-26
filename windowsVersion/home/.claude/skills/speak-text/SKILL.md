---
name: speak-text
description: Generate a spoken audio clip from a text, with one of the voices of this skill (ExplanationBase).
---

# Generating a clip

Write the text to a file, UTF-8, one paragraph per line. Then run:

```powershell
& C:\data\tools\voice_maker\env\Scripts\python.exe "$HOME\.claude\skills\speak-text\speak.py" explanation_base <text_file> <out_wav>
```

The first argument is the name of a voice: a file `voices\<name>.wav` next to `speak.py`.
The voice ExplanationBase is `explanation_base`.

A run needs 4 of the 6 GB of GPU memory: one run at a time.
A run takes about 40 seconds to load the models, then about 2 seconds for each second of speech.

# Building C:\data\tools\voice_maker

`C:\data\tools\voice_maker` holds the Python environment and the model files that `speak.py` loads.
When the folder is missing, build it:

```powershell
$t = 'C:\data\tools\voice_maker'
$k = "$HOME\.claude\skills\speak-text"
uv venv --python 3.11 "$t\env"
uv pip install --python "$t\env\Scripts\python.exe" -r "$k\requirements.txt" --extra-index-url https://download.pytorch.org/whl/cu124 --index-strategy unsafe-best-match
uv pip install --python "$t\env\Scripts\python.exe" --no-deps resemble-enhance==0.0.1
& "$t\env\Scripts\hf.exe" download ResembleAI/chatterbox ve.safetensors t3_cfg.safetensors s3gen.safetensors tokenizer.json conds.pt --local-dir "$t\models\chatterbox"
& "$t\env\Scripts\hf.exe" download ResembleAI/resemble-enhance --include "enhancer_stage2/*" --local-dir "$t\models\resemble_enhance"
```
