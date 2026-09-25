from pathlib import Path
import numpy as np, math, json, struct, base64, shutil
from scipy.spatial import ConvexHull
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[1]
PALETTE={'stone':(67,83,96),'edge':(117,142,150),'dark':(30,40,53),'wood':(104,65,45),'woodlight':(162,106,61),'copper':(213,125,69),'gold':(249,189,100),'rift':(66,230,200),'ice':(181,255,235),'moss':(68,107,73),'bark':(74,55,44),'cloth':(59,90,91),'leather':(70,44,38),'fire':(255,151,65)}
A={}; current=[]; ACTIVE_JOINT='Torso'
def hull(points,name,mat):
 v=np.array(points,dtype=float); h=ConvexHull(v); f=h.simplices.copy()
 for i,tri in enumerate(f):
  a,b,c=v[tri]
  if np.dot(np.cross(b-a,c-a),h.equations[i,:3])<0:f[i]=tri[[0,2,1]]
 current.append({'name':name,'mat':mat,'v':v,'f':f,'joint':ACTIVE_JOINT});return current[-1]
def box(name,p,s,mat):
 p=np.array(p);s=np.array(s)/2
 return hull([p+s*np.array([x,y,z]) for x in [-1,1] for y in [-1,1] for z in [-1,1]],name,mat)
def rod(name,a,b,r,mat,r2=None,n=8):
 a=np.array(a,float);b=np.array(b,float);d=b-a;d/=np.linalg.norm(d)
 u=np.cross(d,[0,0,1] if abs(d[2])<.9 else [0,1,0]);u/=np.linalg.norm(u);w=np.cross(d,u)
 r2=r if r2 is None else r2
 pts=[p+rr*(math.cos(i*2*math.pi/n)*u+math.sin(i*2*math.pi/n)*w) for p,rr in [(a,r),(b,max(.005,r2))] for i in range(n)]
 return hull(pts,name,mat)
def rock(name,p,s,mat,seed=0):
 rng=np.random.default_rng(seed); pts=[]
 for z,r in [(-.8,.6),(-.15,1),(.65,.72)]:
  for i in range(7):
   t=i*2*math.pi/7;pts.append(np.array(p)+np.array(s)*np.array([r*math.cos(t),r*math.sin(t),z+rng.uniform(-.15,.15)]))
 pts.append(np.array(p)+np.array(s)*[.05,0,1]);return hull(pts,name,mat)
def crystal(name,p,r,h,mat='rift',tilt=(0,0)):
 x,y,z=p;pts=[]
 for zz,rr,dx,dy in [(0,.65*r,0,0),(.65*h,r,tilt[0]*.65,tilt[1]*.65)]:
  pts.extend([[x+dx+rr*math.cos(i*math.pi/3),y+dy+rr*math.sin(i*math.pi/3),z+zz] for i in range(6)])
 pts.append([x+tilt[0],y+tilt[1],z+h]);return hull(pts,name,mat)
def prism(name,poly,depth,mat):
 return hull([[x,y,z] for x,z in poly for y in [-depth/2,depth/2]],name,mat)
def start():current.clear()
def finish(name,category):
 A[name]={'category':category,'parts':list(current)}
# tools
for tier in ['Stone','Copper']:
 start();rod('Handle',(0,0,.05),(0,0,2.5),.095,'woodlight')
 rod('Grip',(0,0,.16),(0,0,.87),.13,'leather')
 for z in [.2,.38,.56,.74]:rod('GripWrap',(0,0,z),(0,0,z+.035),.142,'copper' if tier=='Copper' else 'cloth')
 box('HeadBinding',(0,0,2.18),(.34,.35,.38),'dark')
 for s in [-1,1]:
  prism('PickHead',[(s*.1,2.42),(s*.66,2.36),(s*1.03,1.95),(s*.43,2.13),(s*.1,2.08)],.27,'stone' if tier=='Stone' else 'copper')
 box('HeadPin',(0,-.2,2.2),(.1,.08,.1),'rift' if tier=='Copper' else 'edge')
 finish(tier+'_Pickaxe','01_Tools')
