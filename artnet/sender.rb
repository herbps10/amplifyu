require 'socket'

socket = UDPSocket.new

data = ['A', 'r', 't', '-', 'N', 'e', 't'].map { |chr| chr.ord }

socket.send(data.pack('c*'), 0, "192.168.1.9", 6454)
