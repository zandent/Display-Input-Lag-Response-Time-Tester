# Example of simple echo server
# www.solusipse.net

import socket
import time
import matplotlib.pyplot as plt
# create plot
plt.ion() # <-- work in "interactive mode"
fig, ax = plt.subplots()
fig.canvas.set_window_title('Response Time Test')
ax.set_title("Input Lag Results")

def listen():
    time_result = []
    connection = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    connection.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    connection.bind(('0.0.0.0', 9090))
    connection.listen(1)
    print("Server opened on port 9090")
    while True:
        current_connection, address = connection.accept()
        while True:
            data = current_connection.recv(8)
            SERVER_VALUE = data[4:8]
            SERVER_VALUE = SERVER_VALUE[::-1]
            DATA_VALUE = int.from_bytes(SERVER_VALUE, byteorder='big')
            DATA_VALUE = float(DATA_VALUE)/100000
            if(len(time_result) < 200):
                time_result.append(DATA_VALUE)
            else:
                print("PLOT!")
                plt.cla()
                plt.ylim(0, 50)
                ax.plot(time_result, color='r')
                plt.show()
                plt.pause(0.0001) # <-- sets the current plot until refreshed
                time_result = []
            #current_connection.send(data)
            #print("POST VALUE:",DATA_VALUE, " ms")


if __name__ == "__main__":
    try:
        listen()
    except KeyboardInterrupt:
        pass