start();rod('Grip',(0,0,.1),(0,0,.68),.12,'leather');rock('Pommel',(0,0,.1),(.17,.13,.13),'copper');box('Guard',(0,0,.75),(.8,.23,.13),'copper')
prism('Blade',[(-.2,.83),(.2,.83),(.24,2.05),(0,2.55),(-.24,2.05)],.13,'edge')
prism('BladeInset',[(-.05,.9),(.05,.9),(.05,2.04),(0,2.27),(-.05,2.04)],.142,'stone');finish('Stone_Sword','01_Tools')
start()
pts=[(0,0,.15),(.46,0,.6),(.63,0,1.12),(.48,0,1.5),(.63,0,1.88),(.46,0,2.4),(0,0,2.85)]
for i in range(len(pts)-1):rod('BowLimb',pts[i],pts[i+1],.085,'copper')
rod('BowString',pts[0],pts[-1],.012,'cloth',n=6);rod('Grip',(.48,0,1.3),(.48,0,1.7),.12,'leather')
rod('Arrow',(-.4,-.1,1.5),(1.35,-.1,1.5),.027,'woodlight');crystal('Arrowhead',(0,0,0),.08,.25,'edge')
p=current[-1];v=p['v'].copy();p['v']=np.column_stack((v[:,2]+1.35,v[:,1]-.1,-v[:,0]+1.5));finish('Copper_Bow','01_Tools')
start();box('Grip',(0,0,.35),(.22,.26,.7),'leather');box('Body',(0,0,.85),(.48,.9,.48),'dark');rod('Barrel',(0,-.75,.87),(0,.38,.87),.15,'copper');rod('RopeDrum',(-.34,.1,.85),(.34,.1,.85),.26,'woodlight')
for x in [-.36,.36]:rod('DrumCap',(x-.025,.1,.85),(x+.025,.1,.85),.3,'copper')
for x in [-.2,.2]:rod('Hook',(0,-.74,.87),(x,-1,.87),.04,'edge');rod('HookTip',(x,-1,.87),(x,-.77,1.03),.04,'edge')
box('ChargeCell',(0,-.12,1.12),(.2,.35,.1),'rift');finish('Grapple_Launcher','01_Tools')
# creatures front -Y
start();rock('Torso',(0,0,1.15),(.52,.37,.59),'dark',1);rock('Head',(0,-.06,1.9),(.49,.36,.38),'stone',4)
for s in [-1,1]:
 rock('Foot',(s*.3,-.11,.18),(.23,.38,.18),'stone',2);rod('Leg',(s*.28,0,.3),(s*.28,0,.82),.14,'dark')
 rod('UpperArm',(s*.44,0,1.49),(s*.69,-.06,1.15),.16,'stone');rock('Hand',(s*.74,-.14,.9),(.2,.2,.28),'stone',3)
 crystal('Horn',(s*.29,0,2.05),.14,.57,'dark',(s*.17,0));box('Eye',(s*.19,-.373,1.94),(.18,.055,.095),'rift')
 for j in range(2):rod('Claw',(s*.7+(j-.5)*.13,-.29,.8),(s*.7+(j-.5)*.13,-.43,.61),.035,'copper',.005)
crystal('Heart',(0,-.35,1.04),.14,.37);finish('Riftling','02_Enemies')
start();rock('RootBody',(0,0,.85),(.65,.52,.75),'bark',8);rock('Mask',(0,-.34,1.65),(.4,.22,.43),'woodlight',3)
for s in [-1,1]:
 box('Eye',(s*.16,-.565,1.72),(.17,.04,.075),'rift')
 for j in range(2):
  a=(s*.4,.2-j*.48,.8);b=(s*(.85+j*.15),.2-j*.7,.45);c=(s*(1.2+j*.15),.4-j*1.15,.03)
  rod('RootLeg',a,b,.14,'bark',.1);rod('RootFoot',b,c,.1,'bark',.02)
 rod('BranchArm',(s*.48,0,1.2),(s*.87,-.25,1.5),.12,'bark',.07);rod('BranchTip',(s*.87,-.25,1.5),(s*1.03,-.28,2.05),.07,'bark',.012)
 crystal('Crown',(s*.24,0,1.8),.1,.6,'moss',(s*.12,0))
