# Sinh audio mp3 cho shadow-talk/content/lessons.json bang edge-tts.
# Idempotent: file ton tai va >1KB thi bo qua. Chay: python gen-audio.py [voice]
import asyncio, json, os, sys

BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "content")

async def gen(text, out, voice, rate):
    import edge_tts
    tts = edge_tts.Communicate(text, voice, rate=rate)
    await tts.save(out)

def main():
    voice = sys.argv[1] if len(sys.argv) > 1 else "en-US-AndrewNeural"
    with open(os.path.join(BASE, "lessons.json"), encoding="utf-8") as f:
        data = json.load(f)
    rate = data.get("rate", "-4%")
    done = miss = 0
    for lesson in data["lessons"]:
        d = os.path.join(BASE, "audio", lesson["id"])
        os.makedirs(d, exist_ok=True)
        for i, s in enumerate(lesson["sentences"], 1):
            out = os.path.join(d, "%02d.mp3" % i)
            if os.path.exists(out) and os.path.getsize(out) > 1000:
                done += 1
                continue
            try:
                asyncio.run(gen(s["en"], out, voice, rate))
                done += 1
                print("ok", lesson["id"], i, flush=True)
            except Exception as e:
                miss += 1
                print("FAIL", lesson["id"], i, repr(e), flush=True)
    print("SUMMARY done=%d fail=%d voice=%s" % (done, miss, voice), flush=True)

if __name__ == "__main__":
    main()
