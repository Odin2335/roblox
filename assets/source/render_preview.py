"""Orthographic mesh renderer with per-pixel depth, antialiasing and flat lighting."""
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw,ImageFont,ImageFilter
FONT='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf';BOLD='/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
def font(n,b=False):return ImageFont.truetype(BOLD if b else FONT,n)
def render(parts,palette,width,height,cam=(.95,-1.85,1.08)):
 ss=2;w=width*ss;h=height*ss;cam=np.array(cam,float);cam/=np.linalg.norm(cam);right=np.cross([0,0,1],cam);right/=np.linalg.norm(right);up=np.cross(cam,right)
 allv=np.concatenate([p['v'] for p in parts]);xy=np.column_stack((allv@right,allv@up));lo=xy.min(0);hi=xy.max(0);center=(lo+hi)/2;scale=min(w*.84/(hi[0]-lo[0]),h*.84/(hi[1]-lo[1]))
 bg=np.zeros((h,w,3),np.float32)
 for y in range(h):bg[y,:,:]=np.array([28,44,55])+(1-y/h)*np.array([8,9,10])
 # soft contact ellipse
 shadow=Image.new('L',(w,h));d=ImageDraw.Draw(shadow);d.ellipse((w*.17,h*.79,w*.84,h*.96),fill=100);shadow=shadow.filter(ImageFilter.GaussianBlur(17*ss));bg*=1-np.array(shadow)[:,:,None]/255*.42
 depths=np.full((h,w),-np.inf);key=np.array([-1,-1.5,2.8]);key/=np.linalg.norm(key);fill=np.array([2,.5,1]);fill/=np.linalg.norm(fill)
 for p in parts:
  for face in p['f']:
   vs=p['v'][face];normal=np.cross(vs[1]-vs[0],vs[2]-vs[0]);normal/=np.linalg.norm(normal)
   if normal@cam<=1e-8:continue
   pp=np.column_stack((vs@right,vs@up));pp=(pp-center)*scale;pp[:,0]+=w/2;pp[:,1]=h*.49-pp[:,1];zz=vs@cam
   x0=max(0,int(np.floor(pp[:,0].min())));x1=min(w-1,int(np.ceil(pp[:,0].max())));y0=max(0,int(np.floor(pp[:,1].min())));y1=min(h-1,int(np.ceil(pp[:,1].max())))
   if x1<x0 or y1<y0:continue
   xx,yy=np.meshgrid(np.arange(x0,x1+1)+.5,np.arange(y0,y1+1)+.5)
   a,b,c=pp;den=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
   if abs(den)<1e-9:continue
   wa=((b[1]-c[1])*(xx-c[0])+(c[0]-b[0])*(yy-c[1]))/den
   wb=((c[1]-a[1])*(xx-c[0])+(a[0]-c[0])*(yy-c[1]))/den;wc=1-wa-wb
   depth=wa*zz[0]+wb*zz[1]+wc*zz[2];dest=depths[y0:y1+1,x0:x1+1];mask=(wa>=-1e-7)&(wb>=-1e-7)&(wc>=-1e-7)&(depth>dest)
   dest[mask]=depth[mask];shade=.52+.42*max(0,normal@key)+.14*max(0,normal@fill)
   if p['mat'] in ['rift','fire','ice']:shade=.89+.11*max(0,normal@key)
   color=np.clip(np.array(palette[p['mat']])*shade,0,255);bg[y0:y1+1,x0:x1+1][mask]=color
 return Image.fromarray(bg.astype('uint8')).resize((width,height),Image.Resampling.LANCZOS)
def render_all(assets,palette,root,manifest):
 W,H=1920,2130;im=Image.new('RGB',(W,H),(13,23,32));d=ImageDraw.Draw(im)
 d.text((60,35),'RIFTBOUND',font=font(54,True),fill=(230,242,240));d.text((62,106),'ASSET PACK / REVISION 02',font=font(20),fill=(97,218,190))
 stats={a['name']:a for a in manifest}
 for idx,(name,a) in enumerate(assets.items()):
  row,col=divmod(idx,4);x=40+col*470;y=160+row*472
  d.rounded_rectangle((x,y,x+448,y+451),18,fill=(28,44,55),outline=(46,67,79),width=1)
  pic=render(a['parts'],palette,430,340);im.paste(pic,(x+9,y+9))
  d.text((x+19,y+367),name.replace('_',' ').upper(),font=font(18,True),fill=(234,242,240))
  d.text((x+19,y+402),f"{a['category'][3:]}  /  {stats[name]['triangles']:,} triangles",font=font(15),fill=(140,165,172))
 d.text((60,2088),'ACTUAL MESH RENDERS  /  OBJ + glTF  /  STATIC MODELS',font=font(17),fill=(124,153,165))
 im.save(root/'RIFTBOUND_Preview.png')
 hero=Image.new('RGB',(1920,850),(13,23,32));dr=ImageDraw.Draw(hero)
 dr.text((45,30),'RIFTBOUND / REBUILT PROPS',font=font(38,True),fill=(232,244,240));dr.text((47,83),'REVISION 02 - REAL 3D GEOMETRY',font=font(17),fill=(97,218,190))
 for i,name in enumerate(['Grapple_Launcher','Timber_Pile','Workbench']):
  x=30+i*635
  pic=render(assets[name]['parts'],palette,600,540)
  hero.paste(pic,(x,140));dr.text((x+18,705),name.replace('_',' ').upper(),font=font(23,True),fill=(232,244,240))
  subtitle=['Exposed rope reel / three-prong hook','Clean end grain / fitted rope bindings','Forged anvil / screw vise / joinery'][i]
  dr.text((x+18,746),subtitle,font=font(17),fill=(144,170,178))
 hero.save(root/'RIFTBOUND_Detail_Preview.png')
 # Focused sheet for the six MVP enemies.
 enemy=Image.new('RGB',(1920,1800),(13,23,32));ed=ImageDraw.Draw(enemy)
 ed.text((45,24),'RIFTBOUND / ENEMY REVISION',font=font(39,True),fill=(232,244,240))
 ed.text((47,78),'DISTINCT SILHOUETTES / NAMED MESH GROUPS / HIERARCHICAL PIVOTS',font=font(16),fill=(97,218,190))
 enemy_names=['Riftling','Rootstalker','Hollow_Warden','Lantern_Wraith','Rift_Crawler','Burrow_Mimic']
 for i,name in enumerate(enemy_names):
  row,col=divmod(i,3);x=30+col*635;y=125+row*825
  ed.rounded_rectangle((x,y,x+610,y+790),18,fill=(23,37,47),outline=(46,67,79),width=1)
  pic=render(assets[name]['parts'],palette,585,650)
  enemy.paste(pic,(x+12,y+13))
  ed.text((x+22,y+678),name.replace('_',' ').upper(),font=font(25,True),fill=(232,244,240))
  ed.text((x+22,y+719),f"{stats[name]['parts']} mesh groups / {stats[name]['joint_pivots']} pivots",font=font(16),fill=(137,171,176))
  ed.text((x+22,y+748),'Ready for animation setup in Blender',font=font(15),fill=(137,171,176))
 enemy.save(root/'RIFTBOUND_Enemies_Preview.png')
 # secondary angle to inspect intersections and concealed surfaces
 checks=Image.new('RGB',(1800,700),(13,23,32))
 for i,name in enumerate(['Grapple_Launcher','Timber_Pile','Workbench']):checks.paste(render(assets[name]['parts'],palette,600,660,cam=(-1.6,-1.4,.85)),(i*600,20))
 checks.save(root/'RIFTBOUND_Alternate_View.png')