for i in range(4):rock('Moss',(math.cos(i*1.7)*.35,.12+math.sin(i*1.7)*.2,1.4),(.28,.25,.17),'moss',i)
finish('Rootstalker','02_Enemies')
start();rock('Torso',(0,0,2.65),(1,.57,1.05),'stone',9);rock('Waist',(0,0,1.68),(.61,.45,.42),'dark',2)
rock('Head',(0,-.08,3.82),(.49,.43,.6),'dark',4)
for s in [-1,1]:
 rock('Foot',(s*.57,-.23,.25),(.45,.62,.27),'stone',2);rod('Leg',(s*.53,0,.46),(s*.48,0,1.58),.3,'dark')
 rock('Knee',(s*.53,-.27,1),(.35,.28,.35),'copper',1)
 rock('Shoulder',(s*1.11,0,3.15),(.53,.54,.51),'stone',6)
 rod('UpperArm',(s*1.2,0,2.94),(s*1.48,-.04,2.36),.27,'dark');rock('Forearm',(s*1.54,-.08,1.95),(.37,.4,.59),'stone',5)
 rock('Fist',(s*1.58,-.19,1.43),(.4,.39,.33),'dark',1)
 for j in range(3):crystal('ShoulderCrystal',(s*(.86+j*.22),.04,3.47),.13,.48+j*.15,'rift',(s*.15,0))
 rod('Antler',(s*.32,.04,4.13),(s*.69,.08,4.7),.13,'woodlight',.06);rod('AntlerTip',(s*.69,.08,4.7),(s*.63,.06,5.02),.06,'woodlight',.01)
 box('Eye',(s*.19,-.485,3.89),(.23,.04,.095),'rift')
crystal('ChestCore',(0,-.64,2.32),.26,.85,'rift');box('CoreFrame',(0,-.55,2.66),(.73,.15,.13),'copper');finish('Hollow_Warden','02_Enemies')
# resources
for name,mat in [('Stone_Deposit','edge'),('Copper_Deposit','copper'),('Rift_Deposit','rift')]:
 start();rock('Bedrock',(0,0,.43),(1.15,.85,.52),'stone',3)
 for i in range(5):
  t=i*2.4;x=.55*math.cos(t);y=.4*math.sin(t)
  if mat=='edge':rock('StoneChunk',(x,y,.74),(.4,.35,.42),'edge',i)
  else:crystal('OreCrystal',(x,y,.62),.2,.64+i*.13,mat,(x*.35,y*.4))
 for i in range(3):rock('Scatter',(.92*math.cos(i*2),.85*math.sin(i*2),.13),(.24,.2,.16),'dark',i)
 finish(name,'03_Resources')
start()
for x,z in [(-.25,.26),(.25,.26),(0,.67)]:
 rod('Log',(x,-.75,z),(x,.75,z),.26,'bark');rod('CutEnd',(x,-.765,z),(x,-.78,z),.21,'woodlight');rod('Heartwood',(x,-.781,z),(x,-.79,z),.11,'wood')
for y in [-.4,.4]:box('Strap',(0,y,.43),(.91,.09,.82),'leather')
finish('Timber_Pile','03_Resources')
# bench
start()
for x in [-1,1]:
 for y in [-.47,.47]:box('Leg',(x,y,.67),(.2,.2,1.34),'wood')
for y in [-.38,0,.38]:box('Plank',(0,y,1.42),(2.65,.35,.18),'woodlight')
for x in [-1,1]:box('Brace',(x,0,.35),(.16,1.15,.15),'dark')
box('Shelf',(0,0,.43),(2.1,.9,.12),'wood');box('AnvilBase',(.57,0,1.58),(.55,.48,.14),'dark');box('Anvil',(.57,0,1.78),(.63,.3,.28),'stone')
prism('AnvilHorn',[(.88,1.73),(1.25,1.86),(.88,1.92)],.24,'edge');box('CuttingMat',(-.55,-.05,1.54),(.7,.62,.035),'cloth')
rod('HammerHandle',(-.65,-.15,1.59),(-.33,.24,1.59),.045,'wood');box('HammerHead',(-.33,.24,1.62),(.24,.14,.14),'copper');finish('Workbench','04_Structures')
start();box('Foundation',(0,0,.14),(1.85,1.55,.28),'dark')
for z in [.47,.97,1.47]:
 for x in [-.68,.68]:box('StoneWall',(x,0,z),(.42,1.28,.46),'stone')
 box('BackWall',(0,.49,z),(1.15,.28,.46),'stone')
box('Roof',(0,0,1.78),(1.68,1.42,.22),'edge');box('Chimney',(0,.25,2.19),(.58,.59,.62),'stone');box('ChimneyCap',(0,.25,2.53),(.74,.73,.12),'dark')
box('Hearth',(0,0,.34),(1.07,1.1,.1),'fire');box('Lintel',(0,-.56,1.33),(1.1,.21,.32),'dark')
for x in [-.35,0,.35]:crystal('Flame',(x,-.13,.4),.13,.53,'fire')
for x in [-.44,-.22,0,.22,.44]:rod('Grate',(x,-.66,.39),(x,-.66,1.13),.025,'dark')
finish('Smelting_Furnace','04_Structures')
start();box('Base',(0,0,.12),(3.9,1.8,.24),'dark')
for s in [-1,1]:
 for j in range(4):rock('Pillar',(s*1.38,0,.57+j*.66),(.45,.45,.42),'stone',j)
 box('Rune',(s*1.39,-.45,1.88),(.12,.04,.49),'rift')
 for j in range(2):crystal('BaseCrystal',(s*(1.75+j*.12),-.25,.2),.12,.6+j*.2,'rift',(s*.15,0))
