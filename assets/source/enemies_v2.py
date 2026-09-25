from contextlib import contextmanager

@contextmanager
def joint(name):
    global ACTIVE_JOINT
    old=ACTIVE_JOINT; ACTIVE_JOINT=name
    try: yield
    finally: ACTIVE_JOINT=old

# Absolute joint positions use the same Z-up coordinates as the source meshes.
ENEMY_RIGS={}
def rig_for(name, specs):
    ENEMY_RIGS[name]={'Root':{'parent':None,'pivot':[0,0,0]}}
    for j,parent,pivot in specs: ENEMY_RIGS[name][j]={'parent':parent,'pivot':pivot}

def build_enemies():
    for n in ['Riftling','Rootstalker','Hollow_Warden','Lantern_Wraith','Rift_Crawler','Burrow_Mimic']: A.pop(n,None)
    # Quick imp with a compact, armoured torso, twin horns and oversized forearm blades.
    start()
    with joint('Torso'):
        rock('Body',(0,0,1.42),(.54,.39,.60),'stone',13);rock('Shoulder_Carapace',(0,.02,1.81),(.62,.38,.30),'stone',7)
        bevel('Chest_Plate',(0,-.33,1.57),(.53,.15,.4),'edge',.04);crystal('Heart',(0,-.42,1.56),.11,.28,'rift')
        bevel('Belt',(0,0,1.03),(.73,.55,.15),'copper',.025)
    with joint('Head'):
        rock('Head',(0,-.03,2.16),(.43,.37,.40),'stone',12);bevel('Face_Mask',(0,-.35,2.11),(.58,.16,.27),'dark',.05)
        for s in [-1,1]:
            bevel('Eye',(s*.16,-.444,2.16),(.15,.035,.105),'rift',.012)
            rod('Horn',(s*.22,0,2.37),(s*.32,0,2.72),.11,'dark',.015,n=7)
            crystal('Horn_Tip',(s*.32,0,2.70),.052,.13,'copper',(s*.03,0))
    for s,side in [(-1,'Left'),(1,'Right')]:
        with joint(side+'UpperArm'):
            rock('Shoulder',(s*.51,0,1.75),(.29,.36,.31),'edge',3)
            rod('Upper_Arm',(s*.53,0,1.68),(s*.67,-.02,1.39),.16,'dark',.13,n=7)
        with joint(side+'Forearm'):
            rock('Gauntlet',(s*.68,-.03,1.23),(.29,.35,.39),'stone',5)
            rod('Blade_Spike',(s*.77,-.03,1.43),(s*1.03,-.08,1.08),.09,'copper',.006,n=6)
            for j in range(3):bevel('Rivet',(s*(.59+j*.08),-.19,1.27-j*.05),(.05,.025,.05),'gold',.006)
        with joint(side+'Hand'):
            rock('Fist',(s*.71,-.12,.9),(.22,.22,.2),'dark',4)
            for j in range(3):rod('Claw',(s*(.62+j*.09),-.24,.88),(s*(.61+j*.1),-.38,.72),.04,'copper',.005,n=5)
        with joint(side+'Thigh'):
            rod('Thigh',(s*.23,0,.97),(s*.24,0,.49),.15,'dark',.12,n=7)
            bevel('Knee',(s*.24,-.25,.48),(.24,.12,.17),'copper',.02)
            rod('Shin',(s*.24,0,.43),(s*.25,0,.2),.11,'edge',.075,n=7)
        with joint(side+'Foot'):
            rock('Boot',(s*.25,-.1,.14),(.27,.42,.16),'stone',4)
            for j in [-1,1]:rod('Toe_Claw',(s*.25+j*.07,-.29,.12),(s*.25+j*.08,-.41,.07),.022,'copper',.004,n=5)
    finish('Riftling','02_Enemies')
    rig_for('Riftling',[
        ('Torso','Root',[0,0,1.18]),('Head','Torso',[0,0,2.0]),
        ('LeftUpperArm','Torso',[-.43,0,1.68]),('LeftForearm','LeftUpperArm',[-.67,0,1.32]),('LeftHand','LeftForearm',[-.69,-.08,.99]),
        ('RightUpperArm','Torso',[.43,0,1.68]),('RightForearm','RightUpperArm',[.67,0,1.32]),('RightHand','RightForearm',[.69,-.08,.99]),
        ('LeftThigh','Torso',[-.22,0,.92]),('LeftFoot','LeftThigh',[-.24,0,.27]),('RightThigh','Torso',[.22,0,.92]),('RightFoot','RightThigh',[.24,0,.27])])

    # Tree revenant: narrow hunched trunk, split mask, branch antlers and long root fingers.
    start()
    with joint('Torso'):
        rock('Trunk',(0,.04,1.46),(.50,.42,.76),'wood',21);bevel('Bark_Cuirass',(0,-.3,1.62),(.7,.22,.67),'bark',.055)
        crystal('Exposed_Rift',(0,-.43,1.45),.15,.36,'rift')
        for s in [-1,1]:
            for j in range(3):rod('Rib_Vine',(s*.1,-.43,1.83-j*.18),(s*.3,-.4,1.77-j*.18),.023,'moss',.01,n=5)
    with joint('Head'):
        rock('Skull',(0,-.03,2.48),(.34,.3,.42),'bark',4);bevel('Split_Mask',(0,-.28,2.5),(.68,.2,.46),'woodlight',.065)
        bevel('Face_Slit',(0,-.40,2.49),(.4,.035,.095),'dark',.02)
        for s in [-1,1]:
            bevel('Eye',(s*.14,-.423,2.54),(.105,.03,.05),'rift',.008)
            rod('Antler',(s*.21,0,2.8),(s*.39,0,3.16),.09,'woodlight',.045,n=7)
            rod('Antler_Branch',(s*.39,0,3.16),(s*.57,0,3.28),.045,'bark',.01,n=5)
            rod('Antler_Tip',(s*.39,0,3.16),(s*.34,0,3.43),.045,'woodlight',.006,n=5)
        crystal('Moss_Crown',(0,.04,2.85),.09,.4,'moss',(0,.06))
    for s,side in [(-1,'Left'),(1,'Right')]:
        with joint(side+'UpperArm'):
            rock('Root_Shoulder',(s*.44,0,1.88),(.27,.32,.26),'bark',10)
            rod('Branch_Arm',(s*.45,0,1.85),(s*.72,-.06,1.57),.15,'bark',.1,n=7)
            for j in [-1,1]:rod('Shoulder_Thorn',(s*.48,-.06,1.93),(s*.71,-.1,1.98+j*.1),.04,'woodlight',.006,n=5)
        with joint(side+'Forearm'):
            rock('Elbow_Knot',(s*.72,-.05,1.53),(.22,.24,.22),'woodlight',5)
            rod('Long_Tendril',(s*.72,-.05,1.53),(s*.97,-.13,1.3),.12,'bark',.07,n=7)
        with joint(side+'Hand'):
            rock('Palm',(s*.99,-.14,1.28),(.17,.18,.19),'woodlight',4)
            for j in range(4):
                xx=s*(.99+(j-1.5)*.075); spread=s*(j-1.5)*.075
                rod('Root_Finger',(xx,-.17,1.28),(xx+spread,-.25,1.00),.04,'bark',.02,n=5)
                rod('Hooked_Nail',(xx+spread,-.25,1.01),(xx+spread+s*.035,-.3,1.09),.023,'moss',.004,n=5)
        with joint(side+'Thigh'):
            rock('Root_Hip',(s*.24,0,1.01),(.23,.29,.32),'bark',9)
            rod('Bent_Leg',(s*.24,0,.99),(s*.27,-.02,.55),.14,'woodlight',.09,n=7)
            crystal('Knee_Moss',(s*.27,-.14,.57),.08,.18,'moss')
            rod('Lower_Root_Shin',(s*.27,-.02,.55),(s*.27,-.02,.25),.085,'bark',.06,n=6)
        with joint(side+'Foot'):
            for j in [-1,0,1]:
                xx=s*.27+j*.08;rod('Root_Toe',(xx,-.02,.24),(xx,-.34-abs(j)*.03,.045),.065,'bark',.018,n=5)
                rod('Toe_Claw',(xx,-.34-abs(j)*.03,.045),(xx,-.45-abs(j)*.03,.025),.028,'woodlight',.004,n=5)
    finish('Rootstalker','02_Enemies')
    rig_for('Rootstalker',[
        ('Torso','Root',[0,0,1.32]),('Head','Torso',[0,0,2.34]),
        ('LeftUpperArm','Torso',[-.38,0,1.87]),('LeftForearm','LeftUpperArm',[-.69,-.03,1.55]),('LeftHand','LeftForearm',[-.96,-.12,1.3]),
        ('RightUpperArm','Torso',[.38,0,1.87]),('RightForearm','RightUpperArm',[.69,-.03,1.55]),('RightHand','RightForearm',[.96,-.12,1.3]),
        ('LeftThigh','Torso',[-.23,0,1.0]),('LeftFoot','LeftThigh',[-.27,0,.3]),('RightThigh','Torso',[.23,0,1.0]),('RightFoot','RightThigh',[.27,0,.3])])

    # Hollow Warden boss: broad plated frame, massive fists, exposed rift core and antlered helm.
    start()
    with joint('Torso'):
        rock('Armoured_Torso',(0,.02,2.55),(1.02,.58,1.0),'stone',31)
        bevel('Breastplate',(0,-.4,2.79),(1.67,.23,1.28),'stone',.11);bevel('Lower_Cuirass',(0,-.35,2.0),(1.26,.2,.44),'dark',.06)
        for s in [-1,1]:
            bevel('Pectoral',(s*.43,-.53,3.01),(.68,.16,.46),'edge',.05);bevel('Waist_Band',(s*.34,-.47,2.17),(.58,.12,.17),'copper',.03)
            for j in range(3):bevel('Rib_Plate',(s*(.25+j*.15),-.55,2.6-j*.17),(.22,.07,.085),'dark',.02)
        bevel('Core_Frame',(0,-.62,2.68),(.59,.15,.8),'copper',.07);crystal('Heart_Core',(0,-.72,2.4),.22,.6,'rift',(0,.07))
        for s in [-1,1]:rod('Core_Cage',(s*.22,-.70,2.43),(s*.17,-.69,3.0),.03,'gold',n=6)
        for s in [-1,1]:
            for j in range(2):rod('Back_Spike',(s*.77,.34,3.05+j*.1),(s*(1.17+j*.16),.48,3.32+j*.19),.09,'dark',.01,n=6)
    with joint('Head'):
        rock('Hollow_Helm',(0,0,3.82),(.48,.43,.53),'dark',8);bevel('Faceplate',(0,-.4,3.8),(.72,.18,.44),'stone',.07)
        bevel('Visor',(0,-.51,3.8),(.55,.04,.13),'dark',.02)
        for s in [-1,1]:
            bevel('Eye',(s*.18,-.54,3.8),(.16,.035,.055),'rift',.008)
            rod('Crown_Horn',(s*.3,0,4.1),(s*.44,.02,4.55),.14,'woodlight',.065,n=7)
            rod('Horn_Barb',(s*.44,.02,4.55),(s*.65,.02,4.65),.07,'copper',.008,n=6)
            crystal('Crown_Crystal',(s*.14,.06,4.1),.11,.42,'rift',(s*.08,.02))
    for s,side in [(-1,'Left'),(1,'Right')]:
        with joint(side+'UpperArm'):
            rock('Pauldron',(s*1.12,0,3.05),(.61,.61,.56),'edge',15)
            for j in range(3):crystal('Pauldron_Spike',(s*(.91+j*.19),-.03,3.39),.13,.44+j*.09,'rift',(s*.1,0))
            rod('Armour_Trim',(s*.95,-.43,3.05),(s*1.48,-.43,3.05),.045,'copper',n=6)
            rod('Bicep',(s*1.18,0,2.9),(s*1.43,-.02,2.5),.27,'dark',.22,n=8)
        with joint(side+'Forearm'):
            rock('Gauntlet',(s*1.47,-.05,2.16),(.43,.45,.58),'stone',17);bevel('Gauntlet_Plate',(s*1.47,-.3,2.2),(.39,.12,.38),'edge',.05)
            for j in range(3):rod('Gauntlet_Ridge',(s*(1.34+j*.13),-.37,2.29),(s*(1.34+j*.13),-.38,1.99),.023,'copper',n=5)
        with joint(side+'Hand'):
            rock('Fist',(s*1.55,-.16,1.62),(.4,.42,.32),'dark',9)
            for j in [-1,0,1]:rod('Knuckle',(s*1.55+j*.1,-.36,1.7),(s*1.55+j*.1,-.38,1.8),.06,'copper',n=6)
            for j in [-1,1]:rod('Claw',(s*1.55+j*.13,-.18,1.5),(s*1.55+j*.18,-.38,1.37),.055,'edge',.006,n=6)
        with joint(side+'Thigh'):
            rock('Armoured_Thigh',(s*.53,0,1.35),(.44,.48,.6),'dark',6);bevel('Thigh_Plate',(s*.53,-.29,1.4),(.53,.12,.37),'stone',.04)
            rod('Greave',(s*.54,0,1.05),(s*.57,-.03,.49),.23,'edge',.15,n=8);bevel('Greave_Ridge',(s*.57,-.22,.77),(.15,.09,.52),'copper',.02)
        with joint(side+'Foot'):
            rock('Iron_Boot',(s*.57,-.17,.23),(.51,.64,.25),'stone',9)
            for j in [-1,0,1]:bevel('Toe_Spike',(s*.57+j*.14,-.48,.16),(.12,.27,.1),'dark',.015)
    finish('Hollow_Warden','02_Enemies')
    rig_for('Hollow_Warden',[
        ('Torso','Root',[0,0,2.03]),('Head','Torso',[0,0,3.65]),
        ('LeftUpperArm','Torso',[-1.05,0,3.0]),('LeftForearm','LeftUpperArm',[-1.42,-.03,2.4]),('LeftHand','LeftForearm',[-1.55,-.14,1.64]),
        ('RightUpperArm','Torso',[1.05,0,3.0]),('RightForearm','RightUpperArm',[1.42,-.03,2.4]),('RightHand','RightForearm',[1.55,-.14,1.64]),
        ('LeftThigh','Torso',[-.52,0,1.3]),('LeftFoot','LeftThigh',[-.57,-.16,.3]),('RightThigh','Torso',[.52,0,1.3]),('RightFoot','RightThigh',[.57,-.16,.3])])

    # Ghostly lantern hunter: deep hood, blank face, chain-hung spirit light,
    # ragged tapered robe and elongated grasping hands.
    start()
    with joint('Torso'):
        rock('Robe_Core',(0,.06,1.45),(.48,.34,.8),'dark',33)
        prism('Robe_Front',[(-.32,.16),(.32,.16),(.65,.03),(.75,.04),(.63,.8),(.42,1.25),(-.42,1.25),(-.63,.8),(-.75,.04),(-.65,.03)],.18,'cloth')
        prism('Robe_Back',[(-.32,.13),(.32,.13),(.68,.02),(.56,.83),(.39,1.28),(-.39,1.28),(-.56,.83),(-.68,.02)],.15,'dark')
        bevel('Chest_Cage',(0,-.31,1.63),(.63,.12,.63),'edge',.07)
        for s in [-1,1]:
            for j in range(3):rod('Rib',(s*.13,-.39,1.87-j*.18),(s*.3,-.36,1.79-j*.18),.027,'copper',.012,n=5)
        crystal('Captured_Flame',(0,-.44,1.63),.14,.46,'rift',(0,.05))
        for s in [-1,1]:rod('Cage_Bar',(s*.23,-.42,1.38),(s*.18,-.41,1.99),.025,'copper',n=5)
    with joint('Head'):
        rock('Cowl',(0,.03,2.62),(.54,.42,.49),'dark',16)
        # Tall open crown silhouette around a recessed, eyeless face.
        prism('Hood_Opening',[(-.37,2.39),(-.31,2.93),(-.21,3.18),(0,3.28),(.21,3.18),(.31,2.93),(.37,2.39)],.25,'edge')
        bevel('Face_Void',(0,-.39,2.68),(.47,.05,.56),'dark',.08)
        for s in [-1,1]:
            crystal('Wisp_Eye',(s*.13,-.431,2.8),.055,.09,'rift')
            rod('Hood_Horn',(s*.31,0,2.87),(s*.46,.02,3.38),.105,'bark',.03,n=6)
            rod('Hood_Barb',(s*.46,.02,3.38),(s*.64,.02,3.47),.04,'copper',.005,n=5)
        prism('Mask_Bottom',[(-.23,2.52),(0,2.36),(.23,2.52),(0,2.59)],.11,'edge')
    for s,side in [(-1,'Left'),(1,'Right')]:
        with joint(side+'UpperArm'):
            rock('Sleeve',(s*.48,0,1.99),(.25,.32,.4),'cloth',18)
            rod('Long_Arm',(s*.52,0,1.91),(s*.64,-.04,1.4),.115,'dark',.08,n=6)
        with joint(side+'Forearm'):
            rod('Thin_Forearm',(s*.64,-.04,1.41),(s*.73,-.09,.94),.08,'edge',.055,n=6)
        with joint(side+'Hand'):
            rock('Palm',(s*.74,-.12,.86),(.13,.16,.15),'dark',8)
            for j in range(4):
                x=s*(.74+(j-1.5)*.065);rod('Long_Finger',(x,-.16,.82),(x+s*(j-1.5)*.03,-.2,.48-abs(j-1.5)*.04),.027,'edge',.012,n=5)
    with joint('LanternChain'):
        polyline('Chain',[( -.45,0,1.95),(-.64,0,1.61),(-.76,-.02,1.29),(-.8,-.03,.99)],.023,'copper')
        bevel('Lantern_Top',(-.8,-.03,.94),(.33,.28,.12),'copper',.03)
        for s in [-1,1]:rod('Lantern_Frame',(-.8+s*.13,-.03,.91),(-.8+s*.1,-.03,.47),.025,'edge',n=5)
        bevel('Lantern_Base',(-.8,-.03,.45),(.24,.21,.08),'copper',.02)
        crystal('Lantern_Flame',(-.8,-.18,.54),.075,.27,'rift')
    with joint('LeftThigh'):
        prism('Tattered_Hem',[(-.18,.52),(.18,.52),(.35,.04),(.23,.26),(.1,.02),(0,.34),(-.12,.01),(-.23,.28),(-.34,.04)],.12,'cloth')
    finish('Lantern_Wraith','02_Enemies')
    rig_for('Lantern_Wraith',[
        ('Torso','Root',[0,0,1.45]),('Head','Torso',[0,0,2.42]),('LanternChain','Torso',[-.45,0,1.95]),
        ('LeftUpperArm','Torso',[-.43,0,1.98]),('LeftForearm','LeftUpperArm',[-.63,-.03,1.4]),('LeftHand','LeftForearm',[-.72,-.08,.95]),
        ('RightUpperArm','Torso',[.43,0,1.98]),('RightForearm','RightUpperArm',[.63,-.03,1.4]),('RightHand','RightForearm',[.72,-.08,.95]),
        ('LeftThigh','Torso',[-.2,0,.75])])

    # Six-legged rift crawler with split jaw, clustered eyes, plated back and hooked feet.
    start()
    with joint('Torso'):
        rock('Abdomen',(0,.4,.78),(.68,.83,.53),'dark',42)
        for i in range(4):
            x=(i-1.5)*.25;bevel('Carapace_Plate',(x,.12,.98),(.24,.82,.48),'stone' if i%2 else 'edge',.06)
        crystal('Dorsal_Shard',(0,.38,1.21),.2,.49,'rift',(0,.08))
        rock('Thorax',(0,-.23,.79),(.48,.46,.43),'bark',11)
    with joint('Head'):
        rock('Skull',(0,-.55,.84),(.49,.36,.4),'edge',18)
        bevel('Eye_Socket',(0,-.87,1.02),(.65,.12,.31),'dark',.07)
        for x,z,r in [(-.22,1.06,.09),(0,1.1,.11),(.22,1.06,.09)]:
            crystal('Cluster_Eye',(x,-.95,z),r,.07,'rift')
        bevel('Mouth_Cavity',(0,-.91,.76),(.47,.09,.28),'dark',.04)
        for s in [-1,1]:
            for j in range(3):
                x=s*(.1+j*.1);z=.87-j*.065
                rod('Upper_Fang',(x,-.98,z),(x,-1.02,z-.12),.036,'ice',.006,n=5)
                rod('Lower_Fang',(x,-.98,.67),(x,-1.01,.78),.03,'copper',.005,n=5)
    # Pivoted leg pairs, each split at the knee. Pose-ready but not animated.
    for i,(sx,sy,side) in enumerate([(-1,-.32,'L1'),(1,-.32,'R1'),(-1,.05,'L2'),(1,.05,'R2'),(-1,.42,'L3'),(1,.42,'R3')]):
        hip=(sx*.34,sy,.82);knee=(sx*.77,sy-.12,.55);tip=(sx*1.05,sy-.38,.12)
        with joint(side+'UpperLeg'):rod('Armoured_Femur',hip,knee,.15,'stone',.085,n=7)
        with joint(side+'LowerLeg'):
            rock('Knee_Knot',knee,(.17,.17,.17),'copper',i+5);rod('Hooked_Shin',knee,tip,.105,'dark',.035,n=6)
            rod('Foot_Hook',tip,(tip[0]+sx*.09,tip[1]-.16,tip[2]-.08),.045,'edge',.005,n=5)
        with joint('Torso'): crystal('Leg_Node',(hip[0],hip[1],hip[2]),.09,.14,'rift')
    finish('Rift_Crawler','02_Enemies')
    ENEMY_RIGS['Rift_Crawler']={'Root':{'parent':None,'pivot':[0,0,0]},'Torso':{'parent':'Root','pivot':[0,0,.78]},'Head':{'parent':'Torso','pivot':[0,-.43,.86]}}
    for i,(sx,sy,side) in enumerate([(-1,-.32,'L1'),(1,-.32,'R1'),(-1,.05,'L2'),(1,.05,'R2'),(-1,.42,'L3'),(1,.42,'R3')]):
        knee=[sx*.77,sy-.12,.55];hip=[sx*.34,sy,.82]
        ENEMY_RIGS['Rift_Crawler'][side+'UpperLeg']={'parent':'Torso','pivot':hip}
        ENEMY_RIGS['Rift_Crawler'][side+'LowerLeg']={'parent':side+'UpperLeg','pivot':knee}

    # Burrow mimic: weathered supply chest with a hinged biting lid, teeth,
    # glowing eye-stalks and four bent root legs.
    start()
    def hinge_bevel(name,center,size,mat):
        c=np.array(center,float);half=np.array(size,float)/2;b=min(.03,min(half)*.75);verts=[]
        for axis in range(3):
            for sign in [-1,1]:
                other=[j for j in range(3) if j!=axis]
                for u in [-1,1]:
                    for v in [-1,1]:
                        q=np.zeros(3);q[axis]=sign*half[axis];q[other[0]]=u*(half[other[0]]-b);q[other[1]]=v*(half[other[1]]-b)
                        point=c+q;hinge=np.array([0,.43,1.12]);rel=point-hinge;ang=-math.radians(58)
                        rot=np.array([rel[0],rel[1]*math.cos(ang)-rel[2]*math.sin(ang),rel[1]*math.sin(ang)+rel[2]*math.cos(ang)])
                        verts.append(hinge+rot)
        hull(verts,name,mat)
    with joint('Torso'):
        bevel('Chest_Core',(0,0,.64),(1.23,.88,.91),'bark',.07)
        for i in range(5):bevel('Front_Wood_Panel',(-.49+i*.245,-.451,.61),(.23,.035,.78),'wood' if i%2 else 'woodlight',.015)
        bevel('Mouth_Interior',(0,-.50,.90),(1.02,.08,.56),'dark',.045)
        bevel('Lower_Jaw',(0,-.51,.65),(1.27,.12,.2),'woodlight',.025)
        for s in [-1,1]:
            for j in range(4):
                x=s*(.12+j*.095);rod('Lower_Tooth',(x,-.58,.65),(x,-.61,.88),.043,'ice',.006,n=5)
        crystal('Tongue',(0,-.59,.79),.1,.35,'rift',(0,-.08))
        for x in [-.47,.47]:
            bevel('Iron_Corner',(x,-.47,.36),(.12,.08,.67),'dark',.015)
            for z in [.22,.48,.75]:rod('Copper_Rivet',(x,-.53,z),(x,-.55,z),.025,'copper',n=6)
    with joint('Jaw'):
        hinge_bevel('Hinged_Upper_Jaw',(0,-.04,1.28),(1.38,.99,.22),'woodlight')
        for x in [-.58,-.29,0,.29,.58]:
            hinge_bevel('Lid_Plank',(x,-.04,1.405),(.25,.9,.07),'wood' if x else 'bark')
        for s in [-1,1]:
            bevel('Lid_Horn',(s*.5,-.14,1.55),(.19,.2,.28),'edge',.035)
            for j in range(3):
                x=s*(.11+j*.14);rod('Upper_Tooth',(x,-.25,1.55),(x,-.45,1.29),.039,'ice',.005,n=5)
            rod('Hinge',(s*.51,.42,1.0),(s*.51,.47,1.28),.08,'copper',n=8)
        for x in [-.45,.45]:
            rock('Eyestalk_Base',(x,-.14,1.34),(.13,.14,.12),'dark',3)
            rod('Eyestalk',(x,-.14,1.36),(x*1.2,-.17,1.68),.045,'bark',.025,n=6)
            crystal('Mimic_Eye',(x*1.2,-.18,1.68),.075,.12,'rift')
    for s,side in [(-1,'Left'),(1,'Right')]:
        for j,depth in enumerate([-.29,.31]):
            limb=side+('Front' if j==0 else 'Back')+'Leg';hip=(s*.46,depth,.48);knee=(s*.76,depth-.07,.26);foot=(s*.9,depth-.22,.09)
            with joint(limb+'Upper'):
                rod('Root_Femur',hip,knee,.11,'bark',.065,n=6)
                rock('Knee_Node',knee,(.14,.15,.13),'woodlight',j+3)
            with joint(limb+'Lower'):
                rod('Root_Shin',knee,foot,.07,'dark',.04,n=6)
                for k in [-1,1]:rod('Mimic_Claw',(foot[0],foot[1],foot[2]),(foot[0]+s*k*.07,foot[1]-.11,foot[2]-.06),.027,'ice',.004,n=5)
    finish('Burrow_Mimic','02_Enemies')
    ENEMY_RIGS['Burrow_Mimic']={'Root':{'parent':None,'pivot':[0,0,0]},'Torso':{'parent':'Root','pivot':[0,0,.55]},'Jaw':{'parent':'Torso','pivot':[0,.42,1.12]}}
    for s,side in [(-1,'Left'),(1,'Right')]:
        for j,depth in enumerate([-.29,.31]):
            limb=side+('Front' if j==0 else 'Back')+'Leg';hip=[s*.46,depth,.48];knee=[s*.76,depth-.07,.26]
            ENEMY_RIGS['Burrow_Mimic'][limb+'Upper']={'parent':'Torso','pivot':hip}
            ENEMY_RIGS['Burrow_Mimic'][limb+'Lower']={'parent':limb+'Upper','pivot':knee}

    # Declare pivots per model and source component for downstream mesh-node parenting.
    for name,a in A.items():
        if name not in ENEMY_RIGS: continue
        for part in a['parts']:
            part['joint']=part.get('joint','Torso')
            if part['joint'] not in ENEMY_RIGS[name]: part['joint']='Torso'
