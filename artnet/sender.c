#include <sys/socket.h>
#include <sys/types.h>
#include <stdlib.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <time.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>


int bytes_sent;
int server_sock;
char send_msg[100];

struct sockaddr_in to_addr;

int main() {
  to_addr.sin_family = AF_INET;
  to_addr.sin_port = 6454;
  to_addr.sin_addr.s_addr = inet_addr("192.168.1.9");

  bytes_sent = sendto(server_sock, send_msg, sizeof(send_msg), 0, (struct sockaddr *)&to_addr, sizeof(to_addr));

  return 0;
}