for i in range(5):
 a=i*math.pi/4;rock('Arch',(1.38*math.cos(a),0,2.6+1.1*math.sin(a)),(.44,.44,.43),'stone',i+12)
# open portal: no opaque sheet, glowing segmented inner ring
for i in range(16):
 a=2*math.pi*i/16;b=2*math.pi*(i+1)/16
 rod('RiftRing',(1.04*math.cos(a),-.05,1.92+1.5*math.sin(a)),(1.04*math.cos(b),-.05,1.92+1.5*math.sin(b)),.035,'rift',n=6)
finish('Return_Portal','04_Structures')
start();box('ChestBody',(0,0,.57),(1.55,.94,1.03),'wood');box('Lid',(0,0,1.13),(1.63,1.01,.2),'woodlight')
for x in [-.58,.58]:
 box('IronBand',(x,0,.64),(.12,.985,1.13),'dark');box('TopBand',(x,0,1.25),(.12,1.03,.07),'dark')
box('Lock',(0,-.515,.85),(.22,.1,.29),'copper');box('Keyhole',(0,-.573,.86),(.055,.015,.09),'dark');finish('Storage_Chest','04_Structures')
# v2 refinement: reusable bevels, tube curves and connected silhouettes.
def bevel(name,p,s,mat,b=.035):
 p=np.array(p);h=np.array(s)/2;b=min(b,min(h)*.8);pts=[]
 for axis in range(3):
  for side in [-1,1]:
   other=[i for i in range(3) if i!=axis]
   for u in [-1,1]:
    for v in [-1,1]:
     q=np.zeros(3);q[axis]=side*h[axis];q[other[0]]=u*(h[other[0]]-b);q[other[1]]=v*(h[other[1]]-b);pts.append(p+q)
 return hull(pts,name,mat)
def tube(name,points,r,mat,n=6,closed=False):
 pts=np.array(points,float);verts=[]
 for i,p in enumerate(pts):
  d=pts[(i+1)%len(pts)]-pts[(i-1)%len(pts)] if closed else pts[min(i+1,len(pts)-1)]-pts[max(i-1,0)]
  d/=np.linalg.norm(d);u=np.cross(d,[0,0,1] if abs(d[2])<.9 else [0,1,0]);u/=np.linalg.norm(u);w=np.cross(d,u)
  verts.extend(p+r*(np.cos(t)*u+np.sin(t)*w) for t in np.arange(n)*2*np.pi/n)
 faces=[]
 for i in range(len(pts) if closed else len(pts)-1):
  j=(i+1)%len(pts)
  for k in range(n):
   q=(k+1)%n;a=i*n+k;b=i*n+q;c=j*n+q;e=j*n+k
   faces.extend([[a,b,c],[a,c,e]])
 if not closed:
  for k in range(1,n-1):faces.extend([[0,k+1,k],[(len(pts)-1)*n,(len(pts)-1)*n+k,(len(pts)-1)*n+k+1]])
 current.append({'name':name,'mat':mat,'v':np.array(verts),'f':np.array(faces)})
def ring(name,center,r,thick,mat,axis='y',n=20):
 c=np.array(center);pts=[]
 for a in np.arange(n)*2*np.pi/n:
  q=[0,r*np.cos(a),r*np.sin(a)] if axis=='x' else [r*np.cos(a),0,r*np.sin(a)] if axis=='y' else [r*np.cos(a),r*np.sin(a),0]
  pts.append(c+q)
 tube(name,pts,thick,mat,n=6,closed=True)
def polyline(name,pts,r,mat):
 for i in range(len(pts)-1):rod(name+str(i),pts[i],pts[i+1],r,mat,n=6)
