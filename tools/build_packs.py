#!/usr/bin/env python3
"""Regenerate the Picture Pack JSONs from icons using mask_from_icon.
Each mask is trimmed to its bounding box and verified fully-packed + solvable
via the same reverse-peel used by the engine."""
import sys, os, json, random
sys.path.insert(0, os.path.join(os.path.dirname(__file__)))
from mask_from_icon import from_emoji, from_glyph

GRID = 40     # dense / detailed maze

def trim(mask):
    ri = [i for i, r in enumerate(mask) if '#' in r]
    if not ri: return mask
    cols = len(mask[0])
    ci = [c for c in range(cols) if any(row[c] == '#' for row in mask)]
    r0, r1, c0, c1 = ri[0], ri[-1], ci[0], ci[-1]
    return [row[c0:c1+1] for row in mask[r0:r1+1]]

# ── engine mirror: masked reverse-peel + solver (to verify each shape) ──
DC=[0,1,0,-1]; DR=[-1,0,1,0]
def peel_ok(mask):
    rows=len(mask); cols=len(mask[0]); rng=random.Random(7)
    present=[[ch=='#' for ch in row] for row in mask]
    def P(c,r): return 0<=c<cols and 0<=r<rows and present[r][c]
    arrows=[]; cnt=sum(r.count('#') for r in mask)
    def rl(c,r,d):
        n=0;cc=c+DC[d];rr=r+DR[d]
        while 0<=cc<cols and 0<=rr<rows:
            if present[rr][cc]: return -1
            n+=1;cc+=DC[d];rr+=DR[d]
        return n
    while cnt>0:
        opts=[]
        for c in range(cols):
            col=[r for r in range(rows) if present[r][c]]
            if col:
                for rr,d in [(col[0],0),(col[-1],2)]:
                    L=rl(c,rr,d)
                    if L>=0: opts.append((c,rr,d))
        for r in range(rows):
            row=[c for c in range(cols) if present[r][c]]
            if row:
                for cc,d in [(row[0],3),(row[-1],1)]:
                    L=rl(cc,r,d)
                    if L>=0: opts.append((cc,r,d))
        if not opts: break
        us=[o for o in opts if P(o[0]-DC[o[2]],o[1]-DR[o[2]])] or opts
        c,r,d=us[rng.randrange(len(us))]
        body=[(c,r)];present[r][c]=False;cnt-=1;g=(d+2)%4;cc,rr=c,r
        if P(c+DC[g],r+DR[g]):
            cc+=DC[g];rr+=DR[g];body.append((cc,rr));present[rr][cc]=False;cnt-=1
            while len(body)<3+rng.randrange(6):
                nd=[dd for dd in range(4) if dd!=d and P(cc+DC[dd],rr+DR[dd])]
                if not nd: break
                dd=nd[rng.randrange(len(nd))];g=dd;cc+=DC[dd];rr+=DR[dd]
                body.append((cc,rr));present[rr][cc]=False;cnt-=1
        arrows.append({'cells':list(reversed(body)),'dir':d})
    # solvable?
    owner={}
    for i,a in enumerate(arrows):
        for (c,r) in a['cells']: owner[(c,r)]=i
    live=set(range(len(arrows)))
    def lk(i):
        h=arrows[i]['cells'][-1];d=arrows[i]['dir'];c=h[0]+DC[d];r=h[1]+DR[d]
        while 0<=c<cols and 0<=r<rows:
            o=owner.get((c,r))
            if o is not None and o!=i:return False
            c+=DC[d];r+=DR[d]
        return True
    while live:
        o=[i for i in live if lk(i)]
        if not o: return False,0,0
        for (c,r) in arrows[o[0]]['cells']: del owner[(c,r)]
        live.discard(o[0])
    single=sum(1 for a in arrows if len(a['cells'])==1)
    return True, len(arrows), single

BOLD = "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf"
def E(ch): return ("e", ch)
def G(ch): return ("g", ch)
def B(ch): return ("gb", ch)
PACKS = [
 ("shapes","Shapes",False, [(G("♥"),"Heart"),(G("★"),"Star"),(E("🌙"),"Moon"),(G("◆"),"Diamond")]),
 ("animals","Animals",True, [(E("🐱"),"Cat"),(E("🐶"),"Dog"),(E("🐟"),"Fish"),(E("🐢"),"Turtle"),
                             (E("🐰"),"Rabbit"),(E("🐦"),"Bird"),(E("🦋"),"Butterfly"),(E("🐧"),"Penguin")]),
 ("nature","Nature",True, [(E("🌸"),"Flower"),(E("🌳"),"Tree"),(E("🍁"),"Leaf"),(E("🍄"),"Mushroom"),
                           (E("☀"),"Sun"),(E("🍎"),"Apple")]),
 ("objects","Objects",True, [(E("🏠"),"House"),(E("🔑"),"Key"),(E("☂"),"Umbrella"),(E("✈"),"Plane"),
                             (E("⚓"),"Anchor"),(E("🎁"),"Gift"),(E("👑"),"Crown"),(E("🚀"),"Rocket")]),
(  "letters","Letters",True, [(B(ch),ch) for ch in "ABCDEFGHIJKLMNOPQRSTUVWXYZ"]),
]
def make_mask(src):
    kind,ch=src
    if kind=="e":  return from_emoji(ch,GRID,GRID)
    if kind=="gb": return from_glyph(ch,GRID,GRID,font=BOLD)
    return from_glyph(ch,GRID,GRID)

os.makedirs("data/pictures", exist_ok=True)
for f in os.listdir("data/pictures"):
    if f.endswith(".json"): os.remove(os.path.join("data/pictures",f))
print(f"{'pack':9} {'pic':10} {'grid':7} {'cells':6} {'arrows':6} {'single%':7} solvable")
for i,(pid,name,pro,items) in enumerate(PACKS):
    pics=[]
    for (src,pname) in items:
        m=trim(make_mask(src))
        ok,na,sc=peel_ok(m)
        cells=sum(r.count('#') for r in m)
        pics.append({"id":f"{pid}_{pname.lower().replace(' ','_')}","name":pname,"mask":m})
        print(f"{name:9} {pname:10} {len(m[0])}x{len(m):<4} {cells:6} {na:6} {100*sc/max(1,na):6.1f} {'YES' if ok else 'NO!'}")
    json.dump({"id":pid,"name":name,"pro":pro,"pictures":pics},
              open(f"data/pictures/{i:02d}-{pid}.json","w"), indent=1)
print("\nwrote", len(PACKS), "packs to data/pictures/")
