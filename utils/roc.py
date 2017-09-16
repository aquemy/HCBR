import numpy as np
import matplotlib.pyplot as plt
import sys

ID_ROW=0
REAL_ROW=1
GUESS_ROW=2
SCORE_1=5
SCORE_0=6

path = sys.argv[1]
file_name = path.split('/')[-1].split('.')[0]

with open(path) as f:
    data = f.readlines()

p = 1000
n = len(data)

Y = np.ndarray(shape=(n,1), dtype=int, order='F')
T = np.ndarray(shape=(n,1), dtype=float, order='F')
for i in range(0, n):
	e = data[i].split()
	Y[i] = int(e[REAL_ROW])
	T[i] = float(e[SCORE_1]) / (float(e[SCORE_1]) + float(e[SCORE_0]))

thresholds = np.linspace(1,0,p +1)
ROC = np.zeros((p+1,2))

for i in range(p+1):
    t = thresholds[i]

    # Classifier / label agree and disagreements for current threshold.
    TP_t = np.logical_and( T > t, Y==1 ).sum()
    TN_t = np.logical_and( T <=t, Y==0 ).sum()
    FP_t = np.logical_and( T > t, Y==0 ).sum()
    FN_t = np.logical_and( T <=t, Y==1 ).sum()

    # Compute false positive rate for current threshold.
    FPR_t = FP_t / float(FP_t + TN_t)
    ROC[i,0] = FPR_t

    # Compute true  positive rate for current threshold.
    TPR_t = TP_t / float(TP_t + FN_t)
    ROC[i,1] = TPR_t

# Plot the ROC curve.
fig = plt.figure(figsize=(6,6))
plt.plot(ROC[:,0], ROC[:,1], lw=2)
plt.xlim(-0.1,1.1)
plt.ylim(-0.1,1.1)
plt.xlabel('$FPR(t)$')
plt.ylabel('$TPR(t)$')
plt.grid()

AUC = 0.
for i in range(p):
    AUC += (ROC[i+1,0]-ROC[i,0]) * (ROC[i+1,1]+ROC[i,1])
AUC *= 0.5

plt.title('ROC curve, AUC = %.4f'%AUC)
plt.show()