# Pickaxes: tapered curved tines instead of broad axe-like heads.
for tier in ['Stone','Copper']:
 start();rod('Oak_Handle',(0,0,.07),(0,0,2.3),.092,'woodlight',.115,n=10)
 rod('Leather_Grip',(0,0,.17),(0,0,.8),.118,'leather',n=10)
 for z in [.19,.34,.49,.64,.79]:rod('Grip_Binding',(0,0,z),(0,0,z+.034),.124,'cloth',n=10)
 bevel('Head_Socket',(0,0,2.12),(.35,.32,.38),'dark',.05)
 for side in [-1,1]:
  # irregular convex facets taper all the way to a point
  for a,b,r,r2 in [((.11,0,2.22),(.51,0,2.19),.145,.115),((.51,0,2.19),(.84,0,2.02),.115,.065),((.84,0,2.02),(1.12,0,1.75),.065,.007)]:
   rod('Tapered_Pick_Tine',(side*a[0],a[1],a[2]),(side*b[0],b[1],b[2]),r,'stone' if tier=='Stone' else 'copper',r2,n=6)
 rod('Socket_Rivet',(0,-.171,2.13),(0,-.192,2.13),.047,'edge',n=8)
 if tier=='Copper':bevel('Rift_Inlay',(0,-.167,2.24),(.09,.02,.1),'rift',.012)
 finish(tier+'_Pickaxe','01_Tools')
# Grappling launcher: body, grip, barrel, reel, rope, hook and trigger.
start()
bevel('Receiver',(0,.05,1.11),(.51,1.05,.38),'dark',.07)
bevel('Copper_Rail',(0,.03,1.335),(.31,.9,.085),'copper',.02)
rod('Barrel',(0,-.77,1.12),(0,.28,1.12),.132,'edge',n=12)
ring('Muzzle_Collar',(0,-.78,1.12),.14,.035,'copper',axis='y')
# mounting blocks kept behind muzzle and outside the hook assembly
bevel('Rear_Cap',(0,.59,1.12),(.43,.17,.31),'copper',.035)
rod('Grip_Core',(0,.37,.15),(0,.52,.9),.13,'woodlight',.15,n=8)
rod('Grip_Wrap',(0,.39,.25),(0,.49,.75),.15,'leather',.16,n=8)
bevel('Grip_Pommel',(0,.36,.16),(.32,.28,.13),'copper',.035)
# trigger guard, with empty interior
polyline('Trigger_Guard',[(0,.41,.87),(0,-.02,.87),(0,-.12,.57),(0,.31,.45)],.033,'copper')
polyline('Trigger',[(0,.19,.91),(0,.12,.72),(0,.2,.67)],.035,'edge')
# drum behind the receiver: genuine exposed windings
rod('Reel_Axle',(-.43,.52,.91),(.43,.52,.91),.07,'dark',n=10)
rod('Reel_Core',(-.31,.52,.91),(.31,.52,.91),.18,'wood',n=12)
for x in [-.34,.34]:
 rod('Reel_Sideplate',(x-.025,.52,.91),(x+.025,.52,.91),.255,'copper',n=12)
 rod('Reel_Axle_Cap',(x*1.13,.52,.91),(x*1.23,.52,.91),.085,'edge',n=10)
coil=[]
for i in range(161):
 t=i/160;theta=t*2*np.pi*10;coil.append((-.285+.57*t,.52+.202*np.cos(theta),.91+.202*np.sin(theta)))
tube('Wound_Rope',coil,.024,'woodlight',n=5)
# seated hook: three curved prongs, front-facing tips return towards the barrel
rod('Hook_Shaft',(0,-.72,1.12),(0,-1.18,1.12),.046,'edge',n=8)
for a in [np.pi/2,np.pi/2+2*np.pi/3,np.pi/2+4*np.pi/3]:
 ux,uz=np.cos(a),np.sin(a)
 pts=[(0,-1.09,1.12),(.22*ux,-1.26,1.12+.22*uz),(.3*ux,-1.11,1.12+.3*uz),(.24*ux,-.94,1.12+.24*uz)]
 polyline('Grapple_Prong',pts,.035,'edge')
 rod('Hook_Barb',pts[-1],(.19*ux,-1.02,1.12+.19*uz),.035,'edge',.006,n=6)
