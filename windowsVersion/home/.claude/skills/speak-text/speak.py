import sys, re, types, pathlib
pathlib.PosixPath = pathlib.WindowsPath
ds = types.ModuleType("deepspeed"); ds.DeepSpeedConfig = object; ds.init_distributed = None
acc = types.ModuleType("deepspeed.accelerator"); acc.get_accelerator = None
rt = types.ModuleType("deepspeed.runtime")
eng = types.ModuleType("deepspeed.runtime.engine"); eng.DeepSpeedEngine = type("DeepSpeedEngine", (), {})
ut = types.ModuleType("deepspeed.runtime.utils"); ut.clip_grad_norm_ = None
sys.modules.update({"deepspeed": ds, "deepspeed.accelerator": acc, "deepspeed.runtime": rt, "deepspeed.runtime.engine": eng, "deepspeed.runtime.utils": ut})
import torch, torchaudio, perth
perth.PerthImplicitWatermarker = perth.DummyWatermarker
from chatterbox.tts import ChatterboxTTS
from resemble_enhance.enhancer.inference import load_enhancer
from resemble_enhance.inference import inference

here, tools = pathlib.Path(__file__).parent, pathlib.Path("C:/data/tools/voice_maker")
voice, textFile, out = sys.argv[1:]
reference = here / "voices" / (voice + ".wav")
assert reference.exists()

def pieces(paragraph):
  groups = [""]
  for sentence in re.split(r"(?<=[.!?])\s+", paragraph):
    if groups[-1] and len(groups[-1]) + len(sentence) > 400: groups.append("")
    groups[-1] = (groups[-1] + " " + sentence).strip()
  return groups

paragraphs = [p for p in pathlib.Path(textFile).read_text(encoding="utf-8").split("\n") if p.strip()]
model = ChatterboxTTS.from_local(tools / "models" / "chatterbox", "cuda")
def gap(seconds): return torch.zeros(1, int(model.sr * seconds))
parts = []
for paragraph in paragraphs:
  for piece in pieces(paragraph):
    parts += [model.generate(piece, audio_prompt_path=str(reference), exaggeration=0.75, cfg_weight=0.1, temperature=0.8).cpu(), gap(0.25)]
  parts[-1] = gap(0.45)
raw, sr = torch.cat(parts[:-1], dim=-1)[0], model.sr
del model
torch.cuda.empty_cache()
enhancer = load_enhancer(tools / "models" / "resemble_enhance" / "enhancer_stage2", "cuda")
enhancer.configurate_(nfe=64, solver="midpoint", lambd=0.9, tau=0.5)
with torch.inference_mode(): clean, cleanSr = inference(enhancer, raw, sr, "cuda", chunk_seconds=10.0)
torchaudio.save(out, clean.unsqueeze(0).cpu(), cleanSr)
print(out, "seconds", round(clean.shape[-1] / cleanSr, 1))
