
f = open("6b0x.pdb", "r")
lines = f.readlines()
f.close()
atomCount = 50

nf = open("testData.pdb", "w")

for l in lines:
    if (l.split()[0] == "ATOM"):
        if (atomCount <= 0):
            continue
        else:
            atomCount -= 1
    
    nf.write(l)