bevel('Power_Cell_Housing',(0,.01,1.41),(.26,.38,.12),'dark',.025)
bevel('Rift_Power_Cell',(0,.01,1.478),(.17,.28,.042),'rift',.018)
for y in [-.35,.33]:rod('Receiver_Pin',(.245,y,1.12),(.268,y,1.12),.035,'gold',n=8)
finish('Grapple_Launcher','01_Tools')
# Logs: distinct bark, clean end grain and rope that follows the silhouette.
start()
for i,(x,z) in enumerate([(-.325,.33),(.325,.33),(0,.89)]):
 length=[1.15,1.07,.99][i]
 rod('Bark_Log',(x,-length,z),(x,length,z),.32,'bark',n=12)
 for side in [-1,1]:
  end=side*(length+.008)
  rod('Cut_Endgrain',(x,end,z),(x,end+side*.018,z),.278,'woodlight',n=12)
  for r in [.1,.195,.254]:ring('Growth_Ring',(x,end+side*.022,z),r,.0065,'wood',axis='y',n=16)
  # short radial crack in each log end
  polyline('Endgrain_Crack',[(x+.14,end+side*.025,z-.2),(x+.075,end+side*.025,z-.09),(x+.087,end+side*.025,z-.015)],.008,'bark')
 for a in [0,.9,2.1,3.4,4.5]:
  xx=x+.315*np.cos(a);zz=z+.315*np.sin(a)
  rod('Bark_Ridge',(xx,-length+.05,zz),(xx,length-.05,zz),.014,'wood',n=5)
# rope bound tightly around log stack, no solid cuboid cutting through logs
outline=[(-.61,.11),(-.67,.3),(-.59,.56),(-.28,1.06),(-.14,1.2),(.14,1.2),(.28,1.06),(.59,.56),(.67,.3),(.61,.11),(.37,.015),(-.37,.015)]
for y in [-.6,.54]:
 tube('Bundle_Rope',[(x,y,z) for x,z in outline],.034,'woodlight',n=6,closed=True)
 ring('Rope_Knot',(.02,y,1.237),.06,.023,'woodlight',axis='y',n=10)
finish('Timber_Pile','03_Resources')
# Workbench: real apron, joinery, anvil with waist/horn, vise, hammer and tongs.
start()
for x in [-1.2,1.2]:
 for y in [-.52,.52]:
  bevel('Oak_Leg',(x,y,.88),(.23,.23,1.76),'wood',.025)
  bevel('Foot_Band',(x,y,.14),(.254,.254,.13),'dark',.015)
  for z in [.5,1.57]:rod('Joinery_Peg',(x,y-.126,z),(x,y-.145,z),.032,'woodlight',n=8)
for y in [-.53,.53]:bevel('Apron_Rail',(0,y,1.51),(2.5,.14,.32),'wood',.018)
for x in [-1.2,1.2]:
 bevel('Lower_Crossbar',(x,0,.42),(.18,1.24,.19),'wood',.018)
 # bracing rods with square cross section, under worktop
 rod('Corner_Brace',(x,0,.8),(x,.52,1.49),.08,'wood',n=4)
for j in range(4):bevel('Shelf_Plank',(0,-.42+j*.28,.49),(2.45,.27,.1),'woodlight',.012)
for j in range(5):bevel('Top_Plank',(0,-.62+j*.31,1.83),(3.18,.297,.18),'woodlight' if j%2==0 else 'wood',.017)
for x in [-1.23,1.23]:
 for y in [-.61,.61]:rod('Top_Bolt',(x,y,1.922),(x,y,1.934),.032,'dark',n=8)
# Forged anvil, horn on right and rectangular heel left
bevel('Anvil_Foot',(.53,.1,2.005),(.83,.48,.16),'dark',.035)
bevel('Anvil_Waist',(.5,.1,2.18),(.33,.28,.26),'stone',.04)
bevel('Anvil_Face',(.46,.1,2.38),(.9,.39,.16),'edge',.025)
rod('Anvil_Horn',(.88,.1,2.345),(1.29,.1,2.355),.14,'edge',.016,n=8)
bevel('Hardy_Hole',(.13,.1,2.463),(.075,.07,.008),'dark',.008)
# leather working pad left, with securing tacks
bevel('Leather_Mat',(-.7,-.02,1.934),(.88,.86,.025),'cloth',.02)
for x in [-1.08,-.32]:
 for y in [-.37,.33]:rod('Mat_Rivet',(x,y,1.948),(x,y,1.962),.016,'copper',n=8)
