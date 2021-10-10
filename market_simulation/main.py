import random
import matplotlib.pyplot as plt
import numpy as np


def coin_drow(count):
    random.seed()
    x = np.arange(count+1)
    x = x*100/count
    y = [0]
    for drow in range(0, count):
        y_point = random.randint(0, 2)
        if y_point == 2:
            y.append(y[-1]+1)
        elif y_point == 1:
            y.append(y[-1])
        else:
            y.append(y[-1]-1)
    return x, y


x, y = coin_drow(2000)
print(x, y)
fig = plt.figure(figsize=(20, 10))
plt.plot(x, y, label='MCD')
plt.legend()
plt.show()