rod('Hammer_Handle',(-.98,-.28,2.002),(-.53,.23,2.002),.04,'woodlight',n=8)
bevel('Hammer_Head',(-.53,.23,2.06),(.34,.14,.14),'edge',.025)
# tongs raised enough to have actual depth
polyline('Tongs_Left',[(-1.02,.31,1.98),(-.75,-.07,1.98),(-.48,-.3,1.98)],.018,'dark')
polyline('Tongs_Right',[(-.79,.37,1.99),(-.75,-.07,1.99),(-.64,-.37,1.99)],.018,'dark')
rod('Tongs_Pin',(-.75,-.07,1.98),(-.75,-.07,2.014),.032,'copper',n=8)
# front vise; distinct open jaws, screw and tommy bar
bevel('Vise_Fixed',(.95,-.8,1.8),(.4,.15,.32),'stone',.02)
bevel('Vise_Moving',(.95,-1.045,1.8),(.4,.12,.32),'dark',.025)
rod('Vise_Screw',(.95,-1.25,1.75),(.95,-.66,1.75),.045,'edge',n=10)
rod('Vise_Handle',(.75,-1.22,1.61),(1.15,-1.22,1.89),.025,'copper',n=8)
# ingots on lower shelf
for x in [-.57,-.15,.27]:bevel('Copper_Ingot',(x,0,.64),(.32,.38,.2),'copper',.04)
finish('Workbench','04_Structures')
# Resource differentiation: copper occurs as chunky seams, rift as tall crystals.
start();rock('Host_Rock',(0,0,.55),(1.05,.8,.66),'stone',7)
for i,(x,y,z) in enumerate([(-.55,-.38,.68),(-.2,-.6,.75),(.2,-.57,.73),(.52,-.28,.92),(.25,.15,1.09),(-.3,.13,1.01)]):
 rock('Copper_Seam',(x,y,z),(.26,.19,.22),'copper',i+10)
for i in range(3):rock('Loose_Stone',(.86*np.cos(i*2),.78*np.sin(i*2),.13),(.2,.2,.17),'dark',i)
finish('Copper_Deposit','03_Resources')
# Metal chest straps placed on the surface, rather than cutting through the lid.
start()
for j in range(5):bevel('Chest_Plank',(-.64+j*.32,0,.54),(.31,.94,1.02),'wood' if j%2 else 'woodlight',.012)
bevel('Lid',(0,0,1.12),(1.67,1.02,.2),'woodlight',.035)
for x in [-.59,.59]:
 for y in [-.489,.489]:bevel('Vertical_Band',(x,y,.58),(.1,.035,1.08),'dark',.008)
 bevel('Lid_Band',(x,0,1.23),(.1,1.0,.03),'dark',.006)
 for z in [.19,.95]:rod('Band_Rivet',(x,-.515,z),(x,-.534,z),.025,'copper',n=8)
bevel('Lock',(0,-.51,.88),(.2,.09,.28),'copper',.02);bevel('Keyhole',(0,-.562,.89),(.045,.01,.075),'dark',.005)
finish('Storage_Chest','04_Structures')

# Purpose-built enemy bodies with hierarchy-ready pivot groups.
exec((ROOT/'source'/'enemies_v2.py').read_text(),globals())
build_enemies()
# exporters + flat normals, components retain names and local pivots
manifest=[]
for name,a in A.items():
 folder=ROOT/'models'/a['category']/name;folder.mkdir(parents=True,exist_ok=True)
 # ground all objects
 minimum=min(p['v'][:,2].min() for p in a['parts'])
 for p in a['parts']:p['v'][:,2]-=minimum
 lines=['# RIFTBOUND | Z up | flat shaded',f'mtllib {name}.mtl'];offset=1
 for idx,p in enumerate(a['parts']):
  lines+=['o '+p['name']+'_'+str(idx),'usemtl '+p['mat']]
  lines+=['v %.6f %.6f %.6f'%tuple(v) for v in p['v']]
  lines+=['f '+' '.join(str(int(i)+offset) for i in tri) for tri in p['f']];offset+=len(p['v'])
 (folder/(name+'.obj')).write_text('\n'.join(lines))
 (folder/(name+'.mtl')).write_text('\n'.join(f'newmtl {k}\nKd {v[0]/255:.5f} {v[1]/255:.5f} {v[2]/255:.5f}\nKa 0 0 0\nKs 0 0 0\nd 1\nillum 1\n' for k,v in PALETTE.items()))
 g={'asset':{'version':'2.0','generator':'RIFTBOUND procedural asset builder'},'scene':0,'scenes':[{'nodes':[]}],'nodes':[],'meshes':[],'materials':[],'bufferViews':[],'accessors':[]};binary=bytearray()
 for k,col in PALETTE.items():
  c=[(v/255)**2.2 for v in col];m={'name':k,'pbrMetallicRoughness':{'baseColorFactor':c+[1],'metallicFactor':.35 if k in ['copper','gold'] else 0,'roughnessFactor':.8}}
  if k in ['rift','fire','ice']:m['emissiveFactor']=[v*.35 for v in c]
  g['materials'].append(m)
 joint_nodes={}; joint_mesh_nodes={}
 if name in ENEMY_RIGS:
  rig=ENEMY_RIGS[name]
  def cv(q): return [q[0],q[2],-q[1]]
  # A root plus nested empty pivot nodes lets Blender or a rigging workflow rotate
  # whole, named mesh groups around real shoulder, elbow, hip, knee and neck pivots.
  for j,spec in rig.items():
   joint_nodes[j]=len(g['nodes']);g['nodes'].append({'name':'RIG_'+j,'children':[]})
  for j,spec in rig.items():
   node=g['nodes'][joint_nodes[j]];parent=spec['parent'];pv=np.array(spec['pivot'],float);pv[2]-=minimum
   if parent is None:
    node['translation']=cv(pv);g['scenes'][0]['nodes'].append(joint_nodes[j])
   else:
    parent_pv=np.array(rig[parent]['pivot'],float);parent_pv[2]-=minimum;node['translation']=cv(pv-parent_pv)
    g['nodes'][joint_nodes[parent]]['children'].append(joint_nodes[j])
  for pi,p in enumerate(a['parts']):
   j=p.get('joint','Torso');node_i=joint_nodes[j];mesh_i=len(g['nodes'])
   joint_mesh_nodes[pi]=mesh_i
   g['nodes'].append({'name':p['name']+'_Mesh','mesh':pi,'translation':[0,0,0]})
   g['nodes'][node_i]['children'].append(mesh_i)
 def accessor(arr,typ):
  while len(binary)%4:binary.append(0)
  index=len(g['bufferViews']);g['bufferViews'].append({'buffer':0,'byteOffset':len(binary),'byteLength':arr.nbytes});binary.extend(arr.astype('<f4').tobytes())
  out={'bufferView':index,'componentType':5126,'count':len(arr),'type':typ}
  if typ=='VEC3':out.update(min=arr.min(axis=0).tolist(),max=arr.max(axis=0).tolist())
  g['accessors'].append(out);return len(g['accessors'])-1
 for i,p in enumerate(a['parts']):
  v=p['v'];center=v.mean(axis=0);flat=(v[p['f']]-center).reshape(-1,3);norm=np.cross(flat[1::3]-flat[::3],flat[2::3]-flat[::3]);norm/=np.linalg.norm(norm,axis=1)[:,None];norm=np.repeat(norm,3,axis=0)
  # z-up to y-up: (x,z,-y)
  flat=flat[:,[0,2,1]]*np.array([1,1,-1]);norm=norm[:,[0,2,1]]*np.array([1,1,-1]);c=[center[0],center[2],-center[1]]
  pos=accessor(flat.astype(np.float32),'VEC3');nrm=accessor(norm.astype(np.float32),'VEC3')
  g['meshes'].append({'name':p['name']+'_'+str(i),'primitives':[{'attributes':{'POSITION':pos,'NORMAL':nrm},'material':list(PALETTE).index(p['mat'])}]})
  if name in ENEMY_RIGS:
   pivot=np.array(ENEMY_RIGS[name][p.get('joint','Torso')]['pivot'],float);pivot[2]-=minimum
   mesh_node=g['nodes'][joint_mesh_nodes[i]];delta=center-pivot;mesh_node['translation']=[delta[0],delta[2],-delta[1]]
  else:
   g['nodes'].append({'name':p['name']+'_'+str(i),'mesh':i,'translation':c});g['scenes'][0]['nodes'].append(i)
 g['buffers']=[{'byteLength':len(binary),'uri':name+'.bin'}];(folder/(name+'.gltf')).write_text(json.dumps(g,separators=(',',':')));(folder/(name+'.bin')).write_bytes(binary)
 vertices=np.concatenate([p['v'] for p in a['parts']]);manifest.append({'name':name,'category':a['category'],'triangles':sum(len(p['f']) for p in a['parts']),'parts':len(a['parts']),'dimensions_xyz':(vertices.max(0)-vertices.min(0)).round(3).tolist(),'joint_pivot_hierarchy':name in ENEMY_RIGS,'joint_pivots':len(ENEMY_RIGS[name]) if name in ENEMY_RIGS else 0})
(ROOT/'manifest.json').write_text(json.dumps(manifest,indent=2))
(ROOT/'rigs.json').write_text(json.dumps(ENEMY_RIGS,indent=2))

from render_preview import render_all
render_all(A,PALETTE,ROOT,manifest)
print("Generated",len(A),"assets")